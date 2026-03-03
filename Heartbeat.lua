-- ============================================
-- 主脚本心跳模块 - 配合 GuardianRunner 使用
-- 文件名: Heartbeat.lua
-- 使用方法: 将此文件放在主脚本同目录， require("Heartbeat")
-- ============================================

-- 心跳配置
local HEARTBEAT_CONFIG = {
    FILE = "/sdcard/guardian/heartbeat.txt",
    INTERVAL = 3000,  -- 每3秒发送一次心跳
}

-- 最后一次心跳时间
local lastHeartbeatTime = 0

-- 发送心跳
local function sendHeartbeat()
    -- 确保目录存在
    local dir = string.match(HEARTBEAT_CONFIG.FILE, "(.+)/")
    if dir and not dir.Exist(dir) then
        dir.Create(dir)
    end
    
    -- 写入当前时间戳
    File.Write(HEARTBEAT_CONFIG.FILE, tostring(TickCount()))
    lastHeartbeatTime = TickCount()
end

-- 自动心跳函数（需要在主循环中调用）
function AutoHeartbeat()
    local currentTick = TickCount()
    if currentTick - lastHeartbeatTime >= HEARTBEAT_CONFIG.INTERVAL then
        sendHeartbeat()
    end
end

-- 手动发送心跳
function ManualHeartbeat()
    sendHeartbeat()
end

-- 初始化心跳
sendHeartbeat()
TracePrint("心跳模块已初始化")

-- 如果使用：直接在主脚本中定时调用 AutoHeartbeat()
