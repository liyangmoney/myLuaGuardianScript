-- ============================================
-- 按键精灵移动版 - Shell守护启动插件
-- 版本: 4.7.0
-- 描述: 添加 start_eventsrvR 文件自动更新功能
-- ============================================

QMPlugin = {}

local SHELL_SCRIPT = "/sdcard/guardian/GuardianShell.sh"
local PID_FILE = "/sdcard/guardian/guardian_shell.pid"
local HEARTBEAT_FILE = "/sdcard/guardian/heartbeat.txt"

local function exec(cmd)
    return os.execute(cmd)
end

local function fileExists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

local function writeFile(path, content)
    local f = io.open(path, "w")
    if f then f:write(content) f:close() return true end
    return false
end

local function readFile(path)
    local f = io.open(path, "r")
    if f then local c = f:read("*all") f:close() return c or "" end
    return ""
end

local function isRunning()
    if not fileExists(PID_FILE) then return false end
    local pid = readFile(PID_FILE):gsub("%s+", "")
    if pid == "" then return false end
    local tmp = "/sdcard/guardian/.chk"
    exec(string.format("ps | grep %s | grep -v grep > %s", pid, tmp))
    local ex = fileExists(tmp)
    if ex then os.remove(tmp) end
    return ex
end

-- 生成Shell脚本，包含 start_eventsrvR 文件创建功能
local function generateScript(pkgName)
    local logName = "guardian_" .. os.date("%Y%m%d_%H%M%S") .. ".log"
    
    local script = [[#!/system/bin/sh
PKG="]] .. pkgName .. [["
HB_FILE="/sdcard/guardian/heartbeat.txt"
PID_FILE="/sdcard/guardian/guardian_shell.pid"
LOG="/sdcard/guardian/]] .. logName .. [["
TIMEOUT=300
CHECK_INT=30

log() { echo "[$(date +%H:%M:%S)] $1" >> "$LOG"; }

# 创建/更新 start_eventsrvR 文件
update_eventsrv() {
  local files_dir="/data/data/$PKG/files"
  local target_file="$files_dir/start_eventsrvR"
  
  # 确保目录存在
  if [ ! -d "$files_dir" ]; then
    log "创建目录: $files_dir"
    mkdir -p "$files_dir" 2>/dev/null
  fi
  
  # 写入文件内容
  cat > "$target_file" << EOF
export CLASSPATH=/data/user/0/]] .. pkgName .. [[/files/DaemonClient.zip
exec /system/bin/app_process32 /data/user/0/]] .. pkgName .. [[/files com.cyjh.mobileanjian.ipc.ClientService ]] .. pkgName .. [[.event.localserver /data/user/0/]] .. pkgName .. [[/lib/libmqm.so 12030 &
EOF
  
  chmod 755 "$target_file"
  log "已更新: $target_file"
}

# Write PID
echo $$ > "$PID_FILE"
log "=== Guardian Started ==="
log "Package: $PKG"
log "Timeout: ${TIMEOUT}s"
log "Waiting for first heartbeat..."

# 更新 start_eventsrvR
update_eventsrv

# Init heartbeat
echo 0 > "$HB_FILE"
LAST_HB=0
START_TIME=$(date +%s)
RESTART_CNT=0

while true; do
  NOW=$(date +%s)
  HB=$(cat "$HB_FILE" 2>/dev/null || echo 0)
  
  # Update heartbeat
  if [ "$HB" -gt "$LAST_HB" ]; then
    LAST_HB=$HB
    log "Heartbeat: $HB"
  else
    log "Heartbeat: NULL"
  fi
  
  # Check exit signal (-999)
  if [ "$HB" = "-999" ]; then
    log "Exit signal received (-999), stopping..."
    break
  fi
  
  # Calculate elapsed
  if [ "$LAST_HB" -gt 0 ]; then
    ELAPSED=$((NOW - LAST_HB))
  else
    ELAPSED=$((NOW - START_TIME))
  fi
  
  # Check timeout
  if [ "$ELAPSED" -gt "$TIMEOUT" ]; then
    log "TIMEOUT: ${ELAPSED}s - Restarting..."
    RESTART_CNT=$((RESTART_CNT + 1))
    if [ "$RESTART_CNT" -gt 10 ]; then
      log "Max restart reached"
      break
    fi
    log "Stopping app..."
    am force-stop "$PKG" 2>/dev/null
    sleep 1
    log "Starting app..."
    monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 2>/dev/null
    log "App restarted, waiting 20s..."
    sleep 20
    log "Click 369,1216"
    input tap 369 1216
    sleep 2
    log "Click 683,418"
    input tap 683 418
    sleep 1
    log "Click 277,406"
    input tap 277 406
    log "Restarted (#$RESTART_CNT)"
    echo 0 > "$HB_FILE"
    LAST_HB=0
    START_TIME=$(date +%s)
    # 重启后也更新 start_eventsrvR
    update_eventsrv
  fi
  
  touch "$PID_FILE"
  sleep $CHECK_INT
done

rm -f "$PID_FILE"
log "=== Guardian Stopped ==="
]]
    
    exec("mkdir -p /sdcard/guardian")
    writeFile(SHELL_SCRIPT, script)
    exec("chmod +x " .. SHELL_SCRIPT)
end

function QMPlugin.Test()
    return "GuardianPlugin v4.7.0 OK"
end

function QMPlugin.SendHeartbeat()
    writeFile(HEARTBEAT_FILE, tostring(os.time()))
    return "OK"
end

-- 发送退出信号（-999）让守护进程优雅退出
function QMPlugin.SendExitSignal()
    writeFile(HEARTBEAT_FILE, "-999")
    return "退出信号已发送"
end

function QMPlugin.SetMainScript(pkgName)
    if isRunning() then
        return "守护已在运行"
    end
    
    -- 强制重新生成脚本（确保是最新版本）
    local ok, err = pcall(function()
        generateScript(pkgName)
    end)
    
    if not ok then
        return "错误:" .. tostring(err)
    end
    
    -- 启动
    exec(string.format("sh %s > /dev/null 2>&1 &", SHELL_SCRIPT))
    
    local t = os.time()
    while os.time() - t < 5 do
        if isRunning() then
            return "包名:" .. pkgName .. " | 守护已启动(脚本已更新)"
        end
    end
    
    return "启动失败"
end

function QMPlugin.StartGuardian(pkgName)
    if isRunning() then return "守护已在运行" end
    
    -- 确定包名
    local name = pkgName
    if not name then
        -- 尝试从现有脚本读取包名
        if fileExists(SHELL_SCRIPT) then
            local content = readFile(SHELL_SCRIPT)
            name = content:match('PKG="([^"]+)"')
        end
    end
    
    if not name then
        return "请先SetMainScript或在StartGuardian中传入包名"
    end
    
    -- 强制重新生成脚本
    generateScript(name)
    
    exec(string.format("sh %s > /dev/null 2>&1 &", SHELL_SCRIPT))
    local t = os.time()
    while os.time() - t < 3 do
        if isRunning() then return "守护已启动(脚本已更新)" end
    end
    return "启动失败"
end

function QMPlugin.StopGuardian()
    if not fileExists(PID_FILE) then return "守护未运行" end
    local pid = readFile(PID_FILE):gsub("%s+", "")
    if pid ~= "" then
        -- 先发送 TERM 信号
        exec(string.format("kill -TERM %s 2>/dev/null", pid))
        -- 等待5秒
        local t = os.time()
        while os.time() - t < 5 do end
        -- 检查是否还在运行
        exec(string.format("ps | grep %s | grep -v grep > /dev/null 2>&1", pid))
        -- 如果还在，发送 KILL
        exec(string.format("kill -9 %s 2>/dev/null", pid))
    end
    os.remove(PID_FILE)
    return "守护已停止"
end

function QMPlugin.StopAllGuardian()
    local cnt = 0
    -- 先停止 PID 文件的
    if fileExists(PID_FILE) then
        local pid = readFile(PID_FILE):gsub("%s+", "")
        if pid ~= "" then
            exec(string.format("kill -TERM %s 2>/dev/null", pid))
            local t = os.time()
            while os.time() - t < 3 do end
            exec(string.format("kill -9 %s 2>/dev/null", pid))
            cnt = cnt + 1
        end
        os.remove(PID_FILE)
    end
    -- 再查找所有残留
    local tmp = "/sdcard/guardian/.stop"
    exec(string.format("ps | grep GuardianShell | grep -v grep > %s", tmp))
    if fileExists(tmp) then
        local content = readFile(tmp)
        for line in content:gmatch("[^
]+") do
            local p = line:match("^%s*(%d+)")
            if p then
                exec(string.format("kill -TERM %s 2>/dev/null", p))
                exec(string.format("kill -9 %s 2>/dev/null", p))
                cnt = cnt + 1
            end
        end
        os.remove(tmp)
    end
    -- 清理所有相关的 sh 进程
    exec("ps | grep 'sh /sdcard/guardian/GuardianShell.sh' | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null")
    return "已停止 " .. cnt .. " 个进程"
end

function QMPlugin.GetStatus()
    if isRunning() then
        local pid = readFile(PID_FILE)
        return "运行中 PID:" .. pid
    else
        return "未运行"
    end
end
