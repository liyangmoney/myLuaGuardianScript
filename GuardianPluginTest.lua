-- ============================================
-- 按键精灵移动版 - Shell守护启动插件 (测试版)
-- 版本: 4.7.3-TEST
-- 描述: 测试深度清理逻辑，第一轮就执行
-- 配置: TIMEOUT=30s, CHECK_INT=10s, 首轮深度清理
-- ============================================

QMPlugin = {}

local SHELL_SCRIPT = "/sdcard/guardian/GuardianShell_test.sh"
local PID_FILE = "/sdcard/guardian/guardian_shell_test.pid"
local HEARTBEAT_FILE = "/sdcard/guardian/heartbeat_test.txt"

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
 local tmp = "/sdcard/guardian/.chk_test"
 exec(string.format("ps | grep %s | grep -v grep > %s", pid, tmp))
 local ex = fileExists(tmp)
 if ex then os.remove(tmp) end
 return ex
end

local function generateScript(pkgName)
 local logName = "guardian_test_" .. os.date("%Y%m%d_%H%M%S") .. ".log"
 
 local sh = {}
 table.insert(sh, "#!/system/bin/sh")
 table.insert(sh, "PKG=\"" .. pkgName .. "\"")
 table.insert(sh, "HB_FILE=\"/sdcard/guardian/heartbeat_test.txt\"")
 table.insert(sh, "PID_FILE=\"/sdcard/guardian/guardian_shell_test.pid\"")
 table.insert(sh, "LOG=\"/sdcard/guardian/" .. logName .. "\"")
 table.insert(sh, "TIMEOUT=30")
 table.insert(sh, "CHECK_INT=10")
 table.insert(sh, "")
 table.insert(sh, "log() { echo \"[$(date +%H:%M:%S)] $1\" >> \"$LOG\"; }")
 table.insert(sh, "")
 table.insert(sh, "echo $$ > \"$PID_FILE\"")
 table.insert(sh, "log \"=== Guardian Test Started ===\"")
 table.insert(sh, "log \"Package: $PKG\"")
 table.insert(sh, "log \"Timeout: ${TIMEOUT}s\"")
 table.insert(sh, "log \"Check Interval: ${CHECK_INT}s\"")
 table.insert(sh, "log \"[TEST MODE] 首轮直接走深度清理流程\"")
 table.insert(sh, "echo 0 > \"$HB_FILE\"")
 table.insert(sh, "LAST_HB=0")
 table.insert(sh, "START_TIME=$(date +%s)")
 table.insert(sh, "RESTART_CNT=4")  -- 初始设为4，第一轮+1后=5，直接触发深度清理
 table.insert(sh, "while true; do")
 table.insert(sh, " NOW=$(date +%s)")
 table.insert(sh, " HB=$(cat \"$HB_FILE\" 2>/dev/null || echo 0)")
 table.insert(sh, " if [ \"$HB\" -gt \"$LAST_HB\" ]; then")
 table.insert(sh, " LAST_HB=$HB")
 table.insert(sh, " RESTART_CNT=0")
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
 table.insert(sh, " log \"Elapsed: ${ELAPSED}s, Restart count: $RESTART_CNT\"")
 table.insert(sh, " if [ \"$ELAPSED\" -gt \"$TIMEOUT\" ]; then")
 table.insert(sh, " log \"TIMEOUT: ${ELAPSED}s - Restarting...\"")
 table.insert(sh, " RESTART_CNT=$((RESTART_CNT + 1))")
 table.insert(sh, " log \"Restart count: $RESTART_CNT\"")
 table.insert(sh, "")
 table.insert(sh, " # 测试模式：第一轮(RESTART_CNT>=5)就执行深度清理")
 table.insert(sh, " if [ \"$RESTART_CNT\" -ge 5 ]; then")
 table.insert(sh, " log \"[TEST] 执行深度清理流程...\"")
 table.insert(sh, "")
 table.insert(sh, " # 1. 强制停止应用")
 table.insert(sh, " log \"[TEST] Step 1: 强制停止应用\"")
 table.insert(sh, " am force-stop \"$PKG\" 2>/dev/null")
 table.insert(sh, " sleep 2")
 table.insert(sh, "")
 table.insert(sh, " # 2. 清理应用数据")
 table.insert(sh, " log \"[TEST] Step 2: 清理应用数据\"")
 table.insert(sh, " pm clear \"$PKG\" 2>/dev/null")
 table.insert(sh, " log \"应用数据已清理\"")
 table.insert(sh, " sleep 2")
 table.insert(sh, "")
 table.insert(sh, " # 3. 授予所有权限（包括浮窗、电话、短信、通讯录）")
 table.insert(sh, " log \"[TEST] Step 3: 授予所有权限\"")
 table.insert(sh, " log \"[TEST] 授予浮窗权限...\"")
 table.insert(sh, " FLOAT_SUCCESS=0")
 table.insert(sh, " if su -c \"appops set --user 0 '$PKG' SYSTEM_ALERT_WINDOW allow\" 2>/dev/null; then")
 table.insert(sh, " log \"[TEST] 方式1成功: su appops set\"")
 table.insert(sh, " FLOAT_SUCCESS=1")
 table.insert(sh, " elif su -c \"cmd appops set '$PKG' SYSTEM_ALERT_WINDOW allow\" 2>/dev/null; then")
 table.insert(sh, " log \"[TEST] 方式1b成功: su cmd appops\"")
 table.insert(sh, " FLOAT_SUCCESS=1")
 table.insert(sh, " fi")
 table.insert(sh, " if [ \"$FLOAT_SUCCESS\" = \"0\" ]; then")
 table.insert(sh, " if appops set --user 0 \"$PKG\" SYSTEM_ALERT_WINDOW allow 2>/dev/null; then")
 table.insert(sh, " log \"[TEST] 方式2成功: appops set\"")
 table.insert(sh, " FLOAT_SUCCESS=1")
 table.insert(sh, " elif cmd appops set \"$PKG\" SYSTEM_ALERT_WINDOW allow 2>/dev/null; then")
 table.insert(sh, " log \"[TEST] 方式2b成功: cmd appops\"")
 table.insert(sh, " FLOAT_SUCCESS=1")
 table.insert(sh, " fi")
 table.insert(sh, " fi")
 table.insert(sh, " if [ \"$FLOAT_SUCCESS\" = \"0\" ]; then")
 table.insert(sh, " su -c \"settings put secure sys_alert_window_apps '$PKG'\" 2>/dev/null || true")
 table.insert(sh, " su -c \"settings put system sys_alert_window_apps '$PKG'\" 2>/dev/null || true")
 table.insert(sh, " log \"[TEST] 方式3已尝试: settings写入\"")
 table.insert(sh, " fi")
 table.insert(sh, " FLOAT_MODE=\"$(su -c \"appops get '$PKG' SYSTEM_ALERT_WINDOW\" 2>/dev/null || appops get \"$PKG\" SYSTEM_ALERT_WINDOW 2>/dev/null || echo 'UNKNOWN')\"")
 table.insert(sh, " log \"[TEST] 浮窗权限状态: $FLOAT_MODE\"")
 table.insert(sh, " pm grant \"$PKG\" android.permission.READ_EXTERNAL_STORAGE 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.WRITE_EXTERNAL_STORAGE 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.CAMERA 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.RECORD_AUDIO 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.CALL_PHONE 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.READ_PHONE_STATE 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.READ_CALL_LOG 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.WRITE_CALL_LOG 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.PROCESS_OUTGOING_CALLS 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.SEND_SMS 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.RECEIVE_SMS 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.READ_SMS 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.WRITE_SMS 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.READ_CONTACTS 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.WRITE_CONTACTS 2>/dev/null || true")
 table.insert(sh, " pm grant \"$PKG\" android.permission.GET_ACCOUNTS 2>/dev/null || true")
 table.insert(sh, " log \"权限已授予（含电话、短信、通讯录）\"")
 table.insert(sh, " sleep 1")
 table.insert(sh, "")
 table.insert(sh, " # 4. 启动应用")
 table.insert(sh, " log \"[TEST] Step 4: 启动应用\"")
 table.insert(sh, " monkey -p \"$PKG\" -c android.intent.category.LAUNCHER 1 2>/dev/null")
 table.insert(sh, " log \"应用已启动，等待界面加载...\"")
 table.insert(sh, " sleep 20")
 table.insert(sh, "")
 table.insert(sh, " # 5. 初始点击（权限弹窗等）")
 table.insert(sh, " log \"[TEST] 点击 369,1216\"")
 table.insert(sh, " input tap 369 1216")
 table.insert(sh, " sleep 2")
 table.insert(sh, " log \"[TEST] 点击 358,778\"")
 table.insert(sh, " input tap 358 778")
 table.insert(sh, " sleep 2")
 table.insert(sh, " log \"[TEST] 按返回键\"")
 table.insert(sh, " input keyevent 4")
 table.insert(sh, " sleep 2")
 table.insert(sh, "")
 table.insert(sh, " # 6. 执行自动点击")
 table.insert(sh, " log \"[TEST] Step 6: 执行自动点击流程\"")
 table.insert(sh, " input tap 369 1216")
 table.insert(sh, " sleep 2")
 table.insert(sh, " input tap 683 418")
 table.insert(sh, " sleep 1")
 table.insert(sh, " input tap 277 406")
 table.insert(sh, " log \"点击流程完成\"")
 table.insert(sh, "")
 table.insert(sh, " # 动态等待：检测 script.uip 文件是否变化（最多120秒）")
 table.insert(sh, " log \"[TEST] 等待应用完成初始化...\"")
 table.insert(sh, " WAIT_START=$(date +%s)")
 table.insert(sh, " LAST_MTIME=0")
 table.insert(sh, " STABLE_COUNT=0")
 table.insert(sh, " TARGET_FILE=\"/data/data/" .. pkgName .. "/files/script.uip\"")
 table.insert(sh, " while true; do")
 table.insert(sh, " NOW=$(date +%s)")
 table.insert(sh, " ELAPSED=$((NOW - WAIT_START))")
 table.insert(sh, " if [ \"$ELAPSED\" -gt 120 ]; then")
 table.insert(sh, " log \"[TEST] 等待超时(120s)，重新走深度清理流程\"")
 table.insert(sh, " RESTART_CNT=5")
 table.insert(sh, " continue")
 table.insert(sh, " fi")
 table.insert(sh, " CURRENT_MTIME=$(su -c \"stat -c '%Y' \\\"$TARGET_FILE\\\" 2>/dev/null\" 2>/dev/null || stat -c '%Y' \"$TARGET_FILE\" 2>/dev/null || echo '0')")
 table.insert(sh, " if [ \"$CURRENT_MTIME\" = \"$LAST_MTIME\" ] && [ \"$CURRENT_MTIME\" != \"0\" ]; then")
 table.insert(sh, " STABLE_COUNT=$((STABLE_COUNT + 1))")
 table.insert(sh, " else")
 table.insert(sh, " if [ \"$CURRENT_MTIME\" != \"0\" ]; then")
 table.insert(sh, " LAST_MTIME=$CURRENT_MTIME")
 table.insert(sh, " STABLE_COUNT=0")
 table.insert(sh, " log \"[TEST] 检测到 script.uip 变化，mtime: $CURRENT_MTIME\"")
 table.insert(sh, " fi")
 table.insert(sh, " fi")
 table.insert(sh, " if [ \"$STABLE_COUNT\" -ge 3 ] && [ \"$LAST_MTIME\" != \"0\" ]; then")
 table.insert(sh, " log \"[TEST] 应用初始化完成，script.uip 稳定，等待时间: ${ELAPSED}s\"")
 table.insert(sh, " break")
 table.insert(sh, " fi")
 table.insert(sh, " sleep 2")
 table.insert(sh, " done")
 table.insert(sh, "")
 table.insert(sh, " # 7. 关闭应用")
 table.insert(sh, " log \"[TEST] Step 7: 关闭应用\"")
 table.insert(sh, " am force-stop \"$PKG\" 2>/dev/null")
 table.insert(sh, " log \"应用已关闭\"")
 table.insert(sh, " sleep 1")
 table.insert(sh, "")
 table.insert(sh, " # 8. 恢复备份的配置文件")
 table.insert(sh, " log \"[TEST] Step 8: 恢复备份配置...\"")
 table.insert(sh, " BACKUP_CFG=\"/data/data/script.cfg\"")
 table.insert(sh, " TARGET_CFG=\"/data/data/" .. pkgName .. "/files/script.cfg\"")
 table.insert(sh, " if [ -f \"\\$BACKUP_CFG\" ]; then")
 table.insert(sh, " if su -c \"cp '\\$BACKUP_CFG' '\\$TARGET_CFG'\" 2>/dev/null; then")
 table.insert(sh, " log \"[TEST] 备份配置已恢复: script.cfg\"")
 table.insert(sh, " elif cp \"\\$BACKUP_CFG\" \"\\$TARGET_CFG\" 2>/dev/null; then")
 table.insert(sh, " log \"[TEST] 备份配置已恢复: script.cfg\"")
 table.insert(sh, " else")
 table.insert(sh, " log \"[TEST] 警告: 无法恢复备份配置\"")
 table.insert(sh, " fi")
 table.insert(sh, " else")
 table.insert(sh, " log \"[TEST] 未找到备份配置: /data/data/script.cfg\"")
 table.insert(sh, " fi")
 table.insert(sh, " sleep 1")
 table.insert(sh, "")
 table.insert(sh, " # 9. 重置计数器，重新走正常启动流程")
 table.insert(sh, " log \"[TEST] 重新走启动流程...\"")
 table.insert(sh, " RESTART_CNT=0")
 table.insert(sh, " echo 0 > \"$HB_FILE\"")
 table.insert(sh, " LAST_HB=0")
 table.insert(sh, " START_TIME=$(date +%s)")
 table.insert(sh, " log \"=== [TEST] 深度清理完成，重新开始守护流程 ===\"")
 table.insert(sh, " continue")
 table.insert(sh, " fi")
 table.insert(sh, "")
 table.insert(sh, " # 正常重启流程（5次以内）- 测试模式下不会走到这里")
 table.insert(sh, " log \"Normal restart (should not happen in test mode)...\"")
 table.insert(sh, " am force-stop \"$PKG\" 2>/dev/null")
 table.insert(sh, " sleep 1")
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
 table.insert(sh, " START_TIME=$(date +%s)")
 table.insert(sh, " fi")
 table.insert(sh, " touch \"$PID_FILE\"")
 table.insert(sh, " sleep $CHECK_INT")
 table.insert(sh, "done")
 table.insert(sh, "rm -f \"$PID_FILE\"")
 table.insert(sh, "log \"=== Guardian Test Stopped ===\"")
 
 local script = table.concat(sh, "\n")
 exec("mkdir -p /sdcard/guardian")
 writeFile(SHELL_SCRIPT, script)
 exec("chmod +x " .. SHELL_SCRIPT)
end

function QMPlugin.Test()
 return "GuardianPluginTest v4.7.3-TEST OK"
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
 return "测试守护已在运行"
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
 return "[TEST] 包名:" .. pkgName .. " | 测试守护已启动"
 end
 end
 
 return "启动失败"
end

function QMPlugin.StartGuardian(pkgName)
 if isRunning() then return "测试守护已在运行" end
 
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
 if isRunning() then return "测试守护已启动" end
 end
 return "启动失败"
end

function QMPlugin.StopGuardian()
 if not fileExists(PID_FILE) then return "测试守护未运行" end
 local pid = readFile(PID_FILE):gsub("%s+", "")
 if pid ~= "" then
 exec(string.format("kill -TERM %s 2>/dev/null", pid))
 local t = os.time()
 while os.time() - t < 5 do end
 exec(string.format("kill -9 %s 2>/dev/null", pid))
 end
 os.remove(PID_FILE)
 return "测试守护已停止"
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
 local tmp = "/sdcard/guardian/.stop_test"
 exec(string.format("ps | grep GuardianShell_test | grep -v grep > %s", tmp))
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
 exec("ps | grep 'sh /sdcard/guardian/GuardianShell_test.sh' | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null")
 return "[TEST] 已停止 " .. cnt .. " 个进程"
end

function QMPlugin.GetStatus()
 if isRunning() then
 local pid = readFile(PID_FILE)
 return "[TEST] 运行中 PID:" .. pid
 else
 return "[TEST] 未运行"
 end
end
