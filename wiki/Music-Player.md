# 音乐播放器

## 概述

jnlp 是 JNL OS 自带的音乐播放器，基于 GTK4 + GStreamer 开发，支持：

- 音乐库扫描与管理
- 歌词同步显示
- 封面图片展示
- DBus 远程控制
- `.jnl` 音乐包格式

## 界面说明

### 主界面

- **左侧面板**：音乐库导航（艺术家、专辑、歌曲、播放列表）
- **中间区域**：歌曲列表和封面展示
- **底部控制栏**：播放控制按钮和进度条
- **右侧面板**：歌词同步显示

### 播放控制

| 按钮 | 功能 | 快捷键 |
|------|------|--------|
| ▶ | 播放 | Space |
| ⏸ | 暂停 | Space |
| ⏮ | 上一首 | Ctrl+Left |
| ⏭ | 下一首 | Ctrl+Right |
| ⏯ | 播放/暂停切换 | Space |
| 🔀 | 随机播放 | Ctrl+S |
| 🔁 | 循环播放 | Ctrl+R |

### 音量控制

- 使用音量滑块调节音量
- 快捷键：`Ctrl+Up` 增加音量，`Ctrl+Down` 降低音量

## 使用方法

### 添加音乐

1. 点击菜单 → 文件 → 添加文件夹
2. 选择音乐文件夹，播放器自动扫描 `.jnl` 文件和常见音频格式

### 创建播放列表

1. 在左侧面板右键点击播放列表
2. 选择新建播放列表
3. 拖拽歌曲到播放列表中

### 歌词显示

1. 确保歌曲包含歌词信息（.jnl 格式自动包含）
2. 点击右侧面板切换到歌词视图
3. 歌词将随歌曲进度同步滚动

### 搜索音乐

在顶部搜索框输入关键词，支持按标题、艺术家、专辑搜索。

## 命令行控制

### 基本命令

```bash
# 播放音乐
jnlp play /path/to/music.jnl

# 暂停播放
jnlp pause

# 继续播放
jnlp resume

# 下一首
jnlp next

# 上一首
jnlp prev

# 停止播放
jnlp stop

# 设置音量（0-100）
jnlp volume 70

# 显示当前播放信息
jnlp status
```

### DBus 接口

jnlp 通过 DBus 提供远程控制接口：

```bash
# 使用 dbus-send 控制
dbus-send --type=method_call --dest=org.jnl.Playback /org/jnl/Playback org.jnl.Playback.Play

dbus-send --type=method_call --dest=org.jnl.Playback /org/jnl/Playback org.jnl.Playback.Pause

dbus-send --type=method_call --dest=org.jnl.Playback /org/jnl/Playback org.jnl.Playback.Next
```

## 音乐库

### 音乐库位置

默认音乐库位于 `~/Music/JNL/`，包含所有 `.jnl` 文件。

### 扫描音乐库

```bash
# 扫描指定目录
jnlp scan /path/to/music

# 重新扫描整个音乐库
jnlp rescan
```

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| Space | 播放/暂停 |
| Ctrl+Left | 上一首 |
| Ctrl+Right | 下一首 |
| Ctrl+Up | 音量增加 |
| Ctrl+Down | 音量降低 |
| Ctrl+S | 随机播放 |
| Ctrl+R | 循环播放 |
| Ctrl+Q | 退出 |
| Ctrl+F | 搜索 |

## 常见问题

### 播放失败

- 确保安装了 GStreamer 插件：`sudo pacman -S gst-plugins-good gst-plugins-bad gst-plugins-ugly`
- 检查音频文件格式是否支持

### 歌词不显示

- 确保 `.jnl` 文件包含歌词信息
- 手动添加歌词：右键歌曲 → 编辑歌词
