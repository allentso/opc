-- ============================================================================
-- OrgGenerator.lua — 组织架构生成器（4 种原型）
-- ============================================================================

local EventBus = require("core.EventBus")
local E = EventBus.Events

local OrgGenerator = {}

--- 组织原型定义
OrgGenerator.ARCHETYPES = {
    {
        id = "standard",
        name = "通用公司制",
        desc = "稳定均衡，新手友好",
        weakness = "无突出优势",
        bestFor = "均衡型订单",
        icon = "🏢",
        reviewStrength = 0.5,   -- 审查强度 0~1
        execSpeed = 0.5,        -- 执行速度 0~1
        conflictRate = 0.2,     -- 冲突概率 0~1
        incidentModifiers = {},
    },
    {
        id = "three_province",
        name = "三省六部制",
        desc = "高审查、抗风险",
        weakness = "沟通成本高，响应慢",
        bestFor = "高风险/高价值单",
        icon = "🏛️",
        reviewStrength = 0.9,
        execSpeed = 0.3,
        conflictRate = 0.4,
        incidentModifiers = {
            approval_loop = 0.3,
            missed_hotspot = 0.5,
        },
    },
    {
        id = "flat",
        name = "扁平快反制",
        desc = "执行快，响应热点",
        weakness = "容易跳过质检翻车",
        bestFor = "热点速攻单",
        icon = "⚡",
        reviewStrength = 0.2,
        execSpeed = 0.9,
        conflictRate = 0.1,
        incidentModifiers = {
            quality_meltdown = 0.05,  -- 几乎不会因审查过严出事
        },
    },
    {
        id = "hive",
        name = "蜂巢并行制",
        desc = "高并发量产",
        weakness = "调度复杂，内耗多",
        bestFor = "大批量内容单",
        icon = "🐝",
        reviewStrength = 0.4,
        execSpeed = 0.7,
        conflictRate = 0.5,
        incidentModifiers = {
            zhongshu_coup = 0.3,
        },
    },
}

local currentOrg_ = nil  -- 当前组织架构

--- 初始化（默认通用公司制）
function OrgGenerator.Init()
    OrgGenerator.SelectArchetype("standard")
end

--- 选择组织原型
---@param archetypeId string
function OrgGenerator.SelectArchetype(archetypeId)
    for _, arch in ipairs(OrgGenerator.ARCHETYPES) do
        if arch.id == archetypeId then
            currentOrg_ = {
                archetype = arch,
                departments = OrgGenerator._buildDepartments(arch),
                createdDay = 0,
                reportingSwap = false,
            }
            EventBus.Emit(E.ORG_CREATED, currentOrg_)
            return true
        end
    end
    return false
end

--- 构建部门结构
function OrgGenerator._buildDepartments(archetype)
    local depts = {
        {
            id = "zhongshu",
            name = "中书省",
            role = "策划/方案",
            level = 1,
            workload = 0,
            maxWorkload = 3,
            status = "idle",
        },
        {
            id = "gongbu",
            name = "工部",
            role = "内容/执行",
            level = 1,
            workload = 0,
            maxWorkload = 5,
            status = "idle",
        },
        {
            id = "menxia",
            name = "门下省",
            role = "审查/质检",
            level = 1,
            workload = 0,
            maxWorkload = 4,
            status = "idle",
        },
    }
    return depts
end

--- 获取当前组织
---@return table|nil
function OrgGenerator.GetCurrentOrg()
    return currentOrg_
end

--- 获取当前组织原型
---@return table|nil
function OrgGenerator.GetArchetype()
    if not currentOrg_ then return nil end
    return currentOrg_.archetype
end

--- 获取部门状态
---@param deptId string
---@return table|nil
function OrgGenerator.GetDepartment(deptId)
    if not currentOrg_ then return nil end
    for _, d in ipairs(currentOrg_.departments) do
        if d.id == deptId then return d end
    end
    return nil
end

--- 更新部门工作量
---@param deptId string
---@param delta number
function OrgGenerator.UpdateWorkload(deptId, delta)
    local dept = OrgGenerator.GetDepartment(deptId)
    if not dept then return end
    dept.workload = math.max(0, math.min(dept.maxWorkload, dept.workload + delta))
    if dept.workload >= dept.maxWorkload then
        dept.status = "overloaded"
    elseif dept.workload > 0 then
        dept.status = "working"
    else
        dept.status = "idle"
    end
end

--- 设置部门状态
---@param deptId string
---@param status string
function OrgGenerator.SetDepartmentStatus(deptId, status)
    local dept = OrgGenerator.GetDepartment(deptId)
    if dept then
        dept.status = status
    end
end

--- 获取所有部门
---@return table[]
function OrgGenerator.GetAllDepartments()
    if not currentOrg_ then return {} end
    return currentOrg_.departments
end

--- 获取所有原型列表（用于展示选择界面）
---@return table[]
function OrgGenerator.GetAllArchetypes()
    return OrgGenerator.ARCHETYPES
end

--- 紧急重组：切换中书省↔门下省汇报对调状态（影响审查骰子权重）
---@return boolean 是否生效
function OrgGenerator.SwapReportingPair()
    if not currentOrg_ then return false end
    currentOrg_.reportingSwap = not (currentOrg_.reportingSwap or false)
    EventBus.Emit(E.ORG_RESTRUCTURED, currentOrg_)
    return true
end

function OrgGenerator.IsReportingSwapped()
    return currentOrg_ and currentOrg_.reportingSwap == true
end

return OrgGenerator
