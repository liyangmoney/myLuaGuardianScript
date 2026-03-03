# 按键精灵移动版 - 进程守护

提供三种守护方案：
1. **Shell独立进程版** ⭐⭐⭐ **强烈推荐** - Shell脚本作为独立进程运行
2. **独立脚本版** (`GuardianRunner.lua`) - Lua脚本独立运行
3. **插件版** (`GuardianPlugin.lua`) - 作为插件导入

## 📁 文件说明

| 文件 | 说明 |
|------|------|
| `GuardianShell.sh` | **Shell守护脚本** ⭐⭐⭐ **推荐** - 独立进程，真正独立于按键精灵 |
| `GuardianPlugin.lua` | **启动插件** - 用于启动Shell守护 |
| `GuardianRunner.lua` | Lua独立守护脚本 |
| `Heartbeat.lua` | 心跳模块 |
| `MainScript.lua` | 主脚本示例 |

---

## 🚀 强烈推荐方案：Shell独立进程守护

### 方案优势

| 特性 | Shell版 | Lua脚本版 | 插件版 |
|------|---------|-----------|--------|
| 进程独立性 | ⭐⭐⭐⭐⭐ 系统级独立进程 | ⭐⭐ 同APP内线程 | ⭐ 同脚本内 |
| 按键精灵退出后 | ✅ 继续运行 | ❌ 停止 | ❌ 停止 |
| 系统杀死后 | ❌ 停止（需配合其他工具） | ❌ 停止 | ❌ 停止 |
| 资源占用 | 极低 | 低 | 最低 |

### Shell独立进程使用方法

#### 1. 放置文件

```
/sdcard/guardian/
├── GuardianShell.sh     (Shell守护脚本)
├── heartbeat.txt        (心跳文件，自动创建)
├── guardian_shell.pid   (PID文件，自动创建)
└── shell_guardian_*.log (日志文件，自动创建)

/按键精灵/Plugin/
└── GuardianPlugin.lua   (启动插件)
```

#### 2. 在主脚本中添加心跳

```lua
-- 主脚本开头导入插件
Import "GuardianPlugin"

-- 主循环中定时发送心跳
while true do
    GuardianPlugin.SendHeartbeat()  -- 发送心跳
    -- 你的业务代码...
    Delay(3000)
end
```

#### 3. 启动Shell守护（一行代码）

**新功能：SetMainScript 自动完成一切**

```lua
Import "GuardianPlugin"

-- 只需调用 SetMainScript，它会自动：
-- 1. 检测 Shell 守护是否已运行
-- 2. 如未运行，自动生成 GuardianShell.sh
-- 3. 自动启动 Shell 守护进程
local result = GuardianPlugin.SetMainScript("你的主脚本名称")
TracePrint(result)  -- 输出: 主脚本:XXX | Shell守护已自动生成并启动
```

**传统方式（如需单独控制）**
```lua
Import "GuardianPlugin"

-- 手动设置主脚本（Shell守护必须已存在）
GuardianPlugin.SetMainScript("你的主脚本名称")

-- 手动启动 Shell 守护
GuardianPlugin.StartGuardian()
```

**方式3：直接启动Shell脚本（无需插件）**
```bash
# 在终端执行
sh /sdcard/guardian/GuardianShell.sh
```

#### 4. 停止守护

```lua
Import "GuardianPlugin"
GuardianPlugin.StopGuardian()
```

---

## 📂 日志位置

### Shell守护日志
```
/sdcard/guardian/shell_guardian_YYYYMMDD_HHMMSS.log
```

示例：
```
/sdcard/guardian/shell_guardian_20250303_091245.log
```

日志内容示例：
```
[09:12:45] [INFO] ========================================
[09:12:45] [INFO] Shell守护脚本 v1.0.0 启动
[09:12:45] [INFO] 目标脚本: MainScript
[09:12:45] [INFO] ========================================
[09:12:46] [INFO] 主脚本启动完成
[09:13:46] [INFO] 状态:运行正常 运行:1分0秒 重启:0次
```

日志文件按启动时间命名，保存在：
```
/sdcard/guardian/guardian_log_YYYYMMDD_HHMMSS.txt
```

**示例**：
```
/sdcard/guardian/guardian_log_20250303_091245.txt
```

**说明**：
- 每次启动守护都会生成新的日志文件（按时间命名）
- 所有运行日志写入该文件
- 如需清理旧日志，手动删除 /sdcard/guardian/ 目录下的文件即可

## 🔒 防重复启动机制

插件使用**文件锁**机制防止重复启动：

1. **启动检查**: `StartGuardian()` 会先检查 `/sdcard/guardian/guardian.lock` 文件
2. **锁超时**: 如果锁文件存在且超过60秒未更新，认为已过期，可以抢占
3. **锁更新**: 守护进程每60秒更新锁文件时间戳
4. **自动释放**: 停止守护时自动删除锁文件

**强制重置**: 如果发生异常导致锁未释放，可使用：
```lua
GuardianPlugin.ResetGuardian()  -- 强制清理锁状态
```

## 🚀 安装步骤

### 1. 放置插件文件

将 `GuardianPlugin.lua` 复制到按键精灵安装目录的 **Plugin** 文件夹：
```
/按键精灵/Plugin/
└── GuardianPlugin.lua
```

### 2. 刷新插件

在按键精灵左侧的【全部命令】中，右键点击【插件命令】，选择【刷新】。

### 3. 在主脚本中导入插件

在需要使用守护功能的主脚本开头添加：
```lua
Import "GuardianPlugin"
```

## 🔌 使用方式

### 启动守护

```lua
Import "GuardianPlugin"

-- 启动守护（会自动检查是否已运行）
local result = GuardianPlugin.StartGuardian()
TracePrint(result)  -- 输出: 守护已启动 或 守护已在运行中
```

### 在主脚本中发送心跳

```lua
Import "GuardianPlugin"

-- 主循环中定时发送心跳
while true do
    GuardianPlugin.SendHeartbeat()   -- 发送心跳
    -- 你的业务代码...
    Delay(3000)
end
```

### 设置主脚本并自动启动守护（推荐）

```lua
-- 一行代码完成所有操作：
-- 1. 检测 Shell 守护是否已运行
-- 2. 如未运行，自动生成 GuardianShell.sh
-- 3. 自动启动 Shell 守护
local result = GuardianPlugin.SetMainScript("你的主脚本名称")
TracePrint(result)
-- 输出示例: "主脚本:你的主脚本名称 | Shell守护已自动生成并启动"
```

### 停止守护

```lua
GuardianPlugin.StopGuardian()
```

### 获取守护状态

```lua
local status = GuardianPlugin.GetStatus()
TracePrint(status)  -- 输出: Shell守护运行中 PID:12345
```

### 发送心跳（主脚本中调用）

```lua
-- 在主脚本的主循环中定时发送
GuardianPlugin.SendHeartbeat()
```

## ⚙️ 插件配置

编辑 `GuardianPlugin.lua` 修改默认配置：

```lua
local CONFIG = {
    -- 主脚本配置
    MAIN_SCRIPT_NAME = "MainScript",
    MAIN_SCRIPT_PATH = "/sdcard/guardian/script/MainScript.lua",
    
    -- 心跳配置
    HEARTBEAT_FILE = "/sdcard/guardian/heartbeat.txt",
    HEARTBEAT_INTERVAL = 5000,      -- 检测间隔 5秒
    HEARTBEAT_TIMEOUT = 15000,      -- 超时时间 15秒
    
    -- 锁文件配置
    LOCK_FILE = "/sdcard/guardian/guardian.lock",
    
    -- 日志配置 (按时间命名)
    LOG_DIR = "/sdcard/guardian/",
    LOG_PREFIX = "guardian_log_",
    
    -- 重启配置
    RESTART_DELAY = 3000,
    MAX_RESTART_ATTEMPTS = 10,
    RESTART_RESET_TIME = 60000,
}
```

## 📊 导出函数列表

| 函数名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `SetMainScript(name)` | 脚本名称 | 字符串 | **推荐** 设置主脚本并自动启动Shell守护（如未运行则自动生成） |
| `StartGuardian()` | 无 | 字符串 | 手动启动守护（需Shell脚本已存在） |
| `StopGuardian()` | 无 | 字符串 | 停止Shell守护 |
| `SendHeartbeat()` | 无 | 字符串 | 发送心跳（主脚本调用） |
| `GetStatus()` | 无 | 字符串 | 获取Shell守护运行状态 |
| `Test()` | 无 | 字符串 | 测试插件加载 |

## 📝 完整示例

### 方式1：一行代码启动（推荐）

```lua
Import "GuardianPlugin"

-- 测试插件
TracePrint(GuardianPlugin.Test())  -- GuardianPlugin v4.1.0 (Shell版) 加载成功

-- 一行代码：设置主脚本并自动启动Shell守护
-- 如Shell脚本不存在会自动生成，如守护未运行会自动启动
local result = GuardianPlugin.SetMainScript("我的主脚本")
TracePrint(result)
-- 输出: "主脚本:我的主脚本 | Shell守护已自动生成并启动"
```

### 方式2：手动分步启动

```lua
Import "GuardianPlugin"

-- 手动设置主脚本（Shell脚本必须已存在）
GuardianPlugin.SetMainScript("我的主脚本")

-- 手动启动守护
local result = GuardianPlugin.StartGuardian()
TracePrint(result)
```

### 被守护的主脚本

```lua
Import "GuardianPlugin"

function Main()
    TracePrint("主脚本启动")
    
    while true do
        -- 发送心跳
        GuardianPlugin.SendHeartbeat()
        
        -- 执行业务逻辑
        -- ...
        
        Delay(3000)
    end
end

Main()
```
    TracePrint("主脚本启动")
    
    while true do
        -- 发送心跳
        GuardianPlugin.SendHeartbeat()
        
        -- 执行业务逻辑
        -- ...
        
        Delay(3000)
    end
end

Main()
```

## ⚠️ 注意事项

1. **存储权限**: 需要存储权限来读写心跳文件、日志和锁文件
2. **脚本名称**: `SetMainScript` 设置的名称必须与按键精灵中的脚本名称一致
3. **心跳间隔**: 主脚本的心跳间隔应小于 `HEARTBEAT_TIMEOUT`
4. **锁清理**: 正常情况下锁会自动清理，异常时可使用 `ResetGuardian()`

## 📜 更新日志

### v3.2.0
- 添加文件锁机制，防止重复启动守护进程
- 添加 `ResetGuardian()` 强制重置函数
- 优化日志路径，自动创建日志目录

### v3.1.0
- 适配按键精灵移动版插件系统
- 使用 `QMPlugin` 命名空间导出函数

### v3.0.0
- 无界面版本
- 使用 Log 插件记录日志

### v2.0.0
- 文件心跳机制

### v1.0.0
- 基础守护功能
