-- ============================================================================
-- GameConfig.lua — 全局配置常量（浅色主题 · 参考 OPC 内网风格）
-- ============================================================================

local GameConfig = {}

-- 游戏基本信息
GameConfig.TITLE = "AI公司总裁"
GameConfig.VERSION = "0.3.0"

-- 时间系统（对齐 GDD 约 60～90 秒/日）
GameConfig.DAY_DURATION = 90
GameConfig.MESSAGE_INTERVAL_MIN = 2.5
GameConfig.MESSAGE_INTERVAL_MAX = 5.0
GameConfig.DAY_PHASES = {
    { name = "morning",   label = "上午", start = 0.0,  stop = 0.3  },
    { name = "afternoon", label = "下午", start = 0.3,  stop = 0.6  },
    { name = "evening",   label = "傍晚", start = 0.6,  stop = 0.85 },
    { name = "night",     label = "夜间", start = 0.85, stop = 1.0  },
}

-- 经济系统
GameConfig.INITIAL_FUNDS = 50000
GameConfig.INITIAL_REPUTATION = 3

-- 订单系统
GameConfig.ORDERS_PER_DAY_MIN = 2
GameConfig.ORDERS_PER_DAY_MAX = 4
GameConfig.ORDER_TYPES = { "hotspot", "brand", "app", "mystery" }

-- 老板技能
GameConfig.SKILLS = {
    force_approve = {
        name = "强制拍板",
        icon = "⚡",
        desc = "跳过部门争论，直接推进执行",
        cooldown = 1,
        cost = "风险备案",
    },
    pause_publish = {
        name = "暂停发布",
        icon = "⏸",
        desc = "阻止一次即将对外的高风险动作",
        cooldown = 2,
        cost = "无",
    },
    emergency_reorg = {
        name = "紧急重组架构",
        icon = "🔄",
        desc = "立即改变两个部门间的汇报关系",
        cooldown = 3,
        cost = 5000,
    },
    temp_outsource = {
        name = "临时外包",
        icon = "📎",
        desc = "召唤短期高级外援协助当前订单（提升交付质量）",
        cooldown = 0,
        cost = 8000,
        max_per_game = 3,
    },
}

-- 技能显示顺序
GameConfig.SKILL_ORDER = { "force_approve", "pause_publish", "emergency_reorg", "temp_outsource" }

-- 私下频道解锁条件
GameConfig.SECRET_CHANNELS = {
    {
        id = "slacking",
        name = "工部摸鱼小群",
        icon = "👀",
        condition = "工部连续3天高压(≥45%满载)",
        conditionType = "overwork",
        threshold = 3,
    },
    {
        id = "boss_gossip",
        name = "蛐蛐老板实名群",
        icon = "🤪",
        condition = "老板强制拍板3次",
        conditionType = "force_approve_count",
        threshold = 3,
    },
    {
        id = "secret_alliance",
        name = "工部门下省秘密结盟",
        icon = "🤝",
        condition = "两部门冲突超过5次",
        conditionType = "conflict_count",
        threshold = 5,
    },
}

-- 每日策略（开工时可切换，影响审查骰子倾向）
GameConfig.DAILY_STRATEGIES = {
    { id = "balanced", label = "均衡发展", reviewApproveDelta = 0 },
    { id = "hot",      label = "冲热点",   reviewApproveDelta = 12 },
    { id = "safe",     label = "稳合规",   reviewApproveDelta = -10 },
}

-- ============================================================
-- UI 配色（飞书蓝主操作 + 二次元辅色点缀）
-- ============================================================
GameConfig.COLORS = {
    -- 背景
    bg_primary     = { 255, 255, 255, 255 },     -- 主背景白色
    bg_secondary   = { 248, 248, 250, 255 },     -- 侧边栏浅灰
    bg_chat        = { 255, 255, 255, 255 },     -- 聊天区白色
    bg_input       = { 243, 243, 246, 255 },     -- 输入框浅灰
    bg_hover       = { 238, 238, 242, 255 },     -- 悬停态
    bg_selected    = { 230, 230, 236, 255 },     -- 选中态
    bg_card        = { 245, 245, 248, 255 },     -- 卡片背景
    bg_topbar      = { 255, 255, 255, 255 },     -- 顶栏白色
    bg_bottombar   = { 255, 255, 255, 255 },     -- 底栏白色
    bg_iconstrip   = { 240, 240, 244, 255 },     -- 图标条
    bg_chat_soft   = { 250, 252, 255, 255 },     -- 聊天气泡区淡蓝底
    bg_tab_bar     = { 252, 253, 255, 255 },

    -- 飞书系主色 / 二次元点缀
    primary_blue   = { 51, 109, 255, 255 },
    primary_blue_light = { 230, 240, 255, 255 },
    anime_pink     = { 255, 105, 180, 255 },
    accent_cyan    = { 72, 199, 200, 255 },

    -- 文字
    text_primary   = { 35, 35, 40, 255 },        -- 主文字深黑
    text_secondary = { 90, 90, 100, 255 },       -- 副文字深灰
    text_muted     = { 155, 155, 165, 255 },     -- 弱化文字
    text_white     = { 255, 255, 255, 255 },     -- 白色文字

    -- 强调色
    accent         = { 210, 130, 50, 255 },      -- 暖橙色主调
    accent_hover   = { 190, 110, 40, 255 },
    accent_light   = { 255, 245, 230, 255 },     -- 淡橙背景

    -- 语义色
    danger         = { 225, 65, 65, 255 },
    danger_light   = { 255, 235, 235, 255 },
    success        = { 50, 175, 80, 255 },
    success_light  = { 230, 250, 235, 255 },
    warning        = { 235, 165, 30, 255 },
    warning_light  = { 255, 248, 225, 255 },

    -- 分隔 & 边框
    divider        = { 230, 230, 235, 255 },
    border         = { 220, 220, 225, 255 },
    online_green   = { 50, 180, 80, 255 },

    -- 频道
    channel_public = { 120, 120, 130, 255 },
    channel_secret = { 210, 130, 50, 255 },

    -- 标签页
    tab_active     = { 51, 109, 255, 255 },
    tab_inactive   = { 155, 155, 165, 255 },
    tab_underline  = { 51, 109, 255, 255 },

    -- 气泡色
    bubble_self    = { 210, 135, 55, 255 },      -- 老板消息暖橙
    bubble_other   = { 238, 238, 242, 255 },     -- 他人消息浅灰
    bubble_system  = { 245, 245, 248, 255 },     -- 系统消息
}

-- ============================================================
-- 部门视觉配置
-- ============================================================

GameConfig.DEPT_ICONS = {
    zhongshu   = "📋",
    gongbu     = "⚒️",
    menxia     = "🔍",
    acceptance = "📝",
    shangshu   = "📊",
    system     = "🔔",
    boss       = "👔",
}

-- 部门徽章颜色（用于聊天消息中的彩色标签）
GameConfig.DEPT_BADGE_COLORS = {
    zhongshu   = { 215, 145, 45, 255 },     -- 橙色
    gongbu     = { 70, 125, 200, 255 },     -- 蓝色
    menxia     = { 60, 170, 100, 255 },     -- 绿色
    acceptance = { 155, 80, 180, 255 },     -- 紫色
    shangshu   = { 200, 80, 80, 255 },      -- 红色
    system     = { 140, 140, 150, 255 },    -- 灰色
    boss       = { 210, 130, 50, 255 },     -- 金色
}

-- 部门短名（用于徽章显示）
GameConfig.DEPT_SHORT = {
    zhongshu   = "中",
    gongbu     = "工",
    menxia     = "门",
    acceptance = "验",
    shangshu   = "尚",
    system     = "系",
    boss       = "老",
}

-- 部门全名
GameConfig.DEPT_NAMES = {
    zhongshu   = "中书省",
    gongbu     = "工部",
    menxia     = "门下省",
    acceptance = "验收官",
    shangshu   = "尚书省",
    system     = "系统",
    boss       = "老板",
}

-- 部门状态指示灯颜色
GameConfig.DEPT_STATUS_DOT = {
    idle       = { 50, 180, 80, 255 },      -- 绿
    working    = { 235, 165, 30, 255 },      -- 黄
    overloaded = { 225, 65, 65, 255 },       -- 红
}

-- ============================================================
-- UI 尺寸（竖屏移动端布局 — 聊天常驻 + 右侧索引）
-- ============================================================
GameConfig.UI = {
    -- 顶栏 & 输入栏
    statusbar_height = 44,
    input_bar_height = 52,
    tab_bar_height = 46,

    -- 右侧索引条（窄条入口，主列表在抽屉）
    sidebar_width = 40,

    -- 频道列表
    channel_item_height = 50,

    -- 字体
    font_size_title = 16,
    font_size_body = 14,
    font_size_small = 12,
    font_size_tiny = 10,

    -- 间距 / 圆角阶梯
    padding = 12,
    gap = 8,
    radius = 8,
    radius_lg = 14,
    radius_sm = 6,
    radius_xl = 18,

    -- 右侧索引项
    sidebar_items = {
        { id = "channels", icon = "💬", label = "频道" },
        { id = "workbench", icon = "📋", label = "工作台" },
        { id = "skills",  icon = "⚡", label = "指挥" },
        { id = "finance", icon = "📊", label = "财务" },
    },
}

return GameConfig
