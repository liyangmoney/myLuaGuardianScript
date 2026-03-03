-- ============================================
-- 按键精灵移动版 - 进程守护插件
-- 文件名: GuardianPlugin.lua
-- 版本: 3.2.0
-- 描述: 无界面版进程守护插件，防重复启动
-- 
-- 使用方式:
-- 1. 将此文件放入按键精灵安装目录的 Plugin 文件夹
-- 2. 在脚本中使用: Import "GuardianPlugin"
-- 3. 调用: GuardianPlugin.StartGuardian()
-- ============================================

-- 定义插件命名空间
QMPlugin = {}

-- ==================== 插件配置 ====================
local CONFIG = {
    -- 主脚本配置
    MAIN_SCRIPT_NAME = "MainScript",
    MAIN_SCRIPT_PATH = "/sdcard/guardian/script/MainScript.lua",
    
    -- 心跳配置
    HEARTBEAT_FILE = "/sdcard/guardian/heartbeat.txt",
    HEARTBEAT_INTERVAL = 5000,      -- 检测间隔 5秒
    HEARTBEAT_TIMEOUT = 15000,      -- 超时时间 15秒
    
    -- 重启配置
    RESTART_DELAY = 3000,           -- 重启延迟 3秒
    MAX_RESTART_ATTEMPTS = 10,      -- 最大重启次数
    RESTART_RESET_TIME = 60000,     -- 重启计数重置时间 1分钟
    
    -- 日志配置 (按时间命名)
    LOG_DIR = "/sdcard/guardian/",
    LOG_PREFIX = "guardian_log_",
    
    -- 锁文件 (用于防重复启动)
    LOCK_FILE = "/sdcard/guardian/guardian.lock",
}

-- ==================== 全局变量 ====================
local g_running = false
local g_restartCount = 0
local g_lastRestartTime = 0
local g_lastHeartbeatTime = 0
local g_status = "停止"
local g_startTime = 0
local g_logFile = ""  -- 当前日志文件路径（按启动时间命名）

-- ==================== 日志函数 ====================

-- 写入日志 (日志文件按启动时间命名: /sdcard/guardian/guardian_log_YYYYMMDD_HHMMSS.txt)
local function writeLog(level, msg)
    if g_logFile == "" then return end
    
    -- 确保目录存在
    dir.Create(CONFIG.LOG_DIR)
    
    -- 如果文件不存在，先创建空文件
    if not File.Exist(g_logFile) then
        File.Write(g_logFile, "")
    end
    
    local timeStr = DateTime.Format("HH:mm:ss", Now())
    local line = string.format("[%s] [%s] %s\n", timeStr, level, msg)
    File.Append(g_logFile, line)
end

-- ==================== 锁机制 (防重复启动) ====================

-- 检查是否已有守护在运行
local function isAnotherGuardianRunning()
    -- 检查锁文件是否存在
    if not File.Exist(CONFIG.LOCK_FILE) then
        return false
    end
    
    -- 读取锁文件内容 (进程启动时间)
    local lockContent = File.Read(CONFIG.LOCK_FILE)
    if not lockContent or lockContent == "" then
        return false
    end
    
    local lockTick = tonumber(lockContent)
    if not lockTick then
        return false
    end
    
    -- 如果锁时间超过2分钟，认为锁已过期（防止意外崩溃导致死锁）
    local currentTick = TickCount()
    if currentTick - lockTick > 120000 then
        writeLog("WARN", "检测到过期锁，清除...")
        File.Delete(CONFIG.LOCK_FILE)
        return false
    end
    
    return true
end

-- 创建锁
local function createLock()
    dir.Create(CONFIG.LOG_DIR)
    File.Write(CONFIG.LOCK_FILE, tostring(TickCount()))
end

-- 清除锁
local function clearLock()
    if File.Exist(CONFIG.LOCK_FILE) then
        File.Delete(CONFIG.LOCK_FILE)
    end
end

-- ==================== 工具函数 ====================

-- 格式化运行时间
local function formatRuntime(ms)
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
    if not File.Exist(CONFIG.HEARTBEAT_FILE) then
        return 0
    end
    
    local content = File.Read(CONFIG.HEARTBEAT_FILE)
    if content and content ~= "" then
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
    local currentTick = TickCount()
    
    if heartbeatTime == 0 then
        if g_lastHeartbeatTime == 0 then
            g_status = "等待心跳"
            return false, "等待首次心跳"
        else
            g_status = "心跳丢失"
            return false, "心跳文件失效"
        end
    end
    
    -- 更新最后心跳时间
    if heartbeatTime > g_lastHeartbeatTime then
        g_lastHeartbeatTime = heartbeatTime
    end
    
    -- 计算超时
    local elapsed = currentTick - g_lastHeartbeatTime
    
    if elapsed > CONFIG.HEARTBEAT_TIMEOUT then
        g_status = "心跳超时"
        return false, string.format("超时%dms", elapsed)
    end
    
    g_status = "运行正常"
    return true, "OK"
end

-- ==================== 脚本管理 ====================

-- 启动主脚本
local function startMainScript()
    writeLog("INFO", "正在启动主脚本: " .. CONFIG.MAIN_SCRIPT_NAME)
    g_status = "启动中"
    
    -- 重置心跳文件
    File.Write(CONFIG.HEARTBEAT_FILE, tostring(TickCount()))
    g_lastHeartbeatTime = TickCount()
    
    -- 延迟后启动
    Delay(1000)
    
    -- 使用 Thread 插件启动主脚本
    local ok = Thread.Start(CONFIG.MAIN_SCRIPT_NAME)
    
    if ok then
        writeLog("INFO", "主脚本启动成功")
        return true
    else
        writeLog("ERROR", "主脚本启动失败")
        return false
    end
end

-- 重启主脚本
local function restartMainScript()
    local now = TickCount()
    
    -- 检查重启频率
    if now - g_lastRestartTime > CONFIG.RESTART_RESET_TIME then
        g_restartCount = 0
    end
    
    g_restartCount = g_restartCount + 1
    g_lastRestartTime = now
    
    -- 检查最大重启次数
    if g_restartCount > CONFIG.MAX_RESTART_ATTEMPTS then
        writeLog("FATAL", string.format("重启次数超过限制(%d次)，停止守护", CONFIG.MAX_RESTART_ATTEMPTS))
        g_running = false
        return false
    end
    
    writeLog("WARN", string.format("第%d次重启主脚本...", g_restartCount))
    
    -- 延迟后重启
    Delay(CONFIG.RESTART_DELAY)
    
    -- 重置状态
    g_lastHeartbeatTime = 0
    
    return startMainScript()
end

-- ==================== 守护循环 ====================

-- 守护主循环 (在独立线程中运行)
local function guardianLoop()
    writeLog("INFO", "========================================")
    writeLog("INFO", "进程守护插件启动")
    writeLog("INFO", "目标脚本: " .. CONFIG.MAIN_SCRIPT_NAME)
    writeLog("INFO", "日志文件: " .. g_logFile)
    writeLog("INFO", "========================================")
    
    -- 首次启动主脚本
    startMainScript()
    
    -- 主检测循环
    local checkCount = 0
    while g_running do
        checkCount = checkCount + 1
        
        -- 检测主脚本
        local isAlive, msg = checkMainScript()
        
        -- 每12次检测(约60秒)记录一次状态
        if checkCount % 12 == 0 then
            local runtime = formatRuntime(TickCount() - g_startTime)
            writeLog("INFO", string.format("状态:%s 运行:%s 重启:%d次", 
                g_status, runtime, g_restartCount))
        end
        
        -- 异常时重启
        if not isAlive and g_lastHeartbeatTime > 0 then
            writeLog("WARN", "检测到异常: " .. msg)
            restartMainScript()
        end
        
        -- 等待下次检测
        Delay(CONFIG.HEARTBEAT_INTERVAL)
    end
    
    writeLog("INFO", "守护插件停止")
    g_status = "停止"
    
    -- 清除锁
    clearLock()
end

-- ==================== 插件导出函数 ====================

-- 启动守护 (导出函数)
function QMPlugin.StartGuardian()
    -- 检查是否已在运行 (内存中)
    if g_running then
        return "守护已在运行中"
    end
    
    -- 检查是否有其他守护进程在运行 (文件锁)
    if isAnotherGuardianRunning() then
        return "已有另一个守护进程在运行"
    end
    
    -- 创建锁
    createLock()
    
    -- 创建日志目录并生成日志文件名
    dir.Create(CONFIG.LOG_DIR)
    local dateStr = DateTime.Format("yyyyMMdd_HHmmss", Now())
    g_logFile = CONFIG.LOG_DIR .. CONFIG.LOG_PREFIX .. dateStr .. ".txt"
    
    g_running = true
    g_restartCount = 0
    g_lastRestartTime = 0
    g_lastHeartbeatTime = 0
    g_startTime = TickCount()
    g_status = "初始化"
    
    -- 在独立线程中启动守护循环
    -- 注意: Thread.Start 应该接受一个函数，但按键精灵可能只支持字符串
    -- 这里使用 coroutine 或直接用 Thread.Start 启动一个函数
    local ok = Thread.Start(function()
        guardianLoop()
    end)
    
    if not ok then
        -- 如果 Thread.Start 失败，可能是参数问题，尝试直接运行（会阻塞）
        -- 但这不应该发生，所以先记录错误
        writeLog("ERROR", "Thread.Start 失败，尝试使用协程")
        
        -- 使用协程方式
        local co = coroutine.create(guardianLoop)
        coroutine.resume(co)
    end
    
    return "守护已启动"
end

-- 停止守护 (导出函数)
function QMPlugin.StopGuardian()
    if not g_running then
        return "守护未运行"
    end
    
    g_running = false
    clearLock()
    
    return "守护已停止"
end

-- 获取守护状态 (导出函数)
function QMPlugin.GetStatus()
    local runtime = 0
    if g_startTime > 0 then
        runtime = TickCount() - g_startTime
    end
    
    return string.format("状态:%s 运行:%s 重启:%d次", 
        g_status, formatRuntime(runtime), g_restartCount)
end

-- 设置主脚本名称 (导出函数)
function QMPlugin.SetMainScript(scriptName)
    CONFIG.MAIN_SCRIPT_NAME = scriptName
    writeLog("INFO", "设置主脚本: " .. scriptName)
    return "OK"
end

-- 设置心跳超时时间 (导出函数)
function QMPlugin.SetTimeout(timeoutMs)
    CONFIG.HEARTBEAT_TIMEOUT = tonumber(timeoutMs) or 15000
    writeLog("INFO", "设置超时时间: " .. CONFIG.HEARTBEAT_TIMEOUT .. "ms")
    return "OK"
end

-- 发送心跳 (供主脚本调用，导出函数)
function QMPlugin.SendHeartbeat()
    File.Write(CONFIG.HEARTBEAT_FILE, tostring(TickCount()))
    return "OK"
end

-- 测试插件是否加载成功 (导出函数)
function QMPlugin.Test()
    return "GuardianPlugin v3.2.0 加载成功"
end
