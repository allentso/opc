-- ============================================================================
-- AgentProfiles.lua — 各部门 Agent 角色设定 + 性格标签
-- ============================================================================

local AgentProfiles = {}

-- 性格标签定义
AgentProfiles.TAGS = {
    overthink     = { name = "过度思考", desc = "方案极其详尽，但执行延迟" },
    context_loss  = { name = "上下文遗忘", desc = "偶尔忘记之前的决定" },
    overconfident = { name = "极度自信", desc = "不轻易承认错误" },
    hallucinate   = { name = "容易幻觉", desc = "会发明不存在的功能或数据" },
    blame_shift   = { name = "爱甩锅", desc = "出错时指向其他部门" },
    compliant     = { name = "懂合规", desc = "天然倾向谨慎" },
    aesthetic     = { name = "审美优等", desc = "内容质量高但不爱改稿" },
}

-- 部门基础配置
AgentProfiles.DEPARTMENTS = {
    zhongshu = {
        id = "zhongshu",
        name = "中书省",
        role = "策划/方案AI",
        icon = "📋",
        color = { 88, 166, 255, 255 },
        personality = "严谨、爱做计划、偶尔会过度设计",
        defaultTags = { "overthink" },
        duties = {
            "拆解需求",
            "制定执行方案",
            "协调各部门分工",
        },
        phrases = {
            greeting = { "收到，正在分析需求...", "让我拆解一下这个订单。" },
            working = { "方案已完成，共分三个阶段...", "建议采用以下执行路径..." },
            conflict = { "我的方案经过充分论证，请工部按原方案执行。", "这个修改请求缺乏依据。" },
            secret = { "老板那个决策真的合理吗...", "我觉得应该让我来拿主意才对。" },
        },
    },

    gongbu = {
        id = "gongbu",
        name = "工部",
        role = "内容/执行AI",
        icon = "⚒️",
        color = { 250, 168, 26, 255 },
        personality = "执行力强、有时偷懒、会在私下群抱怨门下省太烦",
        defaultTags = { "blame_shift" },
        duties = {
            "实际生产交付物",
            "执行中书省的方案",
            "完成内容创作",
        },
        phrases = {
            greeting = { "好的，马上开始执行。", "收到任务，预估需要一些时间。" },
            working = { "第一稿已经出来了。", "内容已完成，提交审查。", "交付物如下：" },
            conflict = { "门下省的审查标准也太严了吧？", "这个修改意见不合理！" },
            secret = { "门下省又打回了，烦死了...", "要不咱们研究下怎么绕过审查？", "今天又加班，全是门下省的锅。" },
        },
    },

    menxia = {
        id = "menxia",
        name = "门下省",
        role = "审查/质检AI",
        icon = "🔍",
        color = { 237, 66, 69, 255 },
        personality = "严格、规则导向、被老板强制放行时会备案并发出警告",
        defaultTags = { "compliant" },
        duties = {
            "审查所有对外内容",
            "风险评估",
            "合规把关",
        },
        phrases = {
            greeting = { "审查系统已就位。", "门下省准备就绪，等待审查任务。" },
            working = { "正在审查...", "审查完成，以下是审查意见：" },
            approve = { "审查通过，可以发布。", "内容符合标准，通过。" },
            reject = { "审查未通过，存在以下风险：", "打回修改，理由如下：" },
            conflict = { "质量问题不能妥协。", "如果老板强制放行，我需要备案。" },
            secret = { "工部的产出质量堪忧...", "老板总是强制拍板，迟早出事。" },
        },
    },

    acceptance = {
        id = "acceptance",
        name = "验收官",
        role = "客户Agent",
        icon = "📝",
        color = { 87, 242, 135, 255 },
        personality = "挑剔、有自己的评判标准，不受老板控制",
        defaultTags = { "overconfident" },
        duties = {
            "扮演甲方客户",
            "验收交付物",
            "输出评分报告",
        },
        -- 验收官类型（对应不同订单类型）
        subtypes = {
            hotspot = { name = "急性子网红编辑", focus = "只看爆点，不在意合规" },
            brand   = { name = "挑剔的品牌总监", focus = "极度在意调性和一致性" },
            app     = { name = "务实的产品经理", focus = "只看能不能用" },
            mystery = { name = "身份不明的甲方", focus = "评判标准模糊" },
        },
        phrases = {
            reviewing = { "让我看看这次的交付物...", "验收开始，请稍候。" },
            pass = { "基本符合要求，通过。", "质量不错，验收通过！" },
            fail = { "这个完全不符合我的要求。", "退回修改，主要问题如下：" },
            comment = { "情绪价值足够但逻辑自洽性存疑。", "创意不错，但执行层面差了点。" },
            secret = { "这家公司的AI水平就这样？", "给个及格分吧，我也不想太为难他们。" },
        },
    },
}

--- 获取部门配置
---@param deptId string
---@return table|nil
function AgentProfiles.GetDepartment(deptId)
    return AgentProfiles.DEPARTMENTS[deptId]
end

--- 获取所有部门ID列表
---@return string[]
function AgentProfiles.GetDepartmentIds()
    return { "zhongshu", "gongbu", "menxia", "acceptance" }
end

--- 获取工作部门ID列表（不含验收官）
---@return string[]
function AgentProfiles.GetWorkDepartmentIds()
    return { "zhongshu", "gongbu", "menxia" }
end

--- 从部门的短语库中随机取一句
---@param deptId string
---@param category string
---@return string
function AgentProfiles.GetRandomPhrase(deptId, category)
    local dept = AgentProfiles.DEPARTMENTS[deptId]
    if not dept or not dept.phrases[category] then
        return "..."
    end
    local phrases = dept.phrases[category]
    return phrases[math.random(1, #phrases)]
end

return AgentProfiles
