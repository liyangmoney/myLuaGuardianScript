-- ============================================
-- 按键精灵移动版 - Shell守护启动插件
-- 版本: 4.6.0
-- 描述: 简化版，添加详细调试信息
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

local function generateScript(pkgName)
    local logName = "guardian_" .. os.date("%Y%m%d_%H%M%S") .. ".log"
    
    local sh = "#!/system/bin/sh\n"
        .. "PKG=\"" .. pkgName .. "\"\n"
        .. "HB_FILE=\"/sdcard/guardian/heartbeat.txt\"\n"
        .. "PID_FILE=\"/sdcard/guardian/guardian_shell.pid\"\n"
        .. "LOG=\"/sdcard/guardian/" .. logName .. "\"\n"
        .. "TIMEOUT=15\n"
        .. "CHECK_INT=5\n"
        .. "\n"
        .. "log() { echo \"[$(date +%H:%M:%S)] $1\" >> \"$LOG\"; }\n"
        .. "\n"
        .. "# Write PID\n"
        .. "echo $$ > \"$PID_FILE\"\n"
        .. "log \"=== Guardian Started ===\"\n"
        .. "log \"Package: $PKG\"\n"
        .. "log \"Timeout: ${TIMEOUT}s\"\n"
        .. "\n"
        .. "# Start app\n"
        .. "log \"Starting app...\"\n"
        .. "am force-stop \"$PKG\" 2>/dev/null\n"
        .. "sleep 1\n"
        .. "monkey -p \"$PKG\" -c android.intent.category.LAUNCHER 1 2>/dev/null\n"
        .. "log \"App launched\"\n"
        .. "\n"
        .. "# Init heartbeat\n"
        .. "echo 0 > \"$HB_FILE\"\n"
        .. "LAST_HB=0\n"
        .. "START_TIME=$(date +%s)\n"
        .. "RESTART_CNT=0\n"
        .. "\n"
        .. "while true; do\n"
        .. "  NOW=$(date +%s)\n"
        .. "  HB=$(cat \"$HB_FILE\" 2>/dev/null || echo 0)\n"
        .. "  \n"
        .. "  # Update heartbeat\n"
        .. "  if [ \"$HB\" -gt \"$LAST_HB\" ]; then\n"
        .. "    LAST_HB=$HB\n"
        .. "    log \"Heartbeat: $HB\"\n"
        .. "  fi\n"
        .. "  \n"
        .. "  # Calculate elapsed\n"
        .. "  if [ \"$LAST_HB\" -gt 0 ]; then\n"
        .. "    ELAPSED=$((NOW - LAST_HB))\n"
        .. "  else\n"
        .. "    ELAPSED=$((NOW - START_TIME))\n"
        .. "  fi\n"
        .. "  \n"
        .. "  # Check timeout\n"
        .. "  if [ \"$ELAPSED\" -gt \"$TIMEOUT\" ]; then\n"
        .. "    log \"TIMEOUT: ${ELAPSED}s - Restarting...\"\n"
        .. "    RESTART_CNT=$((RESTART_CNT + 1))\n"
        .. "    if [ \"$RESTART_CNT\" -gt 10 ]; then\n"
        .. "      log \"Max restart reached\"\n"
        .. "      break\n"
        .. "    fi\n"
        .. "    am force-stop \"$PKG\" 2>/dev/null\n"
        .. "    sleep 1\n"
        .. "    monkey -p \"$PKG\" -c android.intent.category.LAUNCHER 1 2>/dev/null\n"
        .. "    log \"Restarted (#$RESTART_CNT)\"\n"
        .. "    echo 0 > \"$HB_FILE\"\n"
        .. "    LAST_HB=0\n"
        .. "    START_TIME=$(date +%s)\n"
        .. "  fi\n"
        .. "  \n"
        .. "  touch \"$PID_FILE\"\n"
        .. "  sleep $CHECK_INT\n"
        .. "done\n"
        .. "\n"
        .. "rm -f \"$PID_FILE\"\n"
        .. "log \"=== Guardian Stopped ===\"\n"
    
    exec("mkdir -p /sdcard/guardian")
    writeFile(SHELL_SCRIPT, sh)
    exec("chmod +x " .. SHELL_SCRIPT)
end

function QMPlugin.Test()
    return "GuardianPlugin v4.6.0 OK"
end

function QMPlugin.SendHeartbeat()
    writeFile(HEARTBEAT_FILE, tostring(os.time()))
    return "OK"
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

function QMPlugin.StartGuardian()
    if isRunning() then return "守护已在运行" end
    if not fileExists(SHELL_SCRIPT) then return "脚本不存在" end
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
            exec(string.format("kill -9 %s 2>/dev/null", pid))
            cnt = cnt + 1
        end
        os.remove(PID_FILE)
    end
    local tmp = "/sdcard/guardian/.stop"
    exec(string.format("ps | grep GuardianShell | grep -v grep > %s", tmp))
    if fileExists(tmp) then
        local content = readFile(tmp)
        for line in content:gmatch("[^\r\n]+") do
            local p = line:match("^%s*(%d+)")
            if p then
                exec(string.format("kill -9 %s 2>/dev/null", p))
                cnt = cnt + 1
            end
        end
        os.remove(tmp)
    end
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
