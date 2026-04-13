-- ============================================================================
-- main.lua — AI公司总裁 · 入口文件（支持 C/S 架构）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local EventBus = require("core.EventBus")
local E = EventBus.Events

-- 检测运行模式
local isServer = (network ~= nil and network.serverRunning)

if isServer then
    -- ====================== 服务端模式 ======================
    require("network.Server")
    return
end

-- ====================== 客户端模式 ======================
local GameManager = require("core.GameManager")
local MainLayout = require("ui.MainLayout")
local ChannelManager = require("systems.ChannelManager")
local AgentCaller = require("agent.AgentCaller")

---@type table
local uiRoot_ = nil

-- 保持网络场景引用，防止 GC 回收
---@type Scene
local netScene_ = nil

--- 引擎入口
function Start()
    print("[main] " .. GameConfig.TITLE .. " v" .. GameConfig.VERSION .. " starting...")

    -- ⚠️ 网络握手必须在 Start() 最前面！
    -- persistent_world 模式下，引擎在 Lobby→游戏切换时会发送内部 LoadScene，
    -- 需要尽早设置 serverConnection.scene 来接收。
    -- 注意：引擎内部的 LoadScene 可能早于 Start()，该错误无法避免但不影响功能。
    if network then
        local Shared = require("network.Shared")
        Shared.RegisterClientEvents()

        -- 创建网络同步用的客户端场景（组件用 LOCAL 避免与服务端冲突）
        netScene_ = Scene()
        netScene_:CreateComponent("Octree", LOCAL)

        -- 设置 scene（必须保持 netScene_ 引用防止 GC）
        local serverConn = network:GetServerConnection()
        if serverConn then
            serverConn.scene = netScene_
            print("[main] Network: serverConnection.scene assigned")
        else
            print("[main] WARNING: no server connection available")
        end
    end

    -- 初始化 UI 系统
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } },
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 初始化 AgentCaller（检测 API 模式）
    AgentCaller.InitClient()

    -- 初始化游戏系统
    GameManager.Init()

    -- 获取初始状态
    local state = GameManager.GetState()

    -- 创建主界面
    uiRoot_ = MainLayout.Create(state, {
        onBossSend = function(text)
            GameManager.BossSendMessage(text)
        end,
        onAcceptOrder = function(orderId)
            GameManager.AcceptOrder(orderId)
        end,
        onUseSkill = function(skillId)
            GameManager.UseSkill(skillId)
        end,
    })

    UI.SetRoot(uiRoot_)

    -- 监听状态变化 → 更新 UI
    EventBus.On(E.UI_REFRESH, function() _refreshUI() end)
    EventBus.On(E.FUNDS_CHANGED, function() _refreshUI() end)
    EventBus.On(E.REPUTATION_CHANGED, function() _refreshUI() end)
    EventBus.On(E.DAY_START, function() _refreshUI() end)
    EventBus.On(E.PHASE_CHANGE, function() _refreshUI() end)

    -- 频道切换时更新输入栏状态
    EventBus.On(E.CHANNEL_SWITCH, function()
        MainLayout.UpdateInputState()
    end)

    SubscribeToEvent("Update", "HandleUpdate")

    -- 启动游戏
    GameManager.StartGame()

    -- 所有初始化完成后，通知服务端客户端已准备就绪
    if network then
        local Shared = require("network.Shared")
        local serverConn = network:GetServerConnection()
        if serverConn then
            serverConn:SendRemoteEvent(Shared.E_CLIENT_READY, true)
            print("[main] Network: CLIENT_READY sent (after full init)")
        end
    end

    print("[main] Game started!")
end

--- 统一 UI 刷新（状态栏 + 底部栏）
function _refreshUI()
    if not uiRoot_ then return end
    local state = GameManager.GetState()

    -- 更新顶部状态栏
    local statusBar = uiRoot_:FindById("statusBar")
    if statusBar then
        local alertLabel = statusBar:FindById("alertLabel")
        local alertIcon = statusBar:FindById("alertIcon")
        if alertLabel then alertLabel:SetText(state.alert or "") end
        if alertIcon then
            alertIcon:SetText((state.alert and #state.alert > 0) and "⚡" or "")
        end
        local stratChip = statusBar:FindById("strategyMiniChip")
        if stratChip then
            stratChip:SetText("📌 " .. GameManager.GetDailyStrategyLabel())
        end
    end

    -- 更新底部栏
    local bottomBar = uiRoot_:FindById("bottomBar")
    if bottomBar then
        local repLabel = bottomBar:FindById("bottomRepLabel")
        local fundsLabel = bottomBar:FindById("bottomFundsLabel")
        if repLabel then
            repLabel:SetText("本周声誉 +" .. tostring(math.floor((state.reputation or 3) * 4)))
        end
        if fundsLabel then
            fundsLabel:SetText("资金 ¥" .. MainLayout._formatNumber(state.funds or 0))
        end
    end
end

--- 每帧更新
---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    GameManager.Update(dt)
end

--- 退出清理
function Stop()
    EventBus.Clear()
    UI.Shutdown()
    print("[main] Game stopped.")
end
