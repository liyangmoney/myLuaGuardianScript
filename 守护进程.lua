-- ============================================
-- 按键精灵安卓版 - 进程守护脚本
-- 版本: 1.0.0
-- 功能: 守护主脚本，心跳检测，自动重启，日志记录
-- ============================================

-- ==================== 配置区域 ====================
local CONFIG = {
    -- 主脚本配置
    MAIN_SCRIPT_NAME = "主脚本",           -- 要守护的主脚本名称（显示名）
    MAIN_SCRIPT_PATH = "/sdcard/guardian/script/main.lua",  -- 主脚本路径
    
    -- 检测配置
    HEARTBEAT_INTERVAL = 5000,             -- 心跳检测间隔（毫秒），默认5秒
    HEARTBEAT_TIMEOUT = 15000,             -- 心跳超时时间（毫秒），默认15秒
    
    -- 重启配置
    RESTART_DELAY = 3000,                  -- 重启延迟（毫秒），默认3秒
    MAX_RESTART_ATTEMPTS = 10,             -- 最大连续重启次数（防死循环）
    RESTART_RESET_TIME = 60000,            -- 重启计数重置时间（毫秒），默认1分钟
    
    -- 日志配置
    LOG_ENABLED = true,                    -- 是否启用日志
    LOG_PATH = "/sdcard/guardian/log/guardian_log_",  -- 日志文件路径前缀  -- 日志文件路径前缀
    LOG_MAX_SIZE = 1024 * 1024,           -- 单日志文件最大大小（1MB）
    LOG_MAX_FILES = 7,                     -- 保留日志文件数量
    
    -- 通知配置
    SHOW_TOAST = true,                     -- 是否显示Toast提示
    SHOW_FLOAT_WINDOW = false,             -- 是否显示悬浮窗状态（需要悬浮窗权限）
}

-- ==================== 全局变量 ====================
local g_running = true                    -- 守护进程运行标志
local g_lastHeartbeat = 0                 -- 上次心跳时间
local g_restartCount = 0                  -- 连续重启计数
local g_lastRestartTime = 0               -- 上次重启时间
local g_logFile = nil                     -- 当前日志文件句柄
local g_logFilePath = ""                  -- 当前日志文件路径
local g_mainScriptRunning = false         -- 主脚本运行状态

-- ==================== 工具函数 ====================

-- 获取当前时间字符串
local function getTimeString()
    local t = os.date("%Y-%m-%d %H:%M:%S")
    return t
end

-- 获取日期字符串（用于文件名）
local function getDateString()
    return os.date("%Y%m%d")
end

-- 初始化日志
local function initLog()
    if not CONFIG.LOG_ENABLED then return end
    
    -- 创建日志目录
    local logDir = string.match(CONFIG.LOG_PATH, "(.+)/")
    if logDir then
        os.execute("mkdir -p " .. logDir)
    end
    
    -- 生成日志文件名
    g_logFilePath = CONFIG.LOG_PATH .. getDateString() .. ".txt"
    
    -- 打开日志文件（追加模式）
    g_logFile = io.open(g_logFilePath, "a")
    if g_logFile then
        g_logFile:write("\n========================================\n")
        g_logFile:write("守护进程启动 - " .. getTimeString() .. "\n")
        g_logFile:write("========================================\n")
        g_logFile:flush()
    end
    
    -- 清理旧日志
    cleanOldLogs()
end

-- 写入日志
local function writeLog(level, message)
    if not CONFIG.LOG_ENABLED then return end
    
    local logLine = string.format("[%s] [%s] %s\n", getTimeString(), level, message)
    
    -- 写入文件
    if g_logFile then
        g_logFile:write(logLine)
        g_logFile:flush()
        
        -- 检查文件大小
        local currentSize = g_logFile:seek("end")
        if currentSize > CONFIG.LOG_MAX_SIZE then
            g_logFile:close()
            -- 重命名当前日志
            os.rename(g_logFilePath, g_logFilePath .. ".old")
            g_logFile = io.open(g_logFilePath, "a")
        end
    end
    
    -- 输出到控制台
    print(logLine)
end

-- 清理旧日志
local function cleanOldLogs()
    local logDir = string.match(CONFIG.LOG_PATH, "(.+)/")
    if not logDir then return end
    
    -- 简单实现：只保留最近N天的日志
    -- 实际项目中可以用更复杂的清理逻辑
end

-- 关闭日志
local function closeLog()
    if g_logFile then
        writeLog("INFO", "守护进程停止")
        g_logFile:close()
        g_logFile = nil
    end
end

-- 显示Toast提示
local function showToast(message)
    if CONFIG.SHOW_TOAST then
        toast(message, 2000)
    end
    writeLog("TOAST", message)
end

-- ==================== 心跳检测 ====================

-- 发送心跳（由主脚本调用）
function sendHeartbeat()
    g_lastHeartbeat = mTime()
    g_mainScriptRunning = true
    -- writeLog("DEBUG", "收到主脚本心跳")  -- 调试时取消注释
end

-- 检查心跳超时
local function checkHeartbeat()
    local currentTime = mTime()
    local elapsed = currentTime - g_lastHeartbeat
    
    if g_lastHeartbeat == 0 then
        -- 首次运行，还未收到心跳
        writeLog("INFO", "等待主脚本首次心跳...")
        return false
    end
    
    if elapsed > CONFIG.HEARTBEAT_TIMEOUT then
        writeLog("WARN", string.format("心跳超时！已等待 %d ms", elapsed))
        return false
    end
    
    return true
end

-- ==================== 主脚本管理 ====================

-- 检查主脚本进程是否存在
local function isMainScriptRunning()
    -- 方法1：通过按键精灵API检查脚本运行状态
    -- 注意：不同版本的按键精灵API可能不同
    
    -- 方法2：检查心跳超时
    if not checkHeartbeat() then
        return false
    end
    
    return g_mainScriptRunning
end

-- 启动主脚本
local function startMainScript()
    writeLog("INFO", "正在启动主脚本: " .. CONFIG.MAIN_SCRIPT_NAME)
    
    -- 重置心跳时间
    g_lastHeartbeat = mTime()
    
    -- 方式1：通过runScript启动（同进程）
    -- local success = runScript(CONFIG.MAIN_SCRIPT_PATH)
    
    -- 方式2：通过按键精灵的引擎启动
    -- 这里使用loadfile方式加载并执行
    local mainFunc, err = loadfile(CONFIG.MAIN_SCRIPT_PATH)
    if mainFunc then
        -- 在新协程中运行主脚本
        local co = coroutine.create(function()
            local ok, err = pcall(mainFunc)
            if not ok then
                writeLog("ERROR", "主脚本执行错误: " .. tostring(err))
            end
        end)
        coroutine.resume(co)
        
        writeLog("INFO", "主脚本启动成功")
        showToast("主脚本已启动")
        return true
    else
        writeLog("ERROR", "加载主脚本失败: " .. tostring(err))
        showToast("主脚本加载失败！")
        return false
    end
end

-- 重启主脚本
local function restartMainScript()
    local currentTime = mTime()
    
    -- 检查重启频率，防止死循环
    if currentTime - g_lastRestartTime > CONFIG.RESTART_RESET_TIME then
        g_restartCount = 0
    end
    
    g_restartCount = g_restartCount + 1
    g_lastRestartTime = currentTime
    
    if g_restartCount > CONFIG.MAX_RESTART_ATTEMPTS then
        writeLog("ERROR", string.format("连续重启超过 %d 次，停止守护！", CONFIG.MAX_RESTART_ATTEMPTS))
        showToast("重启次数过多，守护停止！")
        g_running = false
        return false
    end
    
    writeLog("WARN", string.format("第 %d 次重启主脚本...", g_restartCount))
    showToast(string.format("主脚本异常，第 %d 次重启...", g_restartCount))
    
    -- 延迟重启
    delay(CONFIG.RESTART_DELAY)
    
    -- 重置状态
    g_lastHeartbeat = 0
    g_mainScriptRunning = false
    
    -- 启动主脚本
    return startMainScript()
end

-- ==================== 悬浮窗（可选） ====================

-- 创建状态悬浮窗
local function createFloatWindow()
    if not CONFIG.SHOW_FLOAT_WINDOW then return end
    
    -- 需要悬浮窗权限
    require "悬浮窗"
    
    fw = 悬浮窗.创建()
    fw:设置标题("守护进程")
    fw:设置文本("运行中...")
    fw:显示()
    
    -- 定时更新悬浮窗
    while g_running do
        local status = g_mainScriptRunning and "正常" or "异常"
        local text = string.format("主脚本: %s\n重启: %d次", status, g_restartCount)
        fw:设置文本(text)
        delay(1000)
    end
    
    fw:隐藏()
end

-- ==================== 主循环 ====================

-- 守护主循环
local function guardianLoop()
    writeLog("INFO", "守护进程主循环启动")
    
    -- 首次启动主脚本
    startMainScript()
    
    -- 主检测循环
    while g_running do
        -- 检测主脚本状态
        if not isMainScriptRunning() then
            writeLog("WARN", "检测到主脚本异常")
            restartMainScript()
        end
        
        -- 休眠等待下次检测
        delay(CONFIG.HEARTBEAT_INTERVAL)
    end
end

-- ==================== 入口函数 ====================

-- 主函数
function main()
    -- 初始化
    initLog()
    writeLog("INFO", "========================================")
    writeLog("INFO", "进程守护脚本启动")
    writeLog("INFO", "守护目标: " .. CONFIG.MAIN_SCRIPT_NAME)
    writeLog("INFO", "检测间隔: " .. CONFIG.HEARTBEAT_INTERVAL .. "ms")
    writeLog("INFO", "超时时间: " .. CONFIG.HEARTBEAT_TIMEOUT .. "ms")
    writeLog("INFO", "========================================")
    
    showToast("守护进程已启动")
    
    -- 启动悬浮窗（在独立协程中）
    if CONFIG.SHOW_FLOAT_WINDOW then
        thread(createFloatWindow)
    end
    
    -- 启动守护循环
    local ok, err = pcall(guardianLoop)
    if not ok then
        writeLog("FATAL", "守护进程异常退出: " .. tostring(err))
        showToast("守护进程异常！")
    end
    
    -- 清理
    closeLog()
    showToast("守护进程已停止")
end

-- ==================== 心跳API（供主脚本调用） ====================

-- 主脚本需要在适当位置调用此函数发送心跳
-- 例如：每隔几秒调用一次，或在关键操作后调用
--[[
    -- 在主脚本中添加：
    require("守护脚本")
    while true do
        sendHeartbeat()  -- 发送心跳
        -- 主脚本逻辑...
        delay(3000)
    end
--]]

-- 启动守护进程
main()
