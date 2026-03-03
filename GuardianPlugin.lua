-- ============================================
-- 按键精灵移动版 - Shell守护启动插件
-- 文件名: GuardianPlugin.lua
-- 版本: 4.4.0
-- 描述: 使用纯Lua函数，修复日志和脚本启动问题
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
    if f then
        f:close()
        return true
    end
    return false
end

local function writeFile(path, content)
    local f = io.open(path, "w")
    if f then
        f:write(content)
        f:close()
        return true
    end
    return false
end

local function readFile(path)
    local f = io.open(path, "r")
    if f then
        local content = f:read("*all")
        f:close()
        return content or ""
    end
    return ""
end

local function isRunning()
    if not fileExists(PID_FILE) then
        return false
    end
    local pid = readFile(PID_FILE)
    pid = pid:gsub("%s+", "")
    if pid == "" then
        return false
    end
    local tmpfile = "/sdcard/guardian/.check"
    exec(string.format("ps | grep %s | grep -v grep > %s", pid, tmpfile))
    local exists = fileExists(tmpfile)
    if exists then
        os.remove(tmpfile)
    end
    return exists
end

local function generateScript(scriptName)
    -- 生成固定日志文件名
    local logFileName = "shell_guardian_" .. os.date("%Y%m%d_%H%M%S") .. ".log"
    
    local shell = "#!/system/bin/sh\n"
        .. "HEARTBEAT_FILE=\"/sdcard/guardian/heartbeat.txt\"\n"
        .. "HEARTBEAT_INTERVAL=5\n"
        .. "HEARTBEAT_TIMEOUT=15\n"
        .. "RESTART_DELAY=3\n"
        .. "MAX_RESTART=10\n"
        .. "RESTART_RESET_TIME=60\n"
        .. "LOG_FILE=\"/sdcard/guardian/" .. logFileName .. "\"\n"
        .. "PID_FILE=\"/sdcard/guardian/guardian_shell.pid\"\n"
        .. "MAIN_SCRIPT=\"" .. scriptName .. "\"\n"
        .. "\n"
        .. "log() {\n"
        .. "  local t=$(date +\"%H:%M:%S\")\n"
        .. "  echo \"[\"\"$t\"\"] [$1] $2\" >> \"$LOG_FILE\"\n"
        .. "}\n"
        .. "\n"
        .. "check_running() {\n"
        .. "  if [ -f \"$PID_FILE\" ]; then\n"
        .. "    local pid=$(cat \"$PID_FILE\")\n"
        .. "    if [ -n \"$pid\" ] && kill -0 \"$pid\" 2>/dev/null; then\n"
        .. "      return 0\n"
        .. "    fi\n"
        .. "    rm -f \"$PID_FILE\"\n"
        .. "  fi\n"
        .. "  return 1\n"
        .. "}\n"
        .. "\n"
        .. "start_script() {\n"
        .. "  log INFO \"Starting app: $MAIN_SCRIPT\"\n"
        .. "  # Force stop first\n"
        .. "  am force-stop \"$MAIN_SCRIPT\" 2>/dev/null\n"
        .. "  sleep 1\n"
        .. "  # Start app using monkey\n"
        .. "  monkey -p \"$MAIN_SCRIPT\" -c android.intent.category.LAUNCHER 1 2>/dev/null\n"
        .. "  sleep 3\n"
        .. "  log INFO \"App started\"\n"
        .. "}\n"
        .. "\n"
        .. "main() {\n"
        .. "  if check_running; then exit 1; fi\n"
        .. "  echo $$ > \"$PID_FILE\"\n"
        .. "  log INFO \"Guardian started\"\n"
        .. "  log INFO \"Log: $LOG_FILE\"\n"
        .. "  log INFO \"Script: $MAIN_SCRIPT\"\n"
        .. "  \n"
        .. "  start_script\n"
        .. "  \n"
        .. "  local last_hb=0\n"
        .. "  local restart_cnt=0\n"
        .. "  local last_restart=$(date +%s)\n"
        .. "  \n"
        .. "  while true; do\n"
        .. "    local hb=0\n"
        .. "    if [ -f \"$HEARTBEAT_FILE\" ]; then\n"
        .. "      hb=$(cat \"$HEARTBEAT_FILE\")\n"
        .. "    fi\n"
        .. "    local now=$(date +%s)\n"
        .. "    \n"
        .. "    # Update heartbeat if valid\n"
        .. "    if [ \"$hb\" != \"0\" ] && [ -n \"$hb\" ] && [ \"$hb\" -gt \"$last_hb\" ]; then\n"
        .. "      last_hb=$hb\n"
        .. "    fi\n"
        .. "    \n"
        .. "    # Check timeout (if we have a valid heartbeat)\n"
        .. "    if [ \"$last_hb\" -gt 0 ]; then\n"
        .. "      local elapsed=$((now - last_hb))\n"
        .. "      if [ \"$elapsed\" -gt \"$HEARTBEAT_TIMEOUT\" ]; then\n"
        .. "        log WARN \"Timeout: ${elapsed}s\"\n"
        .. "        local since_restart=$((now - last_restart))\n"
        .. "        if [ \"$since_restart\" -gt \"$RESTART_RESET_TIME\" ]; then\n"
        .. "          restart_cnt=0\n"
        .. "        fi\n"
        .. "        restart_cnt=$((restart_cnt + 1))\n"
        .. "        last_restart=$now\n"
        .. "        if [ \"$restart_cnt\" -gt \"$MAX_RESTART\" ]; then\n"
        .. "          log FATAL \"Max restart reached\"\n"
        .. "          break\n"
        .. "        fi\n"
        .. "        sleep \"$RESTART_DELAY\"\n"
        .. "        echo 0 > \"$HEARTBEAT_FILE\"\n"
        .. "        last_hb=0\n"
        .. "        start_script\n"
        .. "      fi\n"
        .. "    fi\n"
        .. "    \n"
        .. "    touch \"$PID_FILE\"\n"
        .. "    sleep \"$HEARTBEAT_INTERVAL\"\n"
        .. "  done\n"
        .. "  \n"
        .. "  rm -f \"$PID_FILE\"\n"
        .. "  log INFO \"Guardian stopped\"\n"
        .. "}\n"
        .. "\n"
        .. "trap 'rm -f \"$PID_FILE\"; exit 0' TERM INT\n"
        .. "main\n"
    
    exec("mkdir -p /sdcard/guardian")
    return writeFile(SHELL_SCRIPT, shell)
end

function QMPlugin.Test()
    return "GuardianPlugin v4.5.0 OK"
end

function QMPlugin.SendHeartbeat()
    writeFile(HEARTBEAT_FILE, tostring(os.time()))
    return "OK"
end

function QMPlugin.SetMainScript(scriptName)
    if isRunning() then
        return "守护运行中，请先停止"
    end
    
    local ok, err = pcall(function()
        generateScript(scriptName)
    end)
    
    if not ok then
        return "错误:" .. tostring(err)
    end
    
    exec(string.format("sh %s > /dev/null 2>&1 &", SHELL_SCRIPT))
    
    local startTime = os.time()
    while os.time() - startTime < 5 do
        if isRunning() then
            return "主脚本:" .. scriptName .. " | 守护已启动"
        end
    end
    
    return "错误:守护启动失败"
end

function QMPlugin.StartGuardian()
    if isRunning() then
        return "守护已在运行"
    end
    if not fileExists(SHELL_SCRIPT) then
        return "错误:脚本不存在"
    end
    exec(string.format("sh %s > /dev/null 2>&1 &", SHELL_SCRIPT))
    local startTime = os.time()
    while os.time() - startTime < 3 do
        if isRunning() then
            return "守护已启动"
        end
    end
    return "启动失败"
end

function QMPlugin.StopGuardian()
    if not fileExists(PID_FILE) then
        return "守护未运行"
    end
    local pid = readFile(PID_FILE)
    pid = pid:gsub("%s+", "")
    if pid ~= "" then
        exec(string.format("kill -TERM %s 2>/dev/null", pid))
        local startTime = os.time()
        while os.time() - startTime < 2 do end
        exec(string.format("kill -9 %s 2>/dev/null", pid))
    end
    os.remove(PID_FILE)
    return "守护已停止"
end

function QMPlugin.GetStatus()
    if isRunning() then
        local pid = readFile(PID_FILE)
        return "运行中 PID:" .. pid
    else
        return "未运行"
    end
end

-- 停止所有GuardianShell进程（清理残留）
function QMPlugin.StopAllGuardian()
    local result = ""
    local count = 0
    
    -- 方法1: 通过PID文件停止
    if fileExists(PID_FILE) then
        local pid = readFile(PID_FILE)
        pid = pid:gsub("%s+", "")
        if pid ~= "" then
            exec(string.format("kill -TERM %s 2>/dev/null", pid))
            local startTime = os.time()
            while os.time() - startTime < 2 do end
            exec(string.format("kill -9 %s 2>/dev/null", pid))
            result = result .. "已停止PID:" .. pid .. "\n"
            count = count + 1
        end
        os.remove(PID_FILE)
    end
    
    -- 方法2: 通过ps查找并停止所有GuardianShell进程
    local tmpfile = "/sdcard/guardian/.stop_check"
    exec(string.format("ps | grep GuardianShell.sh | grep -v grep > %s", tmpfile))
    
    if fileExists(tmpfile) then
        local content = readFile(tmpfile)
        for line in content:gmatch("[^\r\n]+") do
            local pid = line:match("^%s*(%d+)")
            if pid then
                exec(string.format("kill -9 %s 2>/dev/null", pid))
                result = result .. "已停止PID:" .. pid .. "\n"
                count = count + 1
            end
        end
        os.remove(tmpfile)
    end
    
    -- 清理临时文件
    os.remove("/sdcard/guardian/.check")
    
    if count > 0 then
        return "已停止 " .. count .. " 个进程:\n" .. result
    else
        return "未发现运行中的守护进程"
    end
end
