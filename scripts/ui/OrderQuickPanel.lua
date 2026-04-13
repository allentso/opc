-- ============================================================================
-- OrderQuickPanel.lua — 首页底部订单快捷面板（紧凑卡片列表）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local OrderManager = require("systems.OrderManager")
local EventBus = require("core.EventBus")
local C = GameConfig.COLORS
local E = EventBus.Events

local OrderQuickPanel = {}

local containerRef_ = nil
local listRef_ = nil
local callbacks_ = {}

--- 创建订单快捷面板
---@param cbs table { onAcceptOrder }
---@return table widget
function OrderQuickPanel.Create(cbs)
    callbacks_ = cbs or {}

    listRef_ = UI.Panel {
        id = "orderQuickList",
        width = "100%",
        flexDirection = "column",
        paddingLeft = 10, paddingRight = 10,
        paddingTop = 4, paddingBottom = 8,
        gap = 6,
    }

    containerRef_ = UI.Panel {
        id = "orderQuickPanel",
        width = "100%",
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        flexDirection = "column",
        borderTopWidth = 1,
        borderColor = C.divider,
        backgroundColor = C.bg_secondary,
        children = {
            -- 标题栏
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                paddingLeft = 14, paddingRight = 14,
                paddingTop = 8, paddingBottom = 4,
                gap = 6,
                flexShrink = 0,
                children = {
                    UI.Label { text = "📋", fontSize = 14 },
                    UI.Label {
                        text = "可接取订单",
                        fontSize = 13,
                        fontColor = C.text_primary,
                        fontWeight = "bold",
                    },
                },
            },
            -- 滚动列表
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexShrink = 1,
                flexBasis = 0,
                showScrollbar = true,
                children = {
                    listRef_,
                },
            },
        },
    }

    -- 首次填充
    OrderQuickPanel._populateList()

    -- 事件监听
    EventBus.On(E.ORDER_NEW, function() OrderQuickPanel._populateList() end)
    EventBus.On(E.ORDER_ACCEPTED, function() OrderQuickPanel._populateList() end)
    EventBus.On(E.UI_REFRESH, function() OrderQuickPanel._populateList() end)

    return containerRef_
end

--- 填充订单卡片
function OrderQuickPanel._populateList()
    if not listRef_ then return end
    listRef_:ClearChildren()

    -- 进行中的订单
    local active = OrderManager.GetActiveOrder()
    if active then
        listRef_:AddChild(OrderQuickPanel._createActiveCard(active))
    end

    -- 可接取订单
    local available = OrderManager.GetAvailableOrders()
    for _, order in ipairs(available) do
        listRef_:AddChild(OrderQuickPanel._createAvailableCard(order))
    end

    if not active and #available == 0 then
        listRef_:AddChild(UI.Panel {
            width = "100%",
            paddingTop = 12, paddingBottom = 12,
            justifyContent = "center",
            alignItems = "center",
            children = {
                UI.Label {
                    text = "暂无订单",
                    fontSize = 12,
                    fontColor = C.text_muted,
                },
            },
        })
    end
end

--- 进行中订单（紧凑卡片）
function OrderQuickPanel._createActiveCard(order)
    local typeLabel = OrderManager.GetOrderTypeLabel(order.type)
    local progress = order.progress or 0
    local total = order.deliverables or 3

    return UI.Panel {
        width = "100%",
        flexDirection = "column",
        backgroundColor = C.accent_light,
        borderRadius = 8,
        borderWidth = 1,
        borderColor = C.accent,
        paddingLeft = 10, paddingRight = 10,
        paddingTop = 8, paddingBottom = 8,
        gap = 4,
        children = {
            -- 标题行
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                children = {
                    UI.Label {
                        text = "▶ " .. (order.name or ""),
                        fontSize = 12,
                        fontColor = C.accent_hover,
                        fontWeight = "bold",
                        flexShrink = 1,
                    },
                    UI.Label {
                        text = tostring(progress) .. "/" .. tostring(total),
                        fontSize = 11,
                        fontColor = C.accent,
                        fontWeight = "bold",
                        flexShrink = 0,
                    },
                },
            },
            -- 进度条
            UI.ProgressBar {
                value = total > 0 and (progress / total) or 0,
                width = "100%",
                height = 4,
                borderRadius = 2,
                backgroundColor = C.bg_hover,
                fillColor = C.accent,
            },
        },
    }
end

--- 可接取订单（紧凑卡片）
function OrderQuickPanel._createAvailableCard(order)
    local typeLabel = OrderManager.GetOrderTypeLabel(order.type)

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        backgroundColor = C.bg_primary,
        borderRadius = 8,
        borderWidth = 1,
        borderColor = C.border,
        paddingLeft = 10, paddingRight = 10,
        paddingTop = 6, paddingBottom = 6,
        gap = 8,
        children = {
            -- 订单信息（左侧）
            UI.Panel {
                flexGrow = 1,
                flexShrink = 1,
                flexDirection = "column",
                gap = 2,
                children = {
                    UI.Label {
                        text = order.name or "",
                        fontSize = 12,
                        fontColor = C.text_primary,
                        fontWeight = "bold",
                    },
                    UI.Panel {
                        flexDirection = "row",
                        gap = 8,
                        alignItems = "center",
                        children = {
                            UI.Label {
                                text = typeLabel or "",
                                fontSize = 10,
                                fontColor = C.accent,
                            },
                            UI.Label {
                                text = "¥" .. tostring(order.reward),
                                fontSize = 11,
                                fontColor = C.success,
                                fontWeight = "bold",
                            },
                        },
                    },
                },
            },
            -- 接取按钮（右侧）
            UI.Button {
                text = "接取",
                width = 52,
                height = 28,
                fontSize = 11,
                variant = "primary",
                borderRadius = 14,
                onClick = function()
                    if callbacks_.onAcceptOrder then
                        callbacks_.onAcceptOrder(order.id)
                    end
                end,
            },
        },
    }
end

return OrderQuickPanel
