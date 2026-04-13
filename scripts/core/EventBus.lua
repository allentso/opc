-- ============================================================================
-- EventBus.lua — 轻量级事件总线（解耦模块间通信）
-- ============================================================================

local EventBus = {}

local listeners_ = {}

--- 订阅事件
---@param event string
---@param callback function
---@return function unsubscribe 取消订阅函数
function EventBus.On(event, callback)
    if not listeners_[event] then
        listeners_[event] = {}
    end
    table.insert(listeners_[event], callback)
    -- 返回取消订阅函数
    return function()
        EventBus.Off(event, callback)
    end
end

--- 取消订阅
---@param event string
---@param callback function
function EventBus.Off(event, callback)
    local cbs = listeners_[event]
    if not cbs then return end
    for i = #cbs, 1, -1 do
        if cbs[i] == callback then
            table.remove(cbs, i)
            break
        end
    end
end

--- 触发事件
---@param event string
---@param ... any
function EventBus.Emit(event, ...)
    local cbs = listeners_[event]
    if not cbs then return end
    for i = 1, #cbs do
        cbs[i](...)
    end
end

--- 清除所有监听
function EventBus.Clear()
    listeners_ = {}
end

-- 事件名称常量（集中定义，避免拼写错误）
EventBus.Events = {
    -- 游戏流程
    GAME_START        = "game:start",
    DAY_START         = "game:day_start",
    DAY_END           = "game:day_end",
    PHASE_CHANGE      = "game:phase_change",

    -- 频道消息
    MESSAGE_NEW       = "channel:message_new",
    CHANNEL_CREATED   = "channel:created",
    CHANNEL_SWITCH    = "channel:switch",
    CHANNEL_UNLOCKED  = "channel:unlocked",

    -- 订单
    ORDER_NEW         = "order:new",
    ORDER_ACCEPTED    = "order:accepted",
    ORDER_PROGRESS    = "order:progress",
    ORDER_SUBMITTED   = "order:submitted",
    ORDER_RESULT      = "order:result",
    WORKFLOW_ACCEPTANCE_PARSED = "workflow:acceptance_parsed",

    -- 老板操作
    BOSS_MESSAGE      = "boss:message",
    BOSS_SKILL_USED   = "boss:skill_used",
    BOSS_SKILL_READY  = "boss:skill_ready",

    -- 组织
    ORG_CREATED       = "org:created",
    ORG_RESTRUCTURED  = "org:restructured",

    -- 事故
    INCIDENT_TRIGGER  = "incident:trigger",

    -- 经济
    FUNDS_CHANGED     = "economy:funds_changed",
    REPUTATION_CHANGED = "economy:reputation_changed",

    -- 私下频道
    SECRET_UNLOCKED   = "secret:unlocked",
    SECRET_MESSAGE    = "secret:message",
    SECRET_CHANNEL_OPENED = "secret:channel_opened",

    -- UI
    UI_REFRESH        = "ui:refresh",
    UI_TOAST          = "ui:toast",
    UI_MODAL          = "ui:modal",
    TAB_SWITCH        = "ui:tab_switch",

    -- 导航
    NAV_OPEN_CHANNELS = "nav:open_channels",
    NAV_OPEN_OVERLAY  = "nav:open_overlay",
    NAV_CLOSE_OVERLAY = "nav:close_overlay",
}

return EventBus
