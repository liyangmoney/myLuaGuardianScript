# 按键精灵移动版 - 进程守护

提供两种守护方案：
1. **插件版** (`GuardianPlugin.lua`) - 作为插件导入，与主脚本同生命周期
2. **独立脚本版** (`GuardianRunner.lua`) - 作为独立脚本运行，真正独立于主脚本

## 📁 文件说明

| 文件 | 说明 |
|------|------|
| `GuardianRunner.lua` | **独立守护脚本** ⭐ 推荐 - 独立于主脚本运行 |
| `GuardianPlugin.lua` | **守护插件** - 作为插件导入使用 |
| `Heartbeat.lua` | **心跳模块** - 供主脚本调用发送心跳 |
| `MainScript.lua` | **主脚本示例** - 配合守护使用 |

---

## 🚀 推荐方案：独立守护脚本

### 方案对比

| 特性 | 独立脚本版 | 插件版 |
|------|-----------|--------|
| 运行方式 | 单独运行 GuardianRunner.lua | 作为主脚本的一部分 |
| 生命周期 | 独立于主脚本 | 与主脚本绑定 |
| 主脚本退出后 | 继续运行并重启主脚本 | 随主脚本停止 |
| 适用场景 | 需要持续守护的场景 | 临时守护需求 |

### 独立守护脚本使用方法

#### 1. 放置文件

```
/按键精灵/脚本/
├── GuardianRunner.lua  (守护脚本)
├── Heartbeat.lua       (心跳模块)
└── 你的主脚本.lua       (被守护的主脚本)
```

#### 2. 在主脚本中添加心跳

**方式1**：使用 Heartbeat.lua 模块
```lua
-- 主脚本开头导入心跳模块
require("Heartbeat")

-- 主循环
while true do
    AutoHeartbeat()  -- 自动发送心跳
    -- 你的业务代码...
    Delay(100)
end
```

**方式2**：手动发送心跳
```lua
-- 主循环
while true do
    -- 发送心跳
    File.Write("/sdcard/guardian/heartbeat.txt", tostring(TickCount()))
    
    -- 你的业务代码...
    Delay(3000)
end
```

#### 3. 启动守护

**先运行 `GuardianRunner.lua`**，它会自动启动你的主脚本。

如果主脚本崩溃或退出，守护会继续运行并自动重启主脚本。

#### 4. 停止守护

停止 `GuardianRunner.lua` 脚本即可。

---

## 📂 日志位置

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

1. **启动检查**: `StartGuardian()` 会先检查 `/sdcard/按键精灵/guardian.lock` 文件
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

### 停止守护

```lua
GuardianPlugin.StopGuardian()
```

### 强制重置（异常情况）

```lua
-- 如果守护异常退出导致锁未释放，使用此函数强制重置
GuardianPlugin.ResetGuardian()
```

### 获取守护状态

```lua
local status = GuardianPlugin.GetStatus()
TracePrint(status)  -- 输出: 状态:运行正常 运行:5分32秒 重启:0次
```

### 配置守护参数

```lua
-- 设置要守护的主脚本名称（必须在按键精灵中有此脚本）
GuardianPlugin.SetMainScript("你的主脚本名称")

-- 设置心跳超时时间（毫秒）
GuardianPlugin.SetTimeout(15000)  -- 15秒
```

## ⚙️ 插件配置

编辑 `GuardianPlugin.lua` 修改默认配置：

```lua
local CONFIG = {
    -- 主脚本配置
    MAIN_SCRIPT_NAME = "MainScript",
    MAIN_SCRIPT_PATH = "/sdcard/按键精灵/脚本/MainScript.lua",
    
    -- 心跳配置
    HEARTBEAT_FILE = "/sdcard/按键精灵/heartbeat.txt",
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
| `StartGuardian()` | 无 | 字符串 | 启动守护（自动防重复） |
| `StopGuardian()` | 无 | 字符串 | 停止守护并释放锁 |
| `ResetGuardian()` | 无 | 字符串 | 强制重置锁状态 |
| `SendHeartbeat()` | 无 | 字符串 | 发送心跳 |
| `GetStatus()` | 无 | 字符串 | 获取状态 |
| `SetMainScript(name)` | 脚本名称 | 字符串 | 设置主脚本 |
| `SetTimeout(ms)` | 毫秒 | 字符串 | 设置超时 |
| `Test()` | 无 | 字符串 | 测试插件 |

## 📝 完整示例

### 守护启动脚本
```lua
Import "GuardianPlugin"

-- 测试插件是否加载
TracePrint(GuardianPlugin.Test())

-- 配置要守护的脚本
GuardianPlugin.SetMainScript("我的主脚本")
GuardianPlugin.SetTimeout(20000)  -- 20秒超时

-- 启动守护（自动防重复启动）
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
