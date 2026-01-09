-- HunterBeastMasteryTitan.test.lua
-- Property-Based Tests for BM Hunter Titan APL
-- **Feature: bm-hunter-titan-apl**
-- **Validates: Requirements 1.5, 2.1, 2.3, 2.4, 4.1, 6.1, 6.3, 6.4**

-- ============================================================================
-- 测试框架
-- ============================================================================

local testResults = {
    passed = 0,
    failed = 0,
    errors = {}
}

-- 断言函数
local function assert_true(condition, message)
    if not condition then
        error(message or "Assertion failed: expected true")
    end
end

local function assert_equal(expected, actual, message)
    if expected ~= actual then
        error(message or string.format("Assertion failed: expected %s, got %s", tostring(expected), tostring(actual)))
    end
end

local function assert_not_nil(value, message)
    if value == nil then
        error(message or "Assertion failed: expected non-nil value")
    end
end

local function assert_greater_than(a, b, message)
    if not (a > b) then
        error(message or string.format("Assertion failed: expected %s > %s", tostring(a), tostring(b)))
    end
end

local function assert_less_than_or_equal(a, b, message)
    if not (a <= b) then
        error(message or string.format("Assertion failed: expected %s <= %s", tostring(a), tostring(b)))
    end
end

-- 随机数生成
local seed = os.time()
math.randomseed(seed)

-- ============================================================================
-- APL 文件解析器
-- ============================================================================

local APLParser = {}

-- 读取APL文件内容
function APLParser.ReadFile(filepath)
    local file = io.open(filepath, "r")
    if not file then
        return nil, "Cannot open file: " .. filepath
    end
    local content = file:read("*all")
    file:close()
    return content
end

-- 解析APL行
function APLParser.ParseLines(content)
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    return lines
end

-- 检查是否是动作行
function APLParser.IsActionLine(line)
    return line:match("^actions") ~= nil
end

-- 检查是否是注释行
function APLParser.IsCommentLine(line)
    return line:match("^##") ~= nil
end

-- 解析动作行
function APLParser.ParseActionLine(line)
    local result = {
        raw = line,
        listName = nil,
        skillName = nil,
        conditions = {},
        hasCondition = false
    }
    
    -- 匹配 actions.listname+=/skill 或 actions+=/skill
    local listName, skill = line:match("^actions%.([%w_]+)%+=/([%w_]+)")
    if not listName then
        skill = line:match("^actions%+=/([%w_]+)")
        listName = "default"
    end
    
    result.listName = listName
    result.skillName = skill
    
    -- 解析条件
    local conditionStr = line:match(",if=(.+)$")
    if conditionStr then
        result.hasCondition = true
        result.conditionStr = conditionStr
        
        -- 解析 active_enemies 条件
        local enemyThreshold = conditionStr:match("active_enemies>(%d+)")
        if enemyThreshold then
            result.conditions.activeEnemies = tonumber(enemyThreshold)
        end
        
        -- 解析 eagle_count 条件
        local eagleCount = conditionStr:match("buff%.eagle_count<(%d+)")
        if eagleCount then
            result.conditions.eagleCountMax = tonumber(eagleCount)
        end
    end
    
    return result
end

-- 获取所有动作行
function APLParser.GetAllActions(content)
    local lines = APLParser.ParseLines(content)
    local actions = {}
    
    for _, line in ipairs(lines) do
        if APLParser.IsActionLine(line) then
            local parsed = APLParser.ParseActionLine(line)
            if parsed.skillName then
                table.insert(actions, parsed)
            end
        end
    end
    
    return actions
end

-- 获取指定列表的动作
function APLParser.GetActionsForList(content, listName)
    local allActions = APLParser.GetAllActions(content)
    local filtered = {}
    
    for _, action in ipairs(allActions) do
        if action.listName == listName then
            table.insert(filtered, action)
        end
    end
    
    return filtered
end

-- 检查是否包含中文注释
function APLParser.HasChineseComments(content)
    -- 检查是否有中文字符
    return content:match("[\228-\233][\128-\191][\128-\191]") ~= nil
end

-- 获取技能在列表中的位置
function APLParser.GetSkillPosition(actions, skillName)
    for i, action in ipairs(actions) do
        if action.skillName == skillName then
            return i
        end
    end
    return nil
end

-- ============================================================================
-- Property-Based Test Runner
-- ============================================================================

local function runPropertyTest(name, iterations, testFn)
    print(string.format("\n[TEST] %s (%d iterations)", name, iterations))
    local passed = 0
    local failed = 0
    local failingExample = nil
    
    for i = 1, iterations do
        local ok, err = pcall(testFn, i)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            if not failingExample then
                failingExample = {iteration = i, error = err}
            end
        end
    end
    
    if failed == 0 then
        print(string.format("  PASSED: %d/%d iterations", passed, iterations))
        testResults.passed = testResults.passed + 1
        return true, nil
    else
        print(string.format("  FAILED: %d/%d iterations failed", failed, iterations))
        print(string.format("  First failing example (iteration %d): %s", failingExample.iteration, failingExample.error))
        testResults.failed = testResults.failed + 1
        table.insert(testResults.errors, {name = name, example = failingExample})
        return false, failingExample
    end
end

-- ============================================================================
-- 加载APL文件
-- ============================================================================

local APL_PATH = "Wrath/APLs/HunterBeastMasteryTitan.simc"
local aplContent, loadError = APLParser.ReadFile(APL_PATH)

if not aplContent then
    print("ERROR: Cannot load APL file: " .. (loadError or "unknown error"))
    os.exit(1)
end

local allActions = APLParser.GetAllActions(aplContent)
local defaultActions = APLParser.GetActionsForList(aplContent, "default")
local aoeActions = APLParser.GetActionsForList(aplContent, "aoe")


-- ============================================================================
-- Property 3: APL格式正确性
-- *For any* 生成的APL文件，所有动作行应遵循simc语法格式
-- （actions+=/skill_name,if=condition），并包含中文注释。
-- **Validates: Requirements 6.1, 6.3, 6.4**
-- ============================================================================

local function test_property3_apl_format_correctness()
    
    -- Property 3.1: 所有动作行遵循simc语法格式
    runPropertyTest("Property 3.1: 所有动作行遵循simc语法格式", 100, function(iteration)
        -- 随机选择一个动作行进行验证
        local actionIndex = math.random(1, #allActions)
        local action = allActions[actionIndex]
        
        -- 验证动作行格式
        assert_not_nil(action.skillName, "Action should have a skill name: " .. action.raw)
        assert_not_nil(action.listName, "Action should have a list name: " .. action.raw)
        
        -- 验证原始行格式匹配 actions+=/skill 或 actions.list+=/skill
        local validFormat = action.raw:match("^actions[%.%w_]*%+=/[%w_]+") ~= nil
        assert_true(validFormat, "Action line should match simc format: " .. action.raw)
    end)
    
    -- Property 3.2: 条件表达式格式正确
    runPropertyTest("Property 3.2: 条件表达式格式正确", 100, function(iteration)
        -- 随机选择一个有条件的动作行
        local actionsWithConditions = {}
        for _, action in ipairs(allActions) do
            if action.hasCondition then
                table.insert(actionsWithConditions, action)
            end
        end
        
        if #actionsWithConditions > 0 then
            local actionIndex = math.random(1, #actionsWithConditions)
            local action = actionsWithConditions[actionIndex]
            
            -- 验证条件格式 (if=...)
            local hasIfClause = action.raw:match(",if=") ~= nil
            assert_true(hasIfClause, "Conditional action should have if= clause: " .. action.raw)
            
            -- 验证条件不为空
            assert_not_nil(action.conditionStr, "Condition string should not be nil: " .. action.raw)
            assert_true(#action.conditionStr > 0, "Condition string should not be empty: " .. action.raw)
        end
    end)
    
    -- Property 3.3: APL文件包含中文注释
    runPropertyTest("Property 3.3: APL文件包含中文注释", 100, function(iteration)
        -- 验证文件包含中文注释
        local hasChineseComments = APLParser.HasChineseComments(aplContent)
        assert_true(hasChineseComments, "APL file should contain Chinese comments")
    end)
    
    -- Property 3.4: APL文件包含precombat和actions部分
    runPropertyTest("Property 3.4: APL文件包含precombat和actions部分", 100, function(iteration)
        -- 验证precombat部分存在
        local hasPrecombat = aplContent:match("actions%.precombat") ~= nil
        assert_true(hasPrecombat, "APL file should contain precombat section")
        
        -- 验证主actions部分存在
        local hasActions = aplContent:match("actions%+=/") ~= nil
        assert_true(hasActions, "APL file should contain main actions section")
    end)
    
    -- Property 3.5: 所有技能名称有效（非空且只包含字母数字下划线）
    runPropertyTest("Property 3.5: 所有技能名称有效", 100, function(iteration)
        local actionIndex = math.random(1, #allActions)
        local action = allActions[actionIndex]
        
        -- 验证技能名称格式
        local validSkillName = action.skillName:match("^[%w_]+$") ~= nil
        assert_true(validSkillName, "Skill name should only contain alphanumeric and underscore: " .. action.skillName)
    end)
end

-- ============================================================================
-- Property 1: 技能优先级顺序正确性
-- *For any* 单体APL执行序列，在爆发期内，杀戮命令的优先级应始终高于奥术射击，
-- 奥术射击的优先级应始终高于稳固射击。
-- **Validates: Requirements 1.5**
-- ============================================================================

local function test_property1_skill_priority_order()
    
    -- Property 1.1: 杀戮命令优先级高于奥术射击
    runPropertyTest("Property 1.1: 杀戮命令优先级高于奥术射击", 100, function(iteration)
        -- 在默认动作列表中查找位置
        local killCommandPos = APLParser.GetSkillPosition(defaultActions, "kill_command")
        local arcaneShotPos = APLParser.GetSkillPosition(defaultActions, "arcane_shot")
        
        assert_not_nil(killCommandPos, "kill_command should exist in default actions")
        assert_not_nil(arcaneShotPos, "arcane_shot should exist in default actions")
        
        -- 杀戮命令应该在奥术射击之前
        assert_less_than_or_equal(killCommandPos, arcaneShotPos, 
            string.format("kill_command (pos %d) should be before arcane_shot (pos %d)", 
                killCommandPos, arcaneShotPos))
    end)
    
    -- Property 1.2: 奥术射击优先级高于稳固射击
    runPropertyTest("Property 1.2: 奥术射击优先级高于稳固射击", 100, function(iteration)
        -- 在默认动作列表中查找位置
        local arcaneShotPos = APLParser.GetSkillPosition(defaultActions, "arcane_shot")
        local steadyShotPos = APLParser.GetSkillPosition(defaultActions, "steady_shot")
        
        assert_not_nil(arcaneShotPos, "arcane_shot should exist in default actions")
        assert_not_nil(steadyShotPos, "steady_shot should exist in default actions")
        
        -- 奥术射击应该在稳固射击之前
        assert_less_than_or_equal(arcaneShotPos, steadyShotPos, 
            string.format("arcane_shot (pos %d) should be before steady_shot (pos %d)", 
                arcaneShotPos, steadyShotPos))
    end)
    
    -- Property 1.3: 核心循环顺序完整 (杀戮命令 > 奥术射击 > 稳固射击)
    runPropertyTest("Property 1.3: 核心循环顺序完整", 100, function(iteration)
        local killCommandPos = APLParser.GetSkillPosition(defaultActions, "kill_command")
        local arcaneShotPos = APLParser.GetSkillPosition(defaultActions, "arcane_shot")
        local steadyShotPos = APLParser.GetSkillPosition(defaultActions, "steady_shot")
        
        assert_not_nil(killCommandPos, "kill_command should exist")
        assert_not_nil(arcaneShotPos, "arcane_shot should exist")
        assert_not_nil(steadyShotPos, "steady_shot should exist")
        
        -- 验证完整顺序
        assert_less_than_or_equal(killCommandPos, arcaneShotPos, "kill_command should be before arcane_shot")
        assert_less_than_or_equal(arcaneShotPos, steadyShotPos, "arcane_shot should be before steady_shot")
    end)
end

-- ============================================================================
-- Property 2: 雄鹰数量限制
-- *For any* APL状态，雄鹰射击只能在当前雄鹰数量少于2时施放。
-- **Validates: Requirements 4.1**
-- ============================================================================

local function test_property2_eagle_count_limit()
    
    -- Property 2.1: 所有雄鹰射击都有数量限制条件
    runPropertyTest("Property 2.1: 所有雄鹰射击都有数量限制条件", 100, function(iteration)
        -- 查找所有雄鹰射击动作
        local eagleShotActions = {}
        for _, action in ipairs(allActions) do
            if action.skillName == "eagle_shot" then
                table.insert(eagleShotActions, action)
            end
        end
        
        assert_true(#eagleShotActions > 0, "APL should contain eagle_shot actions")
        
        -- 随机选择一个雄鹰射击动作验证
        local actionIndex = math.random(1, #eagleShotActions)
        local action = eagleShotActions[actionIndex]
        
        -- 验证包含 eagle_count<2 条件
        local hasEagleCountCondition = action.raw:match("buff%.eagle_count<2") ~= nil
        assert_true(hasEagleCountCondition, 
            "eagle_shot should have buff.eagle_count<2 condition: " .. action.raw)
    end)
    
    -- Property 2.2: 雄鹰数量限制为2
    runPropertyTest("Property 2.2: 雄鹰数量限制为2", 100, function(iteration)
        -- 查找所有雄鹰射击动作
        for _, action in ipairs(allActions) do
            if action.skillName == "eagle_shot" then
                -- 验证限制值为2
                if action.conditions.eagleCountMax then
                    assert_equal(2, action.conditions.eagleCountMax, 
                        "Eagle count limit should be 2: " .. action.raw)
                end
            end
        end
    end)
end

-- ============================================================================
-- Property 4: AOE阈值递增
-- *For any* AOE APL，技能的敌人数量阈值应递增：
-- 豪猪(>1) ≤ 乱射(>2) ≤ 齐射(>3)。
-- **Validates: Requirements 2.1, 2.3, 2.4**
-- ============================================================================

local function test_property4_aoe_threshold_increasing()
    
    -- Property 4.1: AOE技能存在于AOE列表中
    runPropertyTest("Property 4.1: AOE技能存在于AOE列表中", 100, function(iteration)
        -- 验证AOE列表包含必要技能
        local hasMultishot = false
        local hasVolley = false
        local hasExplosiveTrap = false
        
        for _, action in ipairs(aoeActions) do
            if action.skillName == "multishot" then hasMultishot = true end
            if action.skillName == "volley" then hasVolley = true end
            if action.skillName == "explosive_trap" then hasExplosiveTrap = true end
        end
        
        assert_true(hasMultishot, "AOE list should contain multishot")
        assert_true(hasVolley, "AOE list should contain volley")
        assert_true(hasExplosiveTrap, "AOE list should contain explosive_trap")
    end)
    
    -- Property 4.2: 乱射阈值为>2
    runPropertyTest("Property 4.2: 乱射阈值为>2", 100, function(iteration)
        for _, action in ipairs(aoeActions) do
            if action.skillName == "multishot" then
                local threshold = action.conditions.activeEnemies
                assert_not_nil(threshold, "multishot should have active_enemies condition")
                assert_equal(2, threshold, "multishot threshold should be >2")
            end
        end
    end)
    
    -- Property 4.3: 齐射阈值为>3
    runPropertyTest("Property 4.3: 齐射阈值为>3", 100, function(iteration)
        for _, action in ipairs(aoeActions) do
            if action.skillName == "volley" then
                local threshold = action.conditions.activeEnemies
                assert_not_nil(threshold, "volley should have active_enemies condition")
                assert_equal(3, threshold, "volley threshold should be >3")
            end
        end
    end)
    
    -- Property 4.4: 爆炸陷阱阈值为>2
    runPropertyTest("Property 4.4: 爆炸陷阱阈值为>2", 100, function(iteration)
        for _, action in ipairs(aoeActions) do
            if action.skillName == "explosive_trap" then
                local threshold = action.conditions.activeEnemies
                assert_not_nil(threshold, "explosive_trap should have active_enemies condition")
                assert_equal(2, threshold, "explosive_trap threshold should be >2")
            end
        end
    end)
    
    -- Property 4.5: AOE阈值递增关系
    runPropertyTest("Property 4.5: AOE阈值递增关系", 100, function(iteration)
        local multishotThreshold = nil
        local volleyThreshold = nil
        
        for _, action in ipairs(aoeActions) do
            if action.skillName == "multishot" and action.conditions.activeEnemies then
                multishotThreshold = action.conditions.activeEnemies
            end
            if action.skillName == "volley" and action.conditions.activeEnemies then
                volleyThreshold = action.conditions.activeEnemies
            end
        end
        
        assert_not_nil(multishotThreshold, "multishot should have threshold")
        assert_not_nil(volleyThreshold, "volley should have threshold")
        
        -- 乱射阈值 <= 齐射阈值
        assert_less_than_or_equal(multishotThreshold, volleyThreshold, 
            string.format("multishot threshold (%d) should be <= volley threshold (%d)", 
                multishotThreshold, volleyThreshold))
    end)
end

-- ============================================================================
-- 运行所有测试
-- ============================================================================

print("=" .. string.rep("=", 60))
print("BM Hunter Titan APL Property-Based Tests")
print("**Feature: bm-hunter-titan-apl**")
print("Seed: " .. seed)
print("=" .. string.rep("=", 60))

print("\n--- Property 3: APL格式正确性 ---")
print("**Validates: Requirements 6.1, 6.3, 6.4**")
test_property3_apl_format_correctness()

print("\n--- Property 1: 技能优先级顺序正确性 ---")
print("**Validates: Requirements 1.5**")
test_property1_skill_priority_order()

print("\n--- Property 2: 雄鹰数量限制 ---")
print("**Validates: Requirements 4.1**")
test_property2_eagle_count_limit()

print("\n--- Property 4: AOE阈值递增 ---")
print("**Validates: Requirements 2.1, 2.3, 2.4**")
test_property4_aoe_threshold_increasing()

print("\n" .. string.rep("=", 60))
print(string.format("SUMMARY: %d passed, %d failed", testResults.passed, testResults.failed))
print(string.rep("=", 60))

if testResults.failed > 0 then
    print("\nFailing tests:")
    for _, err in ipairs(testResults.errors) do
        print(string.format("  - %s (iteration %d): %s", err.name, err.example.iteration, err.example.error))
    end
    os.exit(1)
else
    print("\nAll property tests passed!")
    os.exit(0)
end
