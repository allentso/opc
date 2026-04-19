-- ============================================================================
-- StrategyOverlay.lua — 今日策略选择全屏页（对齐 HTML 设计稿 v0.4）
--
-- 通过 EventBus.NAV_OPEN_OVERLAY("strategy") 唤起。
-- 由 MainLayout 包装顶部返回栏，本面板只负责内容区。
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local GameManager = require("core.GameManager")
local EventBus = require("core.EventBus")
local C = GameConfig.COLORS
local E = EventBus.Events

local StrategyOverlay = {}

local containerRef_ = nil
local listRef_ = nil
local pendingSelection_ = nil

--- 创建策略选择面板
---@return table widget
function StrategyOverlay.Create()
    pendingSelection_ = GameManager.GetDailyStrategy() or "balanced"

    listRef_ = UI.Panel {
        id = "strategyList",
        width = "100%",
        flexDirection = "column",
        gap = 9,
    }

    containerRef_ = UI.Panel {
        id = "strategyOverlay",
        width = "100%",
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        flexDirection = "column",
        backgroundColor = C.bg_primary,
        children = {
            UI.ScrollView {
                width = "100%",
                flexGrow = 1, flexBasis = 0,
                showScrollbar = false,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        padding = 12,
                        gap = 9,
                        children = {
                            -- 顶部说明
                            UI.Panel {
                                width = "100%",
                                backgroundColor = C.accent_light,
                                borderRadius = 8,
                                paddingLeft = 11, paddingRight = 11,
                                paddingTop = 9, paddingBottom = 9,
                                borderLeftWidth = 3,
                                borderColor = C.accent,
                                children = {
                                    UI.Label {
                                        text = "策略方向影响今日所有 AI 部门的工作倾向和骰子权重，次日自动重置。每天只能设定一次。",
                                        fontSize = 11,
                                        fontColor = C.text_secondary,
                                    },
                                },
                            },
                            -- 小标题
                            UI.Label {
                                text = "选择今日方向",
                                fontSize = 10,
                                fontColor = C.text_muted,
                                fontWeight = "bold",
                                marginTop = 4,
                            },
                            -- 选项列表
                            listRef_,
                            -- 确认按钮
                            UI.Button {
                                text = "确认今日策略",
                                width = "100%",
                                height = 42,
                                fontSize = 13,
                                fontWeight = "bold",
                                variant = "primary",
                                borderRadius = 9,
                                marginTop = 6,
                                onClick = function()
                                    StrategyOverlay._onConfirm()
                                end,
                            },
                        },
                    },
                },
            },
        },
    }

    StrategyOverlay._populate()

    -- 每次 overlay 打开时刷新一下选中状态
    EventBus.On(E.NAV_OPEN_OVERLAY, function(name)
        if name == "strategy" then
            pendingSelection_ = GameManager.GetDailyStrategy() or "balanced"
            StrategyOverlay._populate()
        end
    end)

    return containerRef_
end

--- 填充策略选项
function StrategyOverlay._populate()
    if not listRef_ then return end
    listRef_:ClearChildren()

    for _, s in ipairs(GameConfig.DAILY_STRATEGIES) do
        listRef_:AddChild(StrategyOverlay._createOption(s))
    end
end

--- 创建单个策略选项卡
function StrategyOverlay._createOption(s)
    local isLocked = StrategyOverlay._isLocked(s)
    local isSelected = (pendingSelection_ == s.id) and not isLocked

    local borderColor = isSelected and C.accent or C.border
    local bgColor = isSelected and C.accent_light or C.bg_card
    local opacity = isLocked and 0.5 or 1.0

    -- 右侧标识（选中 ✓ 或 锁 🔒）
    local rightMark = nil
    if isLocked then
        rightMark = UI.Label {
            text = "🔒",
            fontSize = 14,
            marginLeft = 8,
        }
    elseif isSelected then
        rightMark = UI.Label {
            text = "✓",
            fontSize = 16,
            fontColor = C.accent,
            fontWeight = "bold",
            marginLeft = 8,
        }
    end

    local effectText
    if isLocked then
        effectText = s.unlockHint or "尚未解锁"
    else
        effectText = s.effect or ""
    end

    local children = {
        UI.Label {
            text = s.icon or "📌",
            fontSize = 22,
            marginRight = 9,
            flexShrink = 0,
        },
        UI.Panel {
            flexGrow = 1, flexShrink = 1,
            flexDirection = "column",
            gap = 2,
            children = {
                UI.Label {
                    text = s.label,
                    fontSize = 13,
                    fontColor = C.text_primary,
                    fontWeight = "bold",
                },
                UI.Label {
                    text = effectText,
                    fontSize = 10,
                    fontColor = isLocked and C.text_muted or C.text_secondary,
                },
            },
        },
    }
    if rightMark then table.insert(children, rightMark) end

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        backgroundColor = bgColor,
        borderRadius = 10,
        borderWidth = 1.5,
        borderColor = borderColor,
        paddingLeft = 11, paddingRight = 11,
        paddingTop = 11, paddingBottom = 11,
        opacity = opacity,
        cursor = isLocked and "not-allowed" or "pointer",
        onClick = function()
            if isLocked then
                EventBus.Emit(E.UI_TOAST, "🔒 " .. (s.unlockHint or "尚未解锁"))
                return
            end
            pendingSelection_ = s.id
            StrategyOverlay._populate()
        end,
        onPointerEnter = function(_, w)
            if isLocked then return end
            if pendingSelection_ ~= s.id then
                w:SetStyle({ borderColor = C.accent, backgroundColor = C.accent_light })
            end
        end,
        onPointerLeave = function(_, w)
            if isLocked then return end
            if pendingSelection_ ~= s.id then
                w:SetStyle({ borderColor = C.border, backgroundColor = C.bg_card })
            end
        end,
        children = children,
    }
end

--- 判断策略是否锁定
function StrategyOverlay._isLocked(s)
    if not s.unlockType then return false end
    if s.unlockType == "mystery_completed" then
        local OrderManager = require("systems.OrderManager")
        local stats = OrderManager.GetStats and OrderManager.GetStats() or {}
        local mysteryCount = stats.mystery_completed or 0
        return mysteryCount < (s.unlockThreshold or 1)
    end
    return false
end

--- 确认按钮
function StrategyOverlay._onConfirm()
    if not pendingSelection_ then return end
    local ok = GameManager.SetDailyStrategy(pendingSelection_)
    if ok then
        EventBus.Emit(E.NAV_CLOSE_OVERLAY)
    end
end

return StrategyOverlay
