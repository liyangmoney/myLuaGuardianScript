# 按键精灵移动版 - 进程守护插件

无界面版进程守护插件，仅通过日志记录运行状态。

## 📁 文件说明

| 文件 | 说明 |
|------|------|
| `GuardianPlugin.lua` | **守护插件** - 无界面，仅日志 |
| `MainScript.lua` | **主脚本示例** - 需要配合守护插件使用 |

## 🚀 使用方法

### 1. 导入插件

将 `GuardianPlugin.lua` 导入到按键精灵移动版作为**插件**使用：

```
按键精灵 → 插件 → 导入插件 → 选择 GuardianPlugin.lua
```

### 2. 放置主脚本

将主脚本放到脚本目录：
```
/sdcard/按键精灵/脚本/
├── MainScript.lua    (你的主脚本)
└── ...
```

### 3. 在主脚本中添加心跳

```lua
-- 在主脚本中定时发送心跳
local HEARTBEAT_FILE = "/sdcard/按键精灵/心跳/heartbeat.txt"

local function sendHeartbeat()
    local f = io.open(HEARTBEAT_FILE, "w")
    if f then
        f:write(tostring(TickCount()))
        f:close()
    end
end

-- 主循环
while true do
    sendHeartbeat()   -- 发送心跳
    -- 你的业务代码...
    Delay(3000)
end
```

### 4. 启动守护

**方法1**: 直接运行 `GuardianPlugin.lua` 脚本

**方法2**: 在其他脚本中调用：
```lua
Import "GuardianPlugin"
StartGuardian()   -- 启动守护
```

## ⚙️ 插件配置

编辑 `GuardianPlugin.lua` 修改配置：

```lua
local CONFIG = {
    -- 主脚本配置
    MAIN_SCRIPT_NAME = "MainScript",      -- 主脚本名称
    MAIN_SCRIPT_PATH = "/sdcard/按键精灵/脚本/MainScript.lua",
    
    -- 心跳配置
    HEARTBEAT_FILE = "/sdcard/按键精灵/心跳/heartbeat.txt",
    HEARTBEAT_INTERVAL = 5000,            -- 检测间隔 5秒
    HEARTBEAT_TIMEOUT = 15000,            -- 超时时间 15秒
    
    -- 重启配置
    RESTART_DELAY = 3000,                 -- 重启延迟 3秒
    MAX_RESTART_ATTEMPTS = 10,            -- 最大重启次数
    RESTART_RESET_TIME = 60000,           -- 重启计数重置时间 1分钟
    
    -- 日志配置
    LOG_DIR = "/sdcard/按键精灵/日志/",
    LOG_PREFIX = "guardian_",
}
```

## 📊 功能特性

| 功能 | 说明 |
|------|------|
| 🔄 自动重启 | 检测到主脚本停止自动重启 |
| 📝 日志记录 | 使用按键精灵Log插件记录运行状态 |
| ⏱️ 心跳检测 | 通过文件时间戳检测脚本存活 |
| ⚡ 防死循环 | 限制重启次数，避免无限重启 |
| 🎯 无界面 | 不显示任何UI，后台静默运行 |

## 📜 日志查看

日志文件位置：
```
/sdcard/按键精灵/日志/guardian_yyyyMMdd_HHmmss.txt
```

在按键精灵中使用 `TracePrint` 查看实时日志。

## 🔌 插件接口

```lua
-- 启动守护
StartGuardian()

-- 停止守护
StopGuardian()

-- 获取守护状态
local status = GetGuardianStatus()
-- 返回: {status, restartCount, running, runtime}

-- 发送心跳 (主脚本调用)
SendHeartbeat()
```

## ⚠️ 注意事项

1. **存储权限**: 需要存储权限来读写心跳文件和日志
2. **路径配置**: 确保 `MAIN_SCRIPT_PATH` 与实际路径一致
3. **心跳间隔**: 主脚本的心跳间隔应小于 `HEARTBEAT_TIMEOUT`
4. **多线程**: 插件使用 Thread 插件启动主脚本

## 📝 示例工作流

```
1. 运行 GuardianPlugin.lua
   ↓
2. 插件启动并记录日志
   ↓
3. 插件启动 MainScript.lua
   ↓
4. MainScript 定时发送心跳
   ↓
5. 插件检测心跳，如异常则重启
```

## 🔧 故障排查

### Q: 主脚本不启动？
A: 检查 `MAIN_SCRIPT_NAME` 是否与按键精灵中显示的脚本名称一致

### Q: 频繁重启？
A: 检查主脚本是否正确发送心跳，或调大 `HEARTBEAT_TIMEOUT`

### Q: 无日志输出？
A: 检查是否有存储权限，或手动创建日志目录

## 📜 更新日志

### v3.0.0
- 移除所有UI界面（悬浮窗、Toast）
- 使用按键精灵Log插件记录日志
- 优化插件接口设计
- 使用Thread插件启动主脚本

### v2.0.0
- 改用文件心跳机制
- 添加悬浮窗状态显示

### v1.0.0
- 基础守护功能
