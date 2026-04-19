-- ============================================================================
-- AcceptanceAgent.lua — 验收官：4 种性格 + 结构化 JSON 解析
--
-- 4 种性格（v0.4 GDD）：
--   1. picky_old   挑剔老学究   ：严格、计较细节、爱引用规范
--   2. trend_youth 网感年轻人   ：看热度/调性、嫌"老气"
--   3. bizdev      务实业务方    ：只看转化/数据是否好看
--   4. mystery     神秘审美评委  ：玄学、看"气场/感觉"
--
-- 性格选择策略：
--   - 优先按订单 prefer_acceptance 字段
--   - 否则按订单类型默认映射（hot=trend_youth, brand=picky_old,
--     application=bizdev, mystery=mystery）
--   - 其它兜底 picky_old
-- ============================================================================

local AcceptanceAgent = {}

-- ============================================================
-- 性格定义
-- ============================================================
AcceptanceAgent.PERSONAS = {
    {
        id = "picky_old",
        name = "钱老师",
        title = "挑剔的老学究",
        avatar = "👨‍🏫",
        bgColor = { 232, 240, 230, 255 },
        accentColor = { 86, 130, 86, 255 },
        catchphrase = "细节决定成败",
        bias = -10,              -- 默认严格
        prompt = [[
你是甲方验收官「钱老师」，一位挑剔的老学究。你说话偏正式、爱引用行业规范、计较细节。
- 喜欢：严谨措辞、品牌一致性、合规、参考权威。
- 反感：浮夸口号、缺乏依据、错别字、随意改动 VI。
- 评分倾向：偏严，60 分及格不轻给，过 80 必须挑不出毛病。
请用 1-2 句具体而严肃的评语点出最关键问题或亮点。
]],
        passLines = {
            "细节扎实，符合规范，可以放行。",
            "措辞严谨，逻辑通顺，勉强能用。",
            "整体合规，没什么大毛病，过。",
        },
        failLines = {
            "硬伤太多，请回去对照规范再修。",
            "缺乏权威依据，建议补充资料。",
            "措辞随意，与品牌调性不符，重做。",
        },
    },
    {
        id = "trend_youth",
        name = "小林",
        title = "网感重的年轻人",
        avatar = "👧",
        bgColor = { 254, 235, 224, 255 },
        accentColor = { 232, 112, 64, 255 },
        catchphrase = "玩梗要趁早",
        bias = 5,                -- 默认偏宽
        prompt = [[
你是甲方验收官「小林」，一个网感拉满的年轻人。你说话短促、口语化、爱用"绝绝子/格局打开/破防了"等网络梗。
- 喜欢：抓得住热点、节奏快、有梗、人设鲜明。
- 反感：老干部腔、说教、PPT 感、过时的梗。
- 评分倾向：热点准了直接 90+，老气一律 50 以下。
请用 1-2 句口语化评语，能用梗就用梗。
]],
        passLines = {
            "可以可以，这个梗很到位！",
            "节奏对了，能冲。",
            "调性 OK，发吧。",
        },
        failLines = {
            "太老气了，重写吧。",
            "梗都是上个月的了……",
            "看着就没人会转发。",
        },
    },
    {
        id = "bizdev",
        name = "K总",
        title = "务实业务方",
        avatar = "💼",
        bgColor = { 224, 244, 252, 255 },
        accentColor = { 32, 168, 216, 255 },
        catchphrase = "数据说话",
        bias = 0,
        prompt = [[
你是甲方验收官「K总」，务实业务方代表。你只关心：转化、数据、可量化效果。
- 喜欢：明确 CTA、目标用户清晰、有数据论据、性价比高。
- 反感：纯创意无落地、自嗨、堆形容词、看不到 KPI。
- 评分倾向：能算账就给过，看不到生意逻辑直接打回。
请用 1-2 句突出"能不能赚钱/能不能转化"的评语。
]],
        passLines = {
            "转化路径清晰，可以投放。",
            "目标用户准，预期 ROI 不错，过。",
            "能落地就行，发吧。",
        },
        failLines = {
            "看不到转化路径，重写。",
            "ROI 不明，回去算清楚。",
            "自嗨内容，对生意没帮助。",
        },
    },
    {
        id = "mystery",
        name = "玄学评委",
        title = "神秘审美评委",
        avatar = "🔮",
        bgColor = { 240, 232, 248, 255 },
        accentColor = { 123, 104, 238, 255 },
        catchphrase = "气场对不对",
        bias = 0,                -- 但波动大
        variance = 25,           -- 自身骰子方差大
        prompt = [[
你是甲方验收官「玄学评委」。你看作品凭"气场、磁场、感觉"，评语玄而又玄。
- 喜欢：留白、神秘感、未明说的张力、"对的氛围"。
- 反感：太满、太露、解释太多、用力过猛。
- 评分倾向：随心情，方差大；同一份作品换天给分能差 30。
请用 1-2 句玄学风格评语。允许出现"气场""结界""频率"等词。
]],
        passLines = {
            "嗯，气场对了，过。",
            "频率合上了，可以。",
            "结界稳定，准。",
        },
        failLines = {
            "气场散了，重做。",
            "感觉不对，但说不上来哪不对。",
            "频率没对上，再来一次。",
        },
    },
}

-- ============================================================
-- 选择性格
-- ============================================================
local DEFAULT_BY_ORDER_TYPE = {
    hot = "trend_youth",
    brand = "picky_old",
    application = "bizdev",
    mystery = "mystery",
}

--- 选择验收官性格
---@param order table 订单（可含 prefer_acceptance 字段）
---@return table persona
function AcceptanceAgent.PickPersona(order)
    if order then
        if order.prefer_acceptance then
            local p = AcceptanceAgent.GetPersona(order.prefer_acceptance)
            if p then return p end
        end
        local mapped = DEFAULT_BY_ORDER_TYPE[order.type]
        if mapped then
            local p = AcceptanceAgent.GetPersona(mapped)
            if p then return p end
        end
    end
    return AcceptanceAgent.PERSONAS[1]
end

--- 按 id 取性格
function AcceptanceAgent.GetPersona(id)
    for _, p in ipairs(AcceptanceAgent.PERSONAS) do
        if p.id == id then return p end
    end
    return nil
end

-- ============================================================
-- LLM 提示词拼接（在 AgentCaller 调用 LLM 前用）
-- ============================================================
AcceptanceAgent.JSON_INSTRUCTION_TAIL = [[

输出格式要求：在所有自然语言评语之后，必须在最后一行单独输出一行 JSON（不要包在代码块里），格式严格为：
{"passed":true或false,"score":0到100的整数,"reason":"一句话理由"}
]]

--- 拼接出该性格的完整 system prompt
function AcceptanceAgent.BuildSystemPrompt(persona)
    persona = persona or AcceptanceAgent.PERSONAS[1]
    return (persona.prompt or "") .. AcceptanceAgent.JSON_INSTRUCTION_TAIL
end

-- 兼容旧字段
AcceptanceAgent.JSON_INSTRUCTION = AcceptanceAgent.JSON_INSTRUCTION_TAIL

-- ============================================================
-- simulate 模式下的兜底评语
-- ============================================================
function AcceptanceAgent.PickFallbackLine(persona, passed)
    persona = persona or AcceptanceAgent.PERSONAS[1]
    local pool = passed and persona.passLines or persona.failLines
    if not pool or #pool == 0 then
        return passed and "通过。" or "不通过。"
    end
    return pool[math.random(#pool)]
end

-- ============================================================
-- 解析 LLM 结构化回复
-- ============================================================
function AcceptanceAgent.ParseStructuredResponse(text)
    if not text or text == "" then return nil end
    local jsonChunk = text:match("%b{}")
    if not jsonChunk then return nil end
    local passed
    if jsonChunk:find('"passed"%s*:%s*true') or jsonChunk:find("'passed'%s*:%s*true") then
        passed = true
    elseif jsonChunk:find('"passed"%s*:%s*false') or jsonChunk:find("'passed'%s*:%s*false") then
        passed = false
    end
    local score = tonumber(jsonChunk:match('"score"%s*:%s*(%d+)'))
    local reason = jsonChunk:match('"reason"%s*:%s*"([^"]*)"')
    if score == nil and passed == nil then return nil end
    if score == nil then score = passed and 75 or 45 end
    score = math.max(0, math.min(100, score))
    if passed == nil then
        passed = score >= 60
    end
    return { passed = passed, score = score, reason = reason }
end

return AcceptanceAgent
