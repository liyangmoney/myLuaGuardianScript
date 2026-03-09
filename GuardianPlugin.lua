-- ============================================
-- 按键精灵移动版 - Shell守护启动插件
-- 版本: 4.7.1
-- 描述: 修复字符串转义问题
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

-- 生成Shell脚本
local function generateScript(pkgName)
    local logName = "guardian_" .. os.date("%Y%m%d_%H%M%S") .. ".log"
    
    local lines = {}
    table.insert(lines, "#!/system/bin/sh")
    table.insert(lines, "PKG=\"" .. pkgName .. "\"")
    table.insert(lines, "HB_FILE=\"/sdcard/guardian/heartbeat.txt\"")
    table.insert(lines, "PID_FILE=\"/sdcard/guardian/guardian_shell.pid\"")
    table.insert(lines, "LOG=\"/sdcard/guardian/" .. logName .. "\"")
    table.insert(lines, "TIMEOUT=300")
    table.insert(lines, "CHECK_INT=30")
    table.insert(lines, "")
    table.insert(lines, "log() { echo \"[$(date +%H:%M:%S)] $1\" >> \"$LOG\"; }")
    table.insert(lines, "")
    table.insert(lines, "update_eventsrv() {")
    table.insert(lines, "  local files_dir=\"/data/data/$PKG/files\"")
    table.insert(lines, "  local target_file=\"$files_dir/start_eventsrvR\"")
    table.insert(lines, "  if [ ! -d \"$files_dir\" ]; then")
    table.insert(lines, "    log \"创建目录: $files_dir\"")
    table.insert(lines, "    mkdir -p \"$files_dir\" 2>/dev/null")
    table.insert(lines, "  fi")
    table.insert(lines, "  echo \"export CLASSPATH=/data/user/0/" .. pkgName .. "/files/DaemonClient.zip\" > \"$target_file\"")
    table.insert(lines, "  echo \"exec /system/bin/app_process32 /data/user/0/" .. pkgName .. "/files com.cyjh.mobileanjian.ipc.ClientService " .. pkgName .. ".event.localserver /data/user/0/" .. pkgName .. "/lib/libmqm.so 12030 &\" >> \"$target_file\"")
    table.insert(lines, "  chmod 755 \"$target_file\"")
    table.insert(lines, "  log \"已更新: $target_file\"")
    table.insert(lines, "}")
    table.insert(lines, "")
    table.insert(lines, "echo $$ > \"$PID_FILE\"")
    table.insert(lines, "log \"=== Guardian Started ===\"")
    table.insert(lines, "log \"Package: $PKG\"")
    table.insert(lines, "log \"Timeout: ${TIMEOUT}s\"")
    table.insert(lines, "log \"Waiting for first heartbeat...\"")
    table.insert(lines, "echo 0 > \"$HB_FILE\"")
    table.insert(lines, "LAST_HB=0")
    table.insert(lines, "START_TIME=$(date +%s)")
    table.insert(lines, "RESTART_CNT=0")
    table.insert(lines, "while true; do")
    table.insert(lines, "  NOW=$(date +%s)")
    table.insert(lines, "  HB=$(cat \"$HB_FILE\" 2>/dev/null || echo 0)")
    table.insert(lines, "  if [ \"$HB\" -gt \"$LAST_HB\" ]; then")
    table.insert(lines, "    LAST_HB=$HB")
    table.insert(lines, "    log \"Heartbeat: $HB\"")
    table.insert(lines, "  else")
    table.insert(lines, "    log \"Heartbeat: NULL\"")
    table.insert(lines, "  fi")
    table.insert(lines, "  if [ \"$HB\" = \"-999\" ]; then")
    table.insert(lines, "    log \"Exit signal received (-999), stopping...\"")
    table.insert(lines, "    break")
    table.insert(lines, "  fi")
    table.insert(lines, "  if [ \"$LAST_HB\" -gt 0 ]; then")
    table.insert(lines, "    ELAPSED=$((NOW - LAST_HB))")
    table.insert(lines, "  else")
    table.insert(lines, "    ELAPSED=$((NOW - START_TIME))")
    table.insert(lines, "  fi")
    table.insert(lines, "  if [ \"$ELAPSED\" -gt \"$TIMEOUT\" ]; then")
    table.insert(lines, "    log \"TIMEOUT: ${ELAPSED}s - Restarting...\"")
    table.insert(lines, "    RESTART_CNT=$((RESTART_CNT + 1))")
    table.insert(lines, "    if [ \"$RESTART_CNT\" -gt 10 ]; then")
    table.insert(lines, "      log \"Max restart reached\"")
    table.insert(lines, "      break")
    table.insert(lines, "    fi")
    table.insert(lines, "    log \"Stopping app...\"")
    table.insert(lines, "    am force-stop \"$PKG\" 2>/dev/null")
    table.insert(lines, "    sleep 1")
    table.insert(lines, "    update_eventsrv")
    table.insert(lines, "    log \"Starting app...\"")
    table.insert(lines, "    monkey -p \"$PKG\" -c android.intent.category.LAUNCHER 1 2>/dev/null")
    table.insert(lines, "    log \"App restarted, waiting 20s...\"")
    table.insert(lines, "    sleep 20")
    table.insert(lines, "    log \"Click 369,1216\"")
    table.insert(lines, "    input tap 369 1216")
    table.insert(lines, "    sleep 2")
    table.insert(lines, "    log \"Click 683,418\"")
    table.insert(lines, "    input tap 683 418")
    table.insert(lines, "    sleep 1")
    table.insert(lines, "    log \"Click 277,406\"")
    table.insert(lines, "    input tap 277 406")
    table.insert(lines, "    log \"Restarted (#$RESTART_CNT)\"")
    table.insert(lines, "    echo 0 > \"$HB_FILE\"")
    table.insert(lines, "    LAST_HB=0")
    table.insert(lines, "    START_TIME=$(date +%s)")
    table.insert(lines, "  fi")
    table.insert(lines, "  touch \"$PID_FILE\"")
    table.insert(lines, "  sleep $CHECK_INT")
    table.insert(lines, "done")
    table.insert(lines, "rm -f \"$PID_FILE\"")
    table.insert(lines, "log \"=== Guardian Stopped ===\"")
    
    local script = table.concat(lines, "\n")
    
    exec("mkdir -p /sdcard/guardian")
    writeFile(SHELL_SCRIPT, script)
    exec("chmod +x " .. SHELL_SCRIPT)
end

function QMPlugin.Test()
    return "GuardianPlugin v4.7.1 OK"
end

function QMPlugin.SendHeartbeat()
    writeFile(HEARTBEAT_FILE, tostring(os.time()))
    return "OK"
end

function QMPlugin.SendExitSignal()
    writeFile(HEARTBEAT_FILE, "-999")
    return "退出信号已发送"
end

function QMPlugin.SetMainScript(pkgName)
    if isRunning() then
        return "守护已在运行"
    end
    
    local ok, err = pcall(function()
        generateScript(pkgName)
    end)
    
    if not ok then
        return "错误:" .. tostring(err)
    end
    
    exec(string.format("sh %s > /dev/null 2>&1 &", SHELL_SCRIPT))
    
    local t = os.time()
    while os.time() - t < 5 do
        if isRunning() then
            return "包名:" .. pkgName .. " | 守护已启动"
        end
    end
    
    return "启动失败"
end

function QMPlugin.StartGuardian(pkgName)
    if isRunning() then return "守护已在运行" end
    
    local name = pkgName
    if not name then
        if fileExists(SHELL_SCRIPT) then
            local content = readFile(SHELL_SCRIPT)
            name = content:match('PKG="([^"]+)"')
        end
    end
    
    if not name then
        return "请先SetMainScript或在StartGuardian中传入包名"
    end
    
    generateScript(name)
    
    exec(string.format("sh %s > /dev/null 2>&1 &", SHELL_SCRIPT))
    local t = os.time()
    while os.time() - t < 3 do
        if isRunning() then return "守护已启动" end
    end
    return "启动失败"
end

function QMPlugin.StopGuardian()
    if not fileExists(PID_FILE) then return "守护未运行" end
    local pid = readFile(PID_FILE):gsub("%s+", "")
    if pid ~= "" then
        exec(string.format("kill -TERM %s 2>/dev/null", pid))
        local t = os.time()
        while os.time() - t < 5 do end
        exec(string.format("kill -9 %s 2>/dev/null", pid))
    end
    os.remove(PID_FILE)
    return "守护已停止"
end

function QMPlugin.StopAllGuardian()
    local cnt = 0
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
