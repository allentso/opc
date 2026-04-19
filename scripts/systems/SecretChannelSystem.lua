-- ============================================================================
-- SecretChannelSystem.lua — 私下频道触发条件检测 + 内容生成
-- ============================================================================

local EventBus = require("core.EventBus")
local GameConfig = require("config.GameConfig")
local AgentCaller = require("agent.AgentCaller")
local E = EventBus.Events

local SecretChannelSystem = {}

-- 追踪状态
local stats_ = {
    overwork_days = 0,         -- 工部连续满载天数
    force_approve_count = 0,   -- 老板强制拍板次数
    conflict_count = 0,        -- 部门冲突次数
    zhongshu_orders = 0,       -- 中书省累计参与订单数
    acceptance_failed = 0,     -- 验收未通过次数
}
local unlocked_ = {}          -- 已解锁的频道集合
--- 私下频道懒加载：每日首次打开时再生成（省 API）
local lazyFilled_ = {}

--- 初始化
function SecretChannelSystem.Init()
    stats_ = {
        overwork_days = 0,
        force_approve_count = 0,
        conflict_count = 0,
        zhongshu_orders = 0,
        acceptance_failed = 0,
    }
    unlocked_ = {}
    lazyFilled_ = {}

    EventBus.On(E.BOSS_SKILL_USED, function(skillId)
        if skillId == "force_approve" then
            stats_.force_approve_count = stats_.force_approve_count + 1
            SecretChannelSystem.CheckUnlocks()
        end
    end)

    EventBus.On(E.DAY_START, function()
        SecretChannelSystem._resetDailyLazyFlags()
    end)

    -- 中书省参与订单（每次接订单且 departments 包含 zhongshu）
    EventBus.On(E.ORDER_ACCEPTED, function(order)
        if not order or not order.departments then return end
        for _, d in ipairs(order.departments) do
            if d == "zhongshu" then
                stats_.zhongshu_orders = stats_.zhongshu_orders + 1
                SecretChannelSystem.CheckUnlocks()
                break
            end
        end
    end)

    -- 验收未通过
    EventBus.On(E.WORKFLOW_ACCEPTANCE_PARSED, function(passed)
        if passed == false then
            stats_.acceptance_failed = stats_.acceptance_failed + 1
            SecretChannelSystem.CheckUnlocks()
        end
    end)
end

function SecretChannelSystem._resetDailyLazyFlags()
    for _, sc in ipairs(GameConfig.SECRET_CHANNELS) do
        if unlocked_[sc.id] then
            lazyFilled_[sc.id] = false
        end
    end
end

--- 解锁时允许首次打开再生成
function SecretChannelSystem.ResetLazyContent(secretId)
    lazyFilled_[secretId] = false
end

--- 玩家切换到私下频道时调用 enqueueFn(delay, channelId, message)
function SecretChannelSystem.TryLazyGenerate(secretId, day, enqueueFn)
    if not SecretChannelSystem.IsUnlocked(secretId) then return end
    if lazyFilled_[secretId] then return end
    lazyFilled_[secretId] = true
    local messages = SecretChannelSystem.GenerateContent(secretId, { day = day or 1 })
    for _, msg in ipairs(messages) do
        enqueueFn(msg.delay + 0.2, msg.channel, {
            dept = msg.dept,
            text = msg.text,
        })
    end
end

--- 每日检测（在日结算时调用）
---@param deptStatuses table { gongbu = { workload, maxWorkload } }
function SecretChannelSystem.OnDayEnd(deptStatuses)
    -- 工部「高压」天数：达 max 的 45% 以上即计一天（单订单下也可累积解锁）
    if deptStatuses and deptStatuses.gongbu then
        local g = deptStatuses.gongbu
        local need = math.max(1, math.ceil((g.maxWorkload or 5) * 0.45))
        if g.workload >= need then
            stats_.overwork_days = stats_.overwork_days + 1
        else
            stats_.overwork_days = 0
        end
    end

    SecretChannelSystem.CheckUnlocks()
end

--- 记录冲突
function SecretChannelSystem.RecordConflict()
    stats_.conflict_count = stats_.conflict_count + 1
    SecretChannelSystem.CheckUnlocks()
end

--- 检查解锁条件
function SecretChannelSystem.CheckUnlocks()
    for _, sc in ipairs(GameConfig.SECRET_CHANNELS) do
        if not unlocked_[sc.id] then
            local shouldUnlock = false

            if sc.conditionType == "overwork" then
                shouldUnlock = stats_.overwork_days >= sc.threshold
            elseif sc.conditionType == "force_approve_count" then
                shouldUnlock = stats_.force_approve_count >= sc.threshold
            elseif sc.conditionType == "conflict_count" then
                shouldUnlock = stats_.conflict_count >= sc.threshold
            elseif sc.conditionType == "zhongshu_orders" then
                shouldUnlock = stats_.zhongshu_orders >= sc.threshold
            elseif sc.conditionType == "acceptance_failed" then
                shouldUnlock = stats_.acceptance_failed >= sc.threshold
            end

            if shouldUnlock then
                unlocked_[sc.id] = true
                EventBus.Emit(E.SECRET_UNLOCKED, sc.id, sc.name)
            end
        end
    end
end

--- 为已解锁的私下频道生成内容
---@param channelId string
---@param context table
---@return table[] messages
function SecretChannelSystem.GenerateContent(channelId, context)
    if not unlocked_[channelId] then return {} end
    return AgentCaller.GenerateSecretMessages(channelId, context or {})
end

--- 是否已解锁
---@param channelId string
---@return boolean
function SecretChannelSystem.IsUnlocked(channelId)
    return unlocked_[channelId] == true
end

--- 获取统计数据
---@return table
function SecretChannelSystem.GetStats()
    return stats_
end

return SecretChannelSystem
