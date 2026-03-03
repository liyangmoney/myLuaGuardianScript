#!/system/bin/sh
# ============================================
# 按键精灵守护Shell脚本
# 版本: 1.0.0
# 功能: 独立进程守护，监控主脚本心跳，自动重启
# ============================================

# ==================== 配置区域 ====================
HEARTBEAT_FILE="/sdcard/guardian/heartbeat.txt"
HEARTBEAT_INTERVAL=5           # 检测间隔(秒)
HEARTBEAT_TIMEOUT=15           # 超时时间(秒)
RESTART_DELAY=3                # 重启延迟(秒)
MAX_RESTART=10                 # 最大重启次数
RESTART_RESET_TIME=60          # 重启计数重置时间(秒)

# 日志配置
LOG_DIR="/sdcard/guardian"
LOG_FILE="${LOG_DIR}/shell_guardian_$(date +%Y%m%d_%H%M%S).log"

# 锁文件
PID_FILE="/sdcard/guardian/guardian_shell.pid"

# 主脚本配置
MAIN_SCRIPT_NAME="MainScript"

# ==================== 工具函数 ====================

# 写入日志
log() {
    local level="$1"
    local msg="$2"
    local time_str=$(date +"%H:%M:%S")
    echo "[${time_str}] [${level}] ${msg}" >> "$LOG_FILE"
}

# 检查是否已有实例在运行
check_running() {
    if [ -f "$PID_FILE" ]; then
        local old_pid=$(cat "$PID_FILE")
        if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
            # 进程还在运行
            local lock_time=$(stat -c %Y "$PID_FILE" 2>/dev/null || stat -f %m "$PID_FILE" 2>/dev/null)
            local current_time=$(date +%s)
            local elapsed=$((current_time - lock_time))
            
            # 如果锁超过2分钟未更新，认为已过期
            if [ "$elapsed" -gt 120 ]; then
                log "WARN" "检测到过期锁，清除..."
                rm -f "$PID_FILE"
                return 1
            fi
            return 0
        else
            # PID不存在，清除旧锁
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# 更新PID文件
update_pid() {
    echo $$ > "$PID_FILE"
}

# 清除PID文件
clear_pid() {
    rm -f "$PID_FILE"
}

# 读取心跳时间
read_heartbeat() {
    if [ -f "$HEARTBEAT_FILE" ]; then
        cat "$HEARTBEAT_FILE"
    else
        echo "0"
    fi
}

# 获取当前时间(毫秒)
get_time_ms() {
    # Android的date命令可能不支持%N，使用秒级
    date +%s
}

# 格式化运行时间
format_runtime() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local mins=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [ "$hours" -gt 0 ]; then
        echo "${hours}小时${mins}分"
    elif [ "$mins" -gt 0 ]; then
        echo "${mins}分${secs}秒"
    else
        echo "${secs}秒"
    fi
}

# ==================== 主脚本控制 ====================

# 启动主脚本
start_main_script() {
    log "INFO" "正在启动主脚本: $MAIN_SCRIPT_NAME"
    
    # 重置心跳
    mkdir -p "$LOG_DIR"
    echo "$(get_time_ms)" > "$HEARTBEAT_FILE"
    
    # 启动主脚本
    # 通过am命令启动按键精灵并运行指定脚本
    am start -a android.intent.action.MAIN -n com.cyjh.gundam/.activity.MainActivity 2>/dev/null
    
    # 等待一下
    sleep 2
    
    log "INFO" "主脚本启动完成"
    return 0
}

# 重启主脚本
restart_main_script() {
    log "WARN" "第${restart_count}次重启主脚本..."
    
    sleep "$RESTART_DELAY"
    
    # 清除心跳
    echo "0" > "$HEARTBEAT_FILE"
    last_heartbeat=0
    
    start_main_script
}

# ==================== 主循环 ====================

main_loop() {
    # 检查是否已有实例在运行
    if check_running; then
        echo "已有守护进程在运行，退出..."
        exit 1
    fi
    
    # 创建PID文件
    update_pid
    
    # 初始化
    mkdir -p "$LOG_DIR"
    
    log "INFO" "========================================"
    log "INFO" "Shell守护脚本 v1.0.0 启动"
    log "INFO" "目标脚本: $MAIN_SCRIPT_NAME"
    log "INFO" "日志文件: $LOG_FILE"
    log "INFO" "心跳文件: $HEARTBEAT_FILE"
    log "INFO" "========================================"
    
    echo "守护已启动，PID: $$"
    
    # 首次启动主脚本
    start_main_script
    
    # 主检测循环
    local check_count=0
    local last_heartbeat=0
    local restart_count=0
    local last_restart_time=$(get_time_ms)
    local start_time=$(get_time_ms)
    
    while true; do
        check_count=$((check_count + 1))
        
        # 读取心跳
        local heartbeat=$(read_heartbeat)
        local current_time=$(get_time_ms)
        
        if [ "$heartbeat" != "0" ] && [ -n "$heartbeat" ]; then
            # 更新最后心跳时间
            if [ "$heartbeat" -gt "$last_heartbeat" ]; then
                last_heartbeat=$heartbeat
            fi
            
            # 计算超时
            local elapsed=$((current_time - last_heartbeat))
            
            if [ "$elapsed" -gt "$HEARTBEAT_TIMEOUT" ]; then
                log "WARN" "心跳超时: ${elapsed}秒"
                
                # 检查重启频率
                local time_since_restart=$((current_time - last_restart_time))
                if [ "$time_since_restart" -gt "$RESTART_RESET_TIME" ]; then
                    restart_count=0
                fi
                
                restart_count=$((restart_count + 1))
                last_restart_time=$current_time
                
                # 检查最大重启次数
                if [ "$restart_count" -gt "$MAX_RESTART" ]; then
                    log "FATAL" "重启次数超过限制($MAX_RESTART次)，停止守护"
                    break
                fi
                
                restart_main_script
            fi
        fi
        
        # 每12次检测记录一次状态
        if [ $((check_count % 12)) -eq 0 ]; then
            local runtime=$((current_time - start_time))
            log "INFO" "状态:运行正常 运行:$(format_runtime $runtime) 重启:${restart_count}次"
        fi
        
        # 更新PID文件时间戳
        touch "$PID_FILE"
        
        # 等待下次检测
        sleep "$HEARTBEAT_INTERVAL"
    done
    
    log "INFO" "守护脚本停止"
    clear_pid
}

# 捕获退出信号
trap 'log "INFO" "收到退出信号"; clear_pid; exit 0' TERM INT

# 启动主循环
main_loop
