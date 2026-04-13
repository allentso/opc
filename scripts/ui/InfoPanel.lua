-- ============================================================================
-- InfoPanel.lua — 信息面板（竖屏全宽，含订单 + 老板操作 + 部门状态）
-- 在竖屏模式下作为"操作"Tab的全屏内容
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local OrderManager = require("systems.OrderManager")
local BossSkillSystem = require("systems.BossSkillSystem")
local OrgGenerator = require("systems.OrgGenerator")
local EventBus = require("core.EventBus")
local C = GameConfig.COLORS
local E = EventBus.Events

local InfoPanel = {}

local containerRef_ = nil
local callbacks_ = {}

--- 创建信息面板（全宽）
---@param callbacks table { onAcceptOrder, onUseSkill }
---@return table widget
function InfoPanel.Create(callbacks)
    callbacks_ = callbacks or {}

    containerRef_ = UI.Panel {
        id = "infoPanel",
        width = "100%",
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        backgroundColor = C.bg_secondary,
        flexDirection = "column",
        children = {
            -- 标题栏由 MainLayout overlay 包装器提供

            -- 滚动内容
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                showScrollbar = true,
                children = {
                    UI.Panel {
                        id = "infoPanelContent",
                        width = "100%",
                        flexDirection = "column",
                        padding = 14,
                        gap = 14,
                        children = {
                            InfoPanel._createSkillSection(),
                            InfoPanel._createDeptSection(),
                        },
                    },
                },
            },
        },
    }

    -- 事件监听
    EventBus.On(E.ORDER_NEW, function() InfoPanel.Refresh() end)
    EventBus.On(E.ORDER_ACCEPTED, function() InfoPanel.Refresh() end)
    EventBus.On(E.ORDER_PROGRESS, function() InfoPanel.Refresh() end)
    EventBus.On(E.BOSS_SKILL_USED, function() InfoPanel.Refresh() end)
    EventBus.On(E.BOSS_SKILL_READY, function() InfoPanel.Refresh() end)
    EventBus.On(E.UI_REFRESH, function() InfoPanel.Refresh() end)

    return containerRef_
end

-- ============================================================
-- 订单区域
-- ============================================================

function InfoPanel._createSectionHeader(title, icon)
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 6,
        paddingBottom = 8,
        borderBottomWidth = 1,
        borderColor = C.divider,
        children = {
            UI.Label {
                text = icon or "",
                fontSize = 16,
            },
            UI.Label {
                text = title,
                fontSize = 14,
                fontColor = C.text_primary,
                fontWeight = "bold",
            },
        },
    }
end

function InfoPanel._createOrderSection()
    local section = UI.Panel {
        id = "orderSection",
        width = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_primary,
        borderRadius = 12,
        borderWidth = 1,
        borderColor = C.border,
        padding = 14,
        gap = 10,
    }

    section:AddChild(InfoPanel._createSectionHeader("当前订单", "📦"))

    local active = OrderManager.GetActiveOrder()
    if active then
        section:AddChild(InfoPanel._createActiveOrderCard(active))
    end

    local available = OrderManager.GetAvailableOrders()
    if #available > 0 then
        section:AddChild(UI.Label {
            text = "可接取订单",
            fontSize = 12,
            fontColor = C.text_muted,
            marginTop = 4,
        })
        for _, order in ipairs(available) do
            section:AddChild(InfoPanel._createAvailableOrderCard(order))
        end
    elseif not active then
        section:AddChild(UI.Panel {
            width = "100%",
            padding = 20,
            backgroundColor = C.bg_card,
            borderRadius = 8,
            justifyContent = "center",
            alignItems = "center",
            children = {
                UI.Label {
                    text = "暂无订单",
                    fontSize = 13,
                    fontColor = C.text_muted,
                },
            },
        })
    end

    return section
end

function InfoPanel._createActiveOrderCard(order)
    local typeLabel = OrderManager.GetOrderTypeLabel(order.type)
    local progress = order.progress or 0
    local total = order.deliverables or 3

    return UI.Panel {
        width = "100%",
        flexDirection = "column",
        backgroundColor = C.accent_light,
        borderRadius = 10,
        borderWidth = 1,
        borderColor = C.accent,
        padding = 14,
        gap = 8,
        children = {
            UI.Label {
                text = (typeLabel or "") .. " #" .. (order.id or "?"),
                fontSize = 15,
                fontColor = C.accent_hover,
                fontWeight = "bold",
            },
            UI.Label {
                text = order.name or "进行中的订单",
                fontSize = 12,
                fontColor = C.text_secondary,
            },
            UI.Panel {
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "进度",
                        fontSize = 11,
                        fontColor = C.text_muted,
                    },
                    UI.Label {
                        text = tostring(progress) .. "/" .. tostring(total),
                        fontSize = 11,
                        fontColor = C.accent,
                        fontWeight = "bold",
                    },
                },
            },
            UI.ProgressBar {
                value = total > 0 and (progress / total) or 0,
                width = "100%",
                height = 8,
                borderRadius = 4,
                backgroundColor = C.bg_hover,
                fillColor = C.accent,
            },
            InfoPanel._createCheckpoints(progress, total),
        },
    }
end

function InfoPanel._createCheckpoints(progress, total)
    local row = UI.Panel {
        flexDirection = "row",
        gap = 10,
        flexWrap = "wrap",
    }

    for i = 1, total do
        local done = i <= progress
        local current = i == progress + 1
        local icon = done and "✓" or (current and "⚡" or "○")
        local color = done and C.success or (current and C.warning or C.text_muted)
        local suffix = current and "待定" or ""

        row:AddChild(UI.Label {
            text = icon .. " #" .. tostring(i) .. suffix,
            fontSize = 11,
            fontColor = color,
            fontWeight = done and "bold" or "normal",
        })
    end

    return row
end

function InfoPanel._createAvailableOrderCard(order)
    local typeLabel = OrderManager.GetOrderTypeLabel(order.type)

    return UI.Panel {
        width = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_card,
        borderRadius = 8,
        borderWidth = 1,
        borderColor = C.border,
        padding = 12,
        gap = 8,
        children = {
            UI.Label {
                text = order.name,
                fontSize = 13,
                fontColor = C.text_primary,
                fontWeight = "bold",
            },
            UI.Panel {
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = typeLabel or "",
                        fontSize = 11,
                        fontColor = C.accent,
                    },
                    UI.Label {
                        text = "¥" .. tostring(order.reward),
                        fontSize = 12,
                        fontColor = C.success,
                        fontWeight = "bold",
                    },
                },
            },
            UI.Button {
                text = "接取订单",
                width = "100%",
                height = 36,
                fontSize = 13,
                variant = "primary",
                borderRadius = 8,
                onClick = function()
                    if callbacks_.onAcceptOrder then
                        callbacks_.onAcceptOrder(order.id)
                    end
                end,
            },
        },
    }
end

-- ============================================================
-- 老板操作区域
-- ============================================================

function InfoPanel._createSkillSection()
    local section = UI.Panel {
        id = "skillSection",
        width = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_primary,
        borderRadius = 12,
        borderWidth = 1,
        borderColor = C.border,
        padding = 14,
        gap = 10,
    }

    section:AddChild(InfoPanel._createSectionHeader("老板操作", "⚡"))

    local skills = BossSkillSystem.GetAllSkills()
    for _, skillId in ipairs(GameConfig.SKILL_ORDER) do
        local skill = skills[skillId]
        if skill then
            section:AddChild(InfoPanel._createSkillButton(skillId, skill))
        end
    end

    return section
end

function InfoPanel._createSkillButton(skillId, skill)
    local config = skill.config
    local available = skill.available and skill.usesRemaining > 0

    local label = (config.icon or "⚡") .. "  " .. config.name
    if skill.usesRemaining and skill.usesRemaining < 99 then
        label = label .. "（剩余" .. tostring(skill.usesRemaining) .. "次）"
    end
    if skill.cooldownRemaining and skill.cooldownRemaining > 0 then
        label = label .. " CD:" .. tostring(skill.cooldownRemaining) .. "天"
    end

    return UI.Panel {
        width = "100%",
        height = 46,
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "center",
        gap = 6,
        backgroundColor = available and C.bg_primary or C.bg_hover,
        borderRadius = 10,
        borderWidth = 1,
        borderColor = available and C.border or C.bg_hover,
        cursor = available and "pointer" or "not-allowed",
        onClick = function()
            if available and callbacks_.onUseSkill then
                callbacks_.onUseSkill(skillId)
            end
        end,
        onPointerEnter = function(_, widget)
            if available then
                widget:SetStyle({ backgroundColor = C.bg_hover, borderColor = C.accent })
            end
        end,
        onPointerLeave = function(_, widget)
            if available then
                widget:SetStyle({ backgroundColor = C.bg_primary, borderColor = C.border })
            end
        end,
        children = {
            UI.Label {
                text = label,
                fontSize = 14,
                fontColor = available and C.text_primary or C.text_muted,
                fontWeight = "bold",
            },
        },
    }
end

-- ============================================================
-- 部门状态区域
-- ============================================================

function InfoPanel._createDeptSection()
    local section = UI.Panel {
        id = "deptSection",
        width = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_primary,
        borderRadius = 12,
        borderWidth = 1,
        borderColor = C.border,
        padding = 14,
        gap = 8,
    }

    section:AddChild(InfoPanel._createSectionHeader("部门状态", "🏢"))

    local departments = OrgGenerator.GetAllDepartments()
    for _, dept in ipairs(departments) do
        section:AddChild(InfoPanel._createDeptStatusItem(dept))
    end

    return section
end

function InfoPanel._createDeptStatusItem(dept)
    local statusLabels = {
        idle = "空闲",
        working = "工作中",
        overloaded = "过载",
    }

    local dotColor = GameConfig.DEPT_STATUS_DOT[dept.status] or C.text_muted
    local badgeColor = GameConfig.DEPT_BADGE_COLORS[dept.id] or C.accent
    local shortName = GameConfig.DEPT_SHORT[dept.id] or "?"
    local statusText = statusLabels[dept.status] or dept.status

    if dept.workload and dept.workload > 1 then
        statusText = statusText .. " x" .. tostring(dept.workload)
    end

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 10,
        paddingTop = 6, paddingBottom = 6,
        children = {
            -- 状态圆点
            UI.Panel {
                width = 8, height = 8,
                borderRadius = 4,
                backgroundColor = dotColor,
            },
            -- 部门图标圆
            UI.Panel {
                width = 32, height = 32,
                borderRadius = 16,
                backgroundColor = badgeColor,
                justifyContent = "center",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = shortName,
                        fontSize = 13,
                        fontColor = C.text_white,
                        fontWeight = "bold",
                    },
                },
            },
            -- 名称 + 状态
            UI.Panel {
                flexDirection = "column",
                flexGrow = 1,
                gap = 2,
                children = {
                    UI.Label {
                        text = dept.name,
                        fontSize = 13,
                        fontColor = C.text_primary,
                        fontWeight = "bold",
                    },
                    UI.Label {
                        text = statusText,
                        fontSize = 11,
                        fontColor = C.text_muted,
                    },
                },
            },
        },
    }
end

-- ============================================================
-- 刷新
-- ============================================================

function InfoPanel.Refresh()
    if not containerRef_ then return end
    local content = containerRef_:FindById("infoPanelContent")
    if not content then return end

    content:ClearChildren()
    content:AddChild(InfoPanel._createSkillSection())
    content:AddChild(InfoPanel._createDeptSection())
end

return InfoPanel
