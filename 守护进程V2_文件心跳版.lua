-- ============================================
-- 按键精灵安卓版 - 进程守护脚本 V2（文件心跳版）
-- 版本: 2.0.0
-- 功能: 通过文件心跳检测，自动重启，日志记录
-- ============================================

-- ==================== 配置区域 ====================
local CONFIG = {
    -- 主脚本配置
    MAIN_SCRIPT_NAME = "主脚本",           -- 主脚本名称
    MAIN_SCRIPT_PATH = "/sdcard/按键精灵/脚本/主脚本.lua",  -- 主脚本路径
    
    -- 心跳配置
    HEARTBEAT_FILE = "/sdcard/按键精灵/心跳/heartbeat.txt",  -- 心跳文件路径
    HEARTBEAT_INTERVAL = 5000,             -- 检测间隔（毫秒）
    HEARTBEAT_TIMEOUT = 15000,             -- 超时时间（毫秒）
    
    -- 重启配置
    RESTART_DELAY = 3000,                  -- 重启延迟
    MAX_RESTART_ATTEMPTS = 10,             -- 最大连续重启次数
    RESTART_RESET_TIME = 60000,            -- 重启计数重置时间
    
    -- 日志配置
    LOG_ENABLED = true,
    LOG_DIR = "/sdcard/按键精灵/日志/",
    LOG_MAX_DAYS = 7,                      -- 保留7天日志
    
    -- UI配置
    SHOW_TOAST = true,
    SHOW_FLOAT_STATUS = true,              -- 显示悬浮状态
}

-- ==================== 全局变量 ====================
local g_running = true
local g_restartCount = 0
local g_lastRestartTime = 0
local g_lastHeartbeatTime = 0
local g_status = "初始化"                  -- 当前状态
local g_startTime = mTime()               -- 守护启动时间

-- ==================== 日志模块 ====================

local Log = {
    file = nil,
    path = ""
}

function Log.init()
    if not CONFIG.LOG_ENABLED then return end
    
    -- 创建目录
    os.execute("mkdir -p " .. CONFIG.LOG_DIR)
    os.execute("mkdir -p " .. string.match(CONFIG.HEARTBEAT_FILE, "(.+)/"))
    
    -- 生成日志文件名（带时间戳）
    local dateStr = os.date("%Y%m%d_%H%M%S")
    Log.path = CONFIG.LOG_DIR .. "guardian_" .. dateStr .. ".txt"
    
    Log.file = io.open(Log.path, "a")
    if Log.file then
        Log.write("INFO", "=" .. string.rep("=", 40))
        Log.write("INFO", "守护进程 V2.0 启动")
        Log.write("INFO", "目标脚本: " .. CONFIG.MAIN_SCRIPT_NAME)
        Log.write("INFO", "心跳文件: " .. CONFIG.HEARTBEAT_FILE)
        Log.write("INFO", "超时设置: " .. CONFIG.HEARTBEAT_TIMEOUT .. "ms")
        Log.write("INFO", "=" .. string.rep("=", 40))
    end
end

function Log.write(level, msg)
    if not CONFIG.LOG_ENABLED or not Log.file then return end
    
    local line = string.format("[%s] [%s] %s", os.date("%H:%M:%S"), level, msg)
    Log.file:write(line .. "\n")
    Log.file:flush()
    print(line)
end

function Log.close()
    if Log.file then
        Log.write("INFO", "守护进程停止")
        Log.file:close()
        Log.file = nil
    end
end

-- ==================== 工具函数 ====================

local function showToast(msg)
    if CONFIG.SHOW_TOAST then
        toast(msg, 1500)
    end
    Log.write("TOAST", msg)
end

local function getTimeStr()
    return os.date("%H:%M:%S")
end

local function formatDuration(ms)
    local seconds = math.floor(ms / 1000)
    local mins = math.floor(seconds / 60)
    local hours = math.floor(mins / 60)
    
    if hours > 0 then
        return string.format("%d小时%d分", hours, mins % 60)
    elseif mins > 0 then
        return string.format("%d分%d秒", mins, seconds % 60)
    else
        return string.format("%d秒", seconds)
    end
end

-- ==================== 心跳检测 ====================

-- 读取心跳时间
local function readHeartbeat()
    local f = io.open(CONFIG.HEARTBEAT_FILE, "r")
    if f then
        local content = f:read("*all")
        f:close()
        local timestamp = tonumber(content)
        if timestamp and timestamp > 0 then
            return timestamp
        end
    end
    return 0
end

-- 检测主脚本状态
local function checkMainScript()
    local heartbeatTime = readHeartbeat()
    
    if heartbeatTime == 0 then
        -- 心跳文件不存在或为空
        if g_lastHeartbeatTime == 0 then
            -- 首次检测，等待中
            g_status = "等待心跳"
            return false, "等待首次心跳"
        else
            -- 之前有心跳，现在没了
            g_status = "心跳丢失"
            return false, "心跳文件失效"
        end
    end
    
    -- 更新最后心跳时间
    if heartbeatTime > g_lastHeartbeatTime then
        g_lastHeartbeatTime = heartbeatTime
    end
    
    -- 计算超时
    local currentTime = mTime()
    local elapsed = currentTime - g_lastHeartbeatTime
    
    if elapsed > CONFIG.HEARTBEAT_TIMEOUT then
        g_status = "心跳超时"
        return false, string.format("超时 %d ms", elapsed)
    end
    
    g_status = "运行正常"
    return true, "OK"
end

-- ==================== 脚本管理 ====================

-- 启动主脚本
local function startMainScript()
    Log.write("INFO", "正在启动主脚本...")
    g_status = "启动中"
    
    -- 重置心跳
    local f = io.open(CONFIG.HEARTBEAT_FILE, "w")
    if f then
        f:write(tostring(mTime()))
        f:close()
    end
    g_lastHeartbeatTime = mTime()
    
    -- 延迟一下再启动
    delay(1000)
    
    -- 启动主脚本（使用按键精灵的runScript或loadfile）
    -- 方式1：如果按键精灵支持
    -- runScript(CONFIG.MAIN_SCRIPT_PATH)
    
    -- 方式2：加载并执行
    local ok, result = pcall(function()
        local mainFunc = loadfile(CONFIG.MAIN_SCRIPT_PATH)
        if mainFunc then
            -- 在新线程中执行（如果支持）
            thread(mainFunc)
            return true
        else
            return false, "无法加载脚本"
        end
    end)
    
    if ok and result ~= false then
        Log.write("INFO", "主脚本启动成功")
        showToast("主脚本已启动")
        return true
    else
        local errMsg = result or "未知错误"
        Log.write("ERROR", "启动失败: " .. errMsg)
        showToast("启动失败: " .. errMsg)
        return false
    end
end

-- 重启主脚本
local function restartMainScript()
    local now = mTime()
    
    -- 检查重启频率
    if now - g_lastRestartTime > CONFIG.RESTART_RESET_TIME then
        g_restartCount = 0
    end
    
    g_restartCount = g_restartCount + 1
    g_lastRestartTime = now
    
    -- 检查最大重启次数
    if g_restartCount > CONFIG.MAX_RESTART_ATTEMPTS then
        Log.write("FATAL", "重启次数超过限制，停止守护")
        showToast("守护停止：重启次数过多！")
        g_running = false
        return false
    end
    
    Log.write("WARN", string.format("第 %d 次重启主脚本", g_restartCount))
    showToast(string.format("第 %d 次重启...", g_restartCount))
    
    -- 延迟后重启
    delay(CONFIG.RESTART_DELAY)
    
    return startMainScript()
end

-- ==================== 悬浮窗状态 ====================

local FloatWindow = {
    fw = nil,
    running = false
}

function FloatWindow.init()
    if not CONFIG.SHOW_FLOAT_STATUS then return end
    
    -- 检查是否有悬浮窗权限
    require "悬浮窗"
    FloatWindow.fw = 悬浮窗.创建()
    FloatWindow.fw:设置标题("👁️ 守护进程")
    FloatWindow.fw:设置位置(0, 200)  -- 左上角偏下
    FloatWindow.running = true
end

function FloatWindow.update()
    if not CONFIG.SHOW_FLOAT_STATUS or not FloatWindow.fw then return end
    
    local runTime = mTime() - g_startTime
    local statusIcon = g_status == "运行正常" and "✅" or "⚠️"
    
    local text = string.format(
        "%s %s\n运行: %s\n重启: %d次\n检测: %ds",
        statusIcon,
        g_status,
        formatDuration(runTime),
        g_restartCount,
        math.floor((mTime() - g_lastHeartbeatTime) / 1000)
    )
    
    FloatWindow.fw:设置文本(text)
    if not FloatWindow.fw:是否显示() then
        FloatWindow.fw:显示()
    end
end

function FloatWindow.hide()
    if FloatWindow.fw then
        FloatWindow.fw:隐藏()
    end
    FloatWindow.running = false
end

-- ==================== 主循环 ====================

local function mainLoop()
    Log.init()
    FloatWindow.init()
    
    Log.write("INFO", "守护循环启动")
    showToast("守护进程启动")
    
    -- 首次启动
    startMainScript()
    
    -- 主循环
    local checkCount = 0
    while g_running do
        checkCount = checkCount + 1
        
        -- 检测主脚本
        local isAlive, msg = checkMainScript()
        
        if checkCount % 12 == 0 then  -- 每60秒记录一次正常日志
            Log.write("INFO", string.format("状态: %s, %s", g_status, msg))
        end
        
        -- 异常时重启
        if not isAlive and g_lastHeartbeatTime > 0 then
            Log.write("WARN", string.format("检测到异常: %s", msg))
            restartMainScript()
        end
        
        -- 更新悬浮窗
        if checkCount % 2 == 0 then  -- 每10秒更新
            FloatWindow.update()
        end
        
        -- 等待下次检测
        delay(CONFIG.HEARTBEAT_INTERVAL)
    end
    
    FloatWindow.hide()
    Log.close()
    showToast("守护已停止")
end

-- ==================== 入口 ====================

-- 启动
mainLoop()
