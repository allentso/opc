-- ============================================================================
-- ChannelManager.lua — 频道 + 消息队列管理
-- ============================================================================

local EventBus = require("core.EventBus")
local GameConfig = require("config.GameConfig")
local E = EventBus.Events

local ChannelManager = {}

---@class Channel
---@field id string
---@field name string
---@field icon string
---@field type string "public"|"secret"|"workflow"
---@field readonly boolean
---@field visible boolean
---@field messages table[]
---@field unread number

local channels_ = {}          -- id → Channel
local channelOrder_ = {}      -- 有序频道ID列表
local activeChannelId_ = nil  -- 当前查看的频道

--- 初始化默认频道
function ChannelManager.Init()
    channels_ = {}
    channelOrder_ = {}

    -- 公开频道
    ChannelManager._addChannel({
        id = "global",
        name = "全局公告",
        icon = "📢",
        type = "public",
        readonly = false,
    })
    ChannelManager._addChannel({
        id = "workflow",
        name = "工作流",
        icon = "📋",
        type = "workflow",
        readonly = false,
    })
    ChannelManager._addChannel({
        id = "dept_zhongshu",
        name = "中书省",
        icon = GameConfig.DEPT_ICONS.zhongshu,
        type = "public",
        readonly = false,
    })
    ChannelManager._addChannel({
        id = "dept_gongbu",
        name = "工部",
        icon = GameConfig.DEPT_ICONS.gongbu,
        type = "public",
        readonly = false,
    })
    ChannelManager._addChannel({
        id = "dept_menxia",
        name = "门下省",
        icon = GameConfig.DEPT_ICONS.menxia,
        type = "public",
        readonly = false,
    })

    -- 私下频道（默认不可见）
    for _, sc in ipairs(GameConfig.SECRET_CHANNELS) do
        ChannelManager._addChannel({
            id = "secret_" .. sc.id,
            name = sc.name,
            icon = sc.icon or "👁",
            type = "secret",
            readonly = true,
            visible = false,
            condition = sc.condition,
        })
    end

    activeChannelId_ = "global"
    EventBus.Emit(E.CHANNEL_SWITCH, activeChannelId_)
end

--- 内部：添加频道
function ChannelManager._addChannel(config)
    local ch = {
        id = config.id,
        name = config.name,
        icon = config.icon or "#",
        type = config.type or "public",
        readonly = config.readonly or false,
        visible = (config.visible ~= false),
        messages = {},
        unread = 0,
    }
    channels_[ch.id] = ch
    table.insert(channelOrder_, ch.id)
end

--- 推送消息到指定频道
---@param channelId string
---@param message table { sender, dept, text, isSystem, isBoss, timestamp }
function ChannelManager.PushMessage(channelId, message)
    local ch = channels_[channelId]
    if not ch then
        -- 尝试映射 channel 类型到频道ID
        channelId = ChannelManager._resolveChannelId(channelId, message.dept)
        ch = channels_[channelId]
    end
    if not ch then return end

    message.timestamp = message.timestamp or os.time()
    message.channelId = channelId
    table.insert(ch.messages, message)

    -- 未读计数（不是当前频道才计）
    if channelId ~= activeChannelId_ then
        ch.unread = ch.unread + 1
    end

    EventBus.Emit(E.MESSAGE_NEW, channelId, message)
end

--- 根据对话模板中的 channel 类型解析为实际频道ID
---@param channelType string "workflow"|"dept"|"global"|"secret_xxx"
---@param dept string|nil
---@return string
function ChannelManager._resolveChannelId(channelType, dept)
    if channelType == "workflow" then
        return "workflow"
    elseif channelType == "global" then
        return "global"
    elseif channelType == "dept" and dept then
        return "dept_" .. dept
    elseif channelType:sub(1, 7) == "secret_" then
        return channelType
    end
    return "workflow"
end

--- 切换当前频道
---@param channelId string
function ChannelManager.SwitchChannel(channelId)
    local ch = channels_[channelId]
    if not ch or not ch.visible then return end
    activeChannelId_ = channelId
    ch.unread = 0
    EventBus.Emit(E.CHANNEL_SWITCH, channelId)
    if ch.type == "secret" then
        EventBus.Emit(E.SECRET_CHANNEL_OPENED, channelId)
    end
end

--- 获取当前频道ID
---@return string
function ChannelManager.GetActiveChannelId()
    return activeChannelId_
end

--- 获取频道信息
---@param channelId string
---@return Channel|nil
function ChannelManager.GetChannel(channelId)
    return channels_[channelId]
end

--- 获取频道的消息列表
---@param channelId string
---@return table[]
function ChannelManager.GetMessages(channelId)
    local ch = channels_[channelId]
    if not ch then return {} end
    return ch.messages
end

--- 获取所有可见频道列表（按类型分组）
---@return table { public = Channel[], secret = Channel[] }
function ChannelManager.GetVisibleChannels()
    local result = { public = {}, secret = {} }
    for _, id in ipairs(channelOrder_) do
        local ch = channels_[id]
        if ch and ch.visible then
            if ch.type == "secret" then
                table.insert(result.secret, ch)
            else
                table.insert(result.public, ch)
            end
        end
    end
    return result
end

--- 解锁私下频道
---@param secretId string 如 "slacking"
function ChannelManager.UnlockSecretChannel(secretId)
    local fullId = "secret_" .. secretId
    local ch = channels_[fullId]
    if not ch then return end
    if ch.visible then return end -- 已解锁

    ch.visible = true
    -- 保留 SECRET_CHANNELS 配置的原始 icon

    EventBus.Emit(E.CHANNEL_UNLOCKED, fullId, ch.name)
    EventBus.Emit(E.UI_TOAST, "🔓 发现新频道: " .. ch.name)
end

--- 检查频道是否只读（私下频道老板不能发言）
---@param channelId string
---@return boolean
function ChannelManager.IsReadOnly(channelId)
    local ch = channels_[channelId]
    if not ch then return true end
    return ch.readonly
end

--- 创建订单专属工作流频道
---@param orderId number
---@param orderName string
---@return string channelId
function ChannelManager.CreateWorkflowChannel(orderId, orderName)
    local channelId = "workflow_" .. orderId
    -- 检查是否已存在
    if channels_[channelId] then return channelId end

    ChannelManager._addChannel({
        id = channelId,
        name = "工作流·" .. orderName,
        icon = "📋",
        type = "workflow",
        readonly = false,
    })
    EventBus.Emit(E.CHANNEL_CREATED, channelId)
    return channelId
end

--- 清除所有频道数据（重新开始时调用）
function ChannelManager.Reset()
    ChannelManager.Init()
end

return ChannelManager
