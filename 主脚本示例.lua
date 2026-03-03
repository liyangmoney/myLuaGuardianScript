-- ============================================
-- 主脚本示例 - 集成心跳机制
-- 说明：这是被守护的主脚本，需要集成心跳发送功能
-- ============================================

-- ==================== 配置 ====================
local CONFIG = {
    SCRIPT_NAME = "主脚本",           -- 脚本名称
    HEARTBEAT_INTERVAL = 3000,        -- 心跳发送间隔（毫秒），建议3-5秒
}

-- ==================== 心跳函数 ====================

-- 发送心跳到守护进程
-- 通过全局变量或文件方式通信
local function sendHeartbeat()
    -- 方式1：通过文件记录心跳时间戳
    local heartbeatFile = "/sdcard/guardian/heartbeat.txt"
    local f = io.open(heartbeatFile, "w")
    if f then
        f:write(tostring(mTime()))
        f:close()
    end
    
    -- 方式2：输出日志（守护进程可通过日志检测）
    -- print("[HEARTBEAT] " .. mTime())
end

-- ==================== 主逻辑 ====================

-- 初始化
function init()
    -- 创建心跳目录
    os.execute("mkdir -p /sdcard/guardian")
    
    -- 首次心跳
    sendHeartbeat()
    toast("主脚本启动成功")
end

-- 主任务
function mainTask()
    -- 在这里写你的主业务逻辑
    -- 示例：模拟一些操作
    
    -- 任务1：检查消息
    checkMessages()
    
    -- 任务2：执行自动化操作
    doAutomation()
    
    -- 任务3：数据同步
    syncData()
end

-- 示例任务函数
function checkMessages()
    -- 你的代码...
    -- 示例：print("检查消息...")
end

function doAutomation()
    -- 你的代码...
    -- 示例自动化操作
    -- click(100, 200)
    -- delay(500)
end

function syncData()
    -- 你的代码...
    -- 示例：print("同步数据...")
end

-- ==================== 主循环 ====================

function main()
    -- 初始化
    init()
    
    -- 主循环
    local lastHeartbeat = mTime()
    
    while true do
        -- 执行业务逻辑
        local ok, err = pcall(mainTask)
        if not ok then
            -- 出错时也要发心跳，让守护进程知道还活着
            print("任务执行出错: " .. tostring(err))
        end
        
        -- 定时发送心跳
        local currentTime = mTime()
        if currentTime - lastHeartbeat >= CONFIG.HEARTBEAT_INTERVAL then
            sendHeartbeat()
            lastHeartbeat = currentTime
        end
        
        -- 短暂休眠，避免CPU占用过高
        delay(100)
    end
end

-- 启动主脚本
main()
