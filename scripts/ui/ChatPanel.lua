-- ============================================================================
-- ChatPanel.lua — 聊天面板（对齐 HTML 设计稿 v0.4）
-- 结构：[频道头(28px头像+名+时间)] [聊天消息区]
-- 输入栏由 MainLayout 的 chatColumn 提供（紧贴在 ChatPanel 下方）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local ChannelManager = require("systems.ChannelManager")
local OrderManager = require("systems.OrderManager")
local EventBus = require("core.EventBus")
local C = GameConfig.COLORS
local E = EventBus.Events

local ChatPanel = {}

local containerRef_ = nil
local chatWindowRef_ = nil
local headerAvatarRef_ = nil
local headerAvatarLabelRef_ = nil
local headerNameRef_ = nil
local headerSubtitleRef_ = nil

--- 创建聊天面板
---@return table widget
function ChatPanel.Create()
    containerRef_ = UI.Panel {
        id = "chatPanel",
        width = "100%",
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        backgroundColor = C.bg_primary,
        flexDirection = "column",
        children = {
            ChatPanel._createChannelHeader(),
            ChatPanel._createChatWindow(),
        },
    }

    -- 初始可能是私下频道，应用主题
    ChatPanel._applyThemeForActive()

    EventBus.On(E.CHANNEL_SWITCH, function(channelId)
        ChatPanel._onChannelSwitch(channelId)
        ChatPanel._applyThemeForActive()
    end)

    EventBus.On(E.MESSAGE_NEW, function(channelId, message)
        ChatPanel._onNewMessage(channelId, message)
    end)

    return containerRef_
end

--- 根据当前频道切换浅色/深色主题
function ChatPanel._applyThemeForActive()
    if not containerRef_ then return end
    local activeId = ChannelManager.GetActiveChannelId()
    local ch = ChannelManager.GetChannel(activeId)
    local isSecret = ch and ch.type == "secret"

    if isSecret then
        containerRef_:SetStyle({ backgroundColor = C.secret_bg })
        if chatWindowRef_ then
            chatWindowRef_:SetStyle({ backgroundColor = C.secret_bg })
            -- 若 UI.ChatWindow 不支持动态颜色重写，则下次 ChannelSwitch 重建会自然生效
        end
        if headerAvatarRef_ then
            -- 头部条变深
            local header = containerRef_:FindById("channelHeader")
            if header then
                header:SetStyle({
                    backgroundColor = C.secret_topbar_bg,
                    borderColor = C.secret_bubble_border,
                })
            end
            if headerNameRef_ then headerNameRef_:SetStyle({ fontColor = C.secret_name }) end
            if headerSubtitleRef_ then headerSubtitleRef_:SetStyle({ fontColor = C.secret_text_muted }) end
        end
    else
        containerRef_:SetStyle({ backgroundColor = C.bg_primary })
        if chatWindowRef_ then chatWindowRef_:SetStyle({ backgroundColor = C.bg_primary }) end
        local header = containerRef_:FindById("channelHeader")
        if header then
            header:SetStyle({
                backgroundColor = C.bg_card,
                borderColor = C.divider,
            })
        end
        if headerNameRef_ then headerNameRef_:SetStyle({ fontColor = C.text_primary }) end
        if headerSubtitleRef_ then headerSubtitleRef_:SetStyle({ fontColor = C.text_muted }) end
    end
end

-- ============================================================
-- 频道头部
-- ============================================================

function ChatPanel._createChannelHeader()
    local activeId = ChannelManager.GetActiveChannelId()
    local ch = ChannelManager.GetChannel(activeId)
    local headerInfo = ChatPanel._buildHeaderInfo(ch)

    headerAvatarLabelRef_ = UI.Label {
        text = headerInfo.iconText,
        fontSize = 13,
        fontColor = C.text_white,
        fontWeight = "bold",
    }
    headerAvatarRef_ = UI.Panel {
        width = 28, height = 28,
        borderRadius = 7,
        backgroundColor = headerInfo.badgeColor,
        justifyContent = "center", alignItems = "center",
        flexShrink = 0,
        children = { headerAvatarLabelRef_ },
    }
    headerNameRef_ = UI.Label {
        id = "channelHeaderName",
        text = headerInfo.name,
        fontSize = 13,
        fontColor = C.text_primary,
        fontWeight = "bold",
    }
    headerSubtitleRef_ = UI.Label {
        id = "channelHeaderSubtitle",
        text = headerInfo.subtitle,
        fontSize = 10,
        fontColor = C.text_muted,
    }

    return UI.Panel {
        id = "channelHeader",
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 12, paddingRight = 12,
        paddingTop = 9, paddingBottom = 9,
        backgroundColor = C.bg_card,
        borderBottomWidth = 1,
        borderColor = C.divider,
        flexShrink = 0,
        gap = 7,
        children = {
            headerAvatarRef_,
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                flexDirection = "column",
                children = {
                    headerNameRef_,
                },
            },
            headerSubtitleRef_,
        },
    }
end

--- 构造频道头部信息
function ChatPanel._buildHeaderInfo(ch)
    local info = {
        iconText = "📢",
        badgeColor = C.accent,
        name = ch and ch.name or "频道",
        subtitle = "",
    }
    if not ch then return info end

    local id = ch.id
    if id == "global" then
        info.iconText = "📢"
        info.badgeColor = GameConfig.DEPT_BADGE_COLORS.global
    elseif id == "workflow" then
        info.iconText = "🔄"
        info.badgeColor = GameConfig.DEPT_BADGE_COLORS.workflow
    elseif id and id:sub(1, 5) == "dept_" then
        local pure = id:sub(6)
        info.iconText = GameConfig.DEPT_SHORT[pure] or "?"
        info.badgeColor = GameConfig.DEPT_BADGE_COLORS[pure] or C.accent
    elseif ch.type == "secret" then
        info.iconText = ch.icon or "👁"
        info.badgeColor = C.channel_secret_bg
    end

    -- 副标题：当前订单 / 私下提示 / 时间
    if ch.type == "secret" then
        info.subtitle = "👁 偷窥中"
    else
        local order = OrderManager.GetActiveOrder()
        if order and id == "workflow" then
            info.subtitle = (OrderManager.GetOrderTypeLabel(order.type) or "") ..
                " · " .. (order.name or "")
            if #info.subtitle > 22 then
                info.subtitle = string.sub(info.subtitle, 1, 22) .. "…"
            end
        else
            info.subtitle = os.date("%H:%M")
        end
    end
    return info
end

-- ============================================================
-- 聊天消息窗口
-- ============================================================

function ChatPanel._createChatWindow()
    local activeId = ChannelManager.GetActiveChannelId()
    local messages = ChatPanel._convertMessages(ChannelManager.GetMessages(activeId))

    chatWindowRef_ = UI.ChatWindow {
        id = "chatWindow",
        width = "100%",
        flexGrow = 1, flexBasis = 0,
        messages = messages,
        fontSize = 12,
        backgroundColor = C.bg_primary,
        messageGap = 8,
        bubblePadding = 9,
        colors = {
            bubble_self   = C.bubble_self,
            bubble_other  = C.bubble_other,
            bubble_system = C.bubble_system,
            text          = C.text_primary,
            text_system   = C.text_muted,
            name_self     = C.accent,
            name_other    = C.text_secondary,
        },
    }

    return chatWindowRef_
end

-- ============================================================
-- 事件处理
-- ============================================================

function ChatPanel._onChannelSwitch(channelId)
    local ch = ChannelManager.GetChannel(channelId)
    if not ch then return end

    -- 更新头部
    local info = ChatPanel._buildHeaderInfo(ch)
    if headerAvatarLabelRef_ then headerAvatarLabelRef_:SetText(info.iconText) end
    if headerAvatarRef_ then headerAvatarRef_:SetStyle({ backgroundColor = info.badgeColor }) end
    if headerNameRef_ then headerNameRef_:SetText(info.name) end
    if headerSubtitleRef_ then headerSubtitleRef_:SetText(info.subtitle) end

    -- 更新消息
    if chatWindowRef_ then
        chatWindowRef_:ClearMessages()
        for _, msg in ipairs(ch.messages) do
            chatWindowRef_:AddMessage(ChatPanel._convertOneMessage(msg))
        end
    end
end

function ChatPanel._onNewMessage(channelId, message)
    if channelId ~= ChannelManager.GetActiveChannelId() then return end
    if not chatWindowRef_ then return end
    chatWindowRef_:AddMessage(ChatPanel._convertOneMessage(message))
end

-- ============================================================
-- 消息格式转换
-- ============================================================

function ChatPanel._convertMessages(messages)
    local result = {}
    for _, msg in ipairs(messages) do
        table.insert(result, ChatPanel._convertOneMessage(msg))
    end
    return result
end

function ChatPanel._convertOneMessage(msg)
    local sender = msg.sender or ""
    local isSelf = msg.isBoss == true
    local isSystem = msg.isSystem == true
    local content = msg.text or ""

    -- 事故/奇观消息：用 unicode 框包成卡片
    if isSystem and ChatPanel._looksLikeIncident(content) then
        content = ChatPanel._wrapIncidentCard(content)
    end

    if msg.dept and not msg.sender then
        local deptName = GameConfig.DEPT_NAMES[msg.dept] or msg.dept
        local timeStr = os.date("%H:%M")
        sender = deptName .. "  " .. timeStr
    elseif msg.isBoss then
        sender = "Boss  " .. os.date("%H:%M")
    end

    return {
        sender = sender,
        content = content,
        isSelf = isSelf,
        isSystem = isSystem,
        timestamp = msg.timestamp,
    }
end

--- 判断是否事故/奇观消息（以 ⚠️/💡/🎉/🔮/☕/💕 等图标开头）
local INCIDENT_MARKERS = { "⚠️", "⚠", "💡", "🎉", "🔮", "☕", "💕" }
function ChatPanel._looksLikeIncident(text)
    for _, m in ipairs(INCIDENT_MARKERS) do
        if text:sub(1, #m) == m then return true end
    end
    return false
end

--- 把事故消息包装为带框的卡片（纯文本风格）
function ChatPanel._wrapIncidentCard(text)
    -- 取出第一行作为标题
    local firstLine = text:match("^[^\n]+") or text
    local rest = text:sub(#firstLine + 1)
    if rest:sub(1, 1) == "\n" then rest = rest:sub(2) end

    local lines = {
        "┏━━━━━━━━━━━━━━━━━━━━┓",
        "┃ " .. firstLine,
        "┗━━━━━━━━━━━━━━━━━━━━┛",
    }
    if #rest > 0 then
        table.insert(lines, rest)
    end
    return table.concat(lines, "\n")
end

function ChatPanel.GetInputRef()
    return nil
end

return ChatPanel
