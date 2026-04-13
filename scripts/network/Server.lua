-- ============================================================================
-- Server.lua — 服务端 LLM 代理（接收客户端请求 → 调用 LLM API → 返回结果）
-- ============================================================================

---@diagnostic disable: undefined-global
-- cjson / http / network / HTTP_POST 是引擎内置全局变量

local Shared = require("network.Shared")
local LLMConfig = require("config.LLMConfig")

print("[Server] ==============================")
print("[Server] AI公司总裁 — 服务端启动")
print("[Server] ==============================")

-- ============================================================
-- 场景初始化
-- ============================================================

---@type Scene
local scene_ = nil

function Start()
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- 注册服务端接收的远程事件
    Shared.RegisterServerEvents()

    -- 监听客户端握手（CLIENT_READY → 才分配 scene）
    SubscribeToEvent(Shared.E_CLIENT_READY, "HandleClientReady")
    SubscribeToEvent("ClientConnected", "HandleClientConnected")
    SubscribeToEvent("ClientDisconnected", "HandleClientDisconnected")

    -- 监听 LLM 请求
    SubscribeToEvent(Shared.E_C2S_LLM_REQUEST, "HandleLLMRequest")

    -- 检查 API 配置
    if LLMConfig.IsConfigured() then
        print("[Server] LLM API configured: " .. LLMConfig.MODEL)
    else
        print("[Server] WARNING: LLM API not configured! Fill in config/LLMConfig.lua")
        print("[Server]   Will echo back test responses instead.")
    end

    print("[Server] Ready, waiting for clients...")
end

-- ============================================================
-- 客户端连接管理
-- ============================================================

---@param eventType string
---@param eventData VariantMap
function HandleClientConnected(eventType, eventData)
    -- 不在这里分配 scene！等客户端 CLIENT_READY 后再分配
    print("[Server] Client connected (waiting for CLIENT_READY)")
end

--- 客户端准备就绪 → 此时才分配 scene，完成握手
---@param eventType string
---@param eventData VariantMap
function HandleClientReady(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    if not connection then return end

    connection.scene = scene_
    print("[Server] Client ready, scene assigned. Remote events active.")
end

---@param eventType string
---@param eventData VariantMap
function HandleClientDisconnected(eventType, eventData)
    print("[Server] Client disconnected")
end

-- ============================================================
-- LLM 请求处理
-- ============================================================

---@param eventType string
---@param eventData VariantMap
function HandleLLMRequest(eventType, eventData)
    local requestId = eventData["RequestId"]:GetString()
    local dept = eventData["Dept"]:GetString()
    local systemPrompt = eventData["SystemPrompt"]:GetString()
    local userMessage = eventData["UserMessage"]:GetString()
    local connection = eventData["Connection"]:GetPtr("Connection")

    print("[Server] LLM request: id=" .. requestId .. " dept=" .. dept)
    print("[Server]   user: " .. userMessage:sub(1, 80) .. (userMessage:len() > 80 and "..." or ""))

    if not connection then
        print("[Server] ERROR: no connection for request " .. requestId)
        return
    end

    -- 如果未配置 API，返回模拟回复
    if not LLMConfig.IsConfigured() then
        _sendFallbackResponse(connection, requestId, dept, userMessage)
        return
    end

    -- 调用真实 LLM API
    _callLLM(connection, requestId, dept, systemPrompt, userMessage)
end

-- ============================================================
-- 真实 LLM API 调用
-- ============================================================

function _callLLM(connection, requestId, dept, systemPrompt, userMessage)
    local messages = {
        { role = "system", content = systemPrompt },
        { role = "user",   content = userMessage },
    }

    local requestBody = cjson.encode({
        model = LLMConfig.MODEL,
        messages = messages,
        max_tokens = LLMConfig.MAX_TOKENS,
        temperature = LLMConfig.TEMPERATURE,
    })

    print("[Server] Calling LLM API: " .. LLMConfig.API_URL:sub(1, 60) .. "...")

    http:Create()
        :SetUrl(LLMConfig.API_URL)
        :SetMethod(HTTP_POST)
        :SetContentType("application/json")
        :AddHeader("Authorization", "Bearer " .. LLMConfig.API_KEY)
        :SetBody(requestBody)
        :OnSuccess(function(client, response)
            if not response.success then
                print("[Server] HTTP failed, status: " .. tostring(response.statusCode))
                _sendError(connection, requestId, "HTTP " .. tostring(response.statusCode))
                return
            end

            local ok, data = pcall(cjson.decode, response.dataAsString)
            if not ok then
                print("[Server] JSON parse error: " .. tostring(data))
                _sendError(connection, requestId, "JSON parse error")
                return
            end

            -- 提取回复文本
            local content = ""
            if data.choices and data.choices[1] and data.choices[1].message then
                content = data.choices[1].message.content or ""
            end

            if content == "" then
                print("[Server] WARNING: empty response from LLM")
                content = "（AI暂时无法回应）"
            end

            print("[Server] LLM response: " .. content:sub(1, 80) .. (content:len() > 80 and "..." or ""))

            -- 发送回复给客户端
            _sendResponse(connection, requestId, dept, content)
        end)
        :OnError(function(client, statusCode, error)
            print("[Server] HTTP error: code=" .. tostring(statusCode) .. " err=" .. tostring(error))
            _sendError(connection, requestId, "Network error: " .. tostring(error))
        end)
        :Send()
end

-- ============================================================
-- 发送响应 / 错误
-- ============================================================

function _sendResponse(connection, requestId, dept, content)
    local data = VariantMap()
    data["RequestId"] = Variant(requestId)
    data["Dept"] = Variant(dept)
    data["Content"] = Variant(content)
    connection:SendRemoteEvent(Shared.E_S2C_LLM_RESPONSE, true, data)
    print("[Server] Sent response for " .. requestId)
end

function _sendError(connection, requestId, errorMsg)
    local data = VariantMap()
    data["RequestId"] = Variant(requestId)
    data["ErrorMsg"] = Variant(errorMsg)
    connection:SendRemoteEvent(Shared.E_S2C_LLM_ERROR, true, data)
    print("[Server] Sent error for " .. requestId .. ": " .. errorMsg)
end

-- ============================================================
-- 未配置 API 时的模拟回复
-- ============================================================

local FALLBACK_RESPONSES = {
    zhongshu = {
        "建议先明确需求边界，我这边拟一个初步方案。",
        "1、先理清目标用户；2、确认核心功能；3、排期。",
        "这个方向可以，但需求粒度还不够，我来拆一下。",
    },
    gongbu = {
        "技术上来说没问题，给我半天时间。",
        "这个需求……说简单也不简单，我先调研下。",
        "差不多了，还有几个边界情况要处理。",
    },
    menxia = {
        "这里有问题——数据格式不统一，需要打回修改。",
        "不符合标准，建议重新审视交互逻辑。",
        "形式上通过，但内容还需要补充。",
    },
    acceptance = {
        "综合评分72分，基本达标但有优化空间。",
        "质量达标，可以进入下一环节。",
        "验收不通过，请工部重新检查输出。",
    },
}

function _sendFallbackResponse(connection, requestId, dept, userMessage)
    local pool = FALLBACK_RESPONSES[dept] or FALLBACK_RESPONSES.zhongshu
    local text = pool[math.random(1, #pool)]
    print("[Server] Fallback response for dept=" .. dept)
    _sendResponse(connection, requestId, dept, text)
end
