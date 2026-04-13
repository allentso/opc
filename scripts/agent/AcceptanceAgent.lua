-- ============================================================================
-- AcceptanceAgent.lua — 验收官：结构化 JSON 解析 + 提示词片段（与部门调用分离）
-- ============================================================================

local AcceptanceAgent = {}

AcceptanceAgent.JSON_INSTRUCTION = [[
你是甲方验收官。除自然语言评语外，必须在回复最后一行单独输出一行 JSON（不要有其他代码块），格式严格为：
{"passed":true或false,"score":0到100的整数,"reason":"一句话理由"}
]]

--- 从模型回复中解析验收 JSON（宽松匹配，失败返回 nil）
---@param text string
---@return table|nil { passed, score, reason }
function AcceptanceAgent.ParseStructuredResponse(text)
    if not text or text == "" then return nil end
    local jsonChunk = text:match("%b{}")
    if not jsonChunk then return nil end
    local passed
    if jsonChunk:find('"passed"%s*:%s*true') or jsonChunk:find("'passed'%s*:%s*true") then
        passed = true
    elseif jsonChunk:find('"passed"%s*:%s*false') or jsonChunk:find("'passed'%s*:%s*false") then
        passed = false
    end
    local score = tonumber(jsonChunk:match('"score"%s*:%s*(%d+)'))
    local reason = jsonChunk:match('"reason"%s*:%s*"([^"]*)"')
    if score == nil and passed == nil then return nil end
    if score == nil then score = passed and 75 or 45 end
    score = math.max(0, math.min(100, score))
    if passed == nil then
        passed = score >= 60
    end
    return { passed = passed, score = score, reason = reason }
end

return AcceptanceAgent
