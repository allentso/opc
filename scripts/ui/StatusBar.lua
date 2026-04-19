-- ============================================================================
-- StatusBar.lua — 顶部状态栏（对齐 HTML 设计稿 v0.4）
--   行1：[公司名]  [策略 chip(可点)]  [声誉 chip]  [资金 chip]
--   行2：警报横幅（仅冲突/事故时显示）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local EventBus = require("core.EventBus")
local GameManager = require("core.GameManager")
local C = GameConfig.COLORS
local E = EventBus.Events

local StatusBar = {}

local alertBarRef_ = nil
local alertTextRef_ = nil
local strategyChipLabelRef_ = nil
local repChipLabelRef_ = nil
local fundsChipLabelRef_ = nil
local companyNameRef_ = nil

--- 创建状态栏
---@param state table { companyName, day, phase, funds, reputation, alert }
---@return table widget
function StatusBar.Create(state)
    local hasAlert = state.alert and #state.alert > 0

    -- 公司名
    companyNameRef_ = UI.Label {
        id = "companyName",
        text = state.companyName or "锐思AI工作室",
        fontSize = 14,
        fontColor = C.text_primary,
        fontWeight = "bold",
        flexGrow = 1,
        flexShrink = 1,
    }

    -- 策略 chip（可点击 → 进入今日策略页）
    local strategyChip = StatusBar._createChip(
        "strategyChip",
        "📌 " .. (GameManager.GetDailyStrategyLabel() or "均衡发展"),
        C.accent_light,
        C.accent_hover,
        function()
            EventBus.Emit(E.NAV_OPEN_OVERLAY, "strategy")
        end
    )
    strategyChipLabelRef_ = strategyChip:FindById("strategyChipLabel")

    -- 声誉 chip
    local repChip = StatusBar._createChip(
        "repChip",
        "★ +" .. tostring(math.floor((state.reputation or 3) * 4)),
        C.success_light,
        C.success,
        nil
    )
    repChipLabelRef_ = repChip:FindById("repChipLabel")

    -- 资金 chip
    local fundsChip = StatusBar._createChip(
        "fundsChip",
        "¥" .. StatusBar._formatNumber(state.funds or 0),
        C.primary_blue_light,
        C.primary_blue,
        nil
    )
    fundsChipLabelRef_ = fundsChip:FindById("fundsChipLabel")

    -- 主信息行
    local mainRow = UI.Panel {
        width = "100%",
        height = GameConfig.UI.statusbar_height,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 14, paddingRight = 14,
        gap = 6,
        children = {
            companyNameRef_,
            strategyChip,
            repChip,
            fundsChip,
        },
    }

    -- 警报横幅（仅在 alert 存在时占用空间）
    alertTextRef_ = UI.Label {
        id = "statusAlertText",
        text = state.alert or "",
        fontSize = 11,
        fontColor = C.danger,
        fontWeight = "bold",
        flexGrow = 1,
    }

    alertBarRef_ = UI.Panel {
        id = "statusAlertBar",
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 5,
        paddingLeft = 14, paddingRight = 14,
        paddingTop = hasAlert and 5 or 0,
        paddingBottom = hasAlert and 5 or 0,
        height = hasAlert and GameConfig.UI.alert_bar_height or 0,
        backgroundColor = C.danger_light,
        flexShrink = 0,
        overflow = "hidden",
        children = {
            UI.Label {
                text = "⚠",
                fontSize = 11,
                fontColor = C.danger,
            },
            alertTextRef_,
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
            mainRow,
            alertBarRef_,
        },
    }
end

--- 创建一个 chip（圆角胶囊，可选点击）
function StatusBar._createChip(id, text, bgColor, textColor, onClick)
    return UI.Panel {
        id = id,
        flexDirection = "row",
        alignItems = "center",
        backgroundColor = bgColor,
        borderRadius = 18,
        paddingLeft = 9, paddingRight = 9,
        paddingTop = 3, paddingBottom = 3,
        flexShrink = 0,
        cursor = onClick and "pointer" or "default",
        onClick = onClick,
        children = {
            UI.Label {
                id = id .. "Label",
                text = text,
                fontSize = 10,
                fontColor = textColor,
                fontWeight = "bold",
            },
        },
    }
end

--- 更新警报内容（外部调用）
function StatusBar.UpdateAlert(alertText)
    if not alertBarRef_ then return end
    if alertText and #alertText > 0 then
        if alertTextRef_ then alertTextRef_:SetText(alertText) end
        alertBarRef_:SetStyle({
            height = GameConfig.UI.alert_bar_height,
            paddingTop = 5, paddingBottom = 5,
        })
    else
        alertBarRef_:SetStyle({
            height = 0, paddingTop = 0, paddingBottom = 0,
        })
    end
end

--- 更新策略 chip 文案
function StatusBar.UpdateStrategy(label)
    if strategyChipLabelRef_ then
        strategyChipLabelRef_:SetText("📌 " .. (label or "均衡发展"))
    end
end

--- 更新声誉 chip
function StatusBar.UpdateReputation(rep)
    if repChipLabelRef_ then
        repChipLabelRef_:SetText("★ +" .. tostring(math.floor((rep or 3) * 4)))
    end
end

--- 更新资金 chip
function StatusBar.UpdateFunds(funds)
    if fundsChipLabelRef_ then
        fundsChipLabelRef_:SetText("¥" .. StatusBar._formatNumber(funds or 0))
    end
end

--- 更新公司名
function StatusBar.UpdateCompanyName(name)
    if companyNameRef_ then
        companyNameRef_:SetText(name or "")
    end
end

--- 兼容旧 API
function StatusBar.SwitchTo(tabName)
    EventBus.Emit(E.TAB_SWITCH, tabName)
end

function StatusBar.GetActiveTab()
    return "消息"
end

--- 格式化数字（千分位）
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
