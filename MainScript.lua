-- ============================================
-- 主脚本示例 - 配合 GuardianPlugin 守护插件使用
-- ============================================

-- ==================== 配置 ====================
local CONFIG = {
    HEARTBEAT_INTERVAL = 3000,      -- 心跳间隔 3秒
}

-- ==================== 心跳函数 ====================

-- 发送心跳到守护插件
local function sendHeartbeat()
    -- 调用插件的 SendHeartbeat 函数
    GuardianPlugin.SendHeartbeat()
end

-- ==================== 业务逻辑示例 ====================

-- 模拟任务
local function doWork()
    -- 你的实际业务代码...
    -- 例如：找图、点击、滑动等
    -- FindColor(...)
    -- Tap(x, y)
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
            doWork()
        end)
        
        if not ok then
            -- 出错也要发心跳
            TracePrint("任务执行错误: " .. tostring(err))
        end
        
        -- 定时发送心跳
        local currentTick = TickCount()
        if currentTick - lastHeartbeat >= CONFIG.HEARTBEAT_INTERVAL then
            sendHeartbeat()
            lastHeartbeat = currentTick
        end
        
        -- 短暂休眠
        Delay(100)
    end
end

-- 启动
Main()
