-- ============================================================================
-- IntelSystem.lua — 私下情报识别系统（规则版，v0.4）
--
-- 工作原理：
--   1. 监听 SECRET_MESSAGE 事件，从消息文本中按关键词规则提取情报
--   2. 情报有类型、紧急度、可执行的"应对动作"
--   3. UI（指挥中心）订阅 INTEL_NEW 事件刷新「私下情报行动区」
--   4. 用户点击应对动作，触发 INTEL_ACTION 事件，GameManager 应用效果
--
-- 设计决策：
--   - 规则版不依赖 LLM 摘要，零成本
--   - 同一类型情报会被去重 / 合并（最多保留近 5 条活跃）
--   - 每条情报有 ttl_days，过期自动清除
-- ============================================================================

local EventBus = require("core.EventBus")
local E = EventBus.Events

local IntelSystem = {}

-- ============================================================
-- 情报规则定义
--   keywords: 命中其中任一关键词即触发
--   exclude:  命中即跳过（避免误匹配）
--   intel:    生成的情报模板
-- ============================================================
local RULES = {
    {
        id = "rule_gongbu_strike",
        intelType = "gongbu_morale",
        urgency = "high",
        keywords = { "罢工", "不干了", "辞职", "罢手", "撂挑子" },
        exclude  = {},
        title = "工部士气崩盘",
        summary = "工部出现罢工/辞职言论，再不干预可能停摆。",
        actions = {
            { id = "boost_morale", label = "📣 公开嘉奖（+士气）", cost = 1500 },
            { id = "ignore", label = "无视", cost = 0 },
        },
    },
    {
        id = "rule_zhongshu_burnout",
        intelType = "zhongshu_morale",
        urgency = "medium",
        keywords = { "废人", "摆烂", "算了", "无所谓", "随便吧" },
        exclude  = {},
        title = "中书省创意枯竭",
        summary = "中书省负面情绪爆表，下个方案质量可能跳水。",
        actions = {
            { id = "give_break", label = "🍵 安排放空一天", cost = 0 },
            { id = "ignore", label = "无视", cost = 0 },
        },
    },
    {
        id = "rule_acceptance_strict",
        intelType = "acceptance_warn",
        urgency = "high",
        keywords = { "严格", "再这样", "我直接打回", "下次不会再" },
        exclude  = {},
        title = "验收官情绪不佳",
        summary = "验收官放出狠话，下一单可能严苛打分。",
        actions = {
            { id = "polish_more", label = "💎 启用质量优先策略", cost = 0, applyStrategy = "quality" },
            { id = "ignore", label = "无视", cost = 0 },
        },
    },
    {
        id = "rule_dept_conflict",
        intelType = "dept_conflict",
        urgency = "medium",
        keywords = { "矛盾", "吵架", "打起来", "不合", "撕" },
        exclude  = { "AI 也有情绪" },
        title = "部门内讧苗头",
        summary = "私下言论暴露跨部门积怨，合作效率有风险。",
        actions = {
            { id = "mediate", label = "🤝 召开部门协调会", cost = 800 },
            { id = "ignore", label = "无视", cost = 0 },
        },
    },
    {
        id = "rule_boss_gossip",
        intelType = "boss_gossip",
        urgency = "low",
        keywords = { "老板煞笔", "老板sb", "老板就是", "蛐蛐老板" },
        exclude  = {},
        title = "员工背后议论老板",
        summary = "员工在私下频道吐槽你的决策，但暂未影响业务。",
        actions = {
            { id = "show_off_results", label = "💼 公开炫成绩压人", cost = 0 },
            { id = "ignore", label = "无视", cost = 0 },
        },
    },
    {
        id = "rule_secret_alliance",
        intelType = "secret_alliance",
        urgency = "medium",
        keywords = { "私下", "提前告诉", "暗中", "桌面下" },
        exclude  = {},
        title = "部门间私下结盟",
        summary = "工部与门下省正在桌面下交易，合规风险升高。",
        actions = {
            { id = "warn_secretly", label = "👀 暗中警告", cost = 0 },
            { id = "let_it_be", label = "默许", cost = 0 },
        },
    },
}

-- ============================================================
-- 状态
-- ============================================================
local intels_ = {}    -- { intelType -> intel }
local nextIntelId_ = 1
local DEFAULT_TTL_DAYS = 2
local MAX_ACTIVE = 6

-- ============================================================
-- 初始化
-- ============================================================
function IntelSystem.Init()
    intels_ = {}

    EventBus.On(E.SECRET_MESSAGE, function(channelId, message)
        IntelSystem._processMessage(channelId, message)
    end)

    EventBus.On(E.MESSAGE_NEW, function(channelId, message)
        if not channelId or not channelId:match("^secret_") then return end
        IntelSystem._processMessage(channelId, message)
    end)

    EventBus.On(E.DAY_END, function()
        IntelSystem._tickTtl()
    end)
end

-- ============================================================
-- 消息 -> 情报识别
-- ============================================================
function IntelSystem._processMessage(channelId, message)
    if not message or not message.text then return end
    local text = message.text

    for _, rule in ipairs(RULES) do
        if IntelSystem._matchRule(rule, text) then
            IntelSystem._addOrUpdateIntel(rule, channelId, message)
            -- 不 break：同一条消息可触发多个规则
        end
    end
end

function IntelSystem._matchRule(rule, text)
    -- 排除项
    if rule.exclude then
        for _, ex in ipairs(rule.exclude) do
            if text:find(ex, 1, true) then return false end
        end
    end
    -- 关键词
    for _, kw in ipairs(rule.keywords) do
        if text:find(kw, 1, true) then return true end
    end
    return false
end

--- 加入或刷新情报（去重）
function IntelSystem._addOrUpdateIntel(rule, channelId, message)
    local existing = intels_[rule.intelType]
    if existing then
        -- 已存在则刷新
        existing.ttl = DEFAULT_TTL_DAYS
        existing.evidenceCount = (existing.evidenceCount or 1) + 1
        existing.lastChannelId = channelId
        existing.lastSnippet = IntelSystem._snippet(message.text)
        EventBus.Emit(E.INTEL_UPDATED, existing)
    else
        local intel = {
            id = nextIntelId_,
            ruleId = rule.id,
            intelType = rule.intelType,
            urgency = rule.urgency,
            title = rule.title,
            summary = rule.summary,
            actions = rule.actions,
            evidenceCount = 1,
            lastChannelId = channelId,
            lastSnippet = IntelSystem._snippet(message.text),
            ttl = DEFAULT_TTL_DAYS,
            handled = false,
        }
        nextIntelId_ = nextIntelId_ + 1
        intels_[rule.intelType] = intel
        EventBus.Emit(E.INTEL_NEW, intel)
        IntelSystem._enforceCap()
    end
end

function IntelSystem._snippet(text)
    if #text <= 40 then return text end
    return string.sub(text, 1, 40) .. "…"
end

function IntelSystem._enforceCap()
    -- 收集活跃 intel，按 ttl/紧急度排序，移除超出容量的
    local list = {}
    for _, v in pairs(intels_) do table.insert(list, v) end
    if #list <= MAX_ACTIVE then return end
    table.sort(list, function(a, b)
        if a.urgency == b.urgency then
            return (a.ttl or 0) > (b.ttl or 0)
        end
        local rank = { high = 3, medium = 2, low = 1 }
        return (rank[a.urgency] or 0) > (rank[b.urgency] or 0)
    end)
    for i = MAX_ACTIVE + 1, #list do
        intels_[list[i].intelType] = nil
    end
end

-- ============================================================
-- TTL 衰减（每日触发）
-- ============================================================
function IntelSystem._tickTtl()
    for k, intel in pairs(intels_) do
        intel.ttl = (intel.ttl or 1) - 1
        if intel.ttl <= 0 then
            intels_[k] = nil
            EventBus.Emit(E.INTEL_EXPIRED, intel)
        end
    end
end

-- ============================================================
-- 用户应对动作
-- ============================================================
function IntelSystem.HandleAction(intelTypeOrId, actionId)
    -- 兼容传入 intelType 或 intel id
    local intel
    for _, v in pairs(intels_) do
        if v.id == intelTypeOrId or v.intelType == intelTypeOrId then
            intel = v; break
        end
    end
    if not intel then return false end

    local action
    for _, a in ipairs(intel.actions or {}) do
        if a.id == actionId then action = a; break end
    end
    if not action then return false end

    intel.handled = true
    EventBus.Emit(E.INTEL_ACTION, intel, action)

    -- 处理完即移除
    intels_[intel.intelType] = nil
    EventBus.Emit(E.INTEL_EXPIRED, intel)
    return true
end

-- ============================================================
-- 查询
-- ============================================================
function IntelSystem.GetActiveIntels()
    local list = {}
    for _, v in pairs(intels_) do
        if not v.handled then table.insert(list, v) end
    end
    -- 按紧急度排序
    table.sort(list, function(a, b)
        local rank = { high = 3, medium = 2, low = 1 }
        return (rank[a.urgency] or 0) > (rank[b.urgency] or 0)
    end)
    return list
end

return IntelSystem
