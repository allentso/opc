-- ============================================================================
-- Shared.lua — 远程事件名定义 + 注册（服务端/客户端共用）
-- ============================================================================

local Shared = {}

-- ============================================================
-- 远程事件名称
-- ============================================================

-- 客户端 → 服务端：客户端准备就绪（握手）
Shared.E_CLIENT_READY = "CLIENT_READY"

-- 客户端 → 服务端：请求 LLM 生成对话
Shared.E_C2S_LLM_REQUEST = "C2S_LlmRequest"

-- 服务端 → 客户端：返回 LLM 生成结果
Shared.E_S2C_LLM_RESPONSE = "S2C_LlmResponse"

-- 服务端 → 客户端：返回错误信息
Shared.E_S2C_LLM_ERROR = "S2C_LlmError"

-- ============================================================
-- 注册函数（接收方调用）
-- ============================================================

--- 服务端调用：注册从客户端接收的事件
function Shared.RegisterServerEvents()
    if not network then
        print("[Shared] WARNING: network not available, skip server event registration")
        return
    end
    network:RegisterRemoteEvent(Shared.E_CLIENT_READY)
    network:RegisterRemoteEvent(Shared.E_C2S_LLM_REQUEST)
    print("[Shared] Server events registered")
end

--- 客户端调用：注册从服务端接收的事件
function Shared.RegisterClientEvents()
    if not network then
        print("[Shared] WARNING: network not available, skip client event registration")
        return
    end
    network:RegisterRemoteEvent(Shared.E_S2C_LLM_RESPONSE)
    network:RegisterRemoteEvent(Shared.E_S2C_LLM_ERROR)
    print("[Shared] Client events registered")
end

return Shared
