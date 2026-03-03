-- ============================================
-- 按键精灵移动版 - 独立守护脚本
-- 文件名: GuardianRunner.lua
-- 版本: 4.0.0
-- 描述: 作为独立脚本运行，真正独立于主脚本
-- 
-- 使用方法:
-- 1. 将此脚本作为独立脚本运行（不要作为插件导入）
-- 2. 它会自动启动并守护指定的主脚本
-- 3. 即使主脚本崩溃/退出，守护脚本继续运行
-- ============================================

-- ==================== 配置区域 ====================
local CONFIG = {
    -- 要守护的主脚本名称（必须在按键精灵中有此脚本）
    MAIN_SCRIPT_NAME = "MainScript",
    
    -- 心跳配置
    HEARTBEAT_FILE = "/sdcard/guardian/heartbeat.txt",
    HEARTBEAT_INTERVAL = 5000,      -- 检测间隔 5秒
    HEARTBEAT_TIMEOUT = 15000,      -- 超时时间 15秒
    
    -- 重启配置
    RESTART_DELAY = 3000,           -- 重启延迟 3秒
    MAX_RESTART_ATTEMPTS = 10,      -- 最大重启次数
    RESTART_RESET_TIME = 60000,     -- 重启计数重置时间 1分钟
    
    -- 日志配置
    LOG_DIR = "/sdcard/guardian/",
    LOG_PREFIX = "guardian_log_",
    
    -- 锁文件
    LOCK_FILE = "/sdcard/guardian/guardian.lock",
}

-- ==================== 全局变量 ====================
local g_running = true
local g_restartCount = 0
local g_lastRestartTime = 0
local g_lastHeartbeatTime = 0
local g_status = "初始化"
local g_startTime = TickCount()
local g_logFile = ""

-- ==================== 日志函数 ====================

-- 确保目录存在
local function ensureDir()
    if not dir.Exist(CONFIG.LOG_DIR) then
        dir.Create(CONFIG.LOG_DIR)
    end
end

-- 写入日志
local function writeLog(level, msg)
    if g_logFile == "" then
        -- 首次写入，生成日志文件名
        ensureDir()
        local dateStr = DateTime.Format("yyyyMMdd_HHmmss", Now())
        g_logFile = CONFIG.LOG_DIR .. CONFIG.LOG_PREFIX .. dateStr .. ".txt"
        
        -- 创建空文件
        File.Write(g_logFile, "")
    end
    
    local timeStr = DateTime.Format("HH:mm:ss", Now())
    local line = string.format("[%s] [%s] %s\n", timeStr, level, msg)
    File.Append(g_logFile, line)
end

-- ==================== 锁机制 (防重复启动) ====================

-- 检查是否已有守护在运行
local function isAnotherGuardianRunning()
    if not File.Exist(CONFIG.LOCK_FILE) then
        return false
    end
    
    local lockContent = File.Read(CONFIG.LOCK_FILE)
    if not lockContent or lockContent == "" then
        return false
    end
    
    local lockTick = tonumber(lockContent)
    if not lockTick then
        return false
    end
    
    -- 锁2分钟过期
    local currentTick = TickCount()
    if currentTick - lockTick > 120000 then
        writeLog("WARN", "检测到过期锁，清除...")
        File.Delete(CONFIG.LOCK_FILE)
        return false
    end
    
    return true
end

-- 更新锁（心跳方式，证明自己还活着）
local function updateLock()
    if not dir.Exist(CONFIG.LOG_DIR) then
        dir.Create(CONFIG.LOG_DIR)
    end
    File.Write(CONFIG.LOCK_FILE, tostring(TickCount()))
end

-- 清除锁
local function clearLock()
    if File.Exist(CONFIG.LOCK_FILE) then
        File.Delete(CONFIG.LOCK_FILE)
    end
end

-- ==================== 工具函数 ====================

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
    
    if heartbeatTime > g_lastHeartbeatTime then
        g_lastHeartbeatTime = heartbeatTime
    end
    
    local elapsed = currentTick - g_lastHeartbeatTime
    
    if elapsed > CONFIG.HEARTBEAT_TIMEOUT then
        g_status = "心跳超时"
        return false, string.format("超时%dms", elapsed)
    end
    
    g_status = "运行正常"
    return true, "OK"
end

-- ==================== 脚本管理 ====================

local function startMainScript()
    writeLog("INFO", "正在启动主脚本: " .. CONFIG.MAIN_SCRIPT_NAME)
    g_status = "启动中"
    
    -- 重置心跳
    ensureDir()
    File.Write(CONFIG.HEARTBEAT_FILE, tostring(TickCount()))
    g_lastHeartbeatTime = TickCount()
    
    Delay(1000)
    
    -- 使用 Thread.Start 启动主脚本
    local ok = Thread.Start(CONFIG.MAIN_SCRIPT_NAME)
    
    if ok then
        writeLog("INFO", "主脚本启动成功")
        return true
    else
        writeLog("ERROR", "主脚本启动失败")
        return false
    end
end

local function restartMainScript()
    local now = TickCount()
    
    if now - g_lastRestartTime > CONFIG.RESTART_RESET_TIME then
        g_restartCount = 0
    end
    
    g_restartCount = g_restartCount + 1
    g_lastRestartTime = now
    
    if g_restartCount > CONFIG.MAX_RESTART_ATTEMPTS then
        writeLog("FATAL", string.format("重启次数超过限制(%d次)，停止守护", CONFIG.MAX_RESTART_ATTEMPTS))
        g_running = false
        return false
    end
    
    writeLog("WARN", string.format("第%d次重启主脚本...", g_restartCount))
    
    Delay(CONFIG.RESTART_DELAY)
    
    g_lastHeartbeatTime = 0
    
    return startMainScript()
end

-- ==================== 主循环 ====================

local function mainLoop()
    -- 检查是否已有守护在运行
    if isAnotherGuardianRunning() then
        TracePrint("已有另一个守护进程在运行，退出...")
        return
    end
    
    -- 首次创建锁
    updateLock()
    
    writeLog("INFO", "========================================")
    writeLog("INFO", "独立守护脚本 v4.0.0 启动")
    writeLog("INFO", "目标脚本: " .. CONFIG.MAIN_SCRIPT_NAME)
    writeLog("INFO", "日志文件: " .. g_logFile)
    writeLog("INFO", "========================================")
    
    TracePrint("守护已启动，正在守护: " .. CONFIG.MAIN_SCRIPT_NAME)
    
    -- 首次启动主脚本
    startMainScript()
    
    -- 主检测循环
    local checkCount = 0
    local lastLockUpdate = TickCount()
    
    while g_running do
        checkCount = checkCount + 1
        
        -- 检测主脚本
        local isAlive, msg = checkMainScript()
        
        -- 每12次检测记录一次状态
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
        
        -- 每30秒更新一次锁（证明自己还活着）
        local currentTick = TickCount()
        if currentTick - lastLockUpdate > 30000 then
            updateLock()
            lastLockUpdate = currentTick
        end
        
        -- 等待下次检测
        Delay(CONFIG.HEARTBEAT_INTERVAL)
    end
    
    writeLog("INFO", "守护脚本停止")
    clearLock()
    TracePrint("守护已停止")
end

-- ==================== 入口 ====================

-- 启动守护
mainLoop()
