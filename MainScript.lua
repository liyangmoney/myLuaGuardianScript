-- ============================================
-- 主脚本示例 - 配合守护插件使用
-- 说明：此脚本需要配合 GuardianPlugin.lua 使用
-- ============================================

-- ==================== 配置 ====================
local CONFIG = {
    HEARTBEAT_INTERVAL = 3000,      -- 心跳间隔 3秒
    HEARTBEAT_FILE = "/sdcard/按键精灵/心跳/heartbeat.txt",
}

-- ==================== 心跳函数 ====================

-- 发送心跳
local function sendHeartbeat()
    -- 直接写入时间戳到文件
    local f = io.open(CONFIG.HEARTBEAT_FILE, "w")
    if f then
        f:write(tostring(TickCount()))
        f:close()
    end
end

-- ==================== 业务逻辑示例 ====================

-- 模拟任务1: 检查消息
local function taskCheckMessages()
    -- 你的实际业务代码...
    -- 示例: 找图、点击等
    -- FindColor(...)
    -- Tap(x, y)
end

-- 模拟任务2: 执行自动化
local function taskAutomation()
    -- 你的实际业务代码...
    -- 示例:
    -- Swipe(x1, y1, x2, y2)
    -- Delay(500)
end

-- 模拟任务3: 数据同步
local function taskSyncData()
    -- 你的实际业务代码...
    -- 示例:
    -- HttpGet(...)
end

-- ==================== 主函数 ====================

function Main()
    -- 首次心跳
    sendHeartbeat()
    TracePrint("主脚本启动成功")
    
    -- 主循环
    local lastHeartbeat = TickCount()
    local loopCount = 0
    
    while true do
        loopCount = loopCount + 1
        
        -- 执行业务逻辑 (带错误处理)
        local ok, err = pcall(function()
            taskCheckMessages()
            taskAutomation()
            taskSyncData()
        end)
        
        if not ok then
            -- 出错也要发心跳，让守护进程知道还活着
            TracePrint("任务执行错误: " .. tostring(err))
        end
        
        -- 定时发送心跳
        local currentTick = TickCount()
        if currentTick - lastHeartbeat >= CONFIG.HEARTBEAT_INTERVAL then
            sendHeartbeat()
            lastHeartbeat = currentTick
            
            -- 每10次心跳输出一次状态
            if loopCount % 10 == 0 then
                TracePrint(string.format("主脚本运行中... 循环次数:%d", loopCount))
            end
        end
        
        -- 短暂休眠，避免CPU占用过高
        Delay(100)
    end
end

-- 启动
Main()
