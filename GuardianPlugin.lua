-- ============================================
-- 按键精灵移动版 - Shell守护启动插件
-- 文件名: GuardianPlugin.lua
-- 版本: 4.0.0
-- 描述: 启动独立Shell守护进程，Shell进程独立运行
-- 
-- 使用方式:
-- 1. 将 GuardianShell.sh 放入 /sdcard/guardian/
-- 2. 将此文件放入按键精灵安装目录的 Plugin 文件夹
-- 3. 在脚本中使用: Import "GuardianPlugin"
-- 4. 调用: GuardianPlugin.StartGuardian()
-- ============================================

-- 定义插件命名空间
QMPlugin = {}

-- ==================== 配置区域 ====================
local CONFIG = {
    -- Shell脚本路径
    SHELL_SCRIPT = "/sdcard/guardian/GuardianShell.sh",
    
    -- 心跳配置
    HEARTBEAT_FILE = "/sdcard/guardian/heartbeat.txt",
    
    -- PID文件
    PID_FILE = "/sdcard/guardian/guardian_shell.pid",
}

-- ==================== 工具函数 ====================

-- 检查Shell守护是否正在运行
local function isShellRunning()
    if not File.Exist(CONFIG.PID_FILE) then
        return false
    end
    
    local pid = File.Read(CONFIG.PID_FILE)
    if not pid or pid == "" then
        return false
    end
    
    -- 检查进程是否存在 (使用shell命令)
    local checkCmd = string.format("kill -0 %s 2>/dev/null && echo \"running\" || echo \"not running\"", pid)
    local result = Sys.Execute(checkCmd)
    
    return string.find(result, "running") ~= nil
end

-- ==================== 插件导出函数 ====================

-- 启动Shell守护 (导出函数)
function QMPlugin.StartGuardian()
    -- 检查是否已有Shell守护在运行
    if isShellRunning() then
        return "Shell守护已在运行中"
    end
    
    -- 确保Shell脚本存在
    if not File.Exist(CONFIG.SHELL_SCRIPT) then
        return "错误: Shell脚本不存在: " .. CONFIG.SHELL_SCRIPT
    end
    
    -- 使用sh命令在后台启动Shell脚本
    -- nohup确保在按键精灵退出后Shell继续运行
    local cmd = string.format("sh %s > /dev/null 2>&1 &", CONFIG.SHELL_SCRIPT)
    local result = Sys.Execute(cmd)
    
    -- 等待一下让Shell启动
    Delay(1000)
    
    -- 检查是否成功启动
    if isShellRunning() then
        return "Shell守护已启动"
    else
        return "Shell守护启动失败: " .. result
    end
end

-- 停止Shell守护 (导出函数)
function QMPlugin.StopGuardian()
    if not File.Exist(CONFIG.PID_FILE) then
        return "Shell守护未运行"
    end
    
    local pid = File.Read(CONFIG.PID_FILE)
    if not pid or pid == "" then
        return "无法读取PID"
    end
    
    -- 发送终止信号
    local cmd = string.format("kill -TERM %s", pid)
    Sys.Execute(cmd)
    
    -- 等待进程结束
    Delay(2000)
    
    -- 强制结束（如果还在运行）
    if isShellRunning() then
        cmd = string.format("kill -9 %s", pid)
        Sys.Execute(cmd)
    end
    
    -- 删除PID文件
    if File.Exist(CONFIG.PID_FILE) then
        File.Delete(CONFIG.PID_FILE)
    end
    
    return "Shell守护已停止"
end

-- 获取守护状态 (导出函数)
function QMPlugin.GetStatus()
    if isShellRunning() then
        local pid = File.Read(CONFIG.PID_FILE)
        return string.format("Shell守护运行中 PID:%s", pid)
    else
        return "Shell守护未运行"
    end
end

-- 发送心跳 (供主脚本调用，导出函数)
function QMPlugin.SendHeartbeat()
    File.Write(CONFIG.HEARTBEAT_FILE, tostring(TickCount()))
    return "OK"
end

-- 设置主脚本名称 (导出函数)
-- 注意: 这个设置需要在Shell启动前修改Shell脚本或使用环境变量
function QMPlugin.SetMainScript(scriptName)
    -- 修改Shell脚本中的主脚本名称
    if File.Exist(CONFIG.SHELL_SCRIPT) then
        -- 读取原内容
        local content = File.Read(CONFIG.SHELL_SCRIPT)
        -- 替换主脚本名称
        content = string.gsub(content, "MAIN_SCRIPT_NAME=\"[^\"]*\"", 
            string.format("MAIN_SCRIPT_NAME=\"%s\"", scriptName))
        -- 写回
        File.Write(CONFIG.SHELL_SCRIPT, content)
        return "OK"
    end
    return "错误: Shell脚本不存在"
end

-- 测试插件是否加载成功 (导出函数)
function QMPlugin.Test()
    return "GuardianPlugin v4.0.0 (Shell版) 加载成功"
end
