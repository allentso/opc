-- ============================================================================
-- BossSkillSystem.lua — 老板技能系统
-- ============================================================================

local EventBus = require("core.EventBus")
local GameConfig = require("config.GameConfig")
local E = EventBus.Events

local BossSkillSystem = {}

local skills_ = {}            -- 技能状态
local forceApproveCount_ = 0  -- 强制拍板次数（用于触发私下频道）

--- 初始化
function BossSkillSystem.Init()
    skills_ = {}
    forceApproveCount_ = 0

    for skillId, config in pairs(GameConfig.SKILLS) do
        skills_[skillId] = {
            id = skillId,
            config = config,
            cooldownRemaining = 0,
            usesRemaining = config.max_per_game or math.huge,
            available = true,
        }
    end
end

--- 每日更新冷却
---@param day number
function BossSkillSystem.OnDayEnd(day)
    for _, skill in pairs(skills_) do
        if skill.cooldownRemaining > 0 then
            skill.cooldownRemaining = skill.cooldownRemaining - 1
            if skill.cooldownRemaining <= 0 then
                skill.available = true
                EventBus.Emit(E.BOSS_SKILL_READY, skill.id)
            end
        end
    end
end

--- 使用技能
---@param skillId string
---@param funds number 当前资金
---@return boolean success
---@return string|nil message
function BossSkillSystem.UseSkill(skillId, funds)
    local skill = skills_[skillId]
    if not skill then
        return false, "技能不存在"
    end

    if not skill.available then
        return false, "技能冷却中（剩余" .. skill.cooldownRemaining .. "天）"
    end

    if skill.usesRemaining <= 0 then
        return false, "本局使用次数已达上限"
    end

    -- 检查资金消耗
    local cost = skill.config.cost
    if type(cost) == "number" and funds < cost then
        return false, "资金不足（需要¥" .. cost .. "）"
    end

    -- 使用技能
    skill.cooldownRemaining = skill.config.cooldown
    skill.available = (skill.config.cooldown == 0)
    skill.usesRemaining = skill.usesRemaining - 1

    -- 特殊计数
    if skillId == "force_approve" then
        forceApproveCount_ = forceApproveCount_ + 1
    end

    EventBus.Emit(E.BOSS_SKILL_USED, skillId, skill.config)

    return true, nil
end

--- 获取技能信息
---@param skillId string
---@return table|nil
function BossSkillSystem.GetSkill(skillId)
    return skills_[skillId]
end

--- 获取所有技能
---@return table
function BossSkillSystem.GetAllSkills()
    return skills_
end

--- 获取强制拍板次数
---@return number
function BossSkillSystem.GetForceApproveCount()
    return forceApproveCount_
end

--- 检查技能是否可用
---@param skillId string
---@return boolean
function BossSkillSystem.IsAvailable(skillId)
    local skill = skills_[skillId]
    if not skill then return false end
    return skill.available and skill.usesRemaining > 0
end

return BossSkillSystem
