-- ============================================
-- 按键精灵移动版 - Shell守护启动插件
-- 文件名: GuardianPlugin.lua
-- 版本: 4.2.0
-- 描述: 启动独立Shell守护进程
-- 
-- 注意：按键精灵插件只执行 QMPlugin 下的函数
-- ============================================

-- 定义插件命名空间
QMPlugin = {}

-- 配置（函数外只支持变量定义）
local SHELL_SCRIPT = "/sdcard/guardian/GuardianShell.sh"
local PID_FILE = "/sdcard/guardian/guardian_shell.pid"
local HEARTBEAT_FILE = "/sdcard/guardian/heartbeat.txt"
local LOG_DIR = "/sdcard/guardian"

-- Shell脚本模板
local SHELL_TEMPLATE = [==[#!/system/bin/sh
# ============================================
# 按键精灵守护Shell脚本 (自动生成)
# 主脚本: %s
# ============================================

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

log() {
    local level="$1"
    local msg="$2"
    local time_str=$(date +"%%H:%%M:%%S")
    echo "[${time_str}] [${level}] ${msg}" >> "$LOG_FILE"
}

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

update_pid() {
    echo $$ > "$PID_FILE"
}

clear_pid() {
    rm -f "$PID_FILE"
}

read_heartbeat() {
    if [ -f "$HEARTBEAT_FILE" ]; then
        cat "$HEARTBEAT_FILE"
    else
        echo "0"
    fi
}

get_time() {
    date +%%s
}

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

start_main() {
    log "INFO" "启动主脚本: $MAIN_SCRIPT_NAME"
    mkdir -p "$LOG_DIR"
    echo "$(get_time)" > "$HEARTBEAT_FILE"
    am start -a android.intent.action.MAIN -n com.cyjh.gundam/.activity.MainActivity 2>/dev/null
    sleep 2
    log "INFO" "主脚本启动完成"
}

restart_main() {
    local count=$1
    log "WARN" "第${count}次重启..."
    sleep "$RESTART_DELAY"
    echo "0" > "$HEARTBEAT_FILE"
    start_main
}

main_loop() {
    if check_running; then
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
                
                restart_main $restart_count
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

trap 'clear_pid; exit 0' TERM INT
main_loop
]==]

-- 辅助函数：执行shell命令
local function exec(cmd)
    return Sys.Execute(cmd)
end

-- 辅助函数：检查文件是否存在
local function fileExists(path)
    local result = exec(string.format("ls %s 2>/dev/null && echo YES || echo NO", path))
    return string.find(result, "YES") ~= nil
end

-- 辅助函数：写入文件
local function writeFile(path, content)
    -- 使用echo写入，处理换行
    local cmd = string.format("echo '%s' > %s", content:gsub("'", "'\"'\"'"), path)
    exec(cmd)
end

-- 辅助函数：检查Shell守护是否运行
local function isRunning()
    if not fileExists(PID_FILE) then
        return false
    end
    
    -- 读取PID
    local pid = exec(string.format("cat %s 2>/dev/null", PID_FILE))
    pid = pid:gsub("%s+", "")  -- 去除空白
    
    if pid == "" then
        return false
    end
    
    -- 检查进程是否存在
    local result = exec(string.format("ps | grep %s | grep -v grep", pid))
    return string.find(result, pid) ~= nil
end

-- 生成Shell脚本
local function generateScript(scriptName)
    local timeStr = DateTime.Format("yyyy-MM-dd HH:mm:ss", Now())
    local content = string.format(SHELL_TEMPLATE, scriptName, scriptName)
    
    -- 创建目录
    exec("mkdir -p " .. LOG_DIR)
    
    -- 使用echo逐行写入（处理特殊字符）
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    -- 先创建空文件
    exec(string.format("> %s", SHELL_SCRIPT))
    
    -- 逐行追加
    for _, line in ipairs(lines) do
        -- 转义特殊字符
        line = line:gsub("\"", "\\\"")
        line = line:gsub("\$", "\\$")
        local cmd = string.format("echo \"%s\" >> %s", line, SHELL_SCRIPT)
        exec(cmd)
    end
    
    -- 添加执行权限
    exec("chmod +x " .. SHELL_SCRIPT)
    
    return true
end

-- ==================== 插件导出函数 ====================

-- 测试插件
function QMPlugin.Test()
    return "GuardianPlugin v4.2.0 加载成功"
end

-- 发送心跳
function QMPlugin.SendHeartbeat()
    local cmd = string.format("echo %s > %s", TickCount(), HEARTBEAT_FILE)
    exec(cmd)
    return "OK"
end

-- 设置主脚本并自动启动守护
function QMPlugin.SetMainScript(scriptName)
    -- 检查是否已在运行
    if isRunning() then
        -- 更新配置
        generateScript(scriptName)
        return "主脚本已设置:" .. scriptName .. " (守护运行中)"
    end
    
    -- 生成Shell脚本
    local ok, err = pcall(function()
        generateScript(scriptName)
    end)
    
    if not ok then
        return "错误:生成脚本失败-" .. tostring(err)
    end
    
    -- 验证文件
    Delay(500)
    if not fileExists(SHELL_SCRIPT) then
        return "错误:脚本文件未生成"
    end
    
    -- 启动Shell
    local cmd = string.format("sh %s > /dev/null 2>&1 &", SHELL_SCRIPT)
    exec(cmd)
    
    -- 等待启动
    Delay(2000)
    
    if isRunning() then
        return "主脚本:" .. scriptName .. " | 守护已启动"
    else
        Delay(1000)
        if isRunning() then
            return "主脚本:" .. scriptName .. " | 守护已启动"
        else
            return "错误:守护启动失败"
        end
    end
end

-- 手动启动守护（需脚本已存在）
function QMPlugin.StartGuardian()
    if isRunning() then
        return "守护已在运行"
    end
    
    if not fileExists(SHELL_SCRIPT) then
        return "错误:脚本不存在，请先SetMainScript"
    end
    
    local cmd = string.format("sh %s > /dev/null 2>&1 &", SHELL_SCRIPT)
    exec(cmd)
    
    Delay(1500)
    
    if isRunning() then
        return "守护已启动"
    else
        return "守护启动失败"
    end
end

-- 停止守护
function QMPlugin.StopGuardian()
    if not fileExists(PID_FILE) then
        return "守护未运行"
    end
    
    local pid = exec(string.format("cat %s 2>/dev/null", PID_FILE))
    pid = pid:gsub("%s+", "")
    
    if pid ~= "" then
        exec(string.format("kill -TERM %s 2>/dev/null", pid))
        Delay(2000)
        exec(string.format("kill -9 %s 2>/dev/null", pid))
    end
    
    exec(string.format("rm -f %s", PID_FILE))
    
    return "守护已停止"
end

-- 获取状态
function QMPlugin.GetStatus()
    if isRunning() then
        local pid = exec(string.format("cat %s 2>/dev/null", PID_FILE))
        pid = pid:gsub("%s+", "")
        return "守护运行中 PID:" .. pid
    else
        return "守护未运行"
    end
end
