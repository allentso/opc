-- ============================================================================
-- ChatPanel.lua — 聊天面板（竖屏全宽，简化头部）
-- 输入栏在 MainLayout 的底部输入栏
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
local channelHeaderRef_ = nil
local warningBarRef_ = nil

--- 创建聊天面板
---@return table widget
function ChatPanel.Create()
    containerRef_ = UI.Panel {
        id = "chatPanel",
        width = "100%",
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        backgroundColor = C.bg_chat_soft,
        flexDirection = "column",
        children = {
            -- 频道标题栏（简化版）
            ChatPanel._createChannelHeader(),

            -- 警告横幅
            ChatPanel._createWarningBar(),

            -- 聊天消息区
            ChatPanel._createChatWindow(),
        },
    }

    -- 监听频道切换
    EventBus.On(E.CHANNEL_SWITCH, function(channelId)
        ChatPanel._onChannelSwitch(channelId)
    end)

    -- 监听新消息
    EventBus.On(E.MESSAGE_NEW, function(channelId, message)
        ChatPanel._onNewMessage(channelId, message)
    end)

    -- 监听警报变化
    EventBus.On(E.UI_REFRESH, function()
        ChatPanel._updateWarningBar()
    end)

    return containerRef_
end

-- ============================================================
-- 子组件
-- ============================================================

--- 频道标题栏（竖屏简化：单行 频道名 + 副标题）
function ChatPanel._createChannelHeader()
    local activeId = ChannelManager.GetActiveChannelId()
    local ch = ChannelManager.GetChannel(activeId)
    local chName = ch and ch.name or "频道"
    local chIcon = ch and ch.icon or "#"

    local order = OrderManager.GetActiveOrder()
    local subtitle = ""
    if order then
        subtitle = (OrderManager.GetOrderTypeLabel(order.type) or "") ..
            "·" .. (order.name or "")
    end

    channelHeaderRef_ = UI.Panel {
        id = "channelHeader",
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 6, paddingRight = 16,
        paddingTop = 8, paddingBottom = 8,
        backgroundColor = C.bg_chat_soft,
        borderBottomWidth = 1,
        borderColor = C.divider,
        flexShrink = 0,
        children = {
            -- 频道图标
            UI.Panel {
                width = 32, height = 32,
                borderRadius = 16,
                backgroundColor = C.primary_blue,
                justifyContent = "center",
                alignItems = "center",
                flexShrink = 0,
                marginLeft = 6,
                marginRight = 10,
                children = {
                    UI.Label {
                        text = chIcon,
                        fontSize = 14,
                        fontColor = C.text_white,
                        fontWeight = "bold",
                    },
                },
            },

            -- 频道名 + 描述
            UI.Panel {
                flexGrow = 1,
                flexShrink = 1,
                flexDirection = "column",
                gap = 2,
                children = {
                    UI.Label {
                        id = "channelHeaderName",
                        text = chName,
                        fontSize = 15,
                        fontColor = C.text_primary,
                        fontWeight = "bold",
                    },
                    UI.Label {
                        id = "channelHeaderSubtitle",
                        text = subtitle,
                        fontSize = 11,
                        fontColor = C.text_muted,
                    },
                },
            },
        },
    }
    return channelHeaderRef_
end

--- 警告横幅
function ChatPanel._createWarningBar()
    warningBarRef_ = UI.Panel {
        id = "warningBar",
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 6,
        paddingLeft = 16, paddingRight = 16,
        paddingTop = 8, paddingBottom = 8,
        backgroundColor = C.danger_light,
        borderBottomWidth = 1,
        borderColor = C.divider,
        flexShrink = 0,
        visible = false,
        children = {
            UI.Label {
                text = "⚠",
                fontSize = 14,
                fontColor = C.danger,
            },
            UI.Label {
                id = "warningText",
                text = "",
                fontSize = 12,
                fontColor = C.danger,
                fontWeight = "bold",
                flexGrow = 1,
            },
        },
    }
    return warningBarRef_
end

--- 聊天消息窗口
function ChatPanel._createChatWindow()
    local activeId = ChannelManager.GetActiveChannelId()
    local messages = ChatPanel._convertMessages(ChannelManager.GetMessages(activeId))

    chatWindowRef_ = UI.ChatWindow {
        id = "chatWindow",
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        messages = messages,
        fontSize = 13,
        backgroundColor = C.bg_chat_soft,
        messageGap = 10,
        bubblePadding = 10,
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

    -- 更新标题
    if channelHeaderRef_ then
        local nameLabel = channelHeaderRef_:FindById("channelHeaderName")
        local subtitleLabel = channelHeaderRef_:FindById("channelHeaderSubtitle")
        if nameLabel then
            nameLabel:SetText(ch.name)
        end
        if subtitleLabel then
            local order = OrderManager.GetActiveOrder()
            local subtitle = ""
            if order and ch.id == "workflow" then
                subtitle = (OrderManager.GetOrderTypeLabel(order.type) or "") ..
                    "·" .. (order.name or "")
            elseif ch.type == "secret" then
                subtitle = "🔒 仅可旁观"
            end
            subtitleLabel:SetText(subtitle)
        end
    end

    -- 更新消息
    if chatWindowRef_ then
        chatWindowRef_:ClearMessages()
        for _, msg in ipairs(ch.messages) do
            chatWindowRef_:AddMessage(ChatPanel._convertOneMessage(msg))
        end
    end

    ChatPanel._updateWarningBar()
end

function ChatPanel._onNewMessage(channelId, message)
    if channelId ~= ChannelManager.GetActiveChannelId() then return end
    if not chatWindowRef_ then return end

    local converted = ChatPanel._convertOneMessage(message)
    chatWindowRef_:AddMessage(converted)
end

function ChatPanel._updateWarningBar()
    if not warningBarRef_ then return end
    local GameManager = require("core.GameManager")
    local state = GameManager.GetState()
    local alert = state.alert or ""
    if #alert > 0 then
        warningBarRef_:SetVisible(true)
        local textLabel = warningBarRef_:FindById("warningText")
        if textLabel then textLabel:SetText(alert) end
    else
        warningBarRef_:SetVisible(false)
    end
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

    if msg.dept and not msg.sender then
        local deptName = GameConfig.DEPT_NAMES[msg.dept] or msg.dept
        local shortName = GameConfig.DEPT_SHORT[msg.dept] or ""
        local timeStr = os.date("%H:%M")
        sender = "[" .. shortName .. "] " .. deptName .. "  " .. timeStr
    elseif msg.isBoss then
        sender = "[老] 老板  " .. os.date("%H:%M")
    end

    return {
        sender = sender,
        content = msg.text or "",
        isSelf = isSelf,
        isSystem = isSystem,
        timestamp = msg.timestamp,
    }
end

function ChatPanel.GetInputRef()
    return nil
end

return ChatPanel
