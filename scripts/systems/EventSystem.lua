-- ============================================================================
-- EventSystem.lua — 监听订单/消息，低概率触发事故对话（MVP）
-- ============================================================================

local EventBus = require("core.EventBus")
local E = EventBus.Events
local AgentCaller = require("agent.AgentCaller")

local EventSystem = {}

local cooldown_ = 0

function EventSystem.Init()
    EventBus.On(E.ORDER_PROGRESS, function(_, newStatus)
        if newStatus ~= "reviewing" then return end
        if cooldown_ > 0 then return end
        if math.random(1, 100) > 7 then return end
        EventSystem._trigger("approval_loop")
    end)

    EventBus.On(E.MESSAGE_NEW, function(_, msg)
        if not msg or not msg.text then return end
        if cooldown_ > 0 then return end
        if not msg.text:find("打回") then return end
        if math.random(1, 100) > 4 then return end
        EventSystem._trigger("quality_meltdown")
    end)
end

function EventSystem._trigger(incidentId)
    cooldown_ = 45
    EventBus.Emit(E.INCIDENT_TRIGGER, incidentId)
end

function EventSystem.Update(dt)
    if cooldown_ > 0 then
        cooldown_ = math.max(0, cooldown_ - dt)
    end
end

return EventSystem
