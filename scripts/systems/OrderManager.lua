-- ============================================================================
-- OrderManager.lua — 订单生命周期管理
-- ============================================================================

local EventBus = require("core.EventBus")
local GameConfig = require("config.GameConfig")
local E = EventBus.Events

local OrderManager = {}

-- 订单模板库
local ORDER_TEMPLATES = {
    hotspot = {
        { name = "为AI手机壳写3条抖音脚本", reward = 8000, risk = "low", deliverables = 3 },
        { name = "蹭热搜写一篇爆文", reward = 6000, risk = "medium", deliverables = 1 },
        { name = "紧急：明星代言翻车公关文", reward = 12000, risk = "high", deliverables = 2 },
        { name = "春节营销短视频脚本", reward = 10000, risk = "low", deliverables = 3 },
        { name = "AI女友App病毒式营销方案", reward = 15000, risk = "high", deliverables = 2 },
        { name = "618大促直播间口播稿×5", reward = 9000, risk = "medium", deliverables = 5 },
        { name = "二次元手游上线前宣发短文", reward = 11000, risk = "low", deliverables = 2 },
    },
    brand = {
        { name = "新茶饮品牌全案策划", reward = 25000, risk = "medium", deliverables = 4 },
        { name = "科技公司年度品牌升级", reward = 30000, risk = "low", deliverables = 5 },
        { name = "潮玩品牌联名策划", reward = 20000, risk = "medium", deliverables = 3 },
        { name = "高端护肤线品牌故事与Slogan", reward = 28000, risk = "low", deliverables = 4 },
        { name = "B端SaaS品牌认知调研+定位报告", reward = 32000, risk = "medium", deliverables = 5 },
    },
    app = {
        { name = "健身打卡小程序文案全套", reward = 18000, risk = "low", deliverables = 6 },
        { name = "AI心理咨询App产品文案", reward = 22000, risk = "medium", deliverables = 4 },
        { name = "智能家居App用户引导", reward = 15000, risk = "low", deliverables = 5 },
        { name = "网约车安全功能改版提示文案", reward = 19000, risk = "high", deliverables = 5 },
        { name = "儿童教育App家长端通知模板", reward = 16000, risk = "low", deliverables = 6 },
    },
    mystery = {
        { name = "【保密】某集团内部沟通方案", reward = 40000, risk = "high", deliverables = 3 },
        { name = "【未知甲方】品牌重塑", reward = 35000, risk = "high", deliverables = 4 },
        { name = "【紧急】危机公关全案", reward = 50000, risk = "high", deliverables = 2 },
        { name = "【黑盒需求】只给三个词：破圈·信任·年轻", reward = 38000, risk = "high", deliverables = 3 },
        { name = "【匿名甲】元宇宙展厅概念脚本", reward = 42000, risk = "high", deliverables = 4 },
    },
}

---@class Order
---@field id number
---@field name string
---@field type string
---@field reward number
---@field risk string
---@field deliverables number
---@field status string "available"|"accepted"|"executing"|"reviewing"|"submitted"|"completed"|"failed"
---@field score number|nil
---@field acceptedDay number|nil
---@field acceptancePassed boolean|nil 工作流：验收阶段写入，结算读取
---@field acceptanceScore number|nil

local orders_ = {}            -- 所有订单
local availableOrders_ = {}   -- 当日可用订单
local activeOrder_ = nil      -- 当前进行中的订单
local nextOrderId_ = 1
local completedCount_ = 0
local failedCount_ = 0

--- 初始化
function OrderManager.Init()
    orders_ = {}
    availableOrders_ = {}
    activeOrder_ = nil
    nextOrderId_ = 1
    completedCount_ = 0
    failedCount_ = 0
end

--- 刷新当日可用订单
---@param day number
function OrderManager.RefreshDailyOrders(day)
    availableOrders_ = {}
    local count = math.random(GameConfig.ORDERS_PER_DAY_MIN, GameConfig.ORDERS_PER_DAY_MAX)

    for i = 1, count do
        -- 随机选择订单类型
        local typeIdx = math.random(1, #GameConfig.ORDER_TYPES)
        local orderType = GameConfig.ORDER_TYPES[typeIdx]
        local templates = ORDER_TEMPLATES[orderType]
        if templates and #templates > 0 then
            local tmpl = templates[math.random(1, #templates)]
            local order = {
                id = nextOrderId_,
                name = tmpl.name,
                type = orderType,
                reward = tmpl.reward + math.random(-2000, 2000),
                risk = tmpl.risk,
                deliverables = tmpl.deliverables,
                difficulty = OrderManager._calcDifficulty(orderType, tmpl.risk),
                departments = OrderManager._defaultDepartments(orderType),
                status = "available",
                score = nil,
                acceptedDay = nil,
                acceptancePassed = nil,
                acceptanceScore = nil,
            }
            nextOrderId_ = nextOrderId_ + 1
            table.insert(availableOrders_, order)
            orders_[order.id] = order
            EventBus.Emit(E.ORDER_NEW, order)
        end
    end
end

--- 计算订单难度（1-5 颗星）
function OrderManager._calcDifficulty(orderType, risk)
    local base = ({ hotspot = 2, brand = 3, app = 3, mystery = 5 })[orderType] or 3
    if risk == "high" then base = base + 1
    elseif risk == "low" then base = math.max(1, base - 1) end
    return math.max(1, math.min(5, base))
end

--- 默认参与部门
function OrderManager._defaultDepartments(orderType)
    if orderType == "hotspot" then
        return { "zhongshu", "gongbu" }            -- 热点：策划+执行（少质检）
    elseif orderType == "brand" then
        return { "zhongshu", "gongbu", "menxia" }  -- 品牌：全套
    elseif orderType == "app" then
        return { "gongbu", "menxia" }              -- 应用：执行+测试
    elseif orderType == "mystery" then
        return { "zhongshu", "gongbu", "menxia" }  -- 神秘：全员
    end
    return { "zhongshu", "gongbu", "menxia" }
end

--- 接受订单
---@param orderId number
---@param day number
---@return boolean
function OrderManager.AcceptOrder(orderId, day)
    if activeOrder_ then return false end -- 已有进行中订单

    local order = orders_[orderId]
    if not order or order.status ~= "available" then return false end

    order.status = "accepted"
    order.acceptedDay = day
    activeOrder_ = order

    -- 从可用列表移除
    for i, o in ipairs(availableOrders_) do
        if o.id == orderId then
            table.remove(availableOrders_, i)
            break
        end
    end

    EventBus.Emit(E.ORDER_ACCEPTED, order)
    return true
end

--- 推进订单状态
---@param newStatus string
---@param data table|nil
function OrderManager.AdvanceOrder(newStatus, data)
    if not activeOrder_ then return end
    activeOrder_.status = newStatus

    if data then
        if data.score then activeOrder_.score = data.score end
    end

    EventBus.Emit(E.ORDER_PROGRESS, activeOrder_, newStatus)

    if newStatus == "completed" then
        completedCount_ = completedCount_ + 1
        activeOrder_ = nil
    elseif newStatus == "failed" then
        failedCount_ = failedCount_ + 1
        activeOrder_ = nil
    end
end

--- 验收阶段写入结果（供结算阶段读取）
function OrderManager.SetAcceptanceResult(passed, score, personaId)
    if not activeOrder_ then return end
    activeOrder_.acceptancePassed = passed
    activeOrder_.acceptanceScore = score
    if personaId ~= nil then
        activeOrder_.acceptancePersonaId = personaId
    end
end

function OrderManager.GetAcceptancePersonaId()
    if not activeOrder_ then return nil end
    return activeOrder_.acceptancePersonaId
end

---@return boolean|nil passed
---@return number|nil score
function OrderManager.GetAcceptanceResult()
    if not activeOrder_ then return nil, nil end
    return activeOrder_.acceptancePassed, activeOrder_.acceptanceScore
end

function OrderManager.ClearAcceptanceResult()
    if not activeOrder_ then return end
    activeOrder_.acceptancePassed = nil
    activeOrder_.acceptanceScore = nil
    activeOrder_.acceptancePersonaId = nil
end

--- 获取当前进行中的订单
---@return Order|nil
function OrderManager.GetActiveOrder()
    return activeOrder_
end

--- 获取可用订单列表
---@return Order[]
function OrderManager.GetAvailableOrders()
    return availableOrders_
end

--- 获取统计数据
---@return table
function OrderManager.GetStats()
    -- 按类型统计已完成订单数
    local byType = {}
    for _, ord in ipairs(orders_) do
        if ord.status == "completed" then
            local t = ord.type or "unknown"
            byType[t] = (byType[t] or 0) + 1
        end
    end
    return {
        completed = completedCount_,
        failed = failedCount_,
        total = completedCount_ + failedCount_,
        hot_completed = byType.hot or byType.hotspot or 0,
        brand_completed = byType.brand or 0,
        app_completed = byType.app or byType.application or 0,
        mystery_completed = byType.mystery or 0,
    }
end

--- 获取订单类型标签
---@param orderType string
---@return string
function OrderManager.GetOrderTypeLabel(orderType)
    local labels = {
        hotspot = "🔥 热点速攻",
        brand = "💎 品牌策划",
        app = "📱 应用开发",
        mystery = "❓ 神秘订单",
    }
    return labels[orderType] or orderType
end

--- 获取风险标签
---@param risk string
---@return string, table
function OrderManager.GetRiskLabel(risk)
    local labels = {
        low    = { "低风险", GameConfig.COLORS.success },
        medium = { "中风险", GameConfig.COLORS.warning },
        high   = { "高风险", GameConfig.COLORS.danger },
    }
    local info = labels[risk] or labels.medium
    return info[1], info[2]
end

return OrderManager
