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
    
    -- 日志目录
    LOG_DIR = "/sdcard/guardian",
}

-- ==================== Shell脚本模板 ====================
local SHELL_TEMPLATE = [[#!/system/bin/sh
# ============================================
# 按键精灵守护Shell脚本 (自动生成)
# 主脚本: %s
# 生成时间: %s
# ============================================

# 配置
HEARTBEAT_FILE="/sdcard/guardian/heartbeat.txt"
HEARTBEAT_INTERVAL=5
HEARTBEAT_TIMEOUT=15
RESTART_DELAY=3
MAX_RESTART=10
RESTART_RESET_TIME=60
LOG_DIR="/sdcard/guardian"
LOG_FILE="${LOG_DIR}/shell_guardian_$(date +%%Y%%m%%d_%%H%%M%%S).log"
PID_FILE="/sdcard/guardian/guardian_shell.pid"
MAIN_SCRIPT_NAME="%s"

# 日志函数
log() {
    local level="$1"
    local msg="$2"
    local time_str=$(date +"%%H:%%M:%%S")
    echo "[${time_str}] [${level}] ${msg}" >> "$LOG_FILE"
}

# 检查是否已在运行
check_running() {
    if [ -f "$PID_FILE" ]; then
        local old_pid=$(cat "$PID_FILE")
        if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
            local lock_time=$(stat -c %%Y "$PID_FILE" 2>/dev/null || stat -f %%m "$PID_FILE" 2>/dev/null)
            local current_time=$(date +%%s)
            local elapsed=$((current_time - lock_time))
            if [ "$elapsed" -gt 120 ]; then
                rm -f "$PID_FILE"
                return 1
            fi
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# 更新PID
update_pid() {
    echo $$ > "$PID_FILE"
}

# 清除PID
clear_pid() {
    rm -f "$PID_FILE"
}

# 读取心跳
read_heartbeat() {
    if [ -f "$HEARTBEAT_FILE" ]; then
        cat "$HEARTBEAT_FILE"
    else
        echo "0"
    fi
}

# 获取当前时间(秒)
get_time() {
    date +%%s
}

# 格式化运行时间
format_runtime() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local mins=$(((seconds %% 3600) / 60))
    local secs=$((seconds %% 60))
    if [ "$hours" -gt 0 ]; then
        echo "${hours}小时${mins}分"
    elif [ "$mins" -gt 0 ]; then
        echo "${mins}分${secs}秒"
    else
        echo "${secs}秒"
    fi
}

# 启动主脚本
start_main() {
    log "INFO" "启动主脚本: $MAIN_SCRIPT_NAME"
    mkdir -p "$LOG_DIR"
    echo "$(get_time)" > "$HEARTBEAT_FILE"
    # 启动按键精灵主脚本
    am start -a android.intent.action.MAIN -n com.cyjh.gundam/.activity.MainActivity 2>/dev/null
    sleep 2
    log "INFO" "主脚本启动完成"
}

# 重启主脚本
restart_main() {
    log "WARN" "第${restart_count}次重启..."
    sleep "$RESTART_DELAY"
    echo "0" > "$HEARTBEAT_FILE"
    last_heartbeat=0
    start_main
}

# 主循环
main_loop() {
    if check_running; then
        echo "已有守护在运行，退出"
        exit 1
    fi
    
    update_pid
    mkdir -p "$LOG_DIR"
    
    log "INFO" "========================================"
    log "INFO" "Shell守护启动 | 主脚本: $MAIN_SCRIPT_NAME"
    log "INFO" "========================================"
    
    start_main
    
    local check_count=0
    local last_heartbeat=0
    local restart_count=0
    local last_restart_time=$(get_time)
    local start_time=$(get_time)
    
    while true; do
        check_count=$((check_count + 1))
        
        local heartbeat=$(read_heartbeat)
        local current_time=$(get_time)
        
        if [ "$heartbeat" != "0" ] && [ -n "$heartbeat" ]; then
            if [ "$heartbeat" -gt "$last_heartbeat" ]; then
                last_heartbeat=$heartbeat
            fi
            
            local elapsed=$((current_time - last_heartbeat))
            
            if [ "$elapsed" -gt "$HEARTBEAT_TIMEOUT" ]; then
                log "WARN" "心跳超时: ${elapsed}秒"
                
                local time_since_restart=$((current_time - last_restart_time))
                if [ "$time_since_restart" -gt "$RESTART_RESET_TIME" ]; then
                    restart_count=0
                fi
                
                restart_count=$((restart_count + 1))
                last_restart_time=$current_time
                
                if [ "$restart_count" -gt "$MAX_RESTART" ]; then
                    log "FATAL" "重启次数超限，停止守护"
                    break
                fi
                
                restart_main
            fi
        fi
        
        if [ $((check_count %% 12)) -eq 0 ]; then
            local runtime=$((current_time - start_time))
            log "INFO" "状态:正常 运行:$(format_runtime $runtime) 重启:${restart_count}次"
        fi
        
        touch "$PID_FILE"
        sleep "$HEARTBEAT_INTERVAL"
    done
    
    log "INFO" "守护停止"
    clear_pid
}

trap 'log "INFO" "收到退出信号"; clear_pid; exit 0' TERM INT
main_loop
]]

-- 生成Shell脚本
local function generateShellScript(scriptName)
    local timeStr = DateTime.Format("yyyy-MM-dd HH:mm:ss", Now())
    local content = string.format(SHELL_TEMPLATE, scriptName, timeStr, scriptName)
    
    -- 使用shell命令创建目录（更可靠）
    Sys.Execute("mkdir -p /sdcard/guardian")
    
    -- 写入Shell脚本
    File.Write(CONFIG.SHELL_SCRIPT, content)
    
    -- 给脚本添加执行权限
    Sys.Execute("chmod +x " .. CONFIG.SHELL_SCRIPT)
    
    return true
end

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
    
    return string.find(result, pid) ~= nil
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
-- 自动检测Shell守护状态，如未运行则自动生成并启动
function QMPlugin.SetMainScript(scriptName)
    -- 1. 检查Shell守护是否已在运行
    if isShellRunning() then
        -- Shell已在运行，只需要修改配置
        -- 生成新的Shell脚本（包含新的主脚本名）
        generateShellScript(scriptName)
        return "主脚本已设置为:" .. scriptName .. " (Shell守护已在运行)"
    end
    
    -- 2. Shell未运行，自动生成Shell脚本
    local success, err = pcall(function()
        generateShellScript(scriptName)
    end)
    
    if not success then
        return "错误: 生成Shell脚本失败 - " .. tostring(err)
    end
    
    -- 3. 等待文件写入完成
    Delay(1000)
    
    -- 4. 验证文件是否生成成功
    if not File.Exist(CONFIG.SHELL_SCRIPT) then
        return "错误: Shell脚本文件未生成"
    end
    
    -- 5. 自动启动Shell守护
    local cmd = string.format("sh %s > /dev/null 2>&1 &", CONFIG.SHELL_SCRIPT)
    Sys.Execute(cmd)
    
    -- 6. 等待Shell启动
    Delay(2000)
    
    -- 7. 检查是否成功启动
    if isShellRunning() then
        return "主脚本:" .. scriptName .. " | Shell守护已自动生成并启动"
    else
        -- 再试一次
        Delay(1000)
        if isShellRunning() then
            return "主脚本:" .. scriptName .. " | Shell守护已自动生成并启动"
        else
            return "错误: Shell守护启动失败，请检查日志"
        end
    end
end

-- 测试插件是否加载成功 (导出函数)
function QMPlugin.Test()
    return "GuardianPlugin v4.1.1 (Shell版) 加载成功"
end
