-- ============================================================================
-- AgentCaller.lua — AI 调用接口（模拟模式 / LLM RemoteEvent 模式）
-- ============================================================================

local AgentProfiles = require("agent.AgentProfiles")
local DialoguePool = require("agent.DialoguePool")
local EventBus = require("core.EventBus")
local OrgGenerator = require("systems.OrgGenerator")
local ChannelManager = require("systems.ChannelManager")
local AcceptanceAgent = require("agent.AcceptanceAgent")
local GameConfig = require("config.GameConfig")
local LLMConfig = require("config.LLMConfig")
local E = EventBus.Events

local AgentCaller = {}

-- 当前模式: "simulate" | "api"
AgentCaller.mode = "simulate"

-- 待处理的 LLM 请求（requestId → callback info）
local pendingRequests_ = {}
local requestCounter_ = 0

-- ============================================================
-- 初始化（客户端调用，注册 RemoteEvent 响应监听）
-- ============================================================

function AgentCaller.InitClient()
    -- 已连上常驻服则走 RemoteEvent；是否真调 LLM 由服务端 LLMConfig.IsConfigured() 决定。
    -- 不要求客户端填写 API Key，避免双端配置不一致导致永远不调代理。
    if network and network.serverConnection then
        AgentCaller.mode = "api"
        print("[AgentCaller] API mode (RemoteEvent → server); server decides real LLM vs fallback")
    else
        AgentCaller.mode = "simulate"
        print("[AgentCaller] Simulate mode (no server connection)")
    end

    -- 监听服务端 LLM 回复
    if network then
        local Shared = require("network.Shared")
        SubscribeToEvent(Shared.E_S2C_LLM_RESPONSE, "HandleLLMResponse")
        SubscribeToEvent(Shared.E_S2C_LLM_ERROR, "HandleLLMError")
    end
end

--- 处理服务端 LLM 回复
---@param eventType string
---@param eventData VariantMap
function HandleLLMResponse(eventType, eventData)
    local requestId = eventData["RequestId"]:GetString()
    local dept = eventData["Dept"]:GetString()
    local content = eventData["Content"]:GetString()

    print("[AgentCaller] LLM response: id=" .. requestId .. " dept=" .. dept)

    local pending = pendingRequests_[requestId]
    if pending then
        if pending.parseAcceptanceJson then
            local parsed = AcceptanceAgent.ParseStructuredResponse(content)
            if parsed then
                EventBus.Emit(E.WORKFLOW_ACCEPTANCE_PARSED, parsed.passed, parsed.score)
            end
        end
        ChannelManager.PushMessage(pending.channel, {
            dept = dept,
            text = content,
        })
        pendingRequests_[requestId] = nil
    end
end

--- 处理服务端 LLM 错误
---@param eventType string
---@param eventData VariantMap
function HandleLLMError(eventType, eventData)
    local requestId = eventData["RequestId"]:GetString()
    local errorMsg = eventData["ErrorMsg"]:GetString()

    print("[AgentCaller] LLM error: id=" .. requestId .. " err=" .. errorMsg)

    local pending = pendingRequests_[requestId]
    if pending then
        local detail = errorMsg or ""
        if #detail > 120 then
            detail = detail:sub(1, 117) .. "..."
        end
        local suffix = detail ~= "" and (" [" .. detail .. "]") or ""
        ChannelManager.PushMessage(pending.channel, {
            dept = pending.dept,
            text = "（AI连接异常，自动回复）" .. AgentCaller._getSimulatedText(pending.dept, pending.phase) .. suffix,
        })
        pendingRequests_[requestId] = nil
    end
end

-- ============================================================
-- 公共接口
-- ============================================================

--- 生成订单工作流中某阶段的对话序列
---@param phase string "accept"|"execute"|"review"|"acceptance"|"settlement"
---@param context table { orderType, orderName, deliverableCount, ... }
---@return table[] messages { { delay, dept, channel, text } }
function AgentCaller.GenerateWorkflowMessages(phase, context)
    if AgentCaller.mode == "api" then
        -- API 模式：先返回模拟消息（保持同步），同时异步请求 LLM
        local simMessages = AgentCaller._simulate(phase, context)
        AgentCaller._asyncLLMRequests(phase, context, simMessages)
        return simMessages
    end
    return AgentCaller._simulate(phase, context)
end

--- 生成私下频道消息
---@param channelId string "slacking"|"boss_gossip"|"secret_alliance"
---@param context table
---@return table[] messages
function AgentCaller.GenerateSecretMessages(channelId, context)
    local pool = DialoguePool.SECRET[channelId]
    if not pool or #pool == 0 then return {} end

    local messages = {}
    local count = math.min(#pool, math.random(2, 4))
    local used = {}
    for i = 1, count do
        local idx
        repeat
            idx = math.random(1, #pool)
        until not used[idx]
        used[idx] = true

        local template = pool[idx]
        table.insert(messages, {
            delay = (i - 1) * math.random(15, 30) * 0.1,
            dept = template.dept,
            channel = "secret_" .. channelId,
            text = template.text,
        })
    end
    return messages
end

--- 生成事故对话
---@param incidentId string
---@return table[] messages
function AgentCaller.GenerateIncidentMessages(incidentId)
    local pool = DialoguePool.INCIDENTS[incidentId]
    if not pool or #pool == 0 then return {} end

    local messages = {}
    for i, template in ipairs(pool) do
        table.insert(messages, {
            delay = (i - 1) * 2.0,
            dept = template.dept,
            channel = template.channel,
            text = template.text,
        })
    end
    return messages
end

-- ============================================================
-- API 模式：异步 LLM 请求
-- ============================================================

--- 对工作流对话异步请求 LLM，回复后推送新消息覆盖
function AgentCaller._buildChannelDigest(maxChars)
    maxChars = maxChars or 1200
    local parts = {}
    local function appendBlock(title, channelId)
        local msgs = ChannelManager.GetMessages(channelId)
        if not msgs or #msgs == 0 then return end
        local lines = { "[" .. title .. "]" }
        local start = math.max(1, #msgs - 8)
        for i = start, #msgs do
            local m = msgs[i]
            local who = m.sender or m.dept or "?"
            local t = m.text or ""
            if #t > 120 then t = t:sub(1, 117) .. "..." end
            table.insert(lines, who .. ": " .. t)
        end
        table.insert(parts, table.concat(lines, "\n"))
    end
    appendBlock("工作流", "workflow")
    appendBlock("全局", "global")
    local blob = table.concat(parts, "\n")
    if #blob > maxChars then
        blob = blob:sub(-maxChars)
    end
    return blob
end

function AgentCaller._asyncLLMRequests(phase, context, simMessages)
    if not network or not network.serverConnection then return end

    local Shared = require("network.Shared")
    local connection = network.serverConnection
    local digest = AgentCaller._buildChannelDigest()

    -- 为每个部门消息发送 LLM 请求
    local sentDepts = {} -- 避免同一部门重复请求
    for _, msg in ipairs(simMessages) do
        local dept = msg.dept
        if dept and not sentDepts[dept] and dept ~= "系统" then
            sentDepts[dept] = true

            requestCounter_ = requestCounter_ + 1
            local requestId = "req_" .. tostring(requestCounter_) .. "_" .. dept

            -- 构建 system prompt
            local systemPrompt = LLMConfig.SYSTEM_PROMPT_PREFIX
            if LLMConfig.DEPT_PROMPTS[dept] then
                systemPrompt = systemPrompt .. "\n" .. LLMConfig.DEPT_PROMPTS[dept]
            end
            if phase == "acceptance" and dept == "acceptance" then
                systemPrompt = systemPrompt .. "\n" .. AcceptanceAgent.JSON_INSTRUCTION
            end

            -- 构建 user message
            local userMessage = LLMConfig.WORKFLOW_PROMPT_TEMPLATE
                :gsub("{orderName}", context.orderName or "未命名")
                :gsub("{orderType}", context.orderType or "general")
                :gsub("{phase}", phase)
                :gsub("{dept}", dept)
            if digest ~= "" then
                userMessage = userMessage .. "\n\n【近期频道摘要】\n" .. digest
            end

            local parseAcceptanceJson = (phase == "acceptance" and dept == "acceptance")

            pendingRequests_[requestId] = {
                dept = dept,
                phase = phase,
                channel = msg.channel,
                parseAcceptanceJson = parseAcceptanceJson,
            }

            local data = VariantMap()
            data["RequestId"] = Variant(requestId)
            data["Dept"] = Variant(dept)
            data["SystemPrompt"] = Variant(systemPrompt)
            data["UserMessage"] = Variant(userMessage)
            connection:SendRemoteEvent(Shared.E_C2S_LLM_REQUEST, true, data)

            print("[AgentCaller] Sent LLM request: " .. requestId)
        end
    end
end

--- 获取简单模拟文本（用于错误兜底）
function AgentCaller._getSimulatedText(dept, phase)
    local texts = {
        zhongshu = "方案已更新，请查阅。",
        gongbu = "收到，正在处理中。",
        menxia = "已审核，请注意修改意见。",
        acceptance = "验收报告已生成。",
    }
    return texts[dept] or "已处理。"
end

-- ============================================================
-- 模拟模式实现
-- ============================================================

function AgentCaller._simulate(phase, context)
    local messages = {}
    local orderType = context.orderType or "hotspot"
    local orderName = context.orderName or "未命名订单"

    if phase == "accept" then
        local templates = DialoguePool.GetPhaseDialogues("accept", orderType)
        for i, t in ipairs(templates) do
            local text = AgentCaller._fillTemplate(t.text, context)
            table.insert(messages, {
                delay = (i - 1) * 2.5,
                dept = t.dept,
                channel = t.channel,
                text = text,
            })
        end

    elseif phase == "execute" then
        local templates = DialoguePool.GetPhaseDialogues("execute", orderType)
        for i, t in ipairs(templates) do
            local text = AgentCaller._fillTemplate(t.text, context)
            table.insert(messages, {
                delay = (i - 1) * 3.0,
                dept = t.dept,
                channel = t.channel,
                text = text,
            })
        end

    elseif phase == "review" then
        local arch = OrgGenerator.GetArchetype()
        local rs = arch and arch.reviewStrength or 0.5
        local cr = arch and arch.conflictRate or 0.2
        local approveEnd = math.floor(50 + (1 - rs) * 28)
        local rejectEnd = math.floor(approveEnd + 22 + cr * 22)
        rejectEnd = math.min(94, math.max(approveEnd + 8, rejectEnd))
        if OrgGenerator.IsReportingSwapped() then
            approveEnd = math.max(15, approveEnd - 6)
            rejectEnd = math.min(96, rejectEnd + 4)
        end
        local stratDelta = 0
        local sid = context.dailyStrategy
        if sid then
            for _, s in ipairs(GameConfig.DAILY_STRATEGIES) do
                if s.id == sid then
                    stratDelta = s.reviewApproveDelta or 0
                    break
                end
            end
        end
        approveEnd = math.max(12, math.min(88, approveEnd + stratDelta))
        local roll = math.random(1, 100)
        local subPhase
        if roll <= approveEnd then
            subPhase = "approve"
        elseif roll <= rejectEnd then
            subPhase = "reject"
        else
            subPhase = "conflict"
        end

        local templates = DialoguePool.PHASE_REVIEW[subPhase] or {}
        for i, t in ipairs(templates) do
            local reviewCtx = {
                orderName = orderName,
                issues = DialoguePool.GetRandomReviewIssue(),
                suggestion = "建议增加数据佐证",
            }
            local text = AgentCaller._fillTemplate(t.text, reviewCtx)
            table.insert(messages, {
                delay = (i - 1) * 2.0,
                dept = t.dept,
                channel = t.channel,
                text = text,
                _reviewResult = subPhase,
            })
        end

    elseif phase == "acceptance" then
        local score = math.random(40, 95)
        if context.outsourceBoost then
            score = math.min(95, score + 10)
        end
        local quality
        if score >= 80 then quality = "high"
        elseif score >= 60 then quality = "medium"
        else quality = "low" end

        local subPhase
        if score >= 60 then
            subPhase = (score >= 80) and "pass_high" or "pass_medium"
        else
            subPhase = "fail"
        end

        local templates = DialoguePool.PHASE_ACCEPTANCE[subPhase] or {}
        for i, t in ipairs(templates) do
            local text = AgentCaller._fillTemplate(t.text, {
                score = tostring(score),
                comment = DialoguePool.GetRandomAcceptanceComment(quality),
            })
            table.insert(messages, {
                delay = (i - 1) * 2.0,
                dept = t.dept,
                channel = t.channel,
                text = text,
                _score = score,
                _passed = score >= 60,
            })
        end

    elseif phase == "settlement" then
        local passed = context.passed
        local subPhase
        if passed == true then subPhase = "success"
        elseif passed == false then subPhase = "fail"
        else subPhase = "partial" end

        local templates = DialoguePool.PHASE_SETTLEMENT[subPhase] or {}
        for i, t in ipairs(templates) do
            local text = AgentCaller._fillTemplate(t.text, context)
            table.insert(messages, {
                delay = (i - 1) * 1.0,
                dept = t.dept,
                channel = t.channel,
                text = text,
            })
        end
    end

    return messages
end

--- 模板变量填充
---@param template string
---@param ctx table
---@return string
function AgentCaller._fillTemplate(template, ctx)
    if not ctx then return template end
    return template:gsub("{(%w+)}", function(key)
        if key == "content_preview" then
            return DialoguePool.GetRandomContentPreview(ctx.orderType or "hotspot")
        end
        return ctx[key] or ("{" .. key .. "}")
    end)
end

return AgentCaller
