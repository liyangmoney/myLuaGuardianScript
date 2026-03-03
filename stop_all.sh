#!/system/bin/sh
# ============================================
# 停止所有GuardianShell脚本
# 使用方法: sh /sdcard/guardian/stop_all.sh
# ============================================

echo "正在查找并停止所有GuardianShell进程..."

# 方法1: 通过PID文件停止
if [ -f "/sdcard/guardian/guardian_shell.pid" ]; then
    PID=$(cat /sdcard/guardian/guardian_shell.pid)
    echo "找到PID文件，PID: $PID"
    
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        echo "正在停止进程 $PID..."
        kill -TERM "$PID" 2>/dev/null
        sleep 2
        kill -9 "$PID" 2>/dev/null
        echo "进程已停止"
    else
        echo "进程已不存在"
    fi
    
    rm -f /sdcard/guardian/guardian_shell.pid
else
    echo "未找到PID文件"
fi

# 方法2: 通过进程名查找并停止
echo ""
echo "搜索所有GuardianShell进程..."
ps | grep "GuardianShell.sh" | grep -v grep

# 停止所有匹配的进程
ps | grep "GuardianShell.sh" | grep -v grep | while read line; do
    PID=$(echo "$line" | awk '{print $2}')
    if [ -n "$PID" ]; then
        echo "停止进程 $PID..."
        kill -9 "$PID" 2>/dev/null
    fi
done

# 清理临时文件
rm -f /sdcard/guardian/.check

echo ""
echo "检查是否还有残留进程..."
REMAIN=$(ps | grep "GuardianShell" | grep -v grep | grep -v "stop_all")
if [ -n "$REMAIN" ]; then
    echo "警告: 仍有残留进程:"
    echo "$REMAIN"
else
    echo "✓ 所有GuardianShell进程已清理完毕"
fi
