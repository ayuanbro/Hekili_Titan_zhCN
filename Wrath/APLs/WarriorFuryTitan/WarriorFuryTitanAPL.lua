-- WarriorFuryTitan/WarriorFuryTitanAPL.lua
-- 战士狂暴天赋泰坦APL系统主模块
-- **Feature: warrior-fury-titan-apl**
-- **Requirements: 7.1, 7.4, 9.1**

local WarriorFuryTitanAPL = {}

-- ============================================================================
-- 模块信息
-- ============================================================================

WarriorFuryTitanAPL.VERSION = "1.0.0"
WarriorFuryTitanAPL.NAME = "Warrior Fury Titan APL"
WarriorFuryTitanAPL.AUTHOR = "Warrior Fury Titan APL Team"

-- ============================================================================
-- 模块依赖和加载
-- ============================================================================

local modules = {}
local initialized = false

-- 模块加载顺序（重要：按依赖关系排序）
local moduleLoadOrder = {
    "Core/APLCore",
    "Parser/APLParser", 
    "Monitor/StateMonitor",
    "Optimizer/OutputOptimizer",
    "Config/ConfigManager"
}

-- 加载单个模块
local function loadModule(modulePath)
    local success, module = pcall(require, "Wrath/APLs/WarriorFuryTitan/" .. modulePath)
    
    if success and module then
        local moduleName = modulePath:match("([^/]+)$") -- 获取文件名作为模块名
        modules[moduleName] = module
        
        print(string.format("[WarriorFuryTitanAPL] Loaded module: %s", moduleName))
        return true
    else
        print(string.format("[WarriorFuryTitanAPL] Failed to load module: %s - %s", modulePath, tostring(module)))
        return false
    end
end

-- 加载所有模块
local function loadAllModules()
    local loadedCount = 0
    local totalCount = #moduleLoadOrder
    
    print(string.format("[WarriorFuryTitanAPL] Loading %d modules...", totalCount))
    
    for _, modulePath in ipairs(moduleLoadOrder) do
        if loadModule(modulePath) then
            loadedCount = loadedCount + 1
        end
    end
    
    print(string.format("[WarriorFuryTitanAPL] Loaded %d/%d modules successfully", loadedCount, totalCount))
    
    return loadedCount == totalCount
end

-- ============================================================================
-- 核心接口
-- ============================================================================

-- 初始化系统
function WarriorFuryTitanAPL.initialize()
    if initialized then
        print("[WarriorFuryTitanAPL] Already initialized")
        return true
    end
    
    print(string.format("[WarriorFuryTitanAPL] Initializing %s v%s", WarriorFuryTitanAPL.NAME, WarriorFuryTitanAPL.VERSION))
    
    -- 加载所有模块
    local modulesLoaded = loadAllModules()
    
    if not modulesLoaded then
        print("[WarriorFuryTitanAPL] Failed to load all required modules")
        return false
    end
    
    -- 初始化核心系统
    if modules.APLCore then
        local success = modules.APLCore.initialize()
        if not success then
            print("[WarriorFuryTitanAPL] Failed to initialize core system")
            return false
        end
    end
    
    -- 加载配置
    if modules.ConfigManager then
        local config = modules.ConfigManager.loadConfig()
        if not config then
            print("[WarriorFuryTitanAPL] Failed to load configuration")
            return false
        end
        
        if not config.enabled then
            print("[WarriorFuryTitanAPL] System is disabled in configuration")
            return false
        end
    end
    
    initialized = true
    print("[WarriorFuryTitanAPL] Initialization completed successfully")
    
    return true
end

-- 获取模块
function WarriorFuryTitanAPL.getModule(moduleName)
    return modules[moduleName]
end

-- 检查模块是否已加载
function WarriorFuryTitanAPL.hasModule(moduleName)
    return modules[moduleName] ~= nil
end

-- 获取所有已加载模块
function WarriorFuryTitanAPL.getAllModules()
    local moduleList = {}
    for name, module in pairs(modules) do
        table.insert(moduleList, {name = name, module = module})
    end
    return moduleList
end

-- 检查系统是否已初始化
function WarriorFuryTitanAPL.isInitialized()
    return initialized
end

-- ============================================================================
-- APL功能接口
-- ============================================================================

-- 解析APL文件
function WarriorFuryTitanAPL.parseAPL(aplContent, filename)
    if not initialized then
        print("[WarriorFuryTitanAPL] System not initialized")
        return nil
    end
    
    local parser = modules.APLParser
    if not parser then
        print("[WarriorFuryTitanAPL] APL Parser module not available")
        return nil
    end
    
    return parser.parseAPL(aplContent, filename)
end

-- 获取当前游戏状态
function WarriorFuryTitanAPL.getCurrentState()
    if not initialized then
        return nil
    end
    
    local monitor = modules.StateMonitor
    if not monitor then
        return nil
    end
    
    return monitor.getCurrentState()
end

-- 生成技能推荐
function WarriorFuryTitanAPL.generateRecommendation()
    if not initialized then
        return nil
    end
    
    local monitor = modules.StateMonitor
    local optimizer = modules.OutputOptimizer
    
    if not monitor or not optimizer then
        return nil
    end
    
    local gameState = monitor.getCurrentState()
    if not gameState then
        return nil
    end
    
    return optimizer.generateRecommendation(gameState)
end

-- 计算技能DPS
function WarriorFuryTitanAPL.calculateSkillDPS(skill)
    if not initialized then
        return 0
    end
    
    local monitor = modules.StateMonitor
    local optimizer = modules.OutputOptimizer
    
    if not monitor or not optimizer then
        return 0
    end
    
    local gameState = monitor.getCurrentState()
    if not gameState then
        return 0
    end
    
    return optimizer.calculateSkillDPS(skill, gameState)
end

-- ============================================================================
-- 配置管理接口
-- ============================================================================

-- 获取配置
function WarriorFuryTitanAPL.getConfig(path)
    if not initialized then
        return nil
    end
    
    local configManager = modules.ConfigManager
    if not configManager then
        return nil
    end
    
    if path then
        return configManager.getConfig(path)
    else
        return configManager.getCurrentConfig()
    end
end

-- 更新配置
function WarriorFuryTitanAPL.updateConfig(path, value)
    if not initialized then
        return false
    end
    
    local configManager = modules.ConfigManager
    if not configManager then
        return false
    end
    
    return configManager.updateConfig(path, value)
end

-- 保存配置
function WarriorFuryTitanAPL.saveConfig()
    if not initialized then
        return false
    end
    
    local configManager = modules.ConfigManager
    if not configManager then
        return false
    end
    
    return configManager.saveConfig()
end

-- ============================================================================
-- 调试和诊断接口
-- ============================================================================

-- 获取系统状态
function WarriorFuryTitanAPL.getSystemStatus()
    return {
        initialized = initialized,
        version = WarriorFuryTitanAPL.VERSION,
        modulesLoaded = #modules,
        modules = {}
    }
end

-- 获取错误日志
function WarriorFuryTitanAPL.getErrorLog()
    if not initialized or not modules.APLCore then
        return {}
    end
    
    return modules.APLCore.ErrorHandler.getErrorLog()
end

-- 清除错误日志
function WarriorFuryTitanAPL.clearErrorLog()
    if not initialized or not modules.APLCore then
        return false
    end
    
    modules.APLCore.ErrorHandler.clearErrorLog()
    return true
end

-- 运行诊断
function WarriorFuryTitanAPL.runDiagnostics()
    local diagnostics = {
        system = {
            initialized = initialized,
            version = WarriorFuryTitanAPL.VERSION
        },
        modules = {},
        config = {},
        errors = {}
    }
    
    -- 检查模块状态
    for name, module in pairs(modules) do
        diagnostics.modules[name] = {
            loaded = module ~= nil,
            type = type(module)
        }
    end
    
    -- 检查配置
    if modules.ConfigManager then
        local config = modules.ConfigManager.getCurrentConfig()
        diagnostics.config = {
            loaded = config ~= nil,
            enabled = config and config.enabled or false,
            summary = config and modules.ConfigManager.getConfigSummary() or nil
        }
    end
    
    -- 检查错误
    if modules.APLCore then
        local errors = modules.APLCore.ErrorHandler.getErrorLog()
        diagnostics.errors = {
            count = #errors,
            recent = errors[#errors] or nil
        }
    end
    
    return diagnostics
end

-- ============================================================================
-- 模块导出
-- ============================================================================

-- 全局注册（如果需要）
if _G then
    _G.WarriorFuryTitanAPL = WarriorFuryTitanAPL
end

return WarriorFuryTitanAPL