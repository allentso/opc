-- ============================================================================
-- ShareCardSystem.lua — 日结分享卡 MVP（文本简报，可后续接截图）
-- ============================================================================

local EventBus = require("core.EventBus")
local ChannelManager = require("systems.ChannelManager")
local OrderManager = require("systems.OrderManager")
local E = EventBus.Events

local ShareCardSystem = {}

function ShareCardSystem.Init()
    EventBus.On(E.DAY_END, function(day)
        local GameManager = require("core.GameManager")
        local state = GameManager.GetState()
        local stats = OrderManager.GetStats()
        local lines = {
            "──────── 第 " .. tostring(day) .. " 日战报 ────────",
            "资金 ¥" .. tostring(state.funds or 0) .. "　声誉 " .. tostring(state.reputation or 0) .. "★",
            "累计完单 " .. tostring(stats.completed or 0) .. "　失败 " .. tostring(stats.failed or 0),
            "（分享卡 MVP：可复制本段作为战报）",
        }
        local text = table.concat(lines, "\n")
        ChannelManager.PushMessage("global", {
            sender = "系统",
            text = text,
            isSystem = true,
        })
    end)
end

return ShareCardSystem
