-- ============================================================================
-- MainLayout.lua — 主布局（对齐 HTML 设计稿 v0.4）
--
-- 整体结构：
--   StatusBar
--   ContentArea (flex grow) ← 始终只有一个子视图
--     默认: TabHost（4 个 Tab 视图之一）
--          ┌──────────────────────────────────────────┐
--          │ messageTabView:                          │
--          │   [SidebarLeft 70px] [ChatColumn flex:1] │
--          │                      └ ChatPanel + InputBar │
--          ├──────────────────────────────────────────┤
--          │ workbenchTabView: 工作台滚动列表            │
--          │ commandTabView:  指挥中心滚动列表          │
--          │ financeTabView:  财务报告滚动列表          │
--          └──────────────────────────────────────────┘
--     覆盖: ChannelListOverlay / StrategyOverlay / AcceptanceResultOverlay
--   TabBar (4 tabs)
--
-- 关键变更（v0.4）：
--   • 右侧 76px 频道条 → 左侧 70px 深色频道边栏
--   • 频道边栏仅出现在「消息」Tab 内（其他 Tab 全宽）
--   • 输入栏从根级别下沉到 ChatColumn 内
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local EventBus = require("core.EventBus")
local StatusBar = require("ui.StatusBar")
local ChannelListPanel = require("ui.ChannelListPanel")
local ChatPanel = require("ui.ChatPanel")
local InfoPanel = require("ui.InfoPanel")
local OrderQuickPanel = require("ui.OrderQuickPanel")
local StrategyOverlay = require("ui.StrategyOverlay")
local AcceptanceResultOverlay = require("ui.AcceptanceResultOverlay")
local FinancePanel = require("ui.FinancePanel")
local ChannelManager = require("systems.ChannelManager")
local GameManager = require("core.GameManager")
local C = GameConfig.COLORS
local E = EventBus.Events

local MainLayout = {}

-- ============================================================
-- 模块状态
-- ============================================================
local rootRef_ = nil
local contentRef_ = nil
local callbacks_ = {}

local mainColumnRef_ = nil
local tabHostRef_ = nil
local tabBarRef_ = nil

local messageTabViewRef_ = nil
local workbenchTabViewRef_ = nil
local commandTabViewRef_ = nil
local financeTabViewRef_ = nil
local currentTabId_ = "message"

-- ChatColumn 内组件
local channelSidebarRef_ = nil
local channelSidebarPublicRef_ = nil
local channelSidebarSecretRef_ = nil
local inputBarRef_ = nil
local inputFieldRef_ = nil
local sendButtonRef_ = nil

-- Overlay
local channelOverlayRef_ = nil
local strategyOverlayRef_ = nil
local acceptanceResultOverlayRef_ = nil
local activeOverlay_ = nil

-- ============================================================
-- 创建
-- ============================================================

--- 创建主界面布局
---@param state table { companyName, day, phase, funds, reputation, alert }
---@param callbacks table { onBossSend, onAcceptOrder, onUseSkill }
---@return table widget (root)
function MainLayout.Create(state, callbacks)
    state = state or {}
    callbacks_ = callbacks or {}

    -- 创建各 Tab 视图
    messageTabViewRef_   = MainLayout._createMessageTabView(callbacks_)
    workbenchTabViewRef_ = MainLayout._createWorkbenchTabView(callbacks_)
    commandTabViewRef_   = InfoPanel.Create({
        onAcceptOrder = callbacks_.onAcceptOrder,
        onUseSkill    = callbacks_.onUseSkill,
    })
    financeTabViewRef_   = FinancePanel.Create()

    -- TabHost（动态切换 4 个 Tab 之一）
    tabHostRef_ = UI.Panel {
        id = "tabHost",
        width = "100%",
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        flexDirection = "column",
        children = { messageTabViewRef_ },
    }

    -- TabBar
    tabBarRef_ = MainLayout._createTabBar()

    -- mainColumn（默认显示）
    mainColumnRef_ = UI.Panel {
        id = "mainColumn",
        width = "100%",
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        flexDirection = "column",
        backgroundColor = C.bg_primary,
        children = { tabHostRef_, tabBarRef_ },
    }

    -- 频道列表 overlay
    channelOverlayRef_ = MainLayout._createOverlayView(
        "channels", "频道列表",
        ChannelListPanel.Create()
    )

    -- 今日策略 overlay
    strategyOverlayRef_ = MainLayout._createOverlayView(
        "strategy", "今日策略",
        StrategyOverlay.Create()
    )

    -- 验收结果 overlay
    acceptanceResultOverlayRef_ = MainLayout._createOverlayView(
        "acceptance_result", "验收结果",
        AcceptanceResultOverlay.Create()
    )

    -- 内容区（mainColumn 与 overlay 互斥）
    contentRef_ = UI.Panel {
        id = "contentArea",
        width = "100%",
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        children = { mainColumnRef_ },
    }

    rootRef_ = UI.Panel {
        id = "mainLayout",
        width = "100%",
        height = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_primary,
        children = {
            StatusBar.Create(state),
            contentRef_,
        },
    }

    -- 事件订阅
    EventBus.On(E.CHANNEL_SWITCH, function()
        if activeOverlay_ == "channels" then
            MainLayout._closeOverlay()
        end
        MainLayout._refreshSidebar()
        MainLayout.UpdateInputState()
    end)
    EventBus.On(E.MESSAGE_NEW, function()
        MainLayout._refreshSidebar()
    end)
    EventBus.On(E.CHANNEL_UNLOCKED, function()
        MainLayout._refreshSidebar()
    end)
    EventBus.On(E.NAV_OPEN_CHANNELS, function()
        MainLayout._openOverlay("channels")
    end)
    EventBus.On(E.NAV_OPEN_OVERLAY, function(name)
        MainLayout._openOverlay(name)
    end)
    EventBus.On(E.NAV_CLOSE_OVERLAY, function()
        MainLayout._closeOverlay()
    end)

    return rootRef_
end

-- ============================================================
-- 「消息」Tab：左侧 70px 深色频道边栏 + 主聊天区 + 输入栏
-- ============================================================

function MainLayout._createMessageTabView(callbacks)
    -- 左侧深色频道边栏
    channelSidebarRef_ = MainLayout._createChannelSidebar()

    -- 输入栏（属于消息 tab）
    inputBarRef_ = MainLayout._createInputBar(callbacks)

    -- 主聊天列（聊天 + 输入栏垂直堆叠）
    local chatColumn = UI.Panel {
        id = "chatColumn",
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        flexDirection = "column",
        children = {
            ChatPanel.Create(),
            inputBarRef_,
        },
    }

    return UI.Panel {
        id = "messageTabView",
        width = "100%",
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        flexDirection = "row",
        children = {
            channelSidebarRef_,
            chatColumn,
        },
    }
end

-- ============================================================
-- 左侧深色频道边栏（70px）
-- ============================================================

function MainLayout._createChannelSidebar()
    -- 公开/私下分组容器
    channelSidebarPublicRef_ = UI.Panel {
        id = "channelSidebarPublic",
        width = "100%",
        flexDirection = "column",
        gap = 2,
        alignItems = "center",
    }
    channelSidebarSecretRef_ = UI.Panel {
        id = "channelSidebarSecret",
        width = "100%",
        flexDirection = "column",
        gap = 2,
        alignItems = "center",
    }

    -- 整体可滚动
    local scroll = UI.ScrollView {
        width = "100%",
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        showScrollbar = false,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "column",
                paddingTop = 6, paddingBottom = 6,
                alignItems = "center",
                children = {
                    -- 「公开」小标题
                    MainLayout._createSidebarLabel("公开"),
                    channelSidebarPublicRef_,
                    -- 分隔线
                    UI.Panel {
                        id = "channelSidebarDivider",
                        width = 36, height = 1,
                        backgroundColor = C.channel_sb_divider,
                        marginTop = 4, marginBottom = 2,
                    },
                    -- 「私下」小标题
                    MainLayout._createSidebarLabel("私下"),
                    channelSidebarSecretRef_,
                },
            },
        },
    }

    local sidebar = UI.Panel {
        id = "channelSidebar",
        width = GameConfig.UI.channel_sidebar_width,
        flexShrink = 0,
        flexGrow = 0,
        flexDirection = "column",
        backgroundColor = C.channel_sb_bg,
        children = { scroll },
    }

    MainLayout._refreshSidebar()
    return sidebar
end

function MainLayout._createSidebarLabel(text)
    return UI.Panel {
        width = "100%",
        paddingTop = 5, paddingBottom = 1,
        justifyContent = "center", alignItems = "center",
        children = {
            UI.Label {
                text = text,
                fontSize = 8,
                fontColor = C.channel_sb_label,
                fontWeight = "bold",
            },
        },
    }
end

--- 刷新频道边栏
function MainLayout._refreshSidebar()
    if not channelSidebarPublicRef_ or not channelSidebarSecretRef_ then return end

    channelSidebarPublicRef_:ClearChildren()
    channelSidebarSecretRef_:ClearChildren()

    local channels = ChannelManager.GetVisibleChannels()
    local activeId = ChannelManager.GetActiveChannelId()

    for _, ch in ipairs(channels.public) do
        channelSidebarPublicRef_:AddChild(MainLayout._createSidebarItem(ch, activeId))
    end
    for _, ch in ipairs(channels.secret) do
        channelSidebarSecretRef_:AddChild(MainLayout._createSidebarItem(ch, activeId))
    end
end

--- 单个频道边栏项（彩色头像 + 频道名 + 未读红点）
function MainLayout._createSidebarItem(channel, activeId)
    local isActive = (channel.id == activeId)
    local isSecret = (channel.type == "secret")
    local hasUnread = channel.unread and channel.unread > 0

    -- 决定头像颜色（优先用 channel.id 或 dept 找对应色）
    local deptId = channel.dept or channel.id
    local badgeColor
    local iconText
    if isSecret then
        badgeColor = C.channel_secret_bg
        iconText = channel.icon or "🔒"
    else
        local key = deptId
        if deptId == "global" then
            badgeColor = GameConfig.DEPT_BADGE_COLORS.global
            iconText = "📢"
        elseif deptId == "workflow" then
            badgeColor = GameConfig.DEPT_BADGE_COLORS.workflow
            iconText = "🔄"
        else
            -- dept_xxx 形式
            local pureDept = deptId:match("^dept_(.+)$") or deptId
            badgeColor = GameConfig.DEPT_BADGE_COLORS[pureDept]
                or GameConfig.DEPT_BADGE_COLORS.global
            iconText = GameConfig.DEPT_SHORT[pureDept] or string.sub(channel.name or "?", 1, 1)
        end
    end

    -- 频道短名（最多 3 字符宽，HTML 用 8px 字号显示）
    local shortLabel = channel.name or ""
    if #shortLabel > 9 then
        -- 中文 3 字
        shortLabel = string.sub(shortLabel, 1, 9)
    end

    local labelColor
    if isActive then
        labelColor = C.channel_sb_label_active
    elseif isSecret then
        labelColor = C.channel_secret_label
    else
        labelColor = C.channel_sb_label
    end

    local activeBg = isActive and C.channel_sb_active_bg or { 0, 0, 0, 0 }

    -- 头像 + 标签 + 未读
    local children = {
        -- 头像方块
        UI.Panel {
            width = GameConfig.UI.channel_avatar_size,
            height = GameConfig.UI.channel_avatar_size,
            borderRadius = 9,
            backgroundColor = badgeColor,
            justifyContent = "center", alignItems = "center",
            flexShrink = 0,
            children = {
                UI.Label {
                    text = iconText,
                    fontSize = 14,
                    fontColor = C.text_white,
                    fontWeight = "bold",
                },
            },
        },
        -- 频道名小字
        UI.Label {
            text = shortLabel,
            fontSize = GameConfig.UI.channel_label_size,
            fontColor = labelColor,
            marginTop = 2,
        },
    }

    if hasUnread then
        table.insert(children, UI.Panel {
            position = "absolute",
            top = 1, right = 6,
            minWidth = 16, height = 14,
            borderRadius = 8,
            backgroundColor = C.danger,
            justifyContent = "center", alignItems = "center",
            paddingLeft = 3, paddingRight = 3,
            borderWidth = 1.5,
            borderColor = C.channel_sb_bg,
            children = {
                UI.Label {
                    text = tostring(math.min(99, channel.unread)),
                    fontSize = 8,
                    fontColor = C.text_white,
                    fontWeight = "bold",
                },
            },
        })
    end

    return UI.Panel {
        width = GameConfig.UI.channel_icon_size,
        height = GameConfig.UI.channel_icon_size,
        flexDirection = "column",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = activeBg,
        borderRadius = 8,
        flexShrink = 0,
        cursor = "pointer",
        position = "relative",
        onClick = function()
            ChannelManager.SwitchChannel(channel.id)
        end,
        onPointerEnter = function(_, w)
            if channel.id ~= ChannelManager.GetActiveChannelId() then
                w:SetStyle({ backgroundColor = C.channel_sb_hover_bg })
            end
        end,
        onPointerLeave = function(_, w)
            if channel.id ~= ChannelManager.GetActiveChannelId() then
                w:SetStyle({ backgroundColor = { 0, 0, 0, 0 } })
            end
        end,
        children = children,
    }
end

-- ============================================================
-- 「工作台」Tab（占位，将由第4批替换）
-- ============================================================

function MainLayout._createWorkbenchTabView(callbacks)
    return UI.Panel {
        id = "workbenchTabView",
        width = "100%",
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        flexDirection = "column",
        backgroundColor = C.bg_primary,
        children = {
            -- 今日策略 banner（点击进入策略页）
            MainLayout._createStrategyBanner(),
            -- 订单列表
            OrderQuickPanel.Create({
                onAcceptOrder = callbacks.onAcceptOrder,
            }),
        },
    }
end

local strategyBannerRef_ = nil
local strategyBannerLabelRef_ = nil
local strategyBannerEffectRef_ = nil

function MainLayout._createStrategyBanner()
    local stratLabel = GameManager.GetDailyStrategyLabel() or "均衡发展"
    local stratEffect = ""
    for _, s in ipairs(GameConfig.DAILY_STRATEGIES) do
        if s.id == GameManager.GetDailyStrategy() then
            stratEffect = s.effect or ""
            break
        end
    end

    strategyBannerLabelRef_ = UI.Label {
        text = "📌 " .. stratLabel,
        fontSize = 13,
        fontColor = C.accent,
        fontWeight = "bold",
    }
    strategyBannerEffectRef_ = UI.Label {
        text = stratEffect,
        fontSize = 10,
        fontColor = C.text_secondary,
    }

    strategyBannerRef_ = UI.Panel {
        id = "workbenchStrategyBanner",
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        backgroundColor = C.bg_card,
        borderRadius = 10,
        borderWidth = 1.5,
        borderColor = C.accent,
        marginLeft = 10, marginRight = 10,
        marginTop = 10, marginBottom = 4,
        paddingLeft = 13, paddingRight = 13,
        paddingTop = 11, paddingBottom = 11,
        cursor = "pointer",
        flexShrink = 0,
        onClick = function()
            EventBus.Emit(E.NAV_OPEN_OVERLAY, "strategy")
        end,
        onPointerEnter = function(_, w)
            w:SetStyle({ backgroundColor = C.accent_light })
        end,
        onPointerLeave = function(_, w)
            w:SetStyle({ backgroundColor = C.bg_card })
        end,
        children = {
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                flexDirection = "column",
                gap = 2,
                children = {
                    UI.Label {
                        text = "今日策略方向",
                        fontSize = 10,
                        fontColor = C.text_secondary,
                    },
                    strategyBannerLabelRef_,
                    strategyBannerEffectRef_,
                },
            },
            UI.Label {
                text = "›",
                fontSize = 18,
                fontColor = C.accent,
                marginLeft = 8,
            },
        },
    }

    -- 订阅策略变更
    EventBus.On(E.UI_REFRESH, function()
        MainLayout._refreshStrategyBanner()
    end)

    return strategyBannerRef_
end

function MainLayout._refreshStrategyBanner()
    if not strategyBannerLabelRef_ then return end
    local stratLabel = GameManager.GetDailyStrategyLabel() or "均衡发展"
    local stratEffect = ""
    for _, s in ipairs(GameConfig.DAILY_STRATEGIES) do
        if s.id == GameManager.GetDailyStrategy() then
            stratEffect = s.effect or ""
            break
        end
    end
    strategyBannerLabelRef_:SetText("📌 " .. stratLabel)
    if strategyBannerEffectRef_ then
        strategyBannerEffectRef_:SetText(stratEffect)
    end
end

-- ============================================================
-- 底栏 Tab（4 个）
-- ============================================================

local TAB_CONFIG = {
    { id = "message",   icon = "💬", label = "消息" },
    { id = "workbench", icon = "📋", label = "工作台" },
    { id = "command",   icon = "⚡", label = "指挥" },
    { id = "finance",   icon = "📊", label = "财务" },
}

function MainLayout._createTabBar()
    local bar = UI.Panel {
        id = "mainTabBar",
        width = "100%",
        height = GameConfig.UI.tab_bar_height,
        flexDirection = "row",
        alignItems = "stretch",
        backgroundColor = C.bg_tab_bar,
        borderTopWidth = 1,
        borderColor = C.divider,
        flexShrink = 0,
    }
    for _, t in ipairs(TAB_CONFIG) do
        bar:AddChild(MainLayout._createTabItem(t.id, t.icon, t.label))
    end
    return bar
end

function MainLayout._createTabItem(id, icon, label)
    local isActive = (currentTabId_ == id)
    local color = isActive and C.tab_active or C.tab_inactive
    return UI.Panel {
        id = "tabItem_" .. id,
        flexGrow = 1, flexShrink = 1,
        height = "100%",
        flexDirection = "column",
        justifyContent = "center", alignItems = "center",
        gap = 2,
        cursor = "pointer",
        paddingTop = 6, paddingBottom = 8,
        onClick = function()
            MainLayout._selectTab(id)
        end,
        children = {
            UI.Label {
                text = icon,
                fontSize = 18,
                fontColor = color,
            },
            UI.Label {
                text = label,
                fontSize = 9,
                fontColor = color,
                fontWeight = isActive and "bold" or "normal",
            },
        },
    }
end

function MainLayout._selectTab(tabId)
    -- 关闭 overlay 后再切换 tab
    if activeOverlay_ then
        MainLayout._closeOverlay()
    end
    if currentTabId_ == tabId then return end
    currentTabId_ = tabId

    local view
    if tabId == "message" then view = messageTabViewRef_
    elseif tabId == "workbench" then view = workbenchTabViewRef_
    elseif tabId == "command" then view = commandTabViewRef_
    elseif tabId == "finance" then view = financeTabViewRef_
    else return end

    tabHostRef_:ClearChildren()
    tabHostRef_:AddChild(view)

    MainLayout._restyleTabBar()
    MainLayout.UpdateInputState()
end

function MainLayout._restyleTabBar()
    if not tabBarRef_ then return end
    tabBarRef_:ClearChildren()
    for _, t in ipairs(TAB_CONFIG) do
        tabBarRef_:AddChild(MainLayout._createTabItem(t.id, t.icon, t.label))
    end
end

-- ============================================================
-- Overlay 覆盖层
-- ============================================================

function MainLayout._createOverlayView(id, title, contentChild)
    return UI.Panel {
        id = "overlay_" .. id,
        width = "100%",
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        flexDirection = "column",
        backgroundColor = C.bg_primary,
        children = {
            -- 顶部返回栏
            UI.Panel {
                width = "100%",
                height = 48,
                flexDirection = "row",
                alignItems = "center",
                paddingLeft = 4, paddingRight = 16,
                backgroundColor = C.bg_card,
                borderBottomWidth = 1,
                borderColor = C.divider,
                flexShrink = 0,
                children = {
                    UI.Panel {
                        width = 40, height = 40,
                        borderRadius = 20,
                        justifyContent = "center", alignItems = "center",
                        cursor = "pointer",
                        onClick = function() MainLayout._closeOverlay() end,
                        onPointerEnter = function(_, w) w:SetStyle({ backgroundColor = C.bg_hover }) end,
                        onPointerLeave = function(_, w) w:SetStyle({ backgroundColor = { 0, 0, 0, 0 } }) end,
                        children = {
                            UI.Label {
                                text = "‹",
                                fontSize = 22,
                                fontColor = C.text_primary,
                            },
                        },
                    },
                    UI.Label {
                        text = title,
                        fontSize = 15,
                        fontColor = C.text_primary,
                        fontWeight = "bold",
                        marginLeft = 4,
                    },
                },
            },
            -- 内容
            contentChild,
        },
    }
end

function MainLayout._openOverlay(name)
    if activeOverlay_ == name then return end
    if activeOverlay_ then MainLayout._closeOverlay() end

    activeOverlay_ = name
    contentRef_:RemoveChild(mainColumnRef_)

    local overlayRef = MainLayout._getOverlayRef(name)
    if overlayRef then
        contentRef_:AddChild(overlayRef)
    end

    MainLayout.UpdateInputState()

    if name == "channels" then
        ChannelListPanel.Refresh()
    end
end

function MainLayout._closeOverlay()
    if not activeOverlay_ then return end
    local overlayRef = MainLayout._getOverlayRef(activeOverlay_)
    if overlayRef then contentRef_:RemoveChild(overlayRef) end

    activeOverlay_ = nil
    contentRef_:AddChild(mainColumnRef_)
    MainLayout.UpdateInputState()
end

function MainLayout._getOverlayRef(name)
    if name == "channels" then return channelOverlayRef_ end
    if name == "strategy" then return strategyOverlayRef_ end
    if name == "acceptance_result" then return acceptanceResultOverlayRef_ end
    return nil
end

-- ============================================================
-- 输入栏（属于消息 Tab，跟 ChatPanel 在同一列）
-- ============================================================

function MainLayout._createInputBar(callbacks)
    local activeId = ChannelManager.GetActiveChannelId()
    local isReadOnly = ChannelManager.IsReadOnly(activeId)

    inputFieldRef_ = UI.TextField {
        id = "mainInput",
        flexGrow = 1,
        height = 36,
        placeholder = isReadOnly and "此频道仅可旁观..." or "@部门 下达命令...",
        fontSize = 12,
        disabled = isReadOnly,
        backgroundColor = C.bg_input,
        borderRadius = 18,
        borderWidth = 1,
        borderColor = C.border,
        paddingLeft = 12, paddingRight = 12,
        onSubmit = function(field, text)
            if text and #text > 0 and callbacks.onBossSend then
                callbacks.onBossSend(text)
                field:Clear()
            end
        end,
    }

    sendButtonRef_ = UI.Button {
        id = "sendButton",
        text = "发送",
        width = 56, height = 36,
        fontSize = 12,
        variant = "primary",
        borderRadius = 18,
        disabled = isReadOnly,
        onClick = function()
            if inputFieldRef_ and callbacks.onBossSend then
                local text = inputFieldRef_:GetValue()
                if text and #text > 0 then
                    callbacks.onBossSend(text)
                    inputFieldRef_:Clear()
                end
            end
        end,
    }

    local bar = UI.Panel {
        id = "inputBar",
        width = "100%",
        height = GameConfig.UI.input_bar_height,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 10, paddingRight = 10,
        gap = 7,
        backgroundColor = C.bg_card,
        borderTopWidth = 1,
        borderColor = C.divider,
        flexShrink = 0,
        children = { inputFieldRef_, sendButtonRef_ },
    }

    return bar
end

-- ============================================================
-- 占位
-- ============================================================

function MainLayout._createPlaceholderContent(icon, title, desc)
    return UI.Panel {
        width = "100%",
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        flexDirection = "column",
        justifyContent = "center", alignItems = "center",
        backgroundColor = C.bg_primary,
        gap = 12,
        children = {
            UI.Label { text = icon, fontSize = 48 },
            UI.Label {
                text = title,
                fontSize = 18,
                fontColor = C.text_primary,
                fontWeight = "bold",
            },
            UI.Label {
                text = desc,
                fontSize = 12,
                fontColor = C.text_muted,
            },
            UI.Panel {
                marginTop = 8,
                backgroundColor = C.accent_light,
                paddingLeft = 14, paddingRight = 14,
                paddingTop = 7, paddingBottom = 7,
                borderRadius = 8,
                children = {
                    UI.Label {
                        text = "🚧 即将开放",
                        fontSize = 12,
                        fontColor = C.accent,
                        fontWeight = "bold",
                    },
                },
            },
        },
    }
end

-- ============================================================
-- 公共方法
-- ============================================================

function MainLayout.GetRoot()
    return rootRef_
end

function MainLayout.UpdateInputState()
    if not inputFieldRef_ or not sendButtonRef_ then return end
    local onMsgTab = (currentTabId_ == "message" and activeOverlay_ == nil)
    local activeId = ChannelManager.GetActiveChannelId()
    local isReadOnly = ChannelManager.IsReadOnly(activeId)
    local disabled = (not onMsgTab) or isReadOnly
    inputFieldRef_:SetDisabled(disabled)
    sendButtonRef_:SetDisabled(disabled)
    if not onMsgTab then
        inputFieldRef_:SetPlaceholder("在「消息」页可发言…")
    else
        inputFieldRef_:SetPlaceholder(
            isReadOnly and "🔒 此频道仅可旁观…" or "@部门 下达命令…"
        )
    end
end

return MainLayout
