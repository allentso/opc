-- ============================================================================
-- MainLayout.lua — 竖屏主布局（聊天常驻 + 右侧索引条 + Overlay 覆盖层）
--
-- 布局结构：
--   StatusBar (44px)
--   ContentArea (flex grow) ← 始终只有一个子视图（swap 切换）
--     默认: ChatMainView (row: ChatColumn + RightStrip)
--     覆盖: ChannelListOverlay / OrderOverlay / SkillOverlay / FinanceOverlay
--   InputBar (50px, overlay 时隐藏)
--
-- 关键实现：
--   UI 库的 SetVisible 不影响 Yoga 布局，所以不能用 visible 切换。
--   改用 RemoveChild / AddChild 方式 swap contentArea 的唯一子视图。
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local EventBus = require("core.EventBus")
local StatusBar = require("ui.StatusBar")
local ChannelListPanel = require("ui.ChannelListPanel")
local ChatPanel = require("ui.ChatPanel")
local InfoPanel = require("ui.InfoPanel")
local OrderQuickPanel = require("ui.OrderQuickPanel")
local ChannelManager = require("systems.ChannelManager")
local GameManager = require("core.GameManager")
local C = GameConfig.COLORS
local E = EventBus.Events

local MainLayout = {}

-- 模块状态
local rootRef_ = nil
local contentRef_ = nil
local inputBarRef_ = nil
local inputFieldRef_ = nil
local sendButtonRef_ = nil
local callbacks_ = {}

local mainColumnRef_ = nil
local tabHostRef_ = nil
local tabBarRef_ = nil
local messageTabViewRef_ = nil
local workbenchTabViewRef_ = nil
local commandTabViewRef_ = nil
local financeTabViewRef_ = nil
local currentTabId_ = "message"

local channelOverlayRef_ = nil
local activeOverlay_ = nil

--- 创建主界面布局
---@param state table { companyName, day, phase, funds, reputation, alert }
---@param callbacks table { onBossSend, onAcceptOrder, onUseSkill }
---@return table widget (root)
function MainLayout.Create(state, callbacks)
    state = state or {}
    callbacks_ = callbacks or {}

    messageTabViewRef_ = MainLayout._createMessageTabView(callbacks_)
    workbenchTabViewRef_ = MainLayout._createWorkbenchTabView(callbacks_)
    commandTabViewRef_ = InfoPanel.Create({
        onAcceptOrder = callbacks_.onAcceptOrder,
        onUseSkill = callbacks_.onUseSkill,
    })
    financeTabViewRef_ = MainLayout._createPlaceholderContent(
        "📊", "财务报表", "查看收支与运营数据（占位）"
    )

    tabHostRef_ = UI.Panel {
        id = "tabHost",
        width = "100%",
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        flexDirection = "column",
        children = {
            messageTabViewRef_,
        },
    }

    tabBarRef_ = MainLayout._createTabBar()

    mainColumnRef_ = UI.Panel {
        id = "mainColumn",
        width = "100%",
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        flexDirection = "column",
        backgroundColor = C.bg_primary,
        children = {
            tabHostRef_,
            tabBarRef_,
        },
    }

    channelOverlayRef_ = MainLayout._createOverlayView(
        "channels", "频道列表",
        ChannelListPanel.Create()
    )

    contentRef_ = UI.Panel {
        id = "contentArea",
        width = "100%",
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        children = {
            mainColumnRef_,
        },
    }

    -- 输入栏
    inputBarRef_ = MainLayout._createInputBar(callbacks_)

    rootRef_ = UI.Panel {
        id = "mainLayout",
        width = "100%",
        height = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_primary,
        children = {
            StatusBar.Create(state),
            contentRef_,
            inputBarRef_,
        },
    }

    -- 监听频道切换 → 自动关闭频道列表 overlay
    EventBus.On(E.CHANNEL_SWITCH, function()
        if activeOverlay_ == "channels" then
            MainLayout._closeOverlay()
        end
        MainLayout.UpdateInputState()
    end)

    -- 监听打开频道列表请求（来自 ChatPanel 的 ☰ 按钮）
    EventBus.On(E.NAV_OPEN_CHANNELS, function()
        MainLayout._openOverlay("channels")
    end)

    return rootRef_
end

-- ============================================================
-- 「消息」标签：全高聊天 + 右侧条
-- ============================================================

function MainLayout._createMessageTabView(callbacks)
    local chatColumn = UI.Panel {
        id = "chatColumn",
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        flexDirection = "column",
        children = {
            UI.Panel {
                id = "chatWrapper",
                width = "100%",
                flexGrow = 1,
                flexShrink = 1,
                flexBasis = 0,
                flexDirection = "column",
                children = { ChatPanel.Create() },
            },
        },
    }

    return UI.Panel {
        id = "messageTabView",
        width = "100%",
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        flexDirection = "row",
        children = {
            chatColumn,
            MainLayout._createRightStrip(),
        },
    }
end

-- ============================================================
-- 「工作台」标签：订单 + 今日策略
-- ============================================================

function MainLayout._createWorkbenchTabView(callbacks)
    local strategyRow = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        alignItems = "center",
        gap = 8,
        paddingLeft = 14,
        paddingRight = 14,
        paddingTop = 10,
        paddingBottom = 10,
        backgroundColor = C.primary_blue_light,
        borderBottomWidth = 1,
        borderColor = C.divider,
        flexShrink = 0,
        children = {
            UI.Label {
                text = "今日策略",
                fontSize = 12,
                fontColor = C.text_secondary,
                fontWeight = "bold",
            },
        },
    }
    for _, s in ipairs(GameConfig.DAILY_STRATEGIES) do
        strategyRow:AddChild(MainLayout._createStrategyPill(s))
    end

    return UI.Panel {
        id = "workbenchTabView",
        width = "100%",
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        flexDirection = "column",
        backgroundColor = C.bg_secondary,
        children = {
            strategyRow,
            OrderQuickPanel.Create({
                onAcceptOrder = callbacks.onAcceptOrder,
            }),
        },
    }
end

function MainLayout._createStrategyPill(s)
    local isHot = (s.id == "hot")
    local bg = isHot and C.accent_light or C.bg_card
    return UI.Panel {
        paddingLeft = 12,
        paddingRight = 12,
        paddingTop = 6,
        paddingBottom = 6,
        borderRadius = GameConfig.UI.radius_lg,
        backgroundColor = bg,
        borderWidth = 1,
        borderColor = C.border,
        cursor = "pointer",
        onClick = function()
            GameManager.SetDailyStrategy(s.id)
        end,
        children = {
            UI.Label {
                text = s.label,
                fontSize = 12,
                fontColor = C.tab_active,
                fontWeight = "bold",
            },
        },
    }
end

-- ============================================================
-- 底栏主导航（飞书式 Tab）
-- ============================================================

function MainLayout._createTabBar()
    local     bar = UI.Panel {
        id = "mainTabBar",
        width = "100%",
        height = GameConfig.UI.tab_bar_height,
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "spaceEvenly",
        backgroundColor = C.bg_tab_bar,
        borderTopWidth = 1,
        borderColor = C.divider,
        flexShrink = 0,
    }
    local tabs = {
        { id = "message", label = "消息" },
        { id = "workbench", label = "工作台" },
        { id = "command", label = "指挥" },
        { id = "finance", label = "财务" },
    }
    for _, t in ipairs(tabs) do
        bar:AddChild(MainLayout._createTabItem(t.id, t.label))
    end
    return bar
end

function MainLayout._createTabItem(id, label)
    local isActive = (currentTabId_ == id)
    return UI.Panel {
        id = "tabItem_" .. id,
        flexGrow = 1,
        height = "100%",
        justifyContent = "center",
        alignItems = "center",
        cursor = "pointer",
        borderTopWidth = isActive and 2 or 0,
        borderColor = C.primary_blue,
        onClick = function()
            MainLayout._selectTab(id)
        end,
        children = {
            UI.Label {
                text = label,
                fontSize = 12,
                fontColor = isActive and C.tab_active or C.tab_inactive,
                fontWeight = isActive and "bold" or "normal",
            },
        },
    }
end

function MainLayout._selectTab(tabId)
    if currentTabId_ == tabId and not activeOverlay_ then return end
    currentTabId_ = tabId

    local view
    if tabId == "message" then
        view = messageTabViewRef_
    elseif tabId == "workbench" then
        view = workbenchTabViewRef_
    elseif tabId == "command" then
        view = commandTabViewRef_
    elseif tabId == "finance" then
        view = financeTabViewRef_
    else
        return
    end

    tabHostRef_:ClearChildren()
    tabHostRef_:AddChild(view)

    MainLayout._restyleTabBar()
    MainLayout.UpdateInputState()
end

function MainLayout._restyleTabBar()
    if not tabBarRef_ then return end
    local tabs = { "message", "workbench", "command", "finance" }
    local labels = { message = "消息", workbench = "工作台", command = "指挥", finance = "财务" }
    tabBarRef_:ClearChildren()
    for _, tid in ipairs(tabs) do
        tabBarRef_:AddChild(MainLayout._createTabItem(tid, labels[tid]))
    end
end


-- ============================================================
-- 右侧频道导航条（替代原图标索引条）
-- ============================================================

local rightStripRef_ = nil
local channelListInStripRef_ = nil

function MainLayout._createRightStrip()
    channelListInStripRef_ = UI.Panel {
        id = "stripChannelList",
        width = "100%",
        flexDirection = "column",
        gap = 2,
        paddingTop = 2, paddingBottom = 4,
    }

    rightStripRef_ = UI.Panel {
        id = "rightStrip",
        width = 76,
        height = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_secondary,
        borderLeftWidth = 1,
        borderColor = C.divider,
        flexShrink = 0,
        children = {
            -- 小标题
            UI.Panel {
                width = "100%",
                paddingLeft = 8, paddingTop = 8, paddingBottom = 4,
                flexShrink = 0,
                children = {
                    UI.Label {
                        text = "频道",
                        fontSize = 10,
                        fontColor = C.text_muted,
                        fontWeight = "bold",
                    },
                },
            },
            -- 频道列表（可滚动）
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexShrink = 1,
                flexBasis = 0,
                showScrollbar = false,
                children = {
                    channelListInStripRef_,
                },
            },
            UI.Panel {
                width = "100%",
                flexDirection = "column",
                paddingTop = 4, paddingBottom = 6,
                borderTopWidth = 1,
                borderColor = C.divider,
                flexShrink = 0,
                children = MainLayout._buildStripShortcutChildren(),
            },
        },
    }

    -- 初始填充频道
    MainLayout._refreshStripChannels()

    -- 监听频道事件 → 刷新右侧条
    EventBus.On(E.CHANNEL_SWITCH, function()
        MainLayout._refreshStripChannels()
    end)
    EventBus.On(E.MESSAGE_NEW, function()
        MainLayout._refreshStripChannels()
    end)
    EventBus.On(E.CHANNEL_UNLOCKED, function()
        MainLayout._refreshStripChannels()
    end)

    return rightStripRef_
end

--- 刷新右侧频道图标列表
function MainLayout._refreshStripChannels()
    if not channelListInStripRef_ then return end
    channelListInStripRef_:ClearChildren()

    local channels = ChannelManager.GetVisibleChannels()
    local activeId = ChannelManager.GetActiveChannelId()

    for _, ch in ipairs(channels.public) do
        channelListInStripRef_:AddChild(MainLayout._createChannelStripItem(ch, activeId))
    end
    for _, ch in ipairs(channels.secret) do
        channelListInStripRef_:AddChild(MainLayout._createChannelStripItem(ch, activeId))
    end
end

--- 单个频道条目（头像 + 频道名，横向排列）
function MainLayout._createChannelStripItem(channel, activeId)
    local isActive = (channel.id == activeId)
    local isSecret = (channel.type == "secret")
    local deptId = channel.dept or channel.id
    local badgeColor = isSecret and C.channel_secret or (GameConfig.DEPT_BADGE_COLORS[deptId] or C.accent)
    local shortName = GameConfig.DEPT_SHORT[deptId] or string.sub(channel.name, 1, 1)
    local hasUnread = channel.unread and channel.unread > 0
    local displayName = string.sub(channel.name, 1, 4)

    return UI.Panel {
        width = "100%",
        height = 44,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 6, paddingRight = 6,
        gap = 5,
        borderRadius = 6,
        marginLeft = 4, marginRight = 4,
        backgroundColor = isActive and C.bg_selected or { 0, 0, 0, 0 },
        cursor = "pointer",
        flexShrink = 0,
        onClick = function()
            ChannelManager.SwitchChannel(channel.id)
        end,
        onPointerEnter = function(_, w)
            if channel.id ~= ChannelManager.GetActiveChannelId() then
                w:SetStyle({ backgroundColor = C.bg_hover })
            end
        end,
        onPointerLeave = function(_, w)
            if channel.id ~= ChannelManager.GetActiveChannelId() then
                w:SetStyle({ backgroundColor = { 0, 0, 0, 0 } })
            end
        end,
        children = {
            -- 头像圆
            UI.Panel {
                width = 28, height = 28,
                borderRadius = 14,
                backgroundColor = badgeColor,
                justifyContent = "center",
                alignItems = "center",
                flexShrink = 0,
                children = {
                    UI.Label {
                        text = isSecret and "🔒" or shortName,
                        fontSize = isSecret and 12 or 11,
                        fontColor = C.text_white,
                        fontWeight = "bold",
                    },
                },
            },
            -- 频道名
            UI.Label {
                text = displayName,
                fontSize = 11,
                fontColor = isActive and C.text_primary or C.text_secondary,
                fontWeight = isActive and "bold" or "normal",
                flexShrink = 1,
            },
            -- 未读红点
            hasUnread and UI.Panel {
                minWidth = 16, height = 16,
                borderRadius = 8,
                backgroundColor = C.danger,
                justifyContent = "center",
                alignItems = "center",
                paddingLeft = 3, paddingRight = 3,
                flexShrink = 0,
                children = {
                    UI.Label {
                        text = tostring(channel.unread),
                        fontSize = 9,
                        fontColor = C.text_white,
                        fontWeight = "bold",
                    },
                },
            } or nil,
        },
    }
end

function MainLayout._buildStripShortcutChildren()
    local ch = {}
    for _, item in ipairs(GameConfig.UI.sidebar_items) do
        table.insert(ch, MainLayout._createStripBtn(item.icon, item.label, item.id))
    end
    return ch
end

--- 右侧条快捷入口 → 主导航 / 频道抽屉
function MainLayout._createStripBtn(icon, label, actionId)
    return UI.Panel {
        width = "100%",
        height = 34,
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "center",
        gap = 3,
        borderRadius = GameConfig.UI.radius_sm,
        marginLeft = 4, marginRight = 4,
        cursor = "pointer",
        onClick = function()
            if actionId == "channels" then
                MainLayout._openOverlay("channels")
            else
                MainLayout._closeOverlay()
                if actionId == "workbench" then
                    MainLayout._selectTab("workbench")
                elseif actionId == "skills" then
                    MainLayout._selectTab("command")
                elseif actionId == "finance" then
                    MainLayout._selectTab("finance")
                end
            end
        end,
        onPointerEnter = function(_, w)
            w:SetStyle({ backgroundColor = C.bg_hover })
        end,
        onPointerLeave = function(_, w)
            w:SetStyle({ backgroundColor = { 0, 0, 0, 0 } })
        end,
        children = {
            UI.Label { text = icon, fontSize = 13 },
            UI.Label {
                text = label,
                fontSize = 9,
                fontColor = C.text_secondary,
            },
        },
    }
end

-- ============================================================
-- Overlay 覆盖层（通用包装器：← 返回标题 + 内容）
-- ============================================================

function MainLayout._createOverlayView(id, title, contentChild)
    return UI.Panel {
        id = "overlay_" .. id,
        width = "100%",
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
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
                backgroundColor = C.bg_primary,
                borderBottomWidth = 1,
                borderColor = C.divider,
                flexShrink = 0,
                children = {
                    -- 返回按钮
                    UI.Panel {
                        width = 40, height = 40,
                        borderRadius = 20,
                        justifyContent = "center",
                        alignItems = "center",
                        cursor = "pointer",
                        onClick = function()
                            MainLayout._closeOverlay()
                        end,
                        onPointerEnter = function(_, w) w:SetStyle({ backgroundColor = C.bg_hover }) end,
                        onPointerLeave = function(_, w) w:SetStyle({ backgroundColor = { 0, 0, 0, 0 } }) end,
                        children = {
                            UI.Label {
                                text = "←",
                                fontSize = 20,
                                fontColor = C.text_primary,
                            },
                        },
                    },
                    -- 标题
                    UI.Label {
                        text = title,
                        fontSize = 16,
                        fontColor = C.text_primary,
                        fontWeight = "bold",
                        marginLeft = 4,
                    },
                },
            },

            -- 内容区
            contentChild,
        },
    }
end

-- ============================================================
-- Overlay 打开/关闭 (swap children 方式)
-- ============================================================

function MainLayout._openOverlay(name)
    if activeOverlay_ == name then return end

    -- 先关闭已打开的 overlay
    if activeOverlay_ then
        MainLayout._closeOverlay()
    end

    activeOverlay_ = name

    contentRef_:RemoveChild(mainColumnRef_)

    -- 添加目标 overlay
    local overlayRef = MainLayout._getOverlayRef(name)
    if overlayRef then
        contentRef_:AddChild(overlayRef)
    end

    -- 隐藏输入栏（overlay 时不需要输入）
    -- 用 height=0 + overflow hidden 代替 SetVisible
    inputBarRef_:SetStyle({
        height = 0,
        paddingTop = 0, paddingBottom = 0,
        borderTopWidth = 0,
        overflow = "hidden",
    })

    -- 打开频道列表时刷新
    if name == "channels" then
        ChannelListPanel.Refresh()
    end
end

function MainLayout._closeOverlay()
    if not activeOverlay_ then return end

    -- 从 contentArea 移除当前 overlay
    local overlayRef = MainLayout._getOverlayRef(activeOverlay_)
    if overlayRef then
        contentRef_:RemoveChild(overlayRef)
    end

    activeOverlay_ = nil

    contentRef_:AddChild(mainColumnRef_)

    -- 恢复输入栏
    inputBarRef_:SetStyle({
        height = GameConfig.UI.input_bar_height,
        paddingTop = 0, paddingBottom = 0,
        borderTopWidth = 1,
        overflow = "visible",
    })
end

function MainLayout._getOverlayRef(name)
    if name == "channels" then return channelOverlayRef_ end
    return nil
end

-- ============================================================
-- 输入栏
-- ============================================================

function MainLayout._createInputBar(callbacks)
    local activeId = ChannelManager.GetActiveChannelId()
    local isReadOnly = ChannelManager.IsReadOnly(activeId)

    inputFieldRef_ = UI.TextField {
        id = "mainInput",
        flexGrow = 1,
        height = 36,
        placeholder = isReadOnly and "此频道仅可旁观..." or "@部门 下达命令...",
        fontSize = 13,
        disabled = isReadOnly,
        backgroundColor = C.bg_input,
        borderRadius = 20,
        borderWidth = 1,
        borderColor = C.border,
        paddingLeft = 14, paddingRight = 14,
        onSubmit = function(field, text)
            if text and #text > 0 and callbacks.onBossSend then
                callbacks.onBossSend(text)
                field:Clear()
            end
        end,
    }

    inputBarRef_ = UI.Panel {
        id = "inputBar",
        width = "100%",
        height = GameConfig.UI.input_bar_height,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 12, paddingRight = 12,
        gap = 8,
        backgroundColor = C.bg_bottombar,
        borderTopWidth = 1,
        borderColor = C.divider,
        flexShrink = 0,
        children = {
            inputFieldRef_,
            (function()
                sendButtonRef_ = UI.Button {
                    id = "sendButton",
                    text = "发送",
                    width = 56,
                    height = 36,
                    fontSize = 13,
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
                return sendButtonRef_
            end)(),
        },
    }

    MainLayout.UpdateInputState()
    return inputBarRef_
end

-- ============================================================
-- 占位内容（未开放的功能）
-- ============================================================

function MainLayout._createPlaceholderContent(icon, title, desc)
    return UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        flexDirection = "column",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = C.bg_secondary,
        gap = 12,
        children = {
            UI.Label { text = icon, fontSize = 48 },
            UI.Label {
                text = title,
                fontSize = 20,
                fontColor = C.text_primary,
                fontWeight = "bold",
            },
            UI.Label {
                text = desc,
                fontSize = 13,
                fontColor = C.text_muted,
            },
            UI.Panel {
                marginTop = 8,
                backgroundColor = C.accent_light,
                paddingLeft = 16, paddingRight = 16,
                paddingTop = 8, paddingBottom = 8,
                borderRadius = 8,
                children = {
                    UI.Label {
                        text = "🚧 即将开放",
                        fontSize = 13,
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
            isReadOnly and "此频道仅可旁观…" or "@部门 下达命令…"
        )
    end
end

return MainLayout
