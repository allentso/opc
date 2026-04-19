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

-- 私下频道解锁条件（5 个，对齐 GDD v2.0）
GameConfig.SECRET_CHANNELS = {
    {
        id = "slacking",
        name = "工部摸鱼小群",
        icon = "👀",
        condition = "工部连续 3 天高压（≥45% 满载）",
        conditionType = "overwork",
        threshold = 3,
    },
    {
        id = "boss_gossip",
        name = "蛐蛐老板实名群",
        icon = "🤪",
        condition = "老板强制拍板 3 次",
        conditionType = "force_approve_count",
        threshold = 3,
    },
    {
        id = "secret_alliance",
        name = "工部门下省秘密结盟",
        icon = "🤝",
        condition = "两部门冲突超过 5 次",
        conditionType = "conflict_count",
        threshold = 5,
    },
    {
        id = "zhongshu_abacus",
        name = "中书省小算盘",
        icon = "🧮",
        condition = "中书省累计参与 8 个订单",
        conditionType = "zhongshu_orders",
        threshold = 8,
    },
    {
        id = "acceptance_rant",
        name = "验收官吐槽群",
        icon = "😤",
        condition = "出现过验收不通过",
        conditionType = "acceptance_failed",
        threshold = 1,
    },
}

-- 每日策略（开工时可切换，影响审查/执行/奖励等多维度）
-- effect 字段为简短描述，rules 是机制层影响
GameConfig.DAILY_STRATEGIES = {
    {
        id = "balanced",
        icon = "📌",
        label = "均衡发展",
        effect = "审查通过率+10%，执行速度-5%。新手推荐，不偏科。",
        reviewApproveDelta = 10,
        executeSpeedDelta = -0.05,
        rewardMultiplier = 1.0,
        conflictRateDelta = 0.0,
    },
    {
        id = "fast",
        icon = "⚡",
        label = "快速出单",
        effect = "执行速度+30%，质检强度-20%，风险↑。适合热点单冲速度。",
        reviewApproveDelta = -20,
        executeSpeedDelta = 0.30,
        rewardMultiplier = 1.0,
        conflictRateDelta = 0.10,
    },
    {
        id = "quality",
        icon = "🛡",
        label = "质量优先",
        effect = "高品质通过率+25%，速度-15%。适合品牌单和神秘单。",
        reviewApproveDelta = 5,
        executeSpeedDelta = -0.15,
        rewardMultiplier = 1.0,
        qualityBoost = 0.25,
    },
    {
        id = "profit",
        icon = "💰",
        label = "利益最大化",
        effect = "订单奖励+15%，冲突概率+10%。高风险高回报。",
        reviewApproveDelta = 0,
        executeSpeedDelta = 0,
        rewardMultiplier = 1.15,
        conflictRateDelta = 0.10,
    },
    {
        id = "mystery",
        icon = "🔮",
        label = "神秘策略",
        effect = "???",
        unlockHint = "完成 5 个神秘订单后解锁",
        unlockType = "mystery_completed",
        unlockThreshold = 5,
        reviewApproveDelta = 0,
        executeSpeedDelta = 0,
        rewardMultiplier = 1.0,
    },
}

-- ============================================================
-- UI 配色（对齐 ui_redesign_reference.html v0.4 设计稿）
-- 基调：暖米色背景 + 暖橙色主操作 + 紫蓝色三省色 + 黄红事故色
-- ============================================================
GameConfig.COLORS = {
    -- 背景层（米色基底）
    bg_primary     = { 244, 243, 239, 255 },     -- #F4F3EF 主背景米色
    bg_secondary   = { 248, 247, 243, 255 },     -- 侧边栏暖灰
    bg_card        = { 255, 255, 255, 255 },     -- #FFF 卡片纯白
    bg_chat        = { 255, 255, 255, 255 },     -- 聊天区白色
    bg_input       = { 244, 243, 239, 255 },     -- 输入框米色
    bg_hover       = { 250, 240, 228, 255 },     -- 悬停态：浅橙
    bg_selected    = { 251, 240, 228, 255 },     -- 选中态：橙底淡色（HTML --acc-l）
    bg_topbar      = { 255, 255, 255, 255 },
    bg_bottombar   = { 255, 255, 255, 255 },
    bg_chat_soft   = { 244, 243, 239, 255 },     -- 聊天气泡区
    bg_tab_bar     = { 255, 255, 255, 255 },
    bg_iconstrip   = { 28, 28, 35, 255 },        -- 频道边栏深色 #1C1C23

    -- 强调色（HTML --acc 暖橙）
    accent         = { 210, 130, 50, 255 },      -- #D28232
    accent_hover   = { 168, 95, 26, 255 },       -- #A85F1A
    accent_light   = { 251, 240, 228, 255 },     -- #FBF0E4

    -- 三省色（HTML 设计稿对应色）
    color_zhongshu = { 123, 104, 238, 255 },     -- #7B68EE 中书省紫
    color_zhongshu_light = { 240, 238, 248, 255 },
    color_gongbu   = { 232, 112, 64, 255 },      -- #E87040 工部橙红
    color_gongbu_light = { 254, 235, 224, 255 },
    color_menxia   = { 32, 168, 216, 255 },      -- #20A8D8 门下省青蓝
    color_menxia_light = { 224, 244, 252, 255 },

    -- 副蓝（工作流/应用单）
    primary_blue   = { 74, 107, 245, 255 },      -- #4A6BF5
    primary_blue_light = { 238, 241, 254, 255 }, -- #EEF1FE

    -- 文字
    text_primary   = { 26, 26, 34, 255 },        -- #1A1A22
    text_secondary = { 107, 107, 122, 255 },     -- #6B6B7A
    text_muted     = { 160, 160, 175, 255 },     -- #A0A0AF
    text_white     = { 255, 255, 255, 255 },

    -- 语义色
    danger         = { 232, 64, 64, 255 },       -- #E84040
    danger_light   = { 254, 232, 232, 255 },     -- #FEE8E8
    success        = { 34, 168, 97, 255 },       -- #22A861
    success_light  = { 230, 247, 239, 255 },     -- #E6F7EF
    warning        = { 224, 152, 32, 255 },      -- #E09820
    warning_light  = { 254, 245, 224, 255 },     -- #FEF5E0
    yellow         = { 240, 160, 32, 255 },      -- #F0A020 神秘单/事故黄
    yellow_light   = { 254, 245, 224, 255 },

    -- 分隔 & 边框
    divider        = { 232, 231, 228, 255 },     -- #E8E7E4
    border         = { 232, 231, 228, 255 },
    border_strong  = { 208, 207, 204, 255 },     -- #D0CFCC
    online_green   = { 34, 168, 97, 255 },

    -- 频道边栏（深色基底）
    channel_sb_bg          = { 28, 28, 35, 255 },     -- #1C1C23
    channel_sb_label       = { 255, 255, 255, 64 },   -- rgba(255,255,255,.25)
    channel_sb_label_active= { 255, 255, 255, 204 },  -- rgba(255,255,255,.8)
    channel_sb_active_bg   = { 210, 130, 50, 51 },    -- rgba(210,130,50,.20)
    channel_sb_hover_bg    = { 255, 255, 255, 20 },   -- rgba(255,255,255,.08)
    channel_sb_divider     = { 255, 255, 255, 26 },   -- rgba(255,255,255,.10)
    channel_secret_bg      = { 45, 45, 58, 255 },     -- #2D2D3A 私下头像底
    channel_secret_label   = { 255, 100, 100, 191 },  -- 红色频道名
    channel_secret_locked_bg = { 28, 28, 35, 255 },

    -- 私下频道深色主题
    secret_bg              = { 18, 18, 26, 255 },     -- #12121A
    secret_topbar_bg       = { 28, 28, 35, 255 },     -- #1C1C23
    secret_bubble          = { 45, 45, 58, 255 },     -- #2D2D3A
    secret_bubble_border   = { 255, 255, 255, 18 },
    secret_text            = { 255, 255, 255, 209 },  -- rgba(255,255,255,.82)
    secret_text_muted      = { 255, 255, 255, 64 },
    secret_text_dim        = { 255, 255, 255, 38 },
    secret_avatar_bg       = { 74, 64, 96, 255 },     -- #4A4060
    secret_name            = { 160, 138, 255, 255 },  -- #A08AFF
    secret_intel_bg        = { 255, 160, 0, 26 },     -- rgba(255,160,0,.10)
    secret_intel_border    = { 255, 160, 0, 64 },
    secret_intel_title     = { 255, 180, 0, 230 },
    secret_dot_red         = { 255, 68, 68, 255 },

    -- 标签页 / Tab
    tab_active     = { 210, 130, 50, 255 },
    tab_inactive   = { 160, 160, 175, 255 },
    tab_underline  = { 210, 130, 50, 255 },

    -- 气泡色（聊天）
    bubble_self    = { 210, 130, 50, 255 },      -- 老板消息：橙
    bubble_other   = { 255, 255, 255, 255 },     -- 他人消息：白
    bubble_system  = { 232, 231, 228, 255 },     -- 系统消息：浅灰

    -- 旧 API 兼容别名（待第2批重构 UI 后删除）
    channel_public = { 160, 160, 175, 255 },
    channel_secret = { 232, 64, 64, 255 },
    anime_pink     = { 255, 105, 180, 255 },
    accent_cyan    = { 72, 199, 200, 255 },
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

-- 部门徽章颜色（对齐 HTML 设计稿：紫/橙/青蓝）
GameConfig.DEPT_BADGE_COLORS = {
    zhongshu   = { 123, 104, 238, 255 },    -- #7B68EE 紫
    gongbu     = { 232, 112, 64, 255 },     -- #E87040 橙红
    menxia     = { 32, 168, 216, 255 },     -- #20A8D8 青蓝
    acceptance = { 224, 152, 32, 255 },     -- #E09820 黄
    shangshu   = { 232, 64, 64, 255 },      -- 红
    system     = { 140, 140, 150, 255 },    -- 灰
    boss       = { 210, 130, 50, 255 },     -- #D28232 橙金
    workflow   = { 74, 107, 245, 255 },     -- #4A6BF5 蓝
    global     = { 210, 130, 50, 255 },     -- 全局公告：橙
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
-- UI 尺寸（对齐 HTML 设计稿）
-- ============================================================
GameConfig.UI = {
    -- 顶栏 & 输入栏
    statusbar_height = 44,
    input_bar_height = 52,
    tab_bar_height = 50,
    alert_bar_height = 28,

    -- 频道边栏（左侧深色 70px）
    channel_sidebar_width = 70,
    channel_icon_size = 50,        -- 单个频道图标整体格子
    channel_avatar_size = 34,       -- 头像圆方块
    channel_label_size = 8,         -- 频道名小字号

    -- 频道列表 overlay
    channel_item_height = 56,

    -- 字体
    font_size_title = 15,
    font_size_body = 13,
    font_size_small = 11,
    font_size_tiny = 9,

    -- 间距 / 圆角阶梯
    padding = 12,
    gap = 8,
    radius = 8,
    radius_lg = 12,
    radius_sm = 6,
    radius_xl = 18,
}

return GameConfig
