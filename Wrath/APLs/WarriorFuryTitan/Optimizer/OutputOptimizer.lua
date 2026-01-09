-- WarriorFuryTitan/Optimizer/OutputOptimizer.lua
-- 输出优化器模块
-- **Feature: warrior-fury-titan-apl**
-- **Requirements: 8.1, 8.2, 8.3, 8.4**

local APLCore = require("Wrath/APLs/WarriorFuryTitan/Core/APLCore")

local OutputOptimizer = {}

-- ============================================================================
-- 优化器配置和常量
-- ============================================================================

-- 技能基础数据
local SkillData = {
    bloodthirst = {
        baseDamage = 200,
        rageCost = 30,
        cooldown = 6,
        gcd = 1.5,
        weaponDamagePercent = 0.45
    },
    whirlwind = {
        baseDamage = 150,
        rageCost = 25,
        cooldown = 10,
        gcd = 1.5,
        weaponDamagePercent = 1.0
    },
    execute = {
        baseDamage = 600,
        rageCost = 15,
        cooldown = 0,
        gcd = 1.5,
        weaponDamagePercent = 0.2,
        executeOnly = true
    },
    slam = {
        baseDamage = 180,
        rageCost = 15,
        cooldown = 0,
        gcd = 1.5,
        weaponDamagePercent = 0.87,
        castTime = 1.5
    },
    heroicStrike = {
        baseDamage = 120,
        rageCost = 15,
        cooldown = 0,
        gcd = 0,
        weaponDamagePercent = 1.0,
        nextMelee = true
    },
    cleave = {
        baseDamage = 100,
        rageCost = 20,
        cooldown = 0,
        gcd = 0,
        weaponDamagePercent = 1.0,
        nextMelee = true,
        aoe = true
    }
}

-- Buff效果数据
local BuffEffects = {
    deathWish = {
        damageMultiplier = 1.20,
        duration = 30
    },
    recklessness = {
        critChance = 100,
        duration = 15
    },
    enrage = {
        damageMultiplier = 1.25,
        duration = 12
    },
    flurry = {
        attackSpeedMultiplier = 1.30,
        duration = 15
    },
    bloodsurge = {
        slamInstant = true,
        duration = 5
    }
}

-- ============================================================================
-- DPS计算引擎
-- ============================================================================

-- 计算技能DPS价值
function OutputOptimizer.calculateSkillDPS(skill, gameState)
    if not skill or not gameState then
        APLCore.ErrorHandler.logError(
            APLCore.ErrorTypes.VALIDATION_ERROR,
            APLCore.ErrorSeverity.MEDIUM,
            "Invalid parameters for DPS calculation",
            "Skill and gameState are required",
            "OutputOptimizer.calculateSkillDPS"
        )
        return 0
    end
    
    local skillData = SkillData[skill]
    if not skillData then
        return 0
    end
    
    local success, dps = APLCore.ErrorHandler.safeCall(function()
        -- 基础伤害计算
        local baseDamage = skillData.baseDamage
        local weaponDamage = OutputOptimizer.getWeaponDamage(gameState)
        local totalDamage = baseDamage + (weaponDamage * skillData.weaponDamagePercent)
        
        -- 应用Buff效果
        totalDamage = OutputOptimizer.applyBuffEffects(totalDamage, gameState, skill)
        
        -- 应用暴击效果
        local critChance = OutputOptimizer.getCritChance(gameState, skill)
        local critMultiplier = OutputOptimizer.getCritMultiplier(gameState)
        totalDamage = totalDamage * (1 + critChance * (critMultiplier - 1))
        
        -- 计算DPS（考虑冷却时间和GCD）
        local effectiveCooldown = math.max(skillData.cooldown, skillData.gcd)
        if skillData.castTime then
            effectiveCooldown = math.max(effectiveCooldown, skillData.castTime)
        end
        
        local dps = effectiveCooldown > 0 and (totalDamage / effectiveCooldown) or 0
        
        -- 应用特殊条件修正
        dps = OutputOptimizer.applySpecialModifiers(dps, skill, gameState)
        
        return dps
    end)
    
    if not success then
        APLCore.ErrorHandler.logError(
            APLCore.ErrorTypes.RUNTIME_ERROR,
            APLCore.ErrorSeverity.MEDIUM,
            "DPS calculation failed",
            dps or "Unknown error",
            "OutputOptimizer.calculateSkillDPS"
        )
        return 0
    end
    
    return dps or 0
end

-- 获取武器伤害
function OutputOptimizer.getWeaponDamage(gameState)
    -- 简化实现，实际应该从装备信息获取
    local baseWeaponDamage = 200
    
    -- 根据玩家等级和装备调整
    if gameState.player and gameState.player.equipment then
        -- 这里应该计算实际武器伤害
        baseWeaponDamage = 200 -- 占位符
    end
    
    return baseWeaponDamage
end

-- 应用Buff效果
function OutputOptimizer.applyBuffEffects(damage, gameState, skill)
    local modifiedDamage = damage
    
    if not gameState.player or not gameState.player.buffs then
        return modifiedDamage
    end
    
    local buffs = gameState.player.buffs
    
    -- 死亡之愿效果
    if buffs.deathWish and buffs.deathWish.active then
        local effect = BuffEffects.deathWish
        modifiedDamage = modifiedDamage * effect.damageMultiplier
    end
    
    -- 狂怒效果
    if buffs.enrage and buffs.enrage.active then
        local effect = BuffEffects.enrage
        modifiedDamage = modifiedDamage * effect.damageMultiplier
    end
    
    -- 嗜血猛击效果（仅对猛击有效）
    if skill == "slam" and buffs.bloodsurge and buffs.bloodsurge.active then
        -- 嗜血猛击使猛击变为瞬发，提高其价值
        modifiedDamage = modifiedDamage * 1.5
    end
    
    return modifiedDamage
end

-- 获取暴击几率
function OutputOptimizer.getCritChance(gameState, skill)
    local baseCritChance = 0.15 -- 15%基础暴击
    
    if not gameState.player or not gameState.player.buffs then
        return baseCritChance
    end
    
    -- 鲁莽效果
    if gameState.player.buffs.recklessness and gameState.player.buffs.recklessness.active then
        return 1.0 -- 100%暴击
    end
    
    return baseCritChance
end

-- 获取暴击倍率
function OutputOptimizer.getCritMultiplier(gameState)
    return 2.0 -- 基础暴击倍率
end

-- 应用特殊修正
function OutputOptimizer.applySpecialModifiers(dps, skill, gameState)
    local modifiedDPS = dps
    
    -- 斩杀阶段修正
    if skill == "execute" then
        if gameState.target and gameState.target.healthPercent <= 20 then
            -- 斩杀在低血量时价值更高
            modifiedDPS = modifiedDPS * 2.0
        else
            -- 非斩杀阶段不能使用斩杀
            modifiedDPS = 0
        end
    end
    
    -- 多目标修正
    if gameState.combat and gameState.combat.enemyCount > 1 then
        if skill == "whirlwind" or skill == "cleave" then
            -- AOE技能在多目标时价值提升
            modifiedDPS = modifiedDPS * gameState.combat.enemyCount
        end
    end
    
    -- 怒气效率修正
    local skillData = SkillData[skill]
    if skillData and skillData.rageCost > 0 then
        local rageEfficiency = modifiedDPS / skillData.rageCost
        -- 怒气效率低的技能在怒气紧张时降低优先级
        if gameState.player and gameState.player.rage < skillData.rageCost * 2 then
            modifiedDPS = modifiedDPS * 0.8
        end
    end
    
    return modifiedDPS
end

-- ============================================================================
-- 技能序列评估
-- ============================================================================

-- 评估技能序列
function OutputOptimizer.evaluateSequence(sequence)
    if not sequence or #sequence == 0 then
        return {
            totalDPS = 0,
            skillContributions = {},
            optimizationSuggestions = {"Empty sequence"}
        }
    end
    
    local result = {
        totalDPS = 0,
        skillContributions = {},
        optimizationSuggestions = {}
    }
    
    local success, _ = APLCore.ErrorHandler.safeCall(function()
        local totalTime = 0
        local totalDamage = 0
        
        for i, skillEntry in ipairs(sequence) do
            local skill = skillEntry.skill
            local gameState = skillEntry.gameState
            
            if skill and gameState then
                local skillDPS = OutputOptimizer.calculateSkillDPS(skill, gameState)
                local skillData = SkillData[skill]
                
                if skillData then
                    local skillTime = math.max(skillData.cooldown, skillData.gcd)
                    if skillData.castTime then
                        skillTime = math.max(skillTime, skillData.castTime)
                    end
                    
                    local skillDamage = skillDPS * skillTime
                    totalDamage = totalDamage + skillDamage
                    totalTime = totalTime + skillTime
                    
                    result.skillContributions[skill] = (result.skillContributions[skill] or 0) + skillDamage
                end
            end
        end
        
        result.totalDPS = totalTime > 0 and (totalDamage / totalTime) or 0
        
        -- 生成优化建议
        result.optimizationSuggestions = OutputOptimizer.generateOptimizationSuggestions(sequence, result)
        
        return true
    end)
    
    if not success then
        APLCore.ErrorHandler.logError(
            APLCore.ErrorTypes.RUNTIME_ERROR,
            APLCore.ErrorSeverity.MEDIUM,
            "Sequence evaluation failed",
            "Unknown error during sequence evaluation",
            "OutputOptimizer.evaluateSequence"
        )
    end
    
    return result
end

-- 生成优化建议
function OutputOptimizer.generateOptimizationSuggestions(sequence, result)
    local suggestions = {}
    
    -- 检查技能使用效率
    for skill, contribution in pairs(result.skillContributions) do
        local percentage = result.totalDPS > 0 and (contribution / result.totalDPS) * 100 or 0
        
        if percentage < 5 and skill ~= "heroicStrike" then
            table.insert(suggestions, string.format("Consider removing %s (low contribution: %.1f%%)", skill, percentage))
        end
    end
    
    -- 检查技能顺序
    for i = 1, #sequence - 1 do
        local currentSkill = sequence[i].skill
        local nextSkill = sequence[i + 1].skill
        
        if currentSkill == "execute" and nextSkill ~= "execute" then
            local gameState = sequence[i].gameState
            if gameState.target and gameState.target.healthPercent <= 20 then
                table.insert(suggestions, "Consider using Execute more frequently in execute phase")
            end
        end
    end
    
    -- 检查冷却技能使用
    local hasDeathWish = false
    local hasRecklessness = false
    
    for _, skillEntry in ipairs(sequence) do
        if skillEntry.skill == "deathWish" then
            hasDeathWish = true
        elseif skillEntry.skill == "recklessness" then
            hasRecklessness = true
        end
    end
    
    if not hasDeathWish then
        table.insert(suggestions, "Consider using Death Wish for burst phases")
    end
    
    if not hasRecklessness then
        table.insert(suggestions, "Consider using Recklessness with Death Wish")
    end
    
    return suggestions
end

-- ============================================================================
-- 推荐生成
-- ============================================================================

-- 生成最优建议
function OutputOptimizer.generateRecommendation(gameState)
    if not gameState then
        return {
            skill = nil,
            priority = 0,
            reason = "No game state available",
            conditions = {}
        }
    end
    
    local recommendation = {
        skill = nil,
        priority = 0,
        reason = "",
        conditions = {}
    }
    
    local success, _ = APLCore.ErrorHandler.safeCall(function()
        local availableSkills = OutputOptimizer.getAvailableSkills(gameState)
        local bestSkill = nil
        local bestDPS = 0
        
        -- 评估所有可用技能
        for _, skill in ipairs(availableSkills) do
            local dps = OutputOptimizer.calculateSkillDPS(skill, gameState)
            
            if dps > bestDPS then
                bestDPS = dps
                bestSkill = skill
            end
        end
        
        if bestSkill then
            recommendation.skill = bestSkill
            recommendation.priority = bestDPS
            recommendation.reason = OutputOptimizer.getRecommendationReason(bestSkill, gameState)
            recommendation.conditions = OutputOptimizer.getSkillConditions(bestSkill, gameState)
        else
            recommendation.reason = "No available skills"
        end
        
        return true
    end)
    
    if not success then
        recommendation.reason = "Error generating recommendation"
        APLCore.ErrorHandler.logError(
            APLCore.ErrorTypes.RUNTIME_ERROR,
            APLCore.ErrorSeverity.MEDIUM,
            "Recommendation generation failed",
            "Unknown error during recommendation generation",
            "OutputOptimizer.generateRecommendation"
        )
    end
    
    return recommendation
end

-- 获取可用技能列表
function OutputOptimizer.getAvailableSkills(gameState)
    local availableSkills = {}
    
    if not gameState.skills then
        return availableSkills
    end
    
    for skill, skillState in pairs(gameState.skills) do
        if skillState.available and skillState.cooldown <= 0 then
            -- 检查怒气需求
            local skillData = SkillData[skill]
            if skillData then
                if not skillData.rageCost or gameState.player.rage >= skillData.rageCost then
                    -- 检查特殊条件
                    if skill == "execute" then
                        if gameState.target.healthPercent <= 20 then
                            table.insert(availableSkills, skill)
                        end
                    else
                        table.insert(availableSkills, skill)
                    end
                end
            end
        end
    end
    
    return availableSkills
end

-- 获取推荐理由
function OutputOptimizer.getRecommendationReason(skill, gameState)
    local reasons = {
        bloodthirst = "High DPS core ability",
        whirlwind = "Good rage efficiency",
        execute = "Execute phase - high damage",
        slam = "Bloodsurge proc available",
        heroicStrike = "Rage dump ability",
        cleave = "Multi-target situation"
    }
    
    local baseReason = reasons[skill] or "Optimal DPS choice"
    
    -- 添加上下文信息
    if skill == "slam" and gameState.player.buffs.bloodsurge and gameState.player.buffs.bloodsurge.active then
        return baseReason .. " (Bloodsurge active)"
    end
    
    if gameState.combat and gameState.combat.enemyCount > 1 and (skill == "whirlwind" or skill == "cleave") then
        return baseReason .. string.format(" (%d enemies)", gameState.combat.enemyCount)
    end
    
    return baseReason
end

-- 获取技能条件
function OutputOptimizer.getSkillConditions(skill, gameState)
    local conditions = {}
    
    local skillData = SkillData[skill]
    if skillData then
        if skillData.rageCost then
            conditions.rageRequired = skillData.rageCost
        end
        
        if skillData.executeOnly then
            conditions.targetHealthMax = 20
        end
        
        if skillData.aoe then
            conditions.multiTarget = true
        end
    end
    
    return conditions
end

-- ============================================================================
-- 模块注册
-- ============================================================================

-- 注册到核心系统
APLCore.registerModule("OutputOptimizer", OutputOptimizer)

return OutputOptimizer