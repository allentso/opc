-- ============================================================================
-- AcceptanceResultOverlay.lua — 验收结果全屏页（v0.4 对齐 HTML 设计稿）
--
-- 触发：每次工作流验收阶段产出结果时由 GameManager 自动打开
-- 内容：
--   - 验收官头像 + 名字 + 性格标题（4 种性格之一）
--   - 大分数 + 通过/不通过条
--   - 评语段落
--   - 订单基本信息（名称、类型、报酬、参与部门）
--   - 操作按钮：
--     * 通过 → [继续/查看战报]
--     * 未通过 → [打回重做（消耗资金）/接受失败]
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local OrderManager = require("systems.OrderManager")
local AcceptanceAgent = require("agent.AcceptanceAgent")
local EventBus = require("core.EventBus")
local C = GameConfig.COLORS
local E = EventBus.Events

local AcceptanceResultOverlay = {}

local containerRef_ = nil
local currentPayload_ = nil  -- { passed, score, personaId, orderName, orderType, reason }

--- 创建全屏结果页（一次性创建空壳，由 Show 填充内容）
function AcceptanceResultOverlay.Create()
    containerRef_ = UI.Panel {
        id = "acceptanceResultOverlay",
        width = "100%",
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        flexDirection = "column",
        backgroundColor = C.bg_primary,
    }

    -- 监听验收完成事件
    EventBus.On(E.WORKFLOW_ACCEPTANCE_PARSED, function(passed, score, reason)
        AcceptanceResultOverlay._prepareAndShow(passed, score, reason)
    end)

    -- 兜底：simulate 模式下没有 PARSED 事件，监听 ORDER_PROGRESS 到 settlement 时拉取
    EventBus.On(E.ORDER_PROGRESS, function(order, newStatus)
        if newStatus == "submitted" then
            -- submitted = 验收阶段开始；等待结果
        end
    end)

    return containerRef_
end

--- 准备并显示
function AcceptanceResultOverlay._prepareAndShow(passed, score, reason)
    local order = OrderManager.GetActiveOrder()
    if not order then return end

    local personaId = OrderManager.GetAcceptancePersonaId()
    local persona = AcceptanceAgent.GetPersona(personaId or "picky_old")
        or AcceptanceAgent.PERSONAS[1]

    currentPayload_ = {
        passed = passed,
        score = score or 0,
        reason = reason or AcceptanceAgent.PickFallbackLine(persona, passed),
        persona = persona,
        orderName = order.name,
        orderType = order.type,
        orderReward = order.reward,
        departments = order.departments,
    }

    AcceptanceResultOverlay._render(currentPayload_)
    EventBus.Emit(E.NAV_OPEN_OVERLAY, "acceptance_result")
end

--- 渲染内容
function AcceptanceResultOverlay._render(p)
    if not containerRef_ then return end
    containerRef_:ClearChildren()

    local persona = p.persona or AcceptanceAgent.PERSONAS[1]
    local passed = p.passed
    local score = p.score or 0
    local resultColor = passed and C.success or C.danger
    local resultBg = passed and C.success_light or C.danger_light
    local resultText = passed and "✓ 验收通过" or "✗ 验收未通过"

    local content = UI.Panel {
        width = "100%",
        flexGrow = 1, flexBasis = 0,
        flexDirection = "column",
        backgroundColor = C.bg_primary,
    }

    content:AddChild(UI.ScrollView {
        width = "100%",
        flexGrow = 1, flexBasis = 0,
        showScrollbar = false,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "column",
                padding = 16,
                gap = 12,
                children = {
                    -- 验收官卡片
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        backgroundColor = persona.bgColor or C.bg_card,
                        borderRadius = 14,
                        padding = 14,
                        gap = 12,
                        children = {
                            -- 头像
                            UI.Panel {
                                width = 56, height = 56,
                                borderRadius = 14,
                                backgroundColor = persona.accentColor or C.accent,
                                justifyContent = "center", alignItems = "center",
                                flexShrink = 0,
                                children = {
                                    UI.Label {
                                        text = persona.avatar or "👤",
                                        fontSize = 28,
                                    },
                                },
                            },
                            UI.Panel {
                                flexGrow = 1, flexShrink = 1,
                                flexDirection = "column",
                                gap = 3,
                                children = {
                                    UI.Label {
                                        text = persona.name or "验收官",
                                        fontSize = 16,
                                        fontColor = C.text_primary,
                                        fontWeight = "bold",
                                    },
                                    UI.Label {
                                        text = persona.title or "",
                                        fontSize = 11,
                                        fontColor = C.text_secondary,
                                    },
                                    UI.Label {
                                        text = "「" .. (persona.catchphrase or "") .. "」",
                                        fontSize = 10,
                                        fontColor = persona.accentColor or C.accent,
                                    },
                                },
                            },
                        },
                    },

                    -- 大分数卡
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        alignItems = "center",
                        backgroundColor = resultBg,
                        borderRadius = 14,
                        borderWidth = 2,
                        borderColor = resultColor,
                        paddingTop = 18, paddingBottom = 18,
                        paddingLeft = 14, paddingRight = 14,
                        gap = 6,
                        children = {
                            UI.Label {
                                text = tostring(score),
                                fontSize = 56,
                                fontColor = resultColor,
                                fontWeight = "bold",
                            },
                            UI.Label {
                                text = "/ 100",
                                fontSize = 12,
                                fontColor = C.text_muted,
                            },
                            UI.Label {
                                text = resultText,
                                fontSize = 15,
                                fontColor = resultColor,
                                fontWeight = "bold",
                                marginTop = 4,
                            },
                        },
                    },

                    -- 评语
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        backgroundColor = C.bg_card,
                        borderRadius = 10,
                        padding = 12,
                        gap = 6,
                        borderLeftWidth = 3,
                        borderColor = persona.accentColor or C.accent,
                        children = {
                            UI.Label {
                                text = "验收评语",
                                fontSize = 10,
                                fontColor = C.text_muted,
                                fontWeight = "bold",
                            },
                            UI.Label {
                                text = p.reason or "",
                                fontSize = 13,
                                fontColor = C.text_primary,
                            },
                        },
                    },

                    -- 订单信息
                    AcceptanceResultOverlay._buildOrderInfo(p),
                },
            },
        },
    })

    -- 底部按钮区
    content:AddChild(AcceptanceResultOverlay._buildActionBar(p))

    containerRef_:AddChild(content)
end

function AcceptanceResultOverlay._buildOrderInfo(p)
    local typeLabel = OrderManager.GetOrderTypeLabel(p.orderType) or p.orderType or ""
    local depts = p.departments or {}
    local deptChips = {}
    for _, d in ipairs(depts) do
        local color = GameConfig.DEPT_BADGE_COLORS[d] or C.text_muted
        local short = GameConfig.DEPT_NAMES[d] or d
        table.insert(deptChips, UI.Panel {
            paddingLeft = 6, paddingRight = 6,
            paddingTop = 1, paddingBottom = 1,
            borderRadius = 7,
            borderWidth = 1,
            borderColor = color,
            children = {
                UI.Label {
                    text = short,
                    fontSize = 9,
                    fontColor = color,
                },
            },
        })
    end

    return UI.Panel {
        width = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_card,
        borderRadius = 10,
        padding = 12,
        gap = 7,
        children = {
            UI.Label {
                text = "订单信息",
                fontSize = 10,
                fontColor = C.text_muted,
                fontWeight = "bold",
            },
            UI.Label {
                text = p.orderName or "未命名订单",
                fontSize = 13,
                fontColor = C.text_primary,
                fontWeight = "bold",
            },
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 10,
                children = {
                    UI.Label {
                        text = typeLabel,
                        fontSize = 11,
                        fontColor = C.accent,
                    },
                    UI.Label {
                        text = "¥" .. tostring(p.orderReward or 0),
                        fontSize = 12,
                        fontColor = C.success,
                        fontWeight = "bold",
                    },
                },
            },
            UI.Panel {
                flexDirection = "row",
                gap = 4,
                flexWrap = "wrap",
                children = deptChips,
            },
        },
    }
end

function AcceptanceResultOverlay._buildActionBar(p)
    local actions
    if p.passed then
        actions = {
            UI.Button {
                text = "查看战报",
                flexGrow = 1, flexBasis = 0,
                height = 44,
                fontSize = 13,
                variant = "secondary",
                borderRadius = 22,
                onClick = function()
                    -- 战报页第6批做，这里先关闭即可
                    EventBus.Emit(E.NAV_CLOSE_OVERLAY)
                    EventBus.Emit(E.UI_TOAST, "📊 战报功能开发中…")
                end,
            },
            UI.Button {
                text = "继续 →",
                flexGrow = 2, flexBasis = 0,
                height = 44,
                fontSize = 13,
                fontWeight = "bold",
                variant = "primary",
                borderRadius = 22,
                onClick = function()
                    EventBus.Emit(E.NAV_CLOSE_OVERLAY)
                end,
            },
        }
    else
        actions = {
            UI.Button {
                text = "接受失败",
                flexGrow = 1, flexBasis = 0,
                height = 44,
                fontSize = 13,
                variant = "secondary",
                borderRadius = 22,
                onClick = function()
                    EventBus.Emit(E.NAV_CLOSE_OVERLAY)
                end,
            },
            UI.Button {
                text = "💸 打回重做 (¥3000)",
                flexGrow = 2, flexBasis = 0,
                height = 44,
                fontSize = 13,
                fontWeight = "bold",
                variant = "primary",
                borderRadius = 22,
                onClick = function()
                    EventBus.Emit(E.UI_TOAST, "🔁 已申请改稿，下次工作台可再走一遍流程")
                    EventBus.Emit(E.NAV_CLOSE_OVERLAY)
                end,
            },
        }
    end

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 8,
        paddingLeft = 16, paddingRight = 16,
        paddingTop = 10, paddingBottom = 14,
        backgroundColor = C.bg_card,
        borderTopWidth = 1,
        borderColor = C.divider,
        flexShrink = 0,
        children = actions,
    }
end

return AcceptanceResultOverlay
