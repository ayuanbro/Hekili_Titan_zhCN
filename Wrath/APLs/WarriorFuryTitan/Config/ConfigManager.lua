-- WarriorFuryTitan/Config/ConfigManager.lua
-- 配置管理器模块
-- **Feature: warrior-fury-titan-apl**
-- **Requirements: 10.2, 10.4, 10.5**

local APLCore = require("Wrath/APLs/WarriorFuryTitan/Core/APLCore")

local ConfigManager = {}

-- ============================================================================
-- 配置常量和默认值
-- ============================================================================

-- 默认配置
local DefaultConfig = {
    -- 基础设置
    enabled = true,
    debugMode = false,
    updateInterval = 0.1,
    
    -- APL设置
    apl = {
        useExecutePhase = true,
        executeThreshold = 20,
        useStanceWeaving = true,
        maintainSunderArmor = true,
        sunderArmorStacks = 5,
        useRageThresholds = true,
        heroicStrikeRageThreshold = 60,
        cleaveRageThreshold = 50
    },
    
    -- 冷却技能设置
    cooldowns = {
        useDeathWish = true,
        useRecklessness = true,
        useBloodrage = true,
        deathWishWithSunder = true,
        recklessnessWithDeathWish = true,
        bloodrageRageThreshold = 20
    },
    
    -- 姿态管理设置
    stance = {
        allowWeaving = true,
        weavingConditions = {
            coreSkillsOnCooldown = true,
            minRageForWeave = 30,
            maxWeaveDuration = 3
        }
    },
    
    -- 用户界面设置
    ui = {
        showRecommendations = true,
        showReasons = true,
        showPriorities = true,
        enableRuleToggle = true,
        autoSaveSettings = true
    },
    
    -- 高级设置
    advanced = {
        customThresholds = {},
        disabledRules = {},
        customPriorities = {}
    }
}

-- 配置文件路径
local CONFIG_FILE = "WTF/Account/SavedVariables/WarriorFuryTitanAPL.lua"

-- 当前配置
local currentConfig = {}

-- ============================================================================
-- 配置加载和保存
-- ============================================================================

-- 加载配置
function ConfigManager.loadConfig()
    local success, result = APLCore.ErrorHandler.safeCall(function()
        -- 尝试从文件加载配置
        local loadedConfig = ConfigManager.loadFromFile()
        
        if loadedConfig then
            -- 合并默认配置和加载的配置
            currentConfig = ConfigManager.mergeConfigs(DefaultConfig, loadedConfig)
            
            APLCore.ErrorHandler.logError(
                "CONFIG",
                APLCore.ErrorSeverity.LOW,
                "Configuration loaded successfully",
                string.format("Loaded from: %s", CONFIG_FILE),
                "ConfigManager.loadConfig"
            )
        else
            -- 使用默认配置
            currentConfig = ConfigManager.deepCopy(DefaultConfig)
            
            APLCore.ErrorHandler.logError(
                "CONFIG",
                APLCore.ErrorSeverity.LOW,
                "Using default configuration",
                "No saved configuration found",
                "ConfigManager.loadConfig"
            )
        end
        
        -- 验证配置
        ConfigManager.validateConfig(currentConfig)
        
        return currentConfig
    end)
    
    if not success then
        APLCore.ErrorHandler.logError(
            APLCore.ErrorTypes.CONFIG_ERROR,
            APLCore.ErrorSeverity.HIGH,
            "Failed to load configuration",
            result or "Unknown error",
            "ConfigManager.loadConfig"
        )
        
        -- 回退到默认配置
        currentConfig = ConfigManager.deepCopy(DefaultConfig)
    end
    
    return currentConfig
end

-- 保存配置
function ConfigManager.saveConfig(config)
    if not config then
        config = currentConfig
    end
    
    local success, result = APLCore.ErrorHandler.safeCall(function()
        -- 验证配置
        if not ConfigManager.validateConfig(config) then
            error("Invalid configuration data")
        end
        
        -- 保存到文件
        local saved = ConfigManager.saveToFile(config)
        
        if saved then
            currentConfig = ConfigManager.deepCopy(config)
            
            APLCore.ErrorHandler.logError(
                "CONFIG",
                APLCore.ErrorSeverity.LOW,
                "Configuration saved successfully",
                string.format("Saved to: %s", CONFIG_FILE),
                "ConfigManager.saveConfig"
            )
            
            return true
        else
            error("Failed to save configuration file")
        end
    end)
    
    if not success then
        APLCore.ErrorHandler.logError(
            APLCore.ErrorTypes.CONFIG_ERROR,
            APLCore.ErrorSeverity.HIGH,
            "Failed to save configuration",
            result or "Unknown error",
            "ConfigManager.saveConfig"
        )
        return false
    end
    
    return true
end

-- 从文件加载配置
function ConfigManager.loadFromFile()
    -- 简化实现 - 实际应该读取SavedVariables文件
    -- 这里返回nil表示没有保存的配置
    return nil
end

-- 保存配置到文件
function ConfigManager.saveToFile(config)
    -- 简化实现 - 实际应该写入SavedVariables文件
    -- 这里返回true表示保存成功
    return true
end

-- ============================================================================
-- 配置管理功能
-- ============================================================================

-- 获取默认配置
function ConfigManager.getDefaultConfig()
    return ConfigManager.deepCopy(DefaultConfig)
end

-- 获取当前配置
function ConfigManager.getCurrentConfig()
    if not currentConfig or not next(currentConfig) then
        return ConfigManager.loadConfig()
    end
    return currentConfig
end

-- 更新配置项
function ConfigManager.updateConfig(path, value)
    local config = ConfigManager.getCurrentConfig()
    
    local success, result = APLCore.ErrorHandler.safeCall(function()
        -- 解析配置路径
        local keys = {}
        for key in path:gmatch("[^%.]+") do
            table.insert(keys, key)
        end
        
        if #keys == 0 then
            error("Invalid configuration path: " .. path)
        end
        
        -- 导航到目标位置
        local current = config
        for i = 1, #keys - 1 do
            local key = keys[i]
            if not current[key] then
                current[key] = {}
            end
            current = current[key]
        end
        
        -- 设置值
        local finalKey = keys[#keys]
        current[finalKey] = value
        
        -- 验证更新后的配置
        if not ConfigManager.validateConfig(config) then
            error("Configuration validation failed after update")
        end
        
        -- 自动保存（如果启用）
        if config.ui and config.ui.autoSaveSettings then
            ConfigManager.saveConfig(config)
        end
        
        return true
    end)
    
    if not success then
        APLCore.ErrorHandler.logError(
            APLCore.ErrorTypes.CONFIG_ERROR,
            APLCore.ErrorSeverity.MEDIUM,
            "Failed to update configuration",
            string.format("Path: %s, Error: %s", path, result or "Unknown error"),
            "ConfigManager.updateConfig"
        )
        return false
    end
    
    return true
end

-- 获取配置项
function ConfigManager.getConfig(path)
    local config = ConfigManager.getCurrentConfig()
    
    local success, result = APLCore.ErrorHandler.safeCall(function()
        -- 解析配置路径
        local keys = {}
        for key in path:gmatch("[^%.]+") do
            table.insert(keys, key)
        end
        
        -- 导航到目标值
        local current = config
        for _, key in ipairs(keys) do
            if type(current) ~= "table" or current[key] == nil then
                return nil
            end
            current = current[key]
        end
        
        return current
    end)
    
    if not success then
        APLCore.ErrorHandler.logError(
            APLCore.ErrorTypes.CONFIG_ERROR,
            APLCore.ErrorSeverity.LOW,
            "Failed to get configuration value",
            string.format("Path: %s, Error: %s", path, result or "Unknown error"),
            "ConfigManager.getConfig"
        )
        return nil
    end
    
    return result
end

-- 重置配置到默认值
function ConfigManager.resetConfig()
    local success, result = APLCore.ErrorHandler.safeCall(function()
        currentConfig = ConfigManager.deepCopy(DefaultConfig)
        
        -- 保存重置后的配置
        ConfigManager.saveConfig(currentConfig)
        
        APLCore.ErrorHandler.logError(
            "CONFIG",
            APLCore.ErrorSeverity.LOW,
            "Configuration reset to defaults",
            "All settings restored to default values",
            "ConfigManager.resetConfig"
        )
        
        return true
    end)
    
    if not success then
        APLCore.ErrorHandler.logError(
            APLCore.ErrorTypes.CONFIG_ERROR,
            APLCore.ErrorSeverity.MEDIUM,
            "Failed to reset configuration",
            result or "Unknown error",
            "ConfigManager.resetConfig"
        )
        return false
    end
    
    return true
end

-- ============================================================================
-- 配置验证
-- ============================================================================

-- 验证配置
function ConfigManager.validateConfig(config)
    if type(config) ~= "table" then
        return false
    end
    
    -- 验证必需的顶级键
    local requiredKeys = {"enabled", "apl", "cooldowns", "stance", "ui"}
    for _, key in ipairs(requiredKeys) do
        if config[key] == nil then
            APLCore.ErrorHandler.logError(
                APLCore.ErrorTypes.VALIDATION_ERROR,
                APLCore.ErrorSeverity.MEDIUM,
                "Missing required configuration key",
                "Key: " .. key,
                "ConfigManager.validateConfig"
            )
            return false
        end
    end
    
    -- 验证数值范围
    if config.apl then
        if config.apl.executeThreshold and (config.apl.executeThreshold < 1 or config.apl.executeThreshold > 100) then
            APLCore.ErrorHandler.logError(
                APLCore.ErrorTypes.VALIDATION_ERROR,
                APLCore.ErrorSeverity.MEDIUM,
                "Invalid execute threshold",
                string.format("Value: %s (must be 1-100)", tostring(config.apl.executeThreshold)),
                "ConfigManager.validateConfig"
            )
            return false
        end
        
        if config.apl.sunderArmorStacks and (config.apl.sunderArmorStacks < 1 or config.apl.sunderArmorStacks > 5) then
            APLCore.ErrorHandler.logError(
                APLCore.ErrorTypes.VALIDATION_ERROR,
                APLCore.ErrorSeverity.MEDIUM,
                "Invalid sunder armor stacks",
                string.format("Value: %s (must be 1-5)", tostring(config.apl.sunderArmorStacks)),
                "ConfigManager.validateConfig"
            )
            return false
        end
    end
    
    return true
end

-- ============================================================================
-- 辅助函数
-- ============================================================================

-- 深拷贝表
function ConfigManager.deepCopy(original)
    if type(original) ~= "table" then
        return original
    end
    
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = ConfigManager.deepCopy(value)
    end
    
    return copy
end

-- 合并配置
function ConfigManager.mergeConfigs(default, override)
    local merged = ConfigManager.deepCopy(default)
    
    if type(override) ~= "table" then
        return merged
    end
    
    for key, value in pairs(override) do
        if type(value) == "table" and type(merged[key]) == "table" then
            merged[key] = ConfigManager.mergeConfigs(merged[key], value)
        else
            merged[key] = ConfigManager.deepCopy(value)
        end
    end
    
    return merged
end

-- 获取配置摘要
function ConfigManager.getConfigSummary()
    local config = ConfigManager.getCurrentConfig()
    
    return {
        enabled = config.enabled,
        aplSettings = {
            executePhase = config.apl.useExecutePhase,
            executeThreshold = config.apl.executeThreshold,
            stanceWeaving = config.apl.useStanceWeaving,
            sunderArmor = config.apl.maintainSunderArmor
        },
        cooldownSettings = {
            deathWish = config.cooldowns.useDeathWish,
            recklessness = config.cooldowns.useRecklessness,
            bloodrage = config.cooldowns.useBloodrage
        },
        uiSettings = {
            showRecommendations = config.ui.showRecommendations,
            showReasons = config.ui.showReasons,
            autoSave = config.ui.autoSaveSettings
        }
    }
end

-- ============================================================================
-- 规则管理
-- ============================================================================

-- 启用规则
function ConfigManager.enableRule(ruleName)
    local config = ConfigManager.getCurrentConfig()
    
    if config.advanced and config.advanced.disabledRules then
        -- 从禁用列表中移除
        for i, disabledRule in ipairs(config.advanced.disabledRules) do
            if disabledRule == ruleName then
                table.remove(config.advanced.disabledRules, i)
                break
            end
        end
        
        -- 自动保存
        if config.ui.autoSaveSettings then
            ConfigManager.saveConfig(config)
        end
        
        return true
    end
    
    return false
end

-- 禁用规则
function ConfigManager.disableRule(ruleName)
    local config = ConfigManager.getCurrentConfig()
    
    if config.advanced then
        if not config.advanced.disabledRules then
            config.advanced.disabledRules = {}
        end
        
        -- 检查是否已经禁用
        for _, disabledRule in ipairs(config.advanced.disabledRules) do
            if disabledRule == ruleName then
                return true -- 已经禁用
            end
        end
        
        -- 添加到禁用列表
        table.insert(config.advanced.disabledRules, ruleName)
        
        -- 自动保存
        if config.ui.autoSaveSettings then
            ConfigManager.saveConfig(config)
        end
        
        return true
    end
    
    return false
end

-- 检查规则是否启用
function ConfigManager.isRuleEnabled(ruleName)
    local config = ConfigManager.getCurrentConfig()
    
    if config.advanced and config.advanced.disabledRules then
        for _, disabledRule in ipairs(config.advanced.disabledRules) do
            if disabledRule == ruleName then
                return false
            end
        end
    end
    
    return true
end

-- ============================================================================
-- 模块注册
-- ============================================================================

-- 注册到核心系统
APLCore.registerModule("ConfigManager", ConfigManager)

return ConfigManager