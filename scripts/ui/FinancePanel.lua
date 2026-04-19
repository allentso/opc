-- ============================================================================
-- FinancePanel.lua — 财务报告 Tab（v0.4 对齐 HTML 设计稿）
--
-- 内容（自上而下）：
--   1. 资金概览卡：当前资金、本周变化（▲/▼）、声誉分
--   2. 7 天收支迷你图（柱状图，无第三方依赖，UI.Panel 拼）
--   3. 收入/支出明细（按类别聚合）
--   4. 订单完成统计（数量、平均分、成功率）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local GameManager = require("core.GameManager")
local OrderManager = require("systems.OrderManager")
local EventBus = require("core.EventBus")
local C = GameConfig.COLORS
local E = EventBus.Events

local FinancePanel = {}

local containerRef_ = nil
local contentRef_ = nil

-- 简易内置账本（GameManager 暂未提供历史，按内存累计）
local ledger_ = {
    income = {},     -- { { day, amount, reason } }
    expense = {},
}

local function _onFundsChanged(delta, reason)
    if not delta or delta == 0 then return end
    local entry = {
        day = GameManager.GetState and GameManager.GetState().day or 0,
        amount = math.abs(delta),
        reason = reason or "未分类",
    }
    if delta > 0 then
        table.insert(ledger_.income, entry)
    else
        table.insert(ledger_.expense, entry)
    end
end

--- 创建财务面板
function FinancePanel.Create()
    contentRef_ = UI.Panel {
        id = "financeContent",
        width = "100%",
        flexDirection = "column",
        padding = 12,
        gap = 12,
    }

    containerRef_ = UI.Panel {
        id = "financePanel",
        width = "100%",
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        flexDirection = "column",
        backgroundColor = C.bg_primary,
        children = {
            UI.ScrollView {
                width = "100%",
                flexGrow = 1, flexBasis = 0,
                showScrollbar = true,
                children = { contentRef_ },
            },
        },
    }

    EventBus.On(E.FUNDS_CHANGED, function(delta, reason)
        _onFundsChanged(delta, reason)
        FinancePanel.Refresh()
    end)
    EventBus.On(E.ORDER_PROGRESS, function() FinancePanel.Refresh() end)
    EventBus.On(E.UI_REFRESH, function() FinancePanel.Refresh() end)
    EventBus.On(E.DAY_END, function() FinancePanel.Refresh() end)

    FinancePanel.Refresh()
    return containerRef_
end

-- ============================================================
-- 渲染
-- ============================================================
function FinancePanel.Refresh()
    if not contentRef_ then return end
    contentRef_:ClearChildren()

    contentRef_:AddChild(FinancePanel._buildOverview())
    contentRef_:AddChild(FinancePanel._buildMiniChart())
    contentRef_:AddChild(FinancePanel._buildBreakdown())
    contentRef_:AddChild(FinancePanel._buildOrderStats())
end

-- ============================================================
-- 1. 资金概览
-- ============================================================
function FinancePanel._buildOverview()
    local state = GameManager.GetState and GameManager.GetState() or {}
    local funds = state.funds or 0
    local rep = state.reputation or 3

    local weekIncome = 0
    local weekExpense = 0
    for _, e in ipairs(ledger_.income) do weekIncome = weekIncome + e.amount end
    for _, e in ipairs(ledger_.expense) do weekExpense = weekExpense + e.amount end
    local net = weekIncome - weekExpense

    return UI.Panel {
        width = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_card,
        borderRadius = 12,
        padding = 14,
        gap = 9,
        children = {
            UI.Label {
                text = "💰 资金概览",
                fontSize = 13,
                fontColor = C.text_primary,
                fontWeight = "bold",
            },
            UI.Panel {
                flexDirection = "row",
                alignItems = "baseline",
                gap = 6,
                children = {
                    UI.Label {
                        text = "¥" .. FinancePanel._fmt(funds),
                        fontSize = 32,
                        fontColor = C.text_primary,
                        fontWeight = "bold",
                    },
                    UI.Label {
                        text = (net >= 0 and ("▲ +" .. FinancePanel._fmt(net))
                            or ("▼ " .. FinancePanel._fmt(net))),
                        fontSize = 12,
                        fontColor = (net >= 0) and C.success or C.danger,
                        fontWeight = "bold",
                    },
                },
            },
            UI.Panel {
                flexDirection = "row",
                gap = 16,
                marginTop = 4,
                children = {
                    FinancePanel._chip("收入", "¥" .. FinancePanel._fmt(weekIncome), C.success_light, C.success),
                    FinancePanel._chip("支出", "¥" .. FinancePanel._fmt(weekExpense), C.danger_light, C.danger),
                    FinancePanel._chip("声誉", "★ " .. tostring(math.floor(rep * 4)), C.accent_light, C.accent),
                },
            },
        },
    }
end

function FinancePanel._chip(label, value, bg, fg)
    return UI.Panel {
        flexDirection = "column",
        backgroundColor = bg,
        borderRadius = 8,
        paddingLeft = 9, paddingRight = 9,
        paddingTop = 6, paddingBottom = 6,
        gap = 1,
        children = {
            UI.Label {
                text = label,
                fontSize = 9,
                fontColor = fg,
            },
            UI.Label {
                text = value,
                fontSize = 12,
                fontColor = fg,
                fontWeight = "bold",
            },
        },
    }
end

-- ============================================================
-- 2. 7 天收支迷你柱状图（自绘）
-- ============================================================
function FinancePanel._buildMiniChart()
    -- 按 day 聚合
    local state = GameManager.GetState and GameManager.GetState() or {}
    local today = state.day or 0
    local startDay = math.max(1, today - 6)

    local incPerDay = {}
    local expPerDay = {}
    for d = startDay, today do
        incPerDay[d] = 0
        expPerDay[d] = 0
    end
    for _, e in ipairs(ledger_.income) do
        if e.day >= startDay then incPerDay[e.day] = (incPerDay[e.day] or 0) + e.amount end
    end
    for _, e in ipairs(ledger_.expense) do
        if e.day >= startDay then expPerDay[e.day] = (expPerDay[e.day] or 0) + e.amount end
    end

    -- 找最大值做缩放
    local maxAmt = 100
    for d = startDay, today do
        if incPerDay[d] > maxAmt then maxAmt = incPerDay[d] end
        if expPerDay[d] > maxAmt then maxAmt = expPerDay[d] end
    end

    local bars = {}
    for d = startDay, today do
        local incH = math.floor((incPerDay[d] / maxAmt) * 80)
        local expH = math.floor((expPerDay[d] / maxAmt) * 80)
        table.insert(bars, UI.Panel {
            flexGrow = 1, flexBasis = 0,
            flexDirection = "column",
            alignItems = "center",
            gap = 1,
            children = {
                -- 收入柱（绿，向上）
                UI.Panel {
                    width = "60%",
                    height = math.max(2, incH),
                    backgroundColor = C.success,
                    borderRadius = 2,
                },
                -- 支出柱（红，向下）
                UI.Panel {
                    width = "60%",
                    height = math.max(2, expH),
                    backgroundColor = C.danger,
                    borderRadius = 2,
                },
                UI.Label {
                    text = "D" .. tostring(d),
                    fontSize = 8,
                    fontColor = C.text_muted,
                },
            },
        })
    end

    return UI.Panel {
        width = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_card,
        borderRadius = 12,
        padding = 14,
        gap = 8,
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 8,
                children = {
                    UI.Label {
                        text = "📈 近 7 日收支",
                        fontSize = 13,
                        fontColor = C.text_primary,
                        fontWeight = "bold",
                        flexGrow = 1,
                    },
                    UI.Panel {
                        width = 8, height = 8,
                        backgroundColor = C.success,
                        borderRadius = 2,
                    },
                    UI.Label { text = "收", fontSize = 10, fontColor = C.text_muted },
                    UI.Panel {
                        width = 8, height = 8,
                        backgroundColor = C.danger,
                        borderRadius = 2,
                    },
                    UI.Label { text = "支", fontSize = 10, fontColor = C.text_muted },
                },
            },
            UI.Panel {
                width = "100%",
                height = 180,
                flexDirection = "row",
                alignItems = "flex-end",
                gap = 4,
                paddingTop = 4, paddingBottom = 4,
                children = bars,
            },
        },
    }
end

-- ============================================================
-- 3. 收入/支出明细
-- ============================================================
function FinancePanel._buildBreakdown()
    -- 按 reason 聚合
    local incomeByReason, expenseByReason = {}, {}
    for _, e in ipairs(ledger_.income) do
        incomeByReason[e.reason] = (incomeByReason[e.reason] or 0) + e.amount
    end
    for _, e in ipairs(ledger_.expense) do
        expenseByReason[e.reason] = (expenseByReason[e.reason] or 0) + e.amount
    end

    local function _section(title, color, dict)
        local rows = {}
        local total = 0
        local keys = {}
        for k, v in pairs(dict) do total = total + v; table.insert(keys, k) end
        if #keys == 0 then
            table.insert(rows, UI.Label {
                text = "暂无记录",
                fontSize = 10,
                fontColor = C.text_muted,
            })
        else
            table.sort(keys, function(a, b) return dict[a] > dict[b] end)
            for _, k in ipairs(keys) do
                table.insert(rows, UI.Panel {
                    flexDirection = "row",
                    alignItems = "center",
                    gap = 8,
                    paddingTop = 3, paddingBottom = 3,
                    children = {
                        UI.Label {
                            text = k,
                            fontSize = 11,
                            fontColor = C.text_secondary,
                            flexGrow = 1, flexShrink = 1,
                        },
                        UI.Label {
                            text = "¥" .. FinancePanel._fmt(dict[k]),
                            fontSize = 11,
                            fontColor = color,
                            fontWeight = "bold",
                        },
                    },
                })
            end
        end
        return UI.Panel {
            flexGrow = 1, flexBasis = 0,
            flexDirection = "column",
            gap = 2,
            backgroundColor = C.bg_card,
            borderRadius = 10,
            padding = 11,
            children = {
                UI.Label {
                    text = title,
                    fontSize = 11,
                    fontColor = color,
                    fontWeight = "bold",
                    paddingBottom = 4,
                    borderBottomWidth = 1,
                    borderColor = C.divider,
                },
                UI.Panel {
                    flexDirection = "column",
                    children = rows,
                },
            },
        }
    end

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        gap = 9,
        children = {
            _section("📥 收入明细", C.success, incomeByReason),
            _section("📤 支出明细", C.danger, expenseByReason),
        },
    }
end

-- ============================================================
-- 4. 订单完成统计
-- ============================================================
function FinancePanel._buildOrderStats()
    local stats = OrderManager.GetStats() or {}
    local total = stats.total or 0
    local successRate = total > 0 and (stats.completed / total * 100) or 0

    return UI.Panel {
        width = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_card,
        borderRadius = 12,
        padding = 14,
        gap = 9,
        children = {
            UI.Label {
                text = "📊 订单统计",
                fontSize = 13,
                fontColor = C.text_primary,
                fontWeight = "bold",
            },
            UI.Panel {
                flexDirection = "row",
                gap = 12,
                children = {
                    FinancePanel._statBlock("已完成", tostring(stats.completed or 0), C.success),
                    FinancePanel._statBlock("失败", tostring(stats.failed or 0), C.danger),
                    FinancePanel._statBlock("成功率", string.format("%d%%", math.floor(successRate)), C.accent),
                },
            },
            UI.Panel {
                flexDirection = "row",
                gap = 6,
                marginTop = 4,
                flexWrap = "wrap",
                children = {
                    FinancePanel._typeChip("🔥 热点", stats.hot_completed or 0, C.color_gongbu),
                    FinancePanel._typeChip("💎 品牌", stats.brand_completed or 0, C.color_zhongshu),
                    FinancePanel._typeChip("📱 应用", stats.app_completed or 0, C.primary_blue),
                    FinancePanel._typeChip("❓ 神秘", stats.mystery_completed or 0, C.yellow),
                },
            },
        },
    }
end

function FinancePanel._statBlock(label, value, color)
    return UI.Panel {
        flexGrow = 1, flexBasis = 0,
        flexDirection = "column",
        alignItems = "center",
        backgroundColor = C.bg_primary,
        borderRadius = 8,
        paddingTop = 9, paddingBottom = 9,
        gap = 2,
        children = {
            UI.Label {
                text = value,
                fontSize = 18,
                fontColor = color,
                fontWeight = "bold",
            },
            UI.Label {
                text = label,
                fontSize = 9,
                fontColor = C.text_muted,
            },
        },
    }
end

function FinancePanel._typeChip(label, count, color)
    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        backgroundColor = C.bg_primary,
        borderRadius = 7,
        paddingLeft = 7, paddingRight = 7,
        paddingTop = 3, paddingBottom = 3,
        gap = 4,
        children = {
            UI.Label {
                text = label,
                fontSize = 10,
                fontColor = color,
            },
            UI.Label {
                text = "×" .. tostring(count),
                fontSize = 10,
                fontColor = C.text_secondary,
                fontWeight = "bold",
            },
        },
    }
end

-- ============================================================
-- 工具
-- ============================================================
function FinancePanel._fmt(n)
    n = math.floor(n or 0)
    local s = tostring(n)
    local k
    while true do
        s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return s
end

return FinancePanel
