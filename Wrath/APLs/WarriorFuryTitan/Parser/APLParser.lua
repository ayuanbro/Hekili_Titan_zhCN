-- WarriorFuryTitan/Parser/APLParser.lua
-- APL解析器模块
-- **Feature: warrior-fury-titan-apl**
-- **Requirements: 7.1, 7.2, 7.3, 7.4, 7.5**

local APLCore = require("Wrath/APLs/WarriorFuryTitan/Core/APLCore")

local APLParser = {}

-- ============================================================================
-- 解析器状态和配置
-- ============================================================================

local parseErrors = {}
local currentLine = 0
local currentFile = ""

-- 清除解析错误
local function clearParseErrors()
    parseErrors = {}
    currentLine = 0
    currentFile = ""
end

-- 添加解析错误
local function addParseError(message, line, details)
    local error = {
        message = message,
        line = line or currentLine,
        file = currentFile,
        details = details or "",
        timestamp = time()
    }
    table.insert(parseErrors, error)
    
    -- 记录到核心错误处理器
    APLCore.ErrorHandler.logError(
        APLCore.ErrorTypes.PARSE_ERROR,
        APLCore.ErrorSeverity.MEDIUM,
        message,
        string.format("Line %d: %s", error.line, details or ""),
        "APLParser"
    )
end

-- ============================================================================
-- 词法分析器
-- ============================================================================

-- 词法单元类型
local TokenTypes = {
    ACTIONS = "ACTIONS",
    VARIABLE = "VARIABLE",
    SKILL = "SKILL",
    CONDITION = "CONDITION",
    OPERATOR = "OPERATOR",
    NUMBER = "NUMBER",
    STRING = "STRING",
    COMMENT = "COMMENT",
    NEWLINE = "NEWLINE",
    EOF = "EOF"
}

-- 词法单元结构
local function createToken(type, value, line, column)
    return {
        type = type,
        value = value,
        line = line or currentLine,
        column = column or 0
    }
end

-- 词法分析
local function tokenize(content)
    local tokens = {}
    local lines = {}
    
    -- 分割行
    for line in content:gmatch("[^\r\n]*") do
        table.insert(lines, line)
    end
    
    for lineNum, line in ipairs(lines) do
        currentLine = lineNum
        
        -- 跳过空行
        if line:match("^%s*$") then
            table.insert(tokens, createToken(TokenTypes.NEWLINE, "", lineNum))
            goto continue
        end
        
        -- 处理注释
        if line:match("^%s*##") then
            table.insert(tokens, createToken(TokenTypes.COMMENT, line, lineNum))
            goto continue
        end
        
        -- 处理变量定义
        if line:match("^variable,") then
            table.insert(tokens, createToken(TokenTypes.VARIABLE, line, lineNum))
            goto continue
        end
        
        -- 处理动作行
        if line:match("^actions") then
            table.insert(tokens, createToken(TokenTypes.ACTIONS, line, lineNum))
            goto continue
        end
        
        -- 其他行作为普通内容
        table.insert(tokens, createToken(TokenTypes.STRING, line, lineNum))
        
        ::continue::
    end
    
    table.insert(tokens, createToken(TokenTypes.EOF, "", #lines + 1))
    return tokens
end

-- ============================================================================
-- 语法分析器
-- ============================================================================

-- 解析动作行
local function parseActionLine(line)
    local action = {
        raw = line,
        listName = "default",
        skillName = nil,
        conditions = {},
        hasCondition = false,
        valid = false
    }
    
    -- 匹配 actions.listname+=/skill 或 actions+=/skill
    local listName, skill = line:match("^actions%.([%w_]+)%+=/([%w_]+)")
    if not listName then
        skill = line:match("^actions%+=/([%w_]+)")
        listName = "default"
    end
    
    if not skill then
        addParseError("Invalid action line format", currentLine, line)
        return action
    end
    
    action.listName = listName
    action.skillName = skill
    action.valid = true
    
    -- 解析条件
    local conditionStr = line:match(",if=(.+)$")
    if conditionStr then
        action.hasCondition = true
        action.conditionStr = conditionStr
        action.conditions = parseConditions(conditionStr)
    end
    
    return action
end

-- 解析条件表达式
function parseConditions(conditionStr)
    local conditions = {}
    
    -- 解析各种条件类型
    
    -- 姿态条件
    local stance = conditionStr:match("stance%.([%w_]+)")
    if stance then
        conditions.stance = stance
    end
    
    -- 怒气条件
    local rage = conditionStr:match("rage>=(%d+)")
    if rage then
        conditions.rageMin = tonumber(rage)
    end
    
    local rageMax = conditionStr:match("rage<=(%d+)")
    if rageMax then
        conditions.rageMax = tonumber(rageMax)
    end
    
    -- 血量条件
    local healthPercent = conditionStr:match("target%.health%.pct<=(%d+)")
    if healthPercent then
        conditions.targetHealthMax = tonumber(healthPercent)
    end
    
    -- Buff条件
    local buffActive = conditionStr:match("buff%.([%w_]+)")
    if buffActive then
        conditions.buffRequired = buffActive
    end
    
    -- Debuff条件
    local debuffActive = conditionStr:match("debuff%.([%w_]+)")
    if debuffActive then
        conditions.debuffRequired = debuffActive
    end
    
    -- 冷却条件
    local cooldownReady = conditionStr:match("cooldown%.([%w_]+)%.ready")
    if cooldownReady then
        conditions.cooldownReady = cooldownReady
    end
    
    -- 敌人数量条件
    local enemyCount = conditionStr:match("active_enemies>=(%d+)")
    if enemyCount then
        conditions.minEnemies = tonumber(enemyCount)
    end
    
    return conditions
end

-- 解析变量定义
local function parseVariableLine(line)
    local variable = {
        raw = line,
        name = nil,
        value = nil,
        condition = nil,
        valid = false
    }
    
    -- 匹配 variable,name=value,if=condition
    local name, value = line:match("^variable,name=([%w_]+),value=([^,]+)")
    if not name or not value then
        addParseError("Invalid variable definition", currentLine, line)
        return variable
    end
    
    variable.name = name
    variable.value = value
    variable.valid = true
    
    -- 解析条件
    local conditionStr = line:match(",if=(.+)$")
    if conditionStr then
        variable.condition = conditionStr
    end
    
    return variable
end

-- ============================================================================
-- 主解析函数
-- ============================================================================

-- 解析APL内容
function APLParser.parseAPL(aplContent, filename)
    clearParseErrors()
    currentFile = filename or "unknown"
    
    if not aplContent or aplContent == "" then
        addParseError("Empty APL content", 0, "No content to parse")
        return nil
    end
    
    local tokens = tokenize(aplContent)
    local rules = {
        precombat = {},
        combat = {},
        execute = {},
        variables = {},
        metadata = {
            filename = currentFile,
            parseTime = time(),
            lineCount = currentLine
        }
    }
    
    -- 解析词法单元
    for _, token in ipairs(tokens) do
        currentLine = token.line
        
        if token.type == TokenTypes.VARIABLE then
            local variable = parseVariableLine(token.value)
            if variable.valid then
                table.insert(rules.variables, variable)
            end
            
        elseif token.type == TokenTypes.ACTIONS then
            local action = parseActionLine(token.value)
            if action.valid then
                -- 根据列表名称分类
                if action.listName == "precombat" then
                    table.insert(rules.precombat, action)
                elseif action.listName == "execute" then
                    table.insert(rules.execute, action)
                else
                    table.insert(rules.combat, action)
                end
            end
        end
    end
    
    -- 验证解析结果
    if #parseErrors > 0 then
        addParseError("APL parsing completed with errors", 0, 
            string.format("%d errors found", #parseErrors))
    end
    
    return rules
end

-- 验证APL语法
function APLParser.validateSyntax(aplContent)
    clearParseErrors()
    
    if not aplContent or aplContent == "" then
        addParseError("Empty content", 0, "No content to validate")
        return false
    end
    
    local tokens = tokenize(aplContent)
    local hasActions = false
    local hasPrecombat = false
    
    for _, token in ipairs(tokens) do
        currentLine = token.line
        
        if token.type == TokenTypes.ACTIONS then
            hasActions = true
            
            -- 检查precombat部分
            if token.value:match("actions%.precombat") then
                hasPrecombat = true
            end
            
            -- 验证动作行格式
            local action = parseActionLine(token.value)
            if not action.valid then
                -- 错误已在parseActionLine中记录
            end
            
        elseif token.type == TokenTypes.VARIABLE then
            -- 验证变量定义
            local variable = parseVariableLine(token.value)
            if not variable.valid then
                -- 错误已在parseVariableLine中记录
            end
        end
    end
    
    -- 检查必需部分
    if not hasActions then
        addParseError("Missing actions section", 0, "APL must contain actions")
    end
    
    if not hasPrecombat then
        addParseError("Missing precombat section", 0, "APL should contain precombat actions")
    end
    
    return #parseErrors == 0
end

-- 获取解析错误
function APLParser.getParseErrors()
    return parseErrors
end

-- 获取最后一个错误
function APLParser.getLastError()
    return parseErrors[#parseErrors]
end

-- 检查是否有错误
function APLParser.hasErrors()
    return #parseErrors > 0
end

-- ============================================================================
-- 辅助函数
-- ============================================================================

-- 读取APL文件
function APLParser.readFile(filepath)
    local file = io.open(filepath, "r")
    if not file then
        addParseError("Cannot open file", 0, filepath)
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    
    return content
end

-- 解析APL文件
function APLParser.parseFile(filepath)
    local content = APLParser.readFile(filepath)
    if not content then
        return nil
    end
    
    return APLParser.parseAPL(content, filepath)
end

-- 获取统计信息
function APLParser.getStats(rules)
    if not rules then
        return nil
    end
    
    return {
        precombatActions = #rules.precombat,
        combatActions = #rules.combat,
        executeActions = #rules.execute,
        variables = #rules.variables,
        totalActions = #rules.precombat + #rules.combat + #rules.execute,
        parseErrors = #parseErrors
    }
end

-- ============================================================================
-- 模块注册
-- ============================================================================

-- 注册到核心系统
APLCore.registerModule("APLParser", APLParser)

return APLParser