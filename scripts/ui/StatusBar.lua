-- ============================================================================
-- StatusBar.lua — 顶部状态栏（暗色科技风）
-- 两行结构：
--   行1: 公司名 + 身份标识 + 声誉/资金
--   行2: 订单警报横幅（有订单时显示）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local EventBus = require("core.EventBus")
local GameManager = require("core.GameManager")
local C = GameConfig.COLORS
local E = EventBus.Events

local StatusBar = {}

local alertBarRef_ = nil

--- 创建状态栏
---@param state table { companyName, day, phase, funds, reputation, alert }
---@return table widget
function StatusBar.Create(state)
    local hasAlert = state.alert and #state.alert > 0

    alertBarRef_ = UI.Panel {
        id = "statusAlertBar",
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 6,
        paddingLeft = 14, paddingRight = 14,
        paddingTop = 5, paddingBottom = 5,
        backgroundColor = C.accent_light,
        borderBottomWidth = 1,
        borderColor = C.divider,
        flexShrink = 0,
        visible = hasAlert,
        children = {
            UI.Label {
                text = "❗",
                fontSize = 11,
                fontColor = C.accent,
            },
            UI.Label {
                id = "statusAlertText",
                text = state.alert or "",
                fontSize = 11,
                fontColor = C.accent,
                fontWeight = "bold",
                flexGrow = 1,
            },
        },
    }

    return UI.Panel {
        id = "statusBar",
        width = "100%",
        flexDirection = "column",
        backgroundColor = C.bg_topbar,
        borderBottomWidth = 1,
        borderColor = C.divider,
        flexShrink = 0,
        children = {
            -- 行1: 主信息栏
            UI.Panel {
                width = "100%",
                height = GameConfig.UI.statusbar_height,
                flexDirection = "row",
                alignItems = "center",
                paddingLeft = 14, paddingRight = 14,
                gap = 8,
                children = {
                    -- 左侧：在线指示 + 公司名
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 6,
                        flexShrink = 0,
                        children = {
                            UI.Panel {
                                width = 8, height = 8,
                                borderRadius = 4,
                                backgroundColor = C.online_green,
                            },
                            UI.Label {
                                id = "companyName",
                                text = state.companyName or "赛博朝廷AI",
                                fontSize = 14,
                                fontColor = C.text_primary,
                                fontWeight = "bold",
                            },
                        },
                    },

                    -- 身份标识
                    UI.Panel {
                        backgroundColor = C.accent_light,
                        borderRadius = 4,
                        paddingLeft = 6, paddingRight = 6,
                        paddingTop = 2, paddingBottom = 2,
                        children = {
                            UI.Label {
                                text = "👔 Boss",
                                fontSize = 9,
                                fontColor = C.accent,
                                fontWeight = "bold",
                            },
                        },
                    },

                    UI.Panel {
                        backgroundColor = C.primary_blue_light,
                        borderRadius = 10,
                        paddingLeft = 8, paddingRight = 8,
                        paddingTop = 3, paddingBottom = 3,
                        flexShrink = 1,
                        children = {
                            UI.Label {
                                id = "strategyMiniChip",
                                text = "📌 " .. GameManager.GetDailyStrategyLabel(),
                                fontSize = 9,
                                fontColor = C.primary_blue,
                                fontWeight = "bold",
                            },
                        },
                    },

                    -- 弹性空白
                    UI.Panel { flexGrow = 1 },

                    -- 声誉
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 3,
                        backgroundColor = C.success_light,
                        borderRadius = 10,
                        paddingLeft = 7, paddingRight = 7,
                        paddingTop = 3, paddingBottom = 3,
                        children = {
                            UI.Label {
                                text = "★",
                                fontSize = 10,
                                fontColor = C.success,
                            },
                            UI.Label {
                                id = "statusRepLabel",
                                text = "+" .. tostring(math.floor((state.reputation or 3) * 4)),
                                fontSize = 10,
                                fontColor = C.success,
                                fontWeight = "bold",
                            },
                        },
                    },

                    -- 资金
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 3,
                        backgroundColor = C.warning_light,
                        borderRadius = 10,
                        paddingLeft = 7, paddingRight = 7,
                        paddingTop = 3, paddingBottom = 3,
                        children = {
                            UI.Label {
                                text = "¥",
                                fontSize = 10,
                                fontColor = C.warning,
                                fontWeight = "bold",
                            },
                            UI.Label {
                                id = "statusFundsLabel",
                                text = StatusBar._formatNumber(state.funds or 0),
                                fontSize = 10,
                                fontColor = C.warning,
                                fontWeight = "bold",
                            },
                        },
                    },
                },
            },

            -- 行2: 订单警报横幅
            alertBarRef_,
        },
    }
end

--- 更新警报
function StatusBar.UpdateAlert(alertText)
    if not alertBarRef_ then return end
    if alertText and #alertText > 0 then
        alertBarRef_:SetVisible(true)
        local label = alertBarRef_:FindById("statusAlertText")
        if label then label:SetText(alertText) end
    else
        alertBarRef_:SetVisible(false)
    end
end

--- 外部调用：切换到指定标签（保持兼容性）
function StatusBar.SwitchTo(tabName)
    EventBus.Emit(E.TAB_SWITCH, tabName)
end

--- 获取当前活跃标签名（保持兼容性）
function StatusBar.GetActiveTab()
    return "消息"
end

--- 格式化数字
function StatusBar._formatNumber(n)
    local formatted = tostring(math.floor(n))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

return StatusBar
