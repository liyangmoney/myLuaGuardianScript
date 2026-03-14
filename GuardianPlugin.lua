-- ============================================
-- 按键精灵移动版 - Shell守护启动插件
-- 版本: 4.7.3
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

local function generateScript(pkgName)
 local logName = "guardian_" .. os.date("%Y%m%d_%H%M%S") .. ".log"
 
 local sh = {}
 table.insert(sh, "#!/system/bin/sh")
 table.insert(sh, "PKG=\"" .. pkgName .. "\"")
 table.insert(sh, "HB_FILE=\"/sdcard/guardian/heartbeat.txt\"")
 table.insert(sh, "PID_FILE=\"/sdcard/guardian/guardian_shell.pid\"")
 table.insert(sh, "LOG=\"/sdcard/guardian/" .. logName .. "\"")
 table.insert(sh, "TIMEOUT=300")
 table.insert(sh, "CHECK_INT=30")
 table.insert(sh, "")
 table.insert(sh, "log() { echo \"[$(date +%H:%M:%S)] $1\" >> \"$LOG\"; }")
 table.insert(sh, "")
 table.insert(sh, "update_eventsrv() {")
 table.insert(sh, " local files_dir=\"/data/data/$PKG/files\"")
 table.insert(sh, " local target_file=\"$files_dir/start_eventsrvR\"")
 table.insert(sh, " if [ ! -d \"$files_dir\" ]; then")
 table.insert(sh, " log \"创建目录: $files_dir\"")
 table.insert(sh, " mkdir -p \"$files_dir\" 2>/dev/null")
 table.insert(sh, " fi")
 table.insert(sh, " echo \"export CLASSPATH=/data/user/0/" .. pkgName .. "/files/DaemonClient.zip\" > \"$target_file\"")
 table.insert(sh, " echo \"exec /system/bin/app_process32 /data/user/0/" .. pkgName .. "/files com.cyjh.mobileanjian.ipc.ClientService " .. pkgName .. ".event.localserver /data/user/0/" .. pkgName .. "/lib/libmqm.so 12030 &\" >> \"$target_file\"")
 table.insert(sh, " chmod 755 \"$target_file\"")
 table.insert(sh, " log \"已更新: $target_file\"")
 table.insert(sh, "}")
 table.insert(sh, "")
 table.insert(sh, "echo $$ > \"$PID_FILE\"")
 table.insert(sh, "log \"=== Guardian Started ===\"")
 table.insert(sh, "log \"Package: $PKG\"")
 table.insert(sh, "log \"Timeout: ${TIMEOUT}s\"")
 table.insert(sh, "log \"Waiting for first heartbeat...\"")
 table.insert(sh, "echo 0 > \"$HB_FILE\"")
 table.insert(sh, "LAST_HB=0")
 table.insert(sh, "START_TIME=$(date +%s)")
 table.insert(sh, "RESTART_CNT=0")
 table.insert(sh, "while true; do")
 table.insert(sh, " NOW=$(date +%s)")
 table.insert(sh, " HB=$(cat \"$HB_FILE\" 2>/dev/null || echo 0)")
 table.insert(sh, " if [ \"$HB\" -gt \"$LAST_HB\" ]; then")
 table.insert(sh, " LAST_HB=$HB")
 table.insert(sh, " RESTART_CNT=0")  -- 重启成功后重置计数
 table.insert(sh, " log \"Heartbeat: $HB\"")
 table.insert(sh, " else")
 table.insert(sh, " log \"Heartbeat: NULL\"")
 table.insert(sh, " fi")
 table.insert(sh, " if [ \"$HB\" = \"-999\" ]; then")
 table.insert(sh, " log \"Exit signal received (-999), stopping...\"")
 table.insert(sh, " break")
 table.insert(sh, " fi")
 table.insert(sh, " if [ \"$LAST_HB\" -gt 0 ]; then")
 table.insert(sh, " ELAPSED=$((NOW - LAST_HB))")
 table.insert(sh, " else")
 table.insert(sh, " ELAPSED=$((NOW - START_TIME))")
 table.insert(sh, " fi")
 table.insert(sh, " if [ \"$ELAPSED\" -gt \"$TIMEOUT\" ]; then")
 table.insert(sh, " log \"TIMEOUT: ${ELAPSED}s - Restarting...\"")
 table.insert(sh, " RESTART_CNT=$((RESTART_CNT + 1))")
 table.insert(sh, " log \"Restart count: $RESTART_CNT\"")
 table.insert(sh, "")
 table.insert(sh, " # 连续5次重启失败，深度清理后重试")
 table.insert(sh, " if [ \"$RESTART_CNT\" -ge 5 ]; then")
 table.insert(sh, " log \"连续5次重启失败，执行深度清理...\"")
 table.insert(sh, "")
 table.insert(sh, " # 1. 强制停止应用")
 table.insert(sh, " am force-stop \"$PKG\" 2>/dev/null")
 table.insert(sh, " sleep 2")
 table.insert(sh, "")
 table.insert(sh, " # 2. 清理应用数据")
 table.insert(sh, " pm clear \"$PKG\" 2>/dev/null")
 table.insert(sh, " log \"应用数据已清理\"")
 table.insert(sh, " sleep 2")
 table.insert(sh, "")
 table.insert(sh, " # 3. 授予所有权限（包括浮窗）")
 table.insert(sh, " pm grant \"$PKG\" android.permission.SYSTEM_ALERT_WINDOW 2>/dev/null || true")
 table.insert(sh, " appops set \"$PKG\" SYSTEM_ALERT_WINDOW allow 2>/dev/null || true")
 table.insert(sh, " # 授予其他常见权限")
 table.insert(sh, " pm grant \"$PKG\" android.permission.READ_EXTERNAL_STORAGE 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.WRITE_EXTERNAL_STORAGE 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.CAMERA 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.RECORD_AUDIO 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true")
 table.insert(sh, " log \"权限已授予\"")
 table.insert(sh, " sleep 1")
 table.insert(sh, "")
 table.insert(sh, " # 4. 启动应用")
 table.insert(sh, " update_eventsrv")
 table.insert(sh, " monkey -p \"$PKG\" -c android.intent.category.LAUNCHER 1 2>/dev/null")
 table.insert(sh, " log \"应用已启动，等待界面加载...\"")
 table.insert(sh, " sleep 20")
 table.insert(sh, "")
 table.insert(sh, " # 5. 执行自动点击")
 table.insert(sh, " log \"执行自动点击流程\"")
 table.insert(sh, " input tap 369 1216")
 table.insert(sh, " sleep 2")
 table.insert(sh, " input tap 683 418")
 table.insert(sh, " sleep 1")
 table.insert(sh, " input tap 277 406")
 table.insert(sh, " log \"点击流程完成\"")
 table.insert(sh, " sleep 20")
 table.insert(sh, "")
 table.insert(sh, " # 6. 关闭应用")
 table.insert(sh, " am force-stop \"$PKG\" 2>/dev/null")
 table.insert(sh, " log \"应用已关闭，重新走启动流程\"")
 table.insert(sh, " sleep 3")
 table.insert(sh, "")
 table.insert(sh, " # 7. 重置计数器，重新走正常启动流程")
 table.insert(sh, " RESTART_CNT=0")
 table.insert(sh, " echo 0 > \"$HB_FILE\"")
 table.insert(sh, " LAST_HB=0")
 table.insert(sh, " START_TIME=$(date +%s)")
 table.insert(sh, " log \"=== 重新开始守护流程 ===\"")
 table.insert(sh, " continue")
 table.insert(sh, " fi")
 table.insert(sh, "")
 table.insert(sh, " # 正常重启流程（5次以内）")
 table.insert(sh, " log \"Stopping app...\"")
 table.insert(sh, " am force-stop \"$PKG\" 2>/dev/null")
 table.insert(sh, " sleep 1")
 table.insert(sh, " update_eventsrv")
 table.insert(sh, " log \"Starting app...\"")
 table.insert(sh, " monkey -p \"$PKG\" -c android.intent.category.LAUNCHER 1 2>/dev/null")
 table.insert(sh, " log \"App restarted, waiting 20s...\"")
 table.insert(sh, " sleep 20")
 table.insert(sh, " log \"Click 369,1216\"")
 table.insert(sh, " input tap 369 1216")
 table.insert(sh, " sleep 2")
 table.insert(sh, " log \"Click 683,418\"")
 table.insert(sh, " input tap 683 418")
 table.insert(sh, " sleep 1")
 table.insert(sh, " log \"Click 277,406\"")
 table.insert(sh, " input tap 277 406")
 table.insert(sh, " log \"Restarted (#$RESTART_CNT)\"")
 table.insert(sh, " echo 0 > \"$HB_FILE\"")
 table.insert(sh, " LAST_HB=0")
 table.insert(sh, " START_TIME=$(date +s)")
 table.insert(sh, " fi")
 table.insert(sh, " touch \"$PID_FILE\"")
 table.insert(sh, " sleep $CHECK_INT")
 table.insert(sh, "done")
 table.insert(sh, "rm -f \"$PID_FILE\"")
 table.insert(sh, "log \"=== Guardian Stopped ===\"")
 
 local script = table.concat(sh, "\n")
 exec("mkdir -p /sdcard/guardian")
 writeFile(SHELL_SCRIPT, script)
 exec("chmod +x " .. SHELL_SCRIPT)
end

function QMPlugin.Test()
 return "GuardianPlugin v4.7.3 OK"
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
 for line in string.gmatch(content, "[^\r\n]+") do
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
