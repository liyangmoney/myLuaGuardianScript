-- ============================================
-- 按键精灵移动版 - Shell守护启动插件
-- 文件名: GuardianPlugin.lua
-- 版本: 4.3.0
-- 描述: 使用os.execute执行shell命令
-- 
-- 注意：按键精灵插件中Sys/File对象不可用，使用os.execute
-- ============================================

-- 定义插件命名空间
QMPlugin = {}

-- 配置
local SHELL_SCRIPT = "/sdcard/guardian/GuardianShell.sh"
local PID_FILE = "/sdcard/guardian/guardian_shell.pid"
local HEARTBEAT_FILE = "/sdcard/guardian/heartbeat.txt"

-- 简单的shell执行函数
local function exec(cmd)
    return os.execute(cmd)
end

-- 检查文件是否存在
local function fileExists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- 写入文件
local function writeFile(path, content)
    local f = io.open(path, "w")
    if f then
        f:write(content)
        f:close()
        return true
    end
    return false
end

-- 读取文件
local function readFile(path)
    local f = io.open(path, "r")
    if f then
        local content = f:read("*all")
        f:close()
        return content or ""
    end
    return ""
end

-- 检查Shell守护是否运行
local function isRunning()
    if not fileExists(PID_FILE) then
        return false
    end
    
    local pid = readFile(PID_FILE)
    pid = pid:gsub("%s+", "")
    
    if pid == "" then
        return false
    end
    
    -- 使用ps检查进程
    local tmpfile = "/sdcard/guardian/.check"
    exec(string.format("ps | grep %s | grep -v grep > %s", pid, tmpfile))
    local exists = fileExists(tmpfile)
    if exists then
        os.remove(tmpfile)
    end
    return exists
end

-- 生成Shell脚本
local function generateScript(scriptName)
    local shellContent = "#!/system/bin/sh\n"
        .. "# GuardianShell.sh (auto generated)\n"
        .. "HEARTBEAT_FILE=\"/sdcard/guardian/heartbeat.txt\"\n"
        .. "HEARTBEAT_INTERVAL=5\n"
        .. "HEARTBEAT_TIMEOUT=15\n"
        .. "RESTART_DELAY=3\n"
        .. "MAX_RESTART=10\n"
        .. "RESTART_RESET_TIME=60\n"
        .. "LOG_DIR=\"/sdcard/guardian\"\n"
        .. "PID_FILE=\"/sdcard/guardian/guardian_shell.pid\"\n"
        .. "MAIN_SCRIPT_NAME=\"" .. scriptName .. "\"\n"
        .. "\n"
        .. "log() {\n"
        .. "    local level=\"$1\"\n"
        .. "    local msg=\"$2\"\n"
        .. "    local time_str=$(date +\"%H:%M:%S\")\n"
        .. "    echo \"[${time_str}] [${level}] ${msg}\" >> \"$LOG_DIR/shell_guardian_$(date +%Y%m%d_%H%M%S).log\"\n"
        .. "}\n"
        .. "\n"
        .. "check_running() {\n"
        .. "    if [ -f \"$PID_FILE\" ]; then\n"
        .. "        local old_pid=$(cat \"$PID_FILE\")\n"
        .. "        if [ -n \"$old_pid\" ] && kill -0 \"$old_pid\" 2>/dev/null; then\n"
        .. "            return 0\n"
        .. "        fi\n"
        .. "        rm -f \"$PID_FILE\"\n"
        .. "    fi\n"
        .. "    return 1\n"
        .. "}\n"
        .. "\n"
        .. "update_pid() {\n"
        .. "    echo $$ > \"$PID_FILE\"\n"
        .. "}\n"
        .. "\n"
        .. "clear_pid() {\n"
        .. "    rm -f \"$PID_FILE\"\n"
        .. "}\n"
        .. "\n"
        .. "read_heartbeat() {\n"
        .. "    if [ -f \"$HEARTBEAT_FILE\" ]; then\n"
        .. "        cat \"$HEARTBEAT_FILE\"\n"
        .. "    else\n"
        .. "        echo 0\n"
        .. "    fi\n"
        .. "}\n"
        .. "\n"
        .. "get_time() {\n"
        .. "    date +%s\n"
        .. "}\n"
        .. "\n"
        .. "start_main() {\n"
        .. "    log INFO \"Start: $MAIN_SCRIPT_NAME\"\n"
        .. "    mkdir -p \"$LOG_DIR\"\n"
        .. "    echo $(get_time) > \"$HEARTBEAT_FILE\"\n"
        .. "    am start -a android.intent.action.MAIN -n com.cyjh.gundam/.activity.MainActivity 2>/dev/null\n"
        .. "    sleep 2\n"
        .. "}\n"
        .. "\n"
        .. "main_loop() {\n"
        .. "    if check_running; then exit 1; fi\n"
        .. "    update_pid\n"
        .. "    mkdir -p \"$LOG_DIR\"\n"
        .. "    log INFO \"Guardian started\"\n"
        .. "    start_main\n"
        .. "    local last_heartbeat=0\n"
        .. "    local restart_count=0\n"
        .. "    local last_restart_time=$(get_time)\n"
        .. "    while true; do\n"
        .. "        local hb=$(read_heartbeat)\n"
        .. "        local now=$(get_time)\n"
        .. "        if [ \"$hb\" != \"0\" ] && [ -n \"$hb\" ]; then\n"
        .. "            if [ \"$hb\" -gt \"$last_heartbeat\" ]; then\n"
        .. "                last_heartbeat=$hb\n"
        .. "            fi\n"
        .. "            local elapsed=$((now - last_heartbeat))\n"
        .. "            if [ \"$elapsed\" -gt \"$HEARTBEAT_TIMEOUT\" ]; then\n"
        .. "                log WARN \"Timeout: ${elapsed}s\"\n"
        .. "                restart_count=$((restart_count + 1))\n"
        .. "                if [ \"$restart_count\" -gt \"$MAX_RESTART\" ]; then\n"
        .. "                    log FATAL \"Max restart reached\"\n"
        .. "                    break\n"
        .. "                fi\n"
        .. "                sleep \"$RESTART_DELAY\"\n"
        .. "                start_main\n"
        .. "            fi\n"
        .. "        fi\n"
        .. "        touch \"$PID_FILE\"\n"
        .. "        sleep \"$HEARTBEAT_INTERVAL\"\n"
        .. "    done\n"
        .. "    clear_pid\n"
        .. "}\n"
        .. "trap 'clear_pid; exit 0' TERM INT\n"
        .. "main_loop\n"
    
    -- 创建目录
    exec("mkdir -p /sdcard/guardian")
    
    -- 写入脚本
    return writeFile(SHELL_SCRIPT, shellContent)
end

-- ==================== 插件导出函数 ====================

function QMPlugin.Test()
    return "GuardianPlugin v4.3.0 OK"
end

function QMPlugin.SendHeartbeat()
    writeFile(HEARTBEAT_FILE, tostring(TickCount()))
    return "OK"
end

function QMPlugin.SetMainScript(scriptName)
    if isRunning() then
        generateScript(scriptName)
        return "已设置:" .. scriptName .. " (运行中)"
    end
    
    local ok, err = pcall(function()
        generateScript(scriptName)
    end)
    
    if not ok then
        return "错误:" .. tostring(err)
    end
    
    -- 启动Shell
    exec(string.format("sh %s > /dev/null 2>&1 &", SHELL_SCRIPT))
    
    -- 等待启动（使用循环代替Delay）
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
    
    -- 等待启动
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
        -- 等待2秒
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
