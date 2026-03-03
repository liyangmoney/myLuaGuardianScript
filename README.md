# 按键精灵移动版 - 进程守护插件

无界面版进程守护插件，适配按键精灵移动版插件系统。

## 📁 文件说明

| 文件 | 说明 |
|------|------|
| `GuardianPlugin.lua` | **守护插件** - 放入 Plugin 文件夹 |
| `MainScript.lua` | **主脚本示例** - 需要配合守护插件使用 |

## 🚀 安装步骤

### 1. 放置插件文件

将 `GuardianPlugin.lua` 复制到按键精灵安装目录的 **Plugin** 文件夹：
```
/按键精灵/Plugin/
└── GuardianPlugin.lua
```

### 2. 刷新插件

在按键精灵左侧的【全部命令】中，右键点击【插件命令】，选择【刷新】。

## 📝 日志位置

日志文件位置：
```
/sdcard/按键精灵/guardian_log.txt
```

**说明**：
- 所有运行日志都写入此文件
- 每次启动守护都会追加到文件末尾
- 如需清空日志，手动删除此文件即可

## 🔒 防重复启动机制

插件内置双重防重复启动保护：

### 1. 内存检查
如果当前脚本内存中 `g_running = true`，则拒绝重复启动。

### 2. 文件锁
创建锁文件 `/sdcard/按键精灵/guardian.lock`：
- 启动时检查锁文件是否存在
- 如果存在且未过期（2分钟内），拒绝启动
- 如果锁过期（超过2分钟），自动清除并允许启动
- 停止守护时自动清除锁文件

### 3. 在主脚本中导入插件

在需要使用守护功能的主脚本开头添加：
```lua
Import "GuardianPlugin"
```

## 🔌 使用方式

### 启动守护

```lua
Import "GuardianPlugin"

-- 启动守护（在独立线程中运行）
GuardianPlugin.StartGuardian()
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
    MAIN_SCRIPT_NAME = "MainScript",      -- 默认主脚本名称
    MAIN_SCRIPT_PATH = "/sdcard/按键精灵/脚本/MainScript.lua",
    
    -- 心跳配置
    HEARTBEAT_FILE = "/sdcard/按键精灵/heartbeat.txt",
    HEARTBEAT_INTERVAL = 5000,            -- 检测间隔 5秒
    HEARTBEAT_TIMEOUT = 15000,            -- 超时时间 15秒
    
    -- 重启配置
    RESTART_DELAY = 3000,                 -- 重启延迟 3秒
    MAX_RESTART_ATTEMPTS = 10,            -- 最大重启次数
    RESTART_RESET_TIME = 60000,           -- 重启计数重置时间 1分钟
    
    -- 日志配置
    LOG_FILE = "/sdcard/按键精灵/guardian_log.txt",
}
```

## 📊 导出函数列表

| 函数名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `StartGuardian()` | 无 | 字符串 | 启动守护 |
| `StopGuardian()` | 无 | 字符串 | 停止守护 |
| `SendHeartbeat()` | 无 | 字符串 | 发送心跳 |
| `GetStatus()` | 无 | 字符串 | 获取状态 |
| `SetMainScript(name)` | 脚本名称 | 字符串 | 设置主脚本 |
| `SetTimeout(ms)` | 毫秒 | 字符串 | 设置超时 |
| `Test()` | 无 | 字符串 | 测试插件 |

## 📜 日志查看

日志文件位置：
```
/sdcard/按键精灵/guardian_log.txt
```

在按键精灵中使用 `TracePrint` 查看实时输出。

## 📝 完整示例

### 守护脚本
```lua
Import "GuardianPlugin"

-- 测试插件是否加载
TracePrint(GuardianPlugin.Test())

-- 配置要守护的脚本
GuardianPlugin.SetMainScript("我的主脚本")
GuardianPlugin.SetTimeout(20000)  -- 20秒超时

-- 启动守护
TracePrint(GuardianPlugin.StartGuardian())
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

1. **存储权限**: 需要存储权限来读写心跳文件和日志
2. **脚本名称**: `SetMainScript` 设置的名称必须与按键精灵中的脚本名称一致
3. **心跳间隔**: 主脚本的心跳间隔应小于 `HEARTBEAT_TIMEOUT`
4. **插件路径**: 确保插件文件放在正确的 Plugin 文件夹中

## 🔧 故障排查

### Q: 插件命令不显示？
A: 确保 GuardianPlugin.lua 放在 Plugin 文件夹，然后右键【插件命令】→【刷新】

### Q: 主脚本不启动？
A: 检查 `SetMainScript` 设置的名称是否与按键精灵中的脚本名称完全一致

### Q: 频繁重启？
A: 检查主脚本是否正确调用 `SendHeartbeat()`，或调大超时时间

### Q: 无日志输出？
A: 检查是否有存储权限，或手动创建日志目录

## 📜 更新日志

### v3.1.0
- 适配按键精灵移动版插件系统
- 使用 `QMPlugin` 命名空间导出函数
- 添加 `SetMainScript` 和 `SetTimeout` 配置接口

### v3.0.0
- 无界面版本
- 使用 Log 插件记录日志

### v2.0.0
- 文件心跳机制

### v1.0.0
- 基础守护功能
