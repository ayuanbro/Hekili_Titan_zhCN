-- WarriorFuryTitan/Monitor/StateMonitor.lua
-- 状态监控器模块
-- **Feature: warrior-fury-titan-apl**
-- **Requirements: 9.1, 9.2, 9.3, 9.4, 9.5**

local APLCore = require("Wrath/APLs/WarriorFuryTitan/Core/APLCore")

local StateMonitor = {}

-- ============================================================================
-- 状态缓存和配置
-- ============================================================================

local stateCache = {}
local lastUpdateTime = 0
local updateInterval = 0.1  -- 100ms更新间隔
local stateChangeCallbacks = {}

-- ============================================================================
-- 玩家状态监控
-- ============================================================================

-- 获取玩家状态
function StateMonitor.getPlayerState()
    local playerState = {
        -- 基础属性
        stance = "unknown",
        rage = 0,
        rageMax = 100,
        health = 0,
        healthPercent = 100,
        
        -- Buff状态
        buffs = {
            bloodsurge = StateMonitor.createBuffState(),
            deathWish = StateMonitor.createBuffState(),
            recklessness = StateMonitor.createBuffState(),
            enrage = StateMonitor.createBuffState(),
            flurry = StateMonitor.createBuffState()
        },
        
        -- 装备和天赋
        talents = {},
        equipment = {},
        glyphs = {}
    }
    
    -- 安全获取玩家信息
    local success, result = APLCore.ErrorHandler.safeCall(function()
        -- 获取姿态信息
        local shapeshift = GetShapeshiftForm and GetShapeshiftForm() or 0
        if shapeshift == 1 then
            playerState.stance = "battle"
        elseif shapeshift == 2 then
            playerState.stance = "defensive"
        elseif shapeshift == 3 then
            playerState.stance = "berserker"
        else
            playerState.stance = "none"
        end
        
        -- 获取怒气信息
        if UnitPower then
            playerState.rage = UnitPower("player", Enum.PowerType.Rage or 1) or 0
            playerState.rageMax = UnitPowerMax("player", Enum.PowerType.Rage or 1) or 100
        end
        
        -- 获取生命值信息
        if UnitHealth then
            playerState.health = UnitHealth("player") or 0
            playerState.healthPercent = UnitHealthMax("player") > 0 and 
                (playerState.health / UnitHealthMax("player")) * 100 or 100
        end
        
        -- 获取Buff信息
        StateMonitor.updatePlayerBuffs(playerState.buffs)
        
        return true
    end)
    
    if not success then
        APLCore.ErrorHandler.logError(
            APLCore.ErrorTypes.RUNTIME_ERROR,
            APLCore.ErrorSeverity.MEDIUM,
            "Failed to get player state",
            result or "Unknown error",
            "StateMonitor.getPlayerState"
        )
    end
    
    return playerState
end

-- 更新玩家Buff状态
function StateMonitor.updatePlayerBuffs(buffs)
    local buffMap = {
        bloodsurge = "Bloodsurge",
        deathWish = "Death Wish",
        recklessness = "Recklessness",
        enrage = "Enrage",
        flurry = "Flurry"
    }
    
    for buffKey, buffName in pairs(buffMap) do
        if buffs[buffKey] then
            local buffInfo = StateMonitor.getBuffInfo(buffName)
            buffs[buffKey] = buffInfo
        end
    end
end

-- ============================================================================
-- 目标状态监控
-- ============================================================================

-- 获取目标状态
function StateMonitor.getTargetState()
    local targetState = {
        -- 基础信息
        exists = false,
        health = 0,
        healthPercent = 100,
        distance = 0,
        
        -- Debuff状态
        debuffs = {
            sunderArmor = StateMonitor.createBuffState(),
            rend = StateMonitor.createBuffState(),
            mortalStrike = StateMonitor.createBuffState(),
            shatteringThrow = StateMonitor.createBuffState()
        },
        
        -- 目标类型
        isBoss = false,
        isElite = false,
        classification = "normal"
    }
    
    local success, result = APLCore.ErrorHandler.safeCall(function()
        -- 检查目标是否存在
        if UnitExists and UnitExists("target") then
            targetState.exists = true
            
            -- 获取目标生命值
            if UnitHealth then
                targetState.health = UnitHealth("target") or 0
                local maxHealth = UnitHealthMax("target") or 1
                targetState.healthPercent = (targetState.health / maxHealth) * 100
            end
            
            -- 获取目标距离
            if CheckInteractDistance then
                -- 使用交互距离检查作为近似
                targetState.distance = CheckInteractDistance("target", 3) and 5 or 30
            end
            
            -- 获取目标分类
            if UnitClassification then
                targetState.classification = UnitClassification("target") or "normal"
                targetState.isBoss = targetState.classification == "worldboss" or 
                                   targetState.classification == "rareelite"
                targetState.isElite = targetState.classification == "elite" or 
                                     targetState.classification == "rareelite"
            end
            
            -- 获取Debuff信息
            StateMonitor.updateTargetDebuffs(targetState.debuffs)
        end
        
        return true
    end)
    
    if not success then
        APLCore.ErrorHandler.logError(
            APLCore.ErrorTypes.RUNTIME_ERROR,
            APLCore.ErrorSeverity.MEDIUM,
            "Failed to get target state",
            result or "Unknown error",
            "StateMonitor.getTargetState"
        )
    end
    
    return targetState
end

-- 更新目标Debuff状态
function StateMonitor.updateTargetDebuffs(debuffs)
    local debuffMap = {
        sunderArmor = "Sunder Armor",
        rend = "Rend",
        mortalStrike = "Mortal Strike",
        shatteringThrow = "Shattering Throw"
    }
    
    for debuffKey, debuffName in pairs(debuffMap) do
        if debuffs[debuffKey] then
            local debuffInfo = StateMonitor.getDebuffInfo(debuffName)
            debuffs[debuffKey] = debuffInfo
        end
    end
end

-- ============================================================================
-- 技能状态监控
-- ============================================================================

-- 获取技能状态
function StateMonitor.getSkillStates()
    local skillStates = {
        bloodthirst = StateMonitor.createSkillState(),
        whirlwind = StateMonitor.createSkillState(),
        execute = StateMonitor.createSkillState(),
        slam = StateMonitor.createSkillState(),
        heroicStrike = StateMonitor.createSkillState(),
        cleave = StateMonitor.createSkillState(),
        
        -- 冷却技能
        deathWish = StateMonitor.createSkillState(),
        recklessness = StateMonitor.createSkillState(),
        bloodrage = StateMonitor.createSkillState()
    }
    
    local skillMap = {
        bloodthirst = "Bloodthirst",
        whirlwind = "Whirlwind",
        execute = "Execute",
        slam = "Slam",
        heroicStrike = "Heroic Strike",
        cleave = "Cleave",
        deathWish = "Death Wish",
        recklessness = "Recklessness",
        bloodrage = "Bloodrage"
    }
    
    local success, result = APLCore.ErrorHandler.safeCall(function()
        for skillKey, skillName in pairs(skillMap) do
            if skillStates[skillKey] then
                local skillInfo = StateMonitor.getSkillInfo(skillName)
                skillStates[skillKey] = skillInfo
            end
        end
        
        return true
    end)
    
    if not success then
        APLCore.ErrorHandler.logError(
            APLCore.ErrorTypes.RUNTIME_ERROR,
            APLCore.ErrorSeverity.MEDIUM,
            "Failed to get skill states",
            result or "Unknown error",
            "StateMonitor.getSkillStates"
        )
    end
    
    return skillStates
end

-- ============================================================================
-- 辅助函数
-- ============================================================================

-- 创建Buff/Debuff状态
function StateMonitor.createBuffState()
    return {
        active = false,
        duration = 0,
        stacks = 0,
        source = nil
    }
end

-- 创建技能状态
function StateMonitor.createSkillState()
    return {
        available = false,
        cooldown = 0,
        rageCost = 0,
        charges = 0,
        inRange = false
    }
end

-- 获取Buff信息
function StateMonitor.getBuffInfo(buffName)
    local buffState = StateMonitor.createBuffState()
    
    -- 这里应该调用实际的WoW API来获取buff信息
    -- 由于测试环境限制，使用模拟数据
    if buffName then
        -- 模拟buff检查逻辑
        buffState.active = false  -- 默认未激活
        buffState.duration = 0
        buffState.stacks = 0
        buffState.source = "player"
    end
    
    return buffState
end

-- 获取Debuff信息
function StateMonitor.getDebuffInfo(debuffName)
    local debuffState = StateMonitor.createBuffState()
    
    -- 这里应该调用实际的WoW API来获取debuff信息
    if debuffName then
        debuffState.active = false  -- 默认未激活
        debuffState.duration = 0
        debuffState.stacks = 0
        debuffState.source = "player"
    end
    
    return debuffState
end

-- 获取技能信息
function StateMonitor.getSkillInfo(skillName)
    local skillState = StateMonitor.createSkillState()
    
    -- 这里应该调用实际的WoW API来获取技能信息
    if skillName then
        skillState.available = true  -- 默认可用
        skillState.cooldown = 0
        skillState.rageCost = 10
        skillState.charges = 1
        skillState.inRange = true
    end
    
    return skillState
end

-- ============================================================================
-- 状态更新和缓存
-- ============================================================================

-- 获取当前游戏状态
function StateMonitor.getCurrentState()
    local currentTime = GetTime and GetTime() or time()
    
    -- 检查是否需要更新缓存
    if currentTime - lastUpdateTime < updateInterval and stateCache.player then
        return stateCache
    end
    
    -- 更新状态缓存
    local gameState = {
        player = StateMonitor.getPlayerState(),
        target = StateMonitor.getTargetState(),
        skills = StateMonitor.getSkillStates(),
        combat = StateMonitor.getCombatState(),
        timestamp = currentTime
    }
    
    -- 检查状态变化
    local hasChanged = StateMonitor.hasStateChanged(stateCache, gameState)
    
    -- 更新缓存
    stateCache = gameState
    lastUpdateTime = currentTime
    
    -- 触发状态变化回调
    if hasChanged then
        StateMonitor.triggerStateChangeCallbacks(gameState)
    end
    
    return gameState
end

-- 获取战斗状态
function StateMonitor.getCombatState()
    local combatState = {
        inCombat = false,
        combatTime = 0,
        enemyCount = 0,
        isMoving = false
    }
    
    local success, result = APLCore.ErrorHandler.safeCall(function()
        -- 检查战斗状态
        if UnitAffectingCombat then
            combatState.inCombat = UnitAffectingCombat("player") or false
        end
        
        -- 获取敌人数量（简化实现）
        combatState.enemyCount = combatState.inCombat and 1 or 0
        
        -- 检查移动状态
        if GetUnitSpeed then
            local speed = GetUnitSpeed("player") or 0
            combatState.isMoving = speed > 0
        end
        
        return true
    end)
    
    if not success then
        APLCore.ErrorHandler.logError(
            APLCore.ErrorTypes.RUNTIME_ERROR,
            APLCore.ErrorSeverity.LOW,
            "Failed to get combat state",
            result or "Unknown error",
            "StateMonitor.getCombatState"
        )
    end
    
    return combatState
end

-- 检查状态是否发生变化
function StateMonitor.hasStateChanged(oldState, newState)
    if not oldState or not oldState.player then
        return true
    end
    
    -- 检查关键状态变化
    local oldPlayer = oldState.player
    local newPlayer = newState.player
    
    -- 检查姿态变化
    if oldPlayer.stance ~= newPlayer.stance then
        return true
    end
    
    -- 检查怒气变化（超过5点认为有变化）
    if math.abs(oldPlayer.rage - newPlayer.rage) > 5 then
        return true
    end
    
    -- 检查目标变化
    if oldState.target.exists ~= newState.target.exists then
        return true
    end
    
    -- 检查目标血量变化（超过5%认为有变化）
    if oldState.target.exists and newState.target.exists then
        if math.abs(oldState.target.healthPercent - newState.target.healthPercent) > 5 then
            return true
        end
    end
    
    return false
end

-- ============================================================================
-- 状态变化回调系统
-- ============================================================================

-- 注册状态变化回调
function StateMonitor.onStateChange(callback)
    if type(callback) ~= "function" then
        APLCore.ErrorHandler.logError(
            APLCore.ErrorTypes.VALIDATION_ERROR,
            APLCore.ErrorSeverity.MEDIUM,
            "Invalid callback function",
            "Callback must be a function",
            "StateMonitor.onStateChange"
        )
        return false
    end
    
    table.insert(stateChangeCallbacks, callback)
    return true
end

-- 触发状态变化回调
function StateMonitor.triggerStateChangeCallbacks(gameState)
    for _, callback in ipairs(stateChangeCallbacks) do
        local success, result = APLCore.ErrorHandler.safeCall(callback, gameState)
        if not success then
            APLCore.ErrorHandler.logError(
                APLCore.ErrorTypes.RUNTIME_ERROR,
                APLCore.ErrorSeverity.LOW,
                "State change callback failed",
                result or "Unknown error",
                "StateMonitor.triggerStateChangeCallbacks"
            )
        end
    end
end

-- 清除所有回调
function StateMonitor.clearStateChangeCallbacks()
    stateChangeCallbacks = {}
end

-- ============================================================================
-- 模块注册
-- ============================================================================

-- 注册到核心系统
APLCore.registerModule("StateMonitor", StateMonitor)

return StateMonitor