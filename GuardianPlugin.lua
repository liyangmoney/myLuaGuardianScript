-- ============================================
-- 按键精灵移动版 - 进程守护插件
-- 版本: 3.0.0
-- 描述: 无界面版进程守护，仅日志记录
-- ============================================

-- ==================== 插件配置 ====================
local CONFIG = {
    -- 主脚本配置
    MAIN_SCRIPT_NAME = "主脚本",
    MAIN_SCRIPT_PATH = "/sdcard/按键精灵/脚本/主脚本.lua",
    
    -- 心跳配置
    HEARTBEAT_FILE = "/sdcard/按键精灵/心跳/heartbeat.txt",
    HEARTBEAT_INTERVAL = 5000,      -- 检测间隔 5秒
    HEARTBEAT_TIMEOUT = 15000,      -- 超时时间 15秒
    
    -- 重启配置
    RESTART_DELAY = 3000,           -- 重启延迟 3秒
    MAX_RESTART_ATTEMPTS = 10,      -- 最大重启次数
    RESTART_RESET_TIME = 60000,     -- 重启计数重置时间 1分钟
    
    -- 日志配置 (使用按键精灵Log插件)
    LOG_DIR = "/sdcard/按键精灵/日志/",
    LOG_PREFIX = "guardian_",
}

-- ==================== 全局变量 ====================
local g_running = true
local g_restartCount = 0
local g_lastRestartTime = 0
local g_lastHeartbeatTime = 0
local g_status = "初始化"
local g_startTime = TickCount()
local g_logOpened = false

-- ==================== 日志模块 (使用Log插件) ====================

-- 初始化日志
local function initLog()
    -- 创建日志目录
    dir.Create(CONFIG.LOG_DIR)
    dir.Create(File.GetPath(CONFIG.HEARTBEAT_FILE))
    
    -- 生成日志文件名
    local dateStr = DateTime.Format("yyyyMMdd_HHmmss", Now())
    local logPath = CONFIG.LOG_DIR .. CONFIG.LOG_PREFIX .. dateStr .. ".txt"
    
    -- 使用Log插件打开日志
    Log.Open(logPath)
    g_logOpened = true
    
    -- 写入启动信息
    TracePrint("=" .. string.rep("=", 40))
    TracePrint("进程守护插件 v3.0 启动")
    TracePrint("目标脚本: " .. CONFIG.MAIN_SCRIPT_NAME)
    TracePrint("心跳文件: " .. CONFIG.HEARTBEAT_FILE)
    TracePrint("超时设置: " .. CONFIG.HEARTBEAT_TIMEOUT .. "ms")
    TracePrint("=" .. string.rep("=", 40))
end

-- 关闭日志
local function closeLog()
    if g_logOpened then
        TracePrint("进程守护插件停止")
        Log.Close()
        g_logOpened = false
    end
end

-- ==================== 工具函数 ====================

-- 格式化运行时间
local function formatRuntime(ms)
    local seconds = math.floor(ms / 1000)
    local mins = math.floor(seconds / 60)
    local hours = math.floor(mins / 60)
    
    if hours > 0 then
        return string.format("%d小时%d分%d秒", hours, mins % 60, seconds % 60)
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
    
    -- 计算超时 (使用TickCount差值)
    local elapsed = currentTick - g_lastHeartbeatTime
    
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
    TracePrint("正在启动主脚本: " .. CONFIG.MAIN_SCRIPT_NAME)
    g_status = "启动中"
    
    -- 重置心跳文件
    File.Write(CONFIG.HEARTBEAT_FILE, tostring(TickCount()))
    g_lastHeartbeatTime = TickCount()
    
    -- 延迟后启动
    Delay(1000)
    
    -- 使用Thread插件启动主脚本
    local ok = Thread.Start(CONFIG.MAIN_SCRIPT_NAME)
    
    if ok then
        TracePrint("主脚本启动成功")
        return true
    else
        TracePrint("主脚本启动失败")
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
        TracePrint(string.format("重启次数超过限制(%d次)，停止守护", CONFIG.MAX_RESTART_ATTEMPTS))
        g_running = false
        return false
    end
    
    TracePrint(string.format("第 %d 次重启主脚本...", g_restartCount))
    
    -- 延迟后重启
    Delay(CONFIG.RESTART_DELAY)
    
    -- 重置状态
    g_lastHeartbeatTime = 0
    
    return startMainScript()
end

-- ==================== 主循环 ====================

-- 守护主循环
local function guardianLoop()
    initLog()
    
    TracePrint("守护循环启动")
    
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
            TracePrint(string.format("[%s] 状态:%s 运行:%s 重启:%d次", 
                g_status, msg, runtime, g_restartCount))
        end
        
        -- 异常时重启
        if not isAlive and g_lastHeartbeatTime > 0 then
            TracePrint(string.format("检测到异常: %s", msg))
            restartMainScript()
        end
        
        -- 等待下次检测
        Delay(CONFIG.HEARTBEAT_INTERVAL)
    end
    
    closeLog()
end

-- ==================== 插件入口 ====================

-- 启动守护
function StartGuardian()
    g_running = true
    g_restartCount = 0
    g_lastRestartTime = 0
    g_lastHeartbeatTime = 0
    g_startTime = TickCount()
    
    local ok, err = pcall(guardianLoop)
    if not ok then
        TracePrint("守护插件异常: " .. tostring(err))
        closeLog()
    end
end

-- 停止守护
function StopGuardian()
    g_running = false
    TracePrint("正在停止守护...")
end

-- 获取守护状态
function GetGuardianStatus()
    return {
        status = g_status,
        restartCount = g_restartCount,
        running = g_running,
        runtime = formatRuntime(TickCount() - g_startTime)
    }
end

-- ==================== 心跳接口 (供主脚本调用) ====================

-- 主脚本调用此函数发送心跳
function SendHeartbeat()
    File.Write(CONFIG.HEARTBEAT_FILE, tostring(TickCount()))
end

-- 自动启动 (如果直接运行此插件)
StartGuardian()
