# JNL Music Control — GNOME Shell 顶栏音乐控件

Java Net Lava OS 的 GNOME Shell 扩展，在顶栏右侧提供音乐控制面板，
通过 DBus 与 `jnlp` 桌面播放器通信。

## 功能

- 顶栏右侧显示音乐图标，点击展开下拉控制面板
- 显示当前歌曲标题（粗体）与艺术家（次要色）
- 控制按钮：上一首 / 播放暂停 / 下一首 / 停止
- 音量滑块（拖动实时调节）
- 歌曲列表：列出 `~/.local/share/jnl-os/music/*.jnl`，点击即播放
- 「打开播放器」按钮启动 `jnlp`
- 「刷新歌单」按钮重新扫描音乐目录
- 自动监听 DBus 信号实时更新界面

## 依赖

- GNOME Shell 45 / 46 / 47（ES 模块语法）
- `jnlp` 播放器需已启动并注册 DBus 服务

## DBus 接口

| 项目     | 值                       |
| -------- | ------------------------ |
| 总线名   | `org.jnl_os.Player`     |
| 对象路径 | `/org/jnl_os/Player`     |
| 接口名   | `org.jnl_os.Player`      |

### 方法

| 方法          | 参数         | 返回值        | 说明           |
| ------------- | ------------ | ------------- | -------------- |
| `Play`        | —            | —             | 播放           |
| `Pause`       | —            | —             | 暂停           |
| `Next`        | —            | —             | 下一首         |
| `Previous`    | —            | —             | 上一首         |
| `Stop`        | —            | —             | 停止           |
| `PlayTrack`   | `i index`    | —             | 按索引播放     |
| `GetStatus`   | —            | `s status`    | 获取播放状态   |
| `GetSongInfo` | —            | `s title, s artist` | 获取歌曲信息 |
| `SetVolume`   | `d volume`   | —             | 设置音量(0-1)  |
| `GetVolume`   | —            | `d volume`    | 获取音量(0-1)  |

### 信号

| 信号             | 参数                    | 说明             |
| ---------------- | ----------------------- | ---------------- |
| `SongChanged`    | `s title, s artist`     | 当前曲目变更     |
| `StatusChanged`  | `s status`              | 播放状态变更     |

`status` 取值：`playing`、`paused`、`stopped`

## 安装

### 系统级安装（archiso 构建时）

由 `customize_airootfs.sh` 调用 `install.sh`：

```bash
sudo ./install.sh
```

扩展将被复制到 `/usr/share/gnome-shell/extensions/jnl-music@jnl-os.local/`。

### 手动安装（开发调试）

```bash
# 复制到用户扩展目录
mkdir -p ~/.local/share/gnome-shell/extensions/jnl-music@jnl-os.local/
cp metadata.json extension.js stylesheet.css \
    ~/.local/share/gnome-shell/extensions/jnl-music@jnl-os.local/

# 重启 GNOME Shell（Wayland 需重新登录）
# X11: Alt+F2 输入 r 回车

# 启用扩展
gnome-extensions enable jnl-music@jnl-os.local
```

## 文件结构

```
src/gnome-extension/
├── metadata.json     # 扩展元数据（UUID、名称、GNOME Shell 版本）
├── extension.js      # 扩展主代码（ES 模块，DBus 通信 + UI）
├── stylesheet.css     # 面板样式表
├── install.sh        # 系统级安装脚本
└── README.md         # 本文档
```

## 音乐库

音乐文件存放于 `~/.local/share/jnl-os/music/`，扩展名 `.jnl`。
扩展启动时自动扫描该目录并填充歌曲列表。
