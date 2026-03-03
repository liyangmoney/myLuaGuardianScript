# 按键精灵进程守护脚本

## 📁 文件说明

| 文件 | 说明 |
|------|------|
| `守护进程V2_文件心跳版.lua` | **推荐使用** - 通过文件心跳检测，稳定可靠 |
| `守护进程.lua` | 基础版 - 通过函数调用检测 |
| `主脚本示例.lua` | 主脚本模板，包含心跳发送功能 |

## 🚀 快速开始

### 1. 放置文件

将脚本文件放到按键精灵的脚本目录：
```
/sdcard/按键精灵/脚本/
├── 守护进程V2_文件心跳版.lua  (守护脚本)
├── 主脚本.lua                  (你的主脚本)
└── 主脚本示例.lua              (参考模板)
```

### 2. 修改配置

打开 `守护进程V2_文件心跳版.lua`，修改配置：

```lua
local CONFIG = {
    MAIN_SCRIPT_NAME = "主脚本",           -- 你的主脚本名称
    MAIN_SCRIPT_PATH = "/sdcard/按键精灵/脚本/主脚本.lua",  -- 主脚本路径
    HEARTBEAT_TIMEOUT = 15000,             -- 15秒无心跳视为异常
    MAX_RESTART_ATTEMPTS = 10,             -- 最多连续重启10次
}
```

### 3. 在主脚本中添加心跳

在你的主脚本中加入心跳代码：

```lua
-- 心跳函数
local function sendHeartbeat()
    local f = io.open("/sdcard/按键精灵/心跳/heartbeat.txt", "w")
    if f then
        f:write(tostring(mTime()))
        f:close()
    end
end

-- 主循环中定时发送心跳
while true do
    sendHeartbeat()  -- 发送心跳
    -- 你的业务逻辑...
    delay(3000)      -- 每3秒发送一次
end
```

### 4. 运行守护

先运行 **守护进程V2_文件心跳版.lua**，它会自动启动主脚本。

## ⚙️ 配置详解

### 守护脚本配置

```lua
local CONFIG = {
    -- 主脚本配置
    MAIN_SCRIPT_NAME = "主脚本",           -- 显示名称
    MAIN_SCRIPT_PATH = "/sdcard/按键精灵/脚本/主脚本.lua",
    
    -- 心跳配置
    HEARTBEAT_FILE = "/sdcard/按键精灵/心跳/heartbeat.txt",
    HEARTBEAT_INTERVAL = 5000,             -- 检测间隔（5秒）
    HEARTBEAT_TIMEOUT = 15000,             -- 超时时间（15秒）
    
    -- 重启配置
    RESTART_DELAY = 3000,                  -- 重启延迟（3秒）
    MAX_RESTART_ATTEMPTS = 10,             -- 最大重启次数
    RESTART_RESET_TIME = 60000,            -- 重启计数重置时间（1分钟）
    
    -- 日志配置
    LOG_ENABLED = true,
    LOG_DIR = "/sdcard/按键精灵/日志/",
    
    -- UI配置
    SHOW_TOAST = true,                     -- 显示Toast提示
    SHOW_FLOAT_STATUS = true,              -- 显示悬浮窗状态
}
```

## 📊 功能特性

### ✅ 心跳检测
- 通过文件时间戳检测主脚本是否存活
- 可配置检测间隔和超时时间

### 🔄 自动重启
- 检测到异常自动重启主脚本
- 防死循环机制（限制重启次数）
- 可配置重启延迟

### 📝 日志记录
- 详细的运行日志
- 按时间命名，自动保存
- 包含状态、错误、重启记录

### 🖥️ 悬浮窗状态
- 实时显示守护状态
- 运行时间统计
- 重启次数显示

## 🔧 使用技巧

### 查看日志
```
/sdcard/按键精灵/日志/guardian_YYYYMMDD_HHMMSS.txt
```

### 手动停止守护
- 关闭按键精灵应用
- 或在悬浮窗中操作（如支持）

### 调试模式
在守护脚本中将 `HEARTBEAT_INTERVAL` 调小（如1000ms），方便快速测试。

## ⚠️ 注意事项

1. **权限**：需要存储权限来读写心跳文件和日志
2. **悬浮窗**：如需状态悬浮窗，需要开启悬浮窗权限
3. **路径**：确保配置中的路径与实际路径一致
4. **重启限制**：连续重启超过限制后会自动停止守护，防止无限循环

## 🐛 常见问题

### Q: 主脚本不启动？
A: 检查 `MAIN_SCRIPT_PATH` 路径是否正确，脚本是否存在。

### Q: 频繁重启？
A: 检查主脚本是否正确发送心跳，或调大 `HEARTBEAT_TIMEOUT`。

### Q: 日志不生成？
A: 检查是否有存储权限，或手动创建 `/sdcard/按键精灵/日志/` 目录。

## 📜 更新日志

### v2.0.0 (文件心跳版)
- 改用文件心跳机制，更稳定
- 添加悬浮窗状态显示
- 优化日志记录

### v1.0.0 (基础版)
- 基础守护功能
- 函数调用式心跳
