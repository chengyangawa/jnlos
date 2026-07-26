# jnlp

**jnlp**（Java Net Lava Player）是 Java Net Lava OS 的 `.jnl` 音乐包格式桌面播放器，基于 Python3 + GTK4 + GStreamer 实现。

`.jnl` 是一种基于 ZIP 的音乐打包格式，将一首歌曲的音频（`audio.<ext>`）、元数据（`meta.json`）、封面（`cover.jpg`，可选）和歌词（`lyrics.lrc`，可选）打包为单一文件。格式规范详见 [`../spec/FORMAT.md`](../spec/FORMAT.md)。

## 功能

- **音乐库扫描**：启动时扫描 `~/.local/share/jnl-os/music/*.jnl`，读取 `meta.json`，列出歌单（标题 / 艺术家）。
- **播放控制**：基于 GStreamer `playbin`，支持播放 / 暂停 / 停止 / 上一首 / 下一首 / 进度条拖动跳转 / 音量调节。
- **元数据显示**：当前歌曲标题、艺术家、专辑、时长、比特率。
- **封面显示**：从 `.jnl` 解压 `cover.jpg` 并显示。
- **歌词显示**：从 `.jnl` 读取 `lyrics.lrc`，按时间同步高亮当前行（前后行灰显）。
- **DBus 服务**：导出 `org.jnl_os.Player` 接口，供 GNOME Shell 扩展通过 DBus 控制播放。
- **文件关联**：支持 `.jnl` 双击用 jnlp 打开（依赖 `jnlp.desktop` 中的 MIME 关联）。

## 安装

### 方式一：直接安装（无需打包）

```bash
chmod +x jnlp
sudo cp jnlp /usr/bin/jnlp
sudo cp jnlp.desktop /usr/share/applications/jnlp.desktop
# 刷新桌面与 MIME 数据库
sudo update-desktop-database
sudo update-mime-database /usr/share/mime
```

安装后即可在应用菜单中找到 "JNL Player"，且 `.jnl` 文件可双击打开。

### 方式二：通过 makepkg 安装（Arch Linux）

```bash
cd src/jnl-tools/jnlp
makepkg -si
```

## 用法

```bash
# 打开图形界面并扫描音乐库
jnlp

# 直接播放指定 .jnl 文件
jnlp '/path/周杰伦 - 稻香.jnl'

# 查看帮助
jnlp --help
```

音乐库目录：`~/.local/share/jnl-os/music/`（不存在时启动会自动创建）。

## DBus 接口

jnlp 启动后会在会话总线上注册 `org.jnl_os.Player` 服务，对象路径 `/org/jnl_os/Player`。该名称复用 GTK Application 的 well-known bus name，避免名称冲突与重复占用。

### 方法

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| `Play` | — | — | 播放 / 恢复播放 |
| `Pause` | — | — | 暂停 |
| `Next` | — | — | 下一首 |
| `Previous` | — | — | 上一首 |
| `Stop` | — | — | 停止 |
| `PlayTrack` | `i:index` | — | 按索引播放歌单中的曲目 |
| `GetStatus` | — | `s,i,i` | 状态、当前位置(ms)、总时长(ms) |
| `GetSongInfo` | — | `s,s,s,i` | 标题、艺术家、专辑、时长(秒) |
| `SetVolume` | `d:volume` | — | 设置音量 (0.0 ~ 1.0) |
| `GetVolume` | — | `d` | 获取当前音量 |

### 属性

| 属性 | 类型 | 访问 | 说明 |
|------|------|------|------|
| `Status` | `s` | 读 | 当前状态：`playing` / `paused` / `stopped` |
| `Volume` | `d` | 读 | 当前音量 (0.0 ~ 1.0) |

### 信号

| 信号 | 参数 | 说明 |
|------|------|------|
| `SongChanged` | `s:title, s:artist` | 当前歌曲变化 |
| `StatusChanged` | `s:status` | 播放状态变化 |

### 调用示例

```bash
# 通过 dbus-send 播放
gdbus call --session --dest org.jnl_os.Player \
    --object-path /org/jnl_os/Player \
    --method org.jnl_os.Player.Play

# 获取当前歌曲信息
gdbus call --session --dest org.jnl_os.Player \
    --object-path /org/jnl_os/Player \
    --method org.jnl_os.Player.GetSongInfo

# 监听歌曲切换信号
gdbus monitor --session --dest org.jnl_os.Player \
    --object-path /org/jnl_os/Player
```

## 依赖

- **必需**：
  - `python` (≥ 3.8)
  - `python-gobject` (PyGObject)
  - `gtk4`
  - `gstreamer` + `gst-plugins-base` + `gst-plugins-good`
- **可选**：
  - `gst-plugins-bad` / `gst-plugins-ugly` / `gst-libav`：解码更多音频格式（MP3 通常需要 `gst-plugins-ugly` 或 `gst-libav`）

## 与其他组件的关系

| 组件 | 关系 |
|------|------|
| `jnlc` | 命令行工具，`pack`/`unpack` 生成 jnlp 可播放的 `.jnl` 文件 |
| GNOME Shell 扩展 | 通过 `org.jnl_os.Player` DBus 接口在状态栏控制播放 |
| QQ 音乐下载扩展 | 将下载的音频打包为 `.jnl` 后放入音乐库 |

## 许可证

GPL3
