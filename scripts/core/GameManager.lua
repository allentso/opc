-- ============================================================================
-- GameManager.lua — 游戏主循环（日程推进、消息调度、订单工作流自动化）
-- ============================================================================

local GameConfig = require("config.GameConfig")
local EventBus = require("core.EventBus")
local ChannelManager = require("systems.ChannelManager")
local OrgGenerator = require("systems.OrgGenerator")
local OrderManager = require("systems.OrderManager")
local BossSkillSystem = require("systems.BossSkillSystem")
local SecretChannelSystem = require("systems.SecretChannelSystem")
local EventSystem = require("systems.EventSystem")
local ShareCardSystem = require("systems.ShareCardSystem")
local AgentCaller = require("agent.AgentCaller")
local ChannelListPanel = require("ui.ChannelListPanel")
local InfoPanel = require("ui.InfoPanel")
local E = EventBus.Events

local GameManager = {}

-- 游戏状态
local state_ = {
    day = 0,
    phase = "morning",
    phaseIndex = 1,
    dayTimer = 0,        -- 当天已过秒数
    funds = GameConfig.INITIAL_FUNDS,
    reputation = GameConfig.INITIAL_REPUTATION,
    companyName = "锐思AI工作室",
    alert = "",
    started = false,
    paused = false,
    dailyStrategy = "balanced",
}

-- 消息调度队列
local messageQueue_ = {}   -- { triggerTime, channelId, message }
local queueTimer_ = 0

-- 订单工作流状态
local workflowPhase_ = nil  -- 当前工作流阶段 nil|"accept"|"execute"|"review"|"acceptance"|"settlement"
local workflowTimer_ = 0
local workflowAutoAdvance_ = false
--- 审查结束后自动推进的下一阶段："acceptance" | "execute"（打回改稿）
local workflowPostReviewNext_ = "acceptance"
--- 是否本次 execute 为打回后的改稿（不再叠加工部负载）
local workflowRevisionExecute_ = false

--- 初始化所有系统
function GameManager.Init()
    math.randomseed(os.time())

    -- 初始化各系统
    ChannelManager.Init()
    OrgGenerator.Init()
    OrderManager.Init()
    BossSkillSystem.Init()
    SecretChannelSystem.Init()
    EventSystem.Init()
    ShareCardSystem.Init()

    -- 注册事件监听
    GameManager._registerEvents()

    print("[GameManager] All systems initialized")
end

--- 注册事件回调
function GameManager._registerEvents()
    -- 老板技能使用
    EventBus.On(E.BOSS_SKILL_USED, function(skillId, config)
        -- 扣费
        if type(config.cost) == "number" then
            GameManager.ChangeFunds(-config.cost, "使用技能: " .. config.name)
        end

        -- 技能效果
        if skillId == "force_approve" then
            -- 强制推进工作流
            if workflowPhase_ == "review" or workflowPhase_ == "execute" then
                workflowAutoAdvance_ = true
                GameManager._advanceWorkflow("acceptance")
                ChannelManager.PushMessage("workflow", {
                    sender = "系统",
                    text = "👔 老板使用了【强制拍板】，跳过审查直接推进！",
                    isSystem = true,
                })
            end
        elseif skillId == "pause_publish" then
            ChannelManager.PushMessage("global", {
                sender = "系统",
                text = "⏸️ 老板使用了【暂停发布】，暂停当前发布流程。",
                isSystem = true,
            })
        elseif skillId == "emergency_reorg" then
            local ok = OrgGenerator.SwapReportingPair()
            ChannelManager.PushMessage("global", {
                sender = "系统",
                text = ok and "🔄 已紧急调整部门协作关系（汇报线已对调）。" or "🔄 重组指令已记录（当前架构下无可调对）。" ,
                isSystem = true,
            })
        elseif skillId == "temp_outsource" then
            GameManager._applyTempOutsource()
        end
    end)

    -- 订单接取
    EventBus.On(E.ORDER_ACCEPTED, function(order)
        ChannelManager.PushMessage("workflow", {
            sender = "系统",
            text = "📋 新订单已接取：" .. order.name .. " (¥" .. order.reward .. ")",
            isSystem = true,
        })
        -- 启动工作流
        GameManager._startWorkflow(order)
    end)

    -- 私下频道解锁
    EventBus.On(E.SECRET_UNLOCKED, function(secretId, name)
        ChannelManager.UnlockSecretChannel(secretId)
        SecretChannelSystem.ResetLazyContent(secretId)
        ChannelListPanel.Refresh()
    end)

    EventBus.On(E.INCIDENT_TRIGGER, function(incidentId)
        local msgs = AgentCaller.GenerateIncidentMessages(incidentId)
        for _, m in ipairs(msgs) do
            local isSys = (m.dept == "system")
            GameManager._enqueueMessage(m.delay, m.channel, {
                dept = m.dept,
                text = m.text,
                isSystem = isSys,
                sender = isSys and "系统" or nil,
            })
        end
    end)

    EventBus.On(E.SECRET_CHANNEL_OPENED, function(fullChannelId)
        local id = fullChannelId:match("^secret_(.+)$")
        if not id then return end
        SecretChannelSystem.TryLazyGenerate(id, state_.day, GameManager.EnqueueDelayedMessage)
    end)

    -- API 验收：LLM 返回 JSON 时覆盖模拟分数
    EventBus.On(E.WORKFLOW_ACCEPTANCE_PARSED, function(passed, score)
        if workflowPhase_ == "acceptance" and OrderManager.GetActiveOrder() then
            OrderManager.SetAcceptanceResult(passed, score)
        end
    end)
end

--- 开始游戏
function GameManager.StartGame()
    state_.started = true
    state_.day = 1
    state_.dayTimer = 0
    state_.phaseIndex = 1
    state_.phase = GameConfig.DAY_PHASES[1].label

    EventBus.Emit(E.GAME_START)
    GameManager._startDay()
end

--- 每帧更新（由 main.lua 的 HandleUpdate 调用）
---@param dt number
function GameManager.Update(dt)
    if not state_.started or state_.paused then return end

    -- 日程推进
    state_.dayTimer = state_.dayTimer + dt
    local progress = state_.dayTimer / GameConfig.DAY_DURATION

    -- 阶段检查
    local phases = GameConfig.DAY_PHASES
    for i, p in ipairs(phases) do
        if progress >= p.start and progress < p.stop then
            if state_.phaseIndex ~= i then
                state_.phaseIndex = i
                state_.phase = p.label
                EventBus.Emit(E.PHASE_CHANGE, p.name, p.label)
            end
            break
        end
    end

    -- 一天结束
    if progress >= 1.0 then
        GameManager._endDay()
        return
    end

    -- 消息队列调度
    GameManager._processMessageQueue(dt)

    -- 工作流自动推进
    GameManager._updateWorkflow(dt)

    EventSystem.Update(dt)
end

--- 获取当前状态（供 UI 显示）
function GameManager.GetState()
    return state_
end

--- 老板发言
function GameManager.BossSendMessage(text)
    local activeChannel = ChannelManager.GetActiveChannelId()
    if ChannelManager.IsReadOnly(activeChannel) then return end

    ChannelManager.PushMessage(activeChannel, {
        sender = "老板",
        dept = "boss",
        text = text,
        isBoss = true,
    })

    EventBus.Emit(E.BOSS_MESSAGE, activeChannel, text)
end

--- 接取订单
function GameManager.AcceptOrder(orderId)
    local success = OrderManager.AcceptOrder(orderId, state_.day)
    if success then
        InfoPanel.Refresh()
    end
end

--- 供事故、私下频道懒加载等入队延迟消息
function GameManager.EnqueueDelayedMessage(delay, channelId, message)
    GameManager._enqueueMessage(delay, channelId, message)
end

--- 今日策略（每日开始可改 1 次，影响轻微审查倾向）
function GameManager.SetDailyStrategy(strategyId)
    local opts = GameConfig.DAILY_STRATEGIES
    for _, o in ipairs(opts) do
        if o.id == strategyId then
            state_.dailyStrategy = o.id
            EventBus.Emit(E.UI_TOAST, "📌 今日策略：" .. o.label)
            EventBus.Emit(E.UI_REFRESH)
            return true
        end
    end
    return false
end

function GameManager.GetDailyStrategy()
    return state_.dailyStrategy
end

function GameManager.GetDailyStrategyLabel()
    for _, o in ipairs(GameConfig.DAILY_STRATEGIES) do
        if o.id == state_.dailyStrategy then
            return o.label
        end
    end
    return "均衡发展"
end

--- 使用老板技能
function GameManager.UseSkill(skillId)
    if skillId == "temp_outsource" and not OrderManager.GetActiveOrder() then
        EventBus.Emit(E.UI_TOAST, "❌ 临时外包仅在有进行中订单时可用")
        return
    end
    local success, errMsg = BossSkillSystem.UseSkill(skillId, state_.funds)
    if not success then
        EventBus.Emit(E.UI_TOAST, "❌ " .. (errMsg or "技能使用失败"))
        -- 在全局频道提示
        ChannelManager.PushMessage("global", {
            sender = "系统",
            text = "❌ " .. (errMsg or "技能使用失败"),
            isSystem = true,
        })
    end
    InfoPanel.Refresh()
end

--- 修改资金
function GameManager.ChangeFunds(delta, reason)
    state_.funds = math.max(0, state_.funds + delta)
    EventBus.Emit(E.FUNDS_CHANGED, state_.funds, delta, reason)
    EventBus.Emit(E.UI_REFRESH)
end

--- 修改声誉
function GameManager.ChangeReputation(delta)
    state_.reputation = math.max(1, math.min(5, state_.reputation + delta))
    EventBus.Emit(E.REPUTATION_CHANGED, state_.reputation)
    EventBus.Emit(E.UI_REFRESH)
end

-- ============================================================
-- 日程管理
-- ============================================================

function GameManager._startDay()
    state_.dayTimer = 0
    state_.phaseIndex = 1
    state_.phase = GameConfig.DAY_PHASES[1].label

    EventBus.Emit(E.DAY_START, state_.day)

    -- 刷新每日订单
    OrderManager.RefreshDailyOrders(state_.day)

    -- 全局公告
    ChannelManager.PushMessage("global", {
        sender = "系统",
        text = "☀️ 第 " .. state_.day .. " 天开始了！接订单请打开底部「工作台」，聊天在「消息」。",
        isSystem = true,
    })

    -- 部门问候
    GameManager._scheduleGreetings()

    InfoPanel.Refresh()
    ChannelListPanel.Refresh()
end

function GameManager._endDay()
    EventBus.Emit(E.DAY_END, state_.day)

    -- 各系统日结算
    BossSkillSystem.OnDayEnd(state_.day)

    -- 部门状态收集给 SecretChannelSystem
    local gongbu = OrgGenerator.GetDepartment("gongbu")
    local deptStatuses = {
        gongbu = gongbu and { workload = gongbu.workload, maxWorkload = gongbu.maxWorkload } or nil,
    }
    SecretChannelSystem.OnDayEnd(deptStatuses)

    -- 公告
    ChannelManager.PushMessage("global", {
        sender = "系统",
        text = "🌙 第 " .. state_.day .. " 天结束了。",
        isSystem = true,
    })

    -- 进入下一天
    state_.day = state_.day + 1
    GameManager._startDay()
end

-- ============================================================
-- 消息调度
-- ============================================================

--- 添加延迟消息到队列
---@param delay number 延迟秒数
---@param channelId string
---@param message table
function GameManager._enqueueMessage(delay, channelId, message)
    table.insert(messageQueue_, {
        triggerTime = queueTimer_ + delay,
        channelId = channelId,
        message = message,
    })
end

--- 处理消息队列
function GameManager._processMessageQueue(dt)
    queueTimer_ = queueTimer_ + dt

    local i = 1
    while i <= #messageQueue_ do
        local item = messageQueue_[i]
        if queueTimer_ >= item.triggerTime then
            ChannelManager.PushMessage(item.channelId, item.message)
            table.remove(messageQueue_, i)
        else
            i = i + 1
        end
    end
end

--- 安排部门问候消息
function GameManager._scheduleGreetings()
    local AgentProfiles = require("agent.AgentProfiles")
    local depts = { "zhongshu", "gongbu", "menxia" }
    for i, deptId in ipairs(depts) do
        local greeting = AgentProfiles.GetRandomPhrase(deptId, "greeting")
        if greeting then
            GameManager._enqueueMessage(
                i * math.random(20, 40) * 0.1,
                "dept_" .. deptId,
                {
                    dept = deptId,
                    text = greeting,
                }
            )
        end
    end
end

-- ============================================================
-- 订单工作流自动化
-- ============================================================

--- 启动订单工作流
function GameManager._startWorkflow(order)
    workflowPhase_ = "accept"
    workflowTimer_ = 0
    workflowAutoAdvance_ = true
    workflowPostReviewNext_ = "acceptance"
    workflowRevisionExecute_ = false
    OrderManager.ClearAcceptanceResult()

    -- 设置部门忙碌
    OrgGenerator.UpdateWorkload("zhongshu", 1)
    OrgGenerator.UpdateWorkload("gongbu", 1)

    -- 生成接单阶段对话
    local context = {
        orderType = order.type,
        orderName = order.name,
        deliverableCount = tostring(order.deliverables),
        outsourceBoost = order.outsourceBoost,
        dailyStrategy = state_.dailyStrategy,
    }
    local msgs = AgentCaller.GenerateWorkflowMessages("accept", context)
    for _, msg in ipairs(msgs) do
        GameManager._enqueueMessage(msg.delay + 1.0, msg.channel, {
            dept = msg.dept,
            text = msg.text,
        })
    end
end

--- 推进工作流到下一阶段
function GameManager._advanceWorkflow(nextPhase)
    local order = OrderManager.GetActiveOrder()
    if not order then
        workflowPhase_ = nil
        return
    end

    workflowPhase_ = nextPhase
    workflowTimer_ = 0

    local context = {
        orderType = order.type,
        orderName = order.name,
        deliverableCount = tostring(order.deliverables),
        outsourceBoost = order.outsourceBoost,
        dailyStrategy = state_.dailyStrategy,
    }

    if nextPhase == "execute" then
        OrderManager.AdvanceOrder("executing")
        if not workflowRevisionExecute_ then
            OrgGenerator.UpdateWorkload("gongbu", 1)
        else
            workflowRevisionExecute_ = false
        end
        local msgs = AgentCaller.GenerateWorkflowMessages("execute", context)
        for _, msg in ipairs(msgs) do
            GameManager._enqueueMessage(msg.delay + 0.5, msg.channel, {
                dept = msg.dept,
                text = msg.text,
            })
        end

    elseif nextPhase == "review" then
        OrderManager.AdvanceOrder("reviewing")
        OrgGenerator.UpdateWorkload("menxia", 1)
        local msgs = AgentCaller.GenerateWorkflowMessages("review", context)
        local reviewResult = "approve"
        for _, msg in ipairs(msgs) do
            GameManager._enqueueMessage(msg.delay + 0.5, msg.channel, {
                dept = msg.dept,
                text = msg.text,
            })
            if msg._reviewResult then
                reviewResult = msg._reviewResult
            end
        end
        -- 根据审查结果决定下一步（计时结束后由 _updateWorkflow 分支）
        if reviewResult == "approve" then
            workflowPostReviewNext_ = "acceptance"
            workflowAutoAdvance_ = true
        elseif reviewResult == "reject" then
            workflowPostReviewNext_ = "execute"
            workflowRevisionExecute_ = true
            GameManager._enqueueMessage(#msgs * 2.0 + 3.0, "workflow", {
                sender = "系统",
                text = "🔄 门下省打回了方案，工部需要修改后重新提交。",
                isSystem = true,
            })
            workflowAutoAdvance_ = true
        else
            -- conflict
            SecretChannelSystem.RecordConflict()
            ChannelManager.PushMessage("workflow", {
                sender = "系统",
                text = "⚠️ 中书省与门下省发生冲突！老板可使用【强制拍板】推进。",
                isSystem = true,
            })
            workflowPostReviewNext_ = "acceptance"
            workflowAutoAdvance_ = false -- 等待老板操作
        end

    elseif nextPhase == "acceptance" then
        OrderManager.AdvanceOrder("submitted")
        OrderManager.ClearAcceptanceResult()
        local msgs = AgentCaller.GenerateWorkflowMessages("acceptance", context)
        local score = 70
        local passed = true
        for _, msg in ipairs(msgs) do
            GameManager._enqueueMessage(msg.delay + 0.5, msg.channel, {
                dept = msg.dept,
                text = msg.text,
            })
            if msg._score then score = msg._score end
            if msg._passed ~= nil then passed = msg._passed end
        end
        OrderManager.SetAcceptanceResult(passed, score)
        -- 延迟推送验收摘要（结算由计时器进入 settlement，不依赖消息队列）
        GameManager._enqueueMessage(#msgs * 2.0 + 2.0, "workflow", {
            sender = "系统",
            text = passed
                and ("✅ 验收通过！评分: " .. score .. "/100")
                or ("❌ 验收未通过。评分: " .. score .. "/100"),
            isSystem = true,
        })

    elseif nextPhase == "settlement" then
        local passed, score = OrderManager.GetAcceptanceResult()
        if passed == nil then
            passed = false
            score = 70
        end
        score = score or 70
        -- 完成/失败处理
        order.outsourceBoost = nil
        if passed then
            OrderManager.AdvanceOrder("completed", { score = score })
            local reward = order.reward
            if score >= 80 then reward = math.floor(reward * 1.2) end
            GameManager.ChangeFunds(reward, "订单完成: " .. order.name)
            if score >= 80 then
                GameManager.ChangeReputation(1)
            end
        else
            OrderManager.AdvanceOrder("failed")
            GameManager.ChangeReputation(-1)
        end

        -- 释放部门工作量
        OrgGenerator.UpdateWorkload("zhongshu", -1)
        OrgGenerator.UpdateWorkload("gongbu", -1)
        OrgGenerator.UpdateWorkload("menxia", -1)

        workflowPhase_ = nil
        workflowAutoAdvance_ = false
        OrderManager.ClearAcceptanceResult()
        InfoPanel.Refresh()
    end

    InfoPanel.Refresh()
end

--- 工作流定时推进
function GameManager._updateWorkflow(dt)
    if not workflowPhase_ or not workflowAutoAdvance_ then return end

    workflowTimer_ = workflowTimer_ + dt

    -- 每阶段自动推进的等待时间
    local phaseWait = {
        accept = 12,
        execute = 18,
        review = 14,
        acceptance = 10,
    }

    local wait = phaseWait[workflowPhase_] or 15
    if workflowTimer_ < wait then return end

    if workflowPhase_ == "accept" then
        GameManager._advanceWorkflow("execute")
    elseif workflowPhase_ == "execute" then
        GameManager._advanceWorkflow("review")
    elseif workflowPhase_ == "review" then
        GameManager._advanceWorkflow(workflowPostReviewNext_ or "acceptance")
    elseif workflowPhase_ == "acceptance" then
        GameManager._advanceWorkflow("settlement")
    end
end

--- 临时外包：推一条高优先级工单话术并略抬本单验收期望（模拟高级外援润色）
function GameManager._applyTempOutsource()
    local order = OrderManager.GetActiveOrder()
    if not order then return end
    order.outsourceBoost = true
    ChannelManager.PushMessage("workflow", {
        sender = "系统",
        text = "📎 临时外包顾问已介入，正在协助打磨本单交付物。",
        isSystem = true,
    })
end

return GameManager
