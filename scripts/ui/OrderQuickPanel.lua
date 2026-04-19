-- ============================================================================
-- OrderQuickPanel.lua — 工作台核心面板（v0.4 对齐 HTML 设计稿）
--
-- 区域布局（垂直从上到下）：
--   1. 进行中订单卡（若有）：
--      - 订单标题 + 类型图标 + 风险/难度
--      - 5 阶段进度条（接单→执行→审查→验收→结算）
--      - 参与部门 chip 列表
--   2. 可接取订单列表：
--      - 订单卡（标题 / 类型徽章 / 难度星星 / 参与部门 / 报酬 / 接取按钮）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local OrderManager = require("systems.OrderManager")
local GameManager = require("core.GameManager")
local EventBus = require("core.EventBus")
local C = GameConfig.COLORS
local E = EventBus.Events

local OrderQuickPanel = {}

local containerRef_ = nil
local activeAreaRef_ = nil
local availableHeaderRef_ = nil
local availableListRef_ = nil
local callbacks_ = {}

-- 5 个阶段定义（顺序与 GameManager.workflowPhase 对应）
local PHASES = {
    { id = "accept",     label = "接单",   icon = "📥" },
    { id = "execute",    label = "执行",   icon = "✍️" },
    { id = "review",     label = "审查",   icon = "🔍" },
    { id = "acceptance", label = "验收",   icon = "📋" },
    { id = "settlement", label = "结算",   icon = "💰" },
}

--- 创建工作台面板
function OrderQuickPanel.Create(cbs)
    callbacks_ = cbs or {}

    activeAreaRef_ = UI.Panel {
        id = "wbActiveArea",
        width = "100%",
        flexDirection = "column",
        paddingLeft = 10, paddingRight = 10,
        paddingTop = 4, paddingBottom = 4,
        gap = 6,
    }

    availableHeaderRef_ = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 14, paddingRight = 14,
        paddingTop = 8, paddingBottom = 4,
        gap = 6,
        flexShrink = 0,
        children = {
            UI.Label { text = "📋", fontSize = 13 },
            UI.Label {
                id = "wbAvailHeaderLabel",
                text = "可接取订单",
                fontSize = 12,
                fontColor = C.text_primary,
                fontWeight = "bold",
            },
        },
    }

    availableListRef_ = UI.Panel {
        id = "wbAvailableList",
        width = "100%",
        flexDirection = "column",
        paddingLeft = 10, paddingRight = 10,
        paddingTop = 2, paddingBottom = 8,
        gap = 6,
    }

    containerRef_ = UI.Panel {
        id = "orderQuickPanel",
        width = "100%",
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        flexDirection = "column",
        backgroundColor = C.bg_primary,
        children = {
            UI.ScrollView {
                width = "100%",
                flexGrow = 1, flexBasis = 0,
                showScrollbar = true,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        children = {
                            activeAreaRef_,
                            availableHeaderRef_,
                            availableListRef_,
                        },
                    },
                },
            },
        },
    }

    OrderQuickPanel._refresh()

    EventBus.On(E.ORDER_NEW, function() OrderQuickPanel._refresh() end)
    EventBus.On(E.ORDER_ACCEPTED, function() OrderQuickPanel._refresh() end)
    EventBus.On(E.ORDER_PROGRESS, function() OrderQuickPanel._refresh() end)
    EventBus.On(E.UI_REFRESH, function() OrderQuickPanel._refresh() end)
    EventBus.On(E.PHASE_CHANGE, function() OrderQuickPanel._refresh() end)

    return containerRef_
end

-- ============================================================
-- 刷新整体
-- ============================================================
function OrderQuickPanel._refresh()
    if not activeAreaRef_ or not availableListRef_ then return end

    -- 进行中订单
    activeAreaRef_:ClearChildren()
    local active = OrderManager.GetActiveOrder()
    if active then
        activeAreaRef_:AddChild(OrderQuickPanel._createActiveCard(active))
    end

    -- 可接取订单
    availableListRef_:ClearChildren()
    local available = OrderManager.GetAvailableOrders()

    if availableHeaderRef_ then
        local lbl = availableHeaderRef_:FindById("wbAvailHeaderLabel")
        if lbl then
            lbl:SetText("可接取订单 (" .. tostring(#available) .. ")")
        end
    end

    if #available == 0 and not active then
        availableListRef_:AddChild(UI.Panel {
            width = "100%",
            paddingTop = 18, paddingBottom = 18,
            justifyContent = "center", alignItems = "center",
            children = {
                UI.Label {
                    text = "📭 今日订单已全部接取",
                    fontSize = 12,
                    fontColor = C.text_muted,
                },
            },
        })
        return
    end

    for _, order in ipairs(available) do
        availableListRef_:AddChild(OrderQuickPanel._createAvailableCard(order))
    end
end

-- ============================================================
-- 进行中订单卡（含 5 阶段进度）
-- ============================================================
function OrderQuickPanel._createActiveCard(order)
    local typeLabel = OrderManager.GetOrderTypeLabel(order.type)
    local currentPhase = GameManager.GetWorkflowPhase() or "accept"
    local currentIdx = OrderQuickPanel._phaseIndex(currentPhase)

    -- 顶部：标题 + 类型徽章
    local titleRow = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 8,
        children = {
            UI.Panel {
                paddingLeft = 6, paddingRight = 6,
                paddingTop = 2, paddingBottom = 2,
                borderRadius = 8,
                backgroundColor = OrderQuickPanel._typeBgColor(order.type),
                children = {
                    UI.Label {
                        text = typeLabel or "订单",
                        fontSize = 9,
                        fontColor = OrderQuickPanel._typeFgColor(order.type),
                        fontWeight = "bold",
                    },
                },
            },
            UI.Label {
                text = order.name or "",
                fontSize = 13,
                fontColor = C.text_primary,
                fontWeight = "bold",
                flexGrow = 1, flexShrink = 1,
            },
            UI.Label {
                text = "▶ 进行中",
                fontSize = 10,
                fontColor = C.accent,
                fontWeight = "bold",
            },
        },
    }

    -- 5 阶段进度条
    local phaseBar = OrderQuickPanel._createPhaseBar(currentIdx)

    -- 部门 chip
    local deptRow = OrderQuickPanel._createDeptChips(order)

    -- 当前阶段提示
    local phaseInfo = UI.Label {
        text = "当前：" .. (PHASES[currentIdx] and PHASES[currentIdx].label or "?"),
        fontSize = 10,
        fontColor = C.text_secondary,
    }

    return UI.Panel {
        width = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_card,
        borderRadius = 10,
        borderWidth = 2,
        borderColor = C.accent,
        paddingLeft = 11, paddingRight = 11,
        paddingTop = 11, paddingBottom = 11,
        gap = 8,
        children = {
            titleRow,
            phaseBar,
            phaseInfo,
            deptRow,
        },
    }
end

--- 5 阶段进度条 widget
function OrderQuickPanel._createPhaseBar(currentIdx)
    local children = {}
    for i, p in ipairs(PHASES) do
        local isDone = i < currentIdx
        local isActive = i == currentIdx
        local bg, fg
        if isActive then
            bg, fg = C.accent, C.text_white
        elseif isDone then
            bg, fg = C.success_light, C.success
        else
            bg, fg = C.bg_input, C.text_muted
        end

        table.insert(children, UI.Panel {
            flexGrow = 1,
            flexBasis = 0,
            flexDirection = "column",
            justifyContent = "center", alignItems = "center",
            paddingTop = 6, paddingBottom = 6,
            backgroundColor = bg,
            borderRadius = 6,
            gap = 1,
            children = {
                UI.Label {
                    text = p.icon,
                    fontSize = 13,
                    fontColor = fg,
                },
                UI.Label {
                    text = p.label,
                    fontSize = 8,
                    fontColor = fg,
                    fontWeight = isActive and "bold" or "normal",
                },
            },
        })

        if i < #PHASES then
            -- 阶段连接线
            table.insert(children, UI.Panel {
                width = 4, height = 1,
                backgroundColor = C.divider,
                marginLeft = 1, marginRight = 1,
                alignSelf = "center",
            })
        end
    end

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "stretch",
        gap = 0,
        children = children,
    }
end

--- 部门参与 chip 列表
function OrderQuickPanel._createDeptChips(order)
    local depts = order.departments or { "zhongshu", "gongbu", "menxia" }
    local chips = {
        UI.Label {
            text = "参与:",
            fontSize = 10,
            fontColor = C.text_muted,
            marginRight = 2,
        },
    }
    for _, d in ipairs(depts) do
        local color = GameConfig.DEPT_BADGE_COLORS[d] or C.text_muted
        local short = GameConfig.DEPT_NAMES[d] or d
        table.insert(chips, UI.Panel {
            paddingLeft = 6, paddingRight = 6,
            paddingTop = 1, paddingBottom = 1,
            borderRadius = 7,
            backgroundColor = OrderQuickPanel._lightenColor(color),
            children = {
                UI.Label {
                    text = short,
                    fontSize = 9,
                    fontColor = color,
                    fontWeight = "bold",
                },
            },
        })
    end
    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = 4,
        children = chips,
    }
end

-- ============================================================
-- 可接取订单卡
-- ============================================================
function OrderQuickPanel._createAvailableCard(order)
    local typeLabel = OrderManager.GetOrderTypeLabel(order.type)
    local difficulty = order.difficulty or 3
    local stars = string.rep("★", difficulty) .. string.rep("☆", 5 - difficulty)

    -- 顶部：类型徽章 + 难度
    local headRow = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 6,
        children = {
            UI.Panel {
                paddingLeft = 6, paddingRight = 6,
                paddingTop = 2, paddingBottom = 2,
                borderRadius = 8,
                backgroundColor = OrderQuickPanel._typeBgColor(order.type),
                children = {
                    UI.Label {
                        text = typeLabel or "订单",
                        fontSize = 9,
                        fontColor = OrderQuickPanel._typeFgColor(order.type),
                        fontWeight = "bold",
                    },
                },
            },
            UI.Label {
                text = stars,
                fontSize = 10,
                fontColor = C.warning,
            },
            UI.Label {
                text = "",
                flexGrow = 1,
            },
            UI.Label {
                text = "¥" .. tostring(order.reward),
                fontSize = 13,
                fontColor = C.success,
                fontWeight = "bold",
            },
        },
    }

    -- 标题
    local titleLabel = UI.Label {
        text = order.name or "",
        fontSize = 12,
        fontColor = C.text_primary,
        fontWeight = "bold",
    }

    -- 部门 chip
    local deptRow = OrderQuickPanel._createDeptChips(order)

    -- 接取按钮
    local hasActive = OrderManager.GetActiveOrder() ~= nil
    local acceptBtn = UI.Button {
        text = hasActive and "已有进行中" or "接取",
        width = 84,
        height = 30,
        fontSize = 11,
        variant = hasActive and "secondary" or "primary",
        borderRadius = 15,
        disabled = hasActive,
        onClick = function()
            if hasActive then return end
            if callbacks_.onAcceptOrder then
                callbacks_.onAcceptOrder(order.id)
            end
        end,
    }

    local actionRow = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        children = {
            UI.Panel { flexGrow = 1, children = { deptRow } },
            acceptBtn,
        },
    }

    return UI.Panel {
        width = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_card,
        borderRadius = 10,
        borderWidth = 1,
        borderColor = C.border,
        paddingLeft = 11, paddingRight = 11,
        paddingTop = 9, paddingBottom = 9,
        gap = 6,
        children = {
            headRow,
            titleLabel,
            actionRow,
        },
    }
end

-- ============================================================
-- 工具
-- ============================================================

function OrderQuickPanel._phaseIndex(phaseId)
    if not phaseId then return 1 end
    for i, p in ipairs(PHASES) do
        if p.id == phaseId then return i end
    end
    return 1
end

function OrderQuickPanel._typeBgColor(orderType)
    if orderType == "hotspot" or orderType == "hot" then return C.color_gongbu_light end
    if orderType == "brand" then return C.color_zhongshu_light end
    if orderType == "app" or orderType == "application" then return C.primary_blue_light end
    if orderType == "mystery" then return C.yellow_light end
    return C.accent_light
end

function OrderQuickPanel._typeFgColor(orderType)
    if orderType == "hotspot" or orderType == "hot" then return C.color_gongbu end
    if orderType == "brand" then return C.color_zhongshu end
    if orderType == "app" or orderType == "application" then return C.primary_blue end
    if orderType == "mystery" then return C.yellow end
    return C.accent
end

--- 把一个 RGBA 色淡化为同色系背景
function OrderQuickPanel._lightenColor(rgba)
    local r = math.min(255, rgba[1] + (255 - rgba[1]) * 0.85)
    local g = math.min(255, rgba[2] + (255 - rgba[2]) * 0.85)
    local b = math.min(255, rgba[3] + (255 - rgba[3]) * 0.85)
    return { math.floor(r), math.floor(g), math.floor(b), 255 }
end

return OrderQuickPanel
