-- ============================================================================
-- EventSystem.lua — 事故/奇观触发系统（v0.4：10+ 事故卡片）
--
-- 触发逻辑：
--   1. 监听多种游戏事件，命中"触发上下文"后按 baseChance 掷骰
--   2. 全局冷却 cooldown_，避免事故连续刷屏
--   3. 通过 OrgGenerator.incidentModifiers 提供组织架构差异化
-- ============================================================================

local EventBus = require("core.EventBus")
local E = EventBus.Events

local EventSystem = {}

local cooldown_ = 0
local OrgGenerator = nil  -- 延迟 require 防循环

-- ============================================================
-- 事故定义表（baseChance 是百分制基准触发率）
-- ============================================================
local INCIDENT_DEFS = {
    -- 反派事故
    { id = "approval_loop",      baseChance = 14, on = "review",        cooldown = 60 },
    { id = "quality_meltdown",   baseChance = 10, on = "msg_reject",    cooldown = 75 },
    { id = "zhongshu_coup",      baseChance = 6,  on = "execute_start", cooldown = 90 },
    { id = "missed_hotspot",     baseChance = 8,  on = "review",        cooldown = 60, requireType = "hot" },
    { id = "typo_storm",         baseChance = 12, on = "acceptance",    cooldown = 60 },
    { id = "creative_block",     baseChance = 10, on = "msg_reject",    cooldown = 70 },
    { id = "ai_strike",          baseChance = 5,  on = "execute_start", cooldown = 90 },
    -- 奇观（中性/正向）
    { id = "midnight_inspiration", baseChance = 7,  on = "execute_start", cooldown = 80 },
    { id = "viral_hit",          baseChance = 8,  on = "settlement_pass", cooldown = 90 },
    { id = "office_romance",     baseChance = 4,  on = "execute_start", cooldown = 120 },
    { id = "boss_coffee",        baseChance = 6,  on = "day_start",    cooldown = 120 },
    { id = "mysterious_client",  baseChance = 18, on = "accept",        cooldown = 60, requireType = "mystery" },
}

-- ============================================================
-- 初始化
-- ============================================================
function EventSystem.Init()
    OrgGenerator = require("systems.OrgGenerator")

    EventBus.On(E.ORDER_PROGRESS, function(_, newStatus)
        if newStatus == "reviewing" then
            EventSystem._tryTrigger("review")
        elseif newStatus == "executing" then
            EventSystem._tryTrigger("execute_start")
        elseif newStatus == "submitted" then
            EventSystem._tryTrigger("acceptance")
        elseif newStatus == "accepted" then
            EventSystem._tryTrigger("accept")
        elseif newStatus == "completed" then
            EventSystem._tryTrigger("settlement_pass")
        end
    end)

    EventBus.On(E.MESSAGE_NEW, function(_, msg)
        if not msg or not msg.text then return end
        if msg.text:find("打回") or msg.text:find("不通过") then
            EventSystem._tryTrigger("msg_reject")
        end
    end)

    EventBus.On(E.DAY_START, function()
        EventSystem._tryTrigger("day_start")
    end)
end

-- ============================================================
-- 触发尝试
-- ============================================================
function EventSystem._tryTrigger(triggerKey)
    if cooldown_ > 0 then return end

    -- 收集匹配此 trigger 的候选
    local candidates = {}
    local activeOrder = require("systems.OrderManager").GetActiveOrder()
    for _, def in ipairs(INCIDENT_DEFS) do
        if def.on == triggerKey then
            -- 类型筛选
            if def.requireType then
                if not activeOrder or activeOrder.type ~= def.requireType then
                    goto continue
                end
            end
            local chance = def.baseChance or 5
            -- 组织架构调节
            local arch = OrgGenerator and OrgGenerator.GetArchetype and OrgGenerator.GetArchetype()
            if arch and arch.incidentModifiers and arch.incidentModifiers[def.id] then
                chance = math.floor(chance * arch.incidentModifiers[def.id])
            end
            if math.random(1, 100) <= chance then
                table.insert(candidates, def)
                break -- 单次触发只挑第一个命中的
            end
            ::continue::
        end
    end

    if #candidates > 0 then
        local def = candidates[1]
        cooldown_ = def.cooldown or 60
        EventBus.Emit(E.INCIDENT_TRIGGER, def.id)
    end
end

function EventSystem.Update(dt)
    if cooldown_ > 0 then
        cooldown_ = math.max(0, cooldown_ - dt)
    end
end

return EventSystem
