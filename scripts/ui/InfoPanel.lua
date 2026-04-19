-- ============================================================================
-- InfoPanel.lua — 指挥中心 Tab（v0.4 对齐 HTML 设计稿）
--
-- 区域顺序（自上而下）：
--   1. 私下情报行动区（IntelSystem 的活跃情报，可一键应对）
--   2. 老板技能区
--   3. 部门状态区
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local OrderManager = require("systems.OrderManager")
local BossSkillSystem = require("systems.BossSkillSystem")
local OrgGenerator = require("systems.OrgGenerator")
local IntelSystem = require("systems.IntelSystem")
local EventBus = require("core.EventBus")
local C = GameConfig.COLORS
local E = EventBus.Events

local InfoPanel = {}

local containerRef_ = nil
local intelSectionRef_ = nil
local skillSectionRef_ = nil
local deptSectionRef_ = nil
local callbacks_ = {}

--- 创建指挥中心面板
function InfoPanel.Create(callbacks)
    callbacks_ = callbacks or {}

    intelSectionRef_ = InfoPanel._createIntelSection()
    skillSectionRef_ = InfoPanel._createSkillSection()
    deptSectionRef_  = InfoPanel._createDeptSection()

    containerRef_ = UI.Panel {
        id = "infoPanel",
        width = "100%",
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        backgroundColor = C.bg_primary,
        flexDirection = "column",
        children = {
            UI.ScrollView {
                width = "100%",
                flexGrow = 1, flexBasis = 0,
                showScrollbar = true,
                children = {
                    UI.Panel {
                        id = "infoPanelContent",
                        width = "100%",
                        flexDirection = "column",
                        padding = 12,
                        gap = 12,
                        children = {
                            intelSectionRef_,
                            skillSectionRef_,
                            deptSectionRef_,
                        },
                    },
                },
            },
        },
    }

    EventBus.On(E.ORDER_NEW, function() InfoPanel.Refresh() end)
    EventBus.On(E.ORDER_ACCEPTED, function() InfoPanel.Refresh() end)
    EventBus.On(E.ORDER_PROGRESS, function() InfoPanel.Refresh() end)
    EventBus.On(E.BOSS_SKILL_USED, function() InfoPanel.Refresh() end)
    EventBus.On(E.BOSS_SKILL_READY, function() InfoPanel.Refresh() end)
    EventBus.On(E.UI_REFRESH, function() InfoPanel.Refresh() end)
    EventBus.On(E.INTEL_NEW, function() InfoPanel._refreshIntelOnly() end)
    EventBus.On(E.INTEL_UPDATED, function() InfoPanel._refreshIntelOnly() end)
    EventBus.On(E.INTEL_EXPIRED, function() InfoPanel._refreshIntelOnly() end)

    return containerRef_
end

-- ============================================================
-- 通用 Section
-- ============================================================
function InfoPanel._createSection(title, icon, children)
    local card = UI.Panel {
        width = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_card,
        borderRadius = 12,
        borderWidth = 1,
        borderColor = C.border,
        padding = 12,
        gap = 8,
    }
    card:AddChild(UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 6,
        paddingBottom = 6,
        borderBottomWidth = 1,
        borderColor = C.divider,
        children = {
            UI.Label { text = icon or "", fontSize = 14 },
            UI.Label {
                text = title,
                fontSize = 13,
                fontColor = C.text_primary,
                fontWeight = "bold",
            },
        },
    })
    if children then
        for _, c in ipairs(children) do card:AddChild(c) end
    end
    return card
end

-- ============================================================
-- 私下情报行动区
-- ============================================================
function InfoPanel._createIntelSection()
    local section = UI.Panel {
        id = "intelSection",
        width = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_card,
        borderRadius = 12,
        borderWidth = 1.5,
        borderColor = C.warning,
        padding = 12,
        gap = 8,
    }

    section:AddChild(UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 6,
        paddingBottom = 6,
        borderBottomWidth = 1,
        borderColor = C.divider,
        children = {
            UI.Label { text = "🕵", fontSize = 14 },
            UI.Label {
                text = "私下情报",
                fontSize = 13,
                fontColor = C.text_primary,
                fontWeight = "bold",
            },
            UI.Panel { flexGrow = 1 },
            UI.Label {
                id = "intelCountLabel",
                text = "",
                fontSize = 10,
                fontColor = C.warning,
                fontWeight = "bold",
            },
        },
    })

    section:AddChild(UI.Panel {
        id = "intelList",
        width = "100%",
        flexDirection = "column",
        gap = 7,
    })

    InfoPanel._populateIntel(section)
    return section
end

function InfoPanel._populateIntel(section)
    section = section or intelSectionRef_
    if not section then return end
    local list = section:FindById("intelList")
    local countLabel = section:FindById("intelCountLabel")
    if not list then return end
    list:ClearChildren()

    local intels = IntelSystem.GetActiveIntels()
    if countLabel then
        if #intels > 0 then
            countLabel:SetText(tostring(#intels) .. " 条待处理")
        else
            countLabel:SetText("")
        end
    end

    if #intels == 0 then
        list:AddChild(UI.Panel {
            width = "100%",
            paddingTop = 12, paddingBottom = 12,
            justifyContent = "center", alignItems = "center",
            children = {
                UI.Label {
                    text = "🌿 暂无新情报。多偷窥几次私下频道吧。",
                    fontSize = 11,
                    fontColor = C.text_muted,
                },
            },
        })
        return
    end

    for _, intel in ipairs(intels) do
        list:AddChild(InfoPanel._createIntelCard(intel))
    end
end

function InfoPanel._createIntelCard(intel)
    -- 紧急度指示
    local urgencyColor = (intel.urgency == "high") and C.danger
        or (intel.urgency == "medium") and C.warning
        or C.text_muted
    local urgencyLabel = (intel.urgency == "high") and "高优"
        or (intel.urgency == "medium") and "中优"
        or "低优"

    local actions = {}
    for _, a in ipairs(intel.actions or {}) do
        local btn = UI.Button {
            text = a.label or a.id,
            height = 28,
            fontSize = 10,
            variant = (a.id == "ignore" or a.id == "let_it_be") and "secondary" or "primary",
            borderRadius = 14,
            paddingLeft = 10, paddingRight = 10,
            onClick = function()
                IntelSystem.HandleAction(intel.intelType, a.id)
            end,
        }
        table.insert(actions, btn)
    end

    return UI.Panel {
        width = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_primary,
        borderRadius = 8,
        borderLeftWidth = 3,
        borderColor = urgencyColor,
        paddingLeft = 10, paddingRight = 10,
        paddingTop = 8, paddingBottom = 8,
        gap = 5,
        children = {
            -- 标题行
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                gap = 6,
                children = {
                    UI.Label {
                        text = intel.title or "情报",
                        fontSize = 12,
                        fontColor = C.text_primary,
                        fontWeight = "bold",
                        flexGrow = 1, flexShrink = 1,
                    },
                    UI.Panel {
                        paddingLeft = 5, paddingRight = 5,
                        paddingTop = 1, paddingBottom = 1,
                        borderRadius = 6,
                        backgroundColor = urgencyColor,
                        children = {
                            UI.Label {
                                text = urgencyLabel,
                                fontSize = 8,
                                fontColor = C.text_white,
                                fontWeight = "bold",
                            },
                        },
                    },
                },
            },
            -- 摘要
            UI.Label {
                text = intel.summary or "",
                fontSize = 10,
                fontColor = C.text_secondary,
            },
            -- 证据片段
            UI.Label {
                text = "📝 «" .. (intel.lastSnippet or "") .. "»  ×" .. tostring(intel.evidenceCount or 1),
                fontSize = 9,
                fontColor = C.text_muted,
            },
            -- 应对按钮组
            UI.Panel {
                flexDirection = "row",
                gap = 6,
                flexWrap = "wrap",
                marginTop = 3,
                children = actions,
            },
        },
    }
end

function InfoPanel._refreshIntelOnly()
    InfoPanel._populateIntel(intelSectionRef_)
end

-- ============================================================
-- 老板技能区
-- ============================================================
function InfoPanel._createSkillSection()
    local section = UI.Panel {
        id = "skillSection",
        width = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_card,
        borderRadius = 12,
        borderWidth = 1,
        borderColor = C.border,
        padding = 12,
        gap = 8,
    }

    section:AddChild(UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 6,
        paddingBottom = 6,
        borderBottomWidth = 1,
        borderColor = C.divider,
        children = {
            UI.Label { text = "⚡", fontSize = 14 },
            UI.Label {
                text = "老板技能",
                fontSize = 13,
                fontColor = C.text_primary,
                fontWeight = "bold",
            },
        },
    })

    local skills = BossSkillSystem.GetAllSkills()
    for _, skillId in ipairs(GameConfig.SKILL_ORDER or {}) do
        local skill = skills[skillId]
        if skill then
            section:AddChild(InfoPanel._createSkillCard(skillId, skill))
        end
    end

    return section
end

function InfoPanel._createSkillCard(skillId, skill)
    local config = skill.config or {}
    local available = skill.available and (skill.usesRemaining or 0) > 0

    local sublabel = ""
    if skill.usesRemaining and skill.usesRemaining < 99 then
        sublabel = "剩余 " .. tostring(skill.usesRemaining)
    end
    if skill.cooldownRemaining and skill.cooldownRemaining > 0 then
        if #sublabel > 0 then sublabel = sublabel .. " · " end
        sublabel = sublabel .. "CD " .. tostring(skill.cooldownRemaining) .. "天"
    end
    if config.cost and type(config.cost) == "number" and config.cost > 0 then
        if #sublabel > 0 then sublabel = sublabel .. " · " end
        sublabel = sublabel .. "¥" .. tostring(config.cost)
    end

    local bg = available and C.bg_primary or C.bg_input
    local fg = available and C.text_primary or C.text_muted
    local borderColor = available and C.border or C.bg_input

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 9,
        backgroundColor = bg,
        borderRadius = 9,
        borderWidth = 1,
        borderColor = borderColor,
        paddingLeft = 11, paddingRight = 11,
        paddingTop = 9, paddingBottom = 9,
        cursor = available and "pointer" or "not-allowed",
        onClick = function()
            if available and callbacks_.onUseSkill then
                callbacks_.onUseSkill(skillId)
            end
        end,
        onPointerEnter = function(_, w)
            if available then
                w:SetStyle({ borderColor = C.accent, backgroundColor = C.accent_light })
            end
        end,
        onPointerLeave = function(_, w)
            if available then
                w:SetStyle({ borderColor = C.border, backgroundColor = C.bg_primary })
            end
        end,
        children = {
            UI.Label {
                text = config.icon or "⚡",
                fontSize = 22,
                flexShrink = 0,
            },
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                flexDirection = "column",
                gap = 2,
                children = {
                    UI.Label {
                        text = config.name or skillId,
                        fontSize = 12,
                        fontColor = fg,
                        fontWeight = "bold",
                    },
                    UI.Label {
                        text = sublabel,
                        fontSize = 9,
                        fontColor = C.text_muted,
                    },
                },
            },
            UI.Label {
                text = available and "›" or "·",
                fontSize = 16,
                fontColor = available and C.accent or C.text_muted,
            },
        },
    }
end

-- ============================================================
-- 部门状态区
-- ============================================================
function InfoPanel._createDeptSection()
    local section = UI.Panel {
        id = "deptSection",
        width = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_card,
        borderRadius = 12,
        borderWidth = 1,
        borderColor = C.border,
        padding = 12,
        gap = 6,
    }

    section:AddChild(UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 6,
        paddingBottom = 6,
        borderBottomWidth = 1,
        borderColor = C.divider,
        children = {
            UI.Label { text = "🏢", fontSize = 14 },
            UI.Label {
                text = "部门状态",
                fontSize = 13,
                fontColor = C.text_primary,
                fontWeight = "bold",
            },
        },
    })

    local departments = OrgGenerator.GetAllDepartments()
    for _, dept in ipairs(departments) do
        section:AddChild(InfoPanel._createDeptItem(dept))
    end
    return section
end

function InfoPanel._createDeptItem(dept)
    local statusLabels = { idle = "空闲", working = "工作中", overloaded = "🔥过载" }
    local dotColor = GameConfig.DEPT_STATUS_DOT[dept.status] or C.text_muted
    local badgeColor = GameConfig.DEPT_BADGE_COLORS[dept.id] or C.accent
    local shortName = GameConfig.DEPT_SHORT[dept.id] or "?"
    local statusText = statusLabels[dept.status] or dept.status
    if dept.workload and dept.workload > 1 then
        statusText = statusText .. " ×" .. tostring(dept.workload)
    end

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 9,
        paddingTop = 5, paddingBottom = 5,
        children = {
            UI.Panel {
                width = 8, height = 8,
                borderRadius = 4,
                backgroundColor = dotColor,
            },
            UI.Panel {
                width = 30, height = 30,
                borderRadius = 7,
                backgroundColor = badgeColor,
                justifyContent = "center", alignItems = "center",
                children = {
                    UI.Label {
                        text = shortName,
                        fontSize = 12,
                        fontColor = C.text_white,
                        fontWeight = "bold",
                    },
                },
            },
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                flexDirection = "column",
                gap = 1,
                children = {
                    UI.Label {
                        text = dept.name or "",
                        fontSize = 12,
                        fontColor = C.text_primary,
                        fontWeight = "bold",
                    },
                    UI.Label {
                        text = statusText,
                        fontSize = 10,
                        fontColor = C.text_muted,
                    },
                },
            },
        },
    }
end

-- ============================================================
-- 整体刷新
-- ============================================================
function InfoPanel.Refresh()
    if not containerRef_ then return end
    local content = containerRef_:FindById("infoPanelContent")
    if not content then return end

    intelSectionRef_ = InfoPanel._createIntelSection()
    skillSectionRef_ = InfoPanel._createSkillSection()
    deptSectionRef_  = InfoPanel._createDeptSection()

    content:ClearChildren()
    content:AddChild(intelSectionRef_)
    content:AddChild(skillSectionRef_)
    content:AddChild(deptSectionRef_)
end

return InfoPanel
