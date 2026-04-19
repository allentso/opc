-- ============================================================================
-- ShareCardSystem.lua — 日终战报（v0.4 文本升级）
--
-- 升级点：
--   - 框线更精致，模拟"截图分享卡"的视觉
--   - 加入：完成订单详单、得分摘要、最佳/最差表现、今日策略、声誉变化、私下情报数
--   - 末尾附 #公司名 #日期 标签，方便玩家原文分享
-- ============================================================================

local EventBus = require("core.EventBus")
local ChannelManager = require("systems.ChannelManager")
local OrderManager = require("systems.OrderManager")
local E = EventBus.Events

local ShareCardSystem = {}

local previousFunds_ = nil
local previousRep_ = nil
local todayCompletedOrders_ = {}    -- 当日完成订单临时记录

function ShareCardSystem.Init()
    previousFunds_ = nil
    previousRep_ = nil
    todayCompletedOrders_ = {}

    EventBus.On(E.DAY_START, function()
        todayCompletedOrders_ = {}
    end)

    EventBus.On(E.ORDER_PROGRESS, function(order, newStatus)
        if newStatus == "completed" or newStatus == "failed" then
            table.insert(todayCompletedOrders_, {
                name = order.name,
                type = order.type,
                reward = order.reward,
                score = order.acceptanceScore or order.score,
                passed = (newStatus == "completed"),
            })
        end
    end)

    EventBus.On(E.DAY_END, function(day)
        ShareCardSystem._postSummary(day)
    end)
end

function ShareCardSystem._postSummary(day)
    local GameManager = require("core.GameManager")
    local state = GameManager.GetState()
    local stats = OrderManager.GetStats()
    local funds = state.funds or 0
    local rep = state.reputation or 0
    local fundsDelta = previousFunds_ and (funds - previousFunds_) or 0
    local repDelta = previousRep_ and (rep - previousRep_) or 0
    previousFunds_ = funds
    previousRep_ = rep

    -- 当日完成订单详情
    local orderLines = {}
    local successCount, failCount = 0, 0
    local highScore, highScoreOrder = 0, nil
    for _, o in ipairs(todayCompletedOrders_) do
        local mark = o.passed and "✅" or "❌"
        local scoreText = o.score and (" " .. tostring(o.score) .. "分") or ""
        table.insert(orderLines, "  " .. mark .. " " .. (o.name or "") .. scoreText)
        if o.passed then
            successCount = successCount + 1
            if (o.score or 0) > highScore then
                highScore = o.score or 0
                highScoreOrder = o.name
            end
        else
            failCount = failCount + 1
        end
    end
    if #orderLines == 0 then
        table.insert(orderLines, "  · 今日无订单完结")
    end

    local fundsTrend = fundsDelta >= 0 and ("▲ +¥" .. tostring(math.floor(fundsDelta))) or ("▼ ¥" .. tostring(math.floor(fundsDelta)))
    local repTrend = repDelta >= 0 and ("▲ +" .. tostring(math.floor(repDelta * 10) / 10)) or ("▼ " .. tostring(math.floor(repDelta * 10) / 10))

    local stratLabel = GameManager.GetDailyStrategyLabel and GameManager.GetDailyStrategyLabel() or "均衡发展"
    local companyName = state.companyName or "锐思AI工作室"
    local repStars = string.rep("★", math.max(0, math.min(5, math.floor(rep))))
        .. string.rep("☆", 5 - math.max(0, math.min(5, math.floor(rep))))

    local lines = {
        "╔══════════════════════════╗",
        "║  📊 第 " .. tostring(day) .. " 日 · 战报",
        "║  " .. companyName,
        "╠══════════════════════════╣",
        "║ 💰 资金 ¥" .. ShareCardSystem._fmt(funds) .. "  " .. fundsTrend,
        "║ ⭐ 声誉 " .. repStars .. "  " .. repTrend,
        "║ 📌 策略 " .. stratLabel,
        "╠══════════════════════════╣",
        "║ 📝 今日订单（成 " .. successCount .. " / 败 " .. failCount .. "）",
    }
    for _, ol in ipairs(orderLines) do
        table.insert(lines, "║" .. ol)
    end
    if highScoreOrder then
        table.insert(lines, "║ 🏆 最佳：" .. highScoreOrder .. " (" .. highScore .. "分)")
    end
    table.insert(lines, "╠══════════════════════════╣")
    table.insert(lines, "║ 累计 完单 " .. (stats.completed or 0) .. " / 失败 " .. (stats.failed or 0))
    table.insert(lines, "╚══════════════════════════╝")
    table.insert(lines, "")
    table.insert(lines, "#" .. companyName .. " #第" .. day .. "日 #AI公司模拟")

    ChannelManager.PushMessage("global", {
        sender = "战报",
        text = table.concat(lines, "\n"),
        isSystem = true,
        isShareCard = true,
    })
end

function ShareCardSystem._fmt(n)
    n = math.floor(n or 0)
    local s = tostring(n)
    local k
    while true do
        s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return s
end

return ShareCardSystem
