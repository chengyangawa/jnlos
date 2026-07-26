# 音乐功能使用指南

> Java Net Lava OS 内置完整的音乐生态：从歌曲下载、打包、播放到任务栏控制，
> 所有组件通过 `.jnl` 格式与 DBus 信号串联协作。

---

## 1. 功能概览

| 组件 | 角色 | 启动方式 |
| --- | --- | --- |
| `jnlp` 桌面播放器 | 播放与管理 `.jnl`，提供 DBus 服务 | 桌面双击 "JNL 播放器" 或终端 `jnlp` |
| `jnlc` 命令行工具 | pack / unpack / info / play / list | 终端 `jnlc <子命令>` |
| 浏览器扩展（QQ音乐下载） | 在线歌曲下载并打包为 `.jnl` | Firefox / Chromium 加载扩展 |
| GNOME Shell 任务栏控件 | 顶栏显示曲目并提供播放控制 | 系统启动后自动启用 |
| Native Messaging 桥接 | 浏览器扩展 ↔ jnlc pack 通信 | 由扩展自动调用 |

### 数据流

```
QQ音乐网页
   │ (浏览器扩展拦截音频流)
   ▼
jnl-bridge.py  ──►  jnlc pack  ──►  ~/.local/share/jnl-os/music/歌曲.jnl
                                                    │
                                                    ▼
                                              jnlp 播放器
                                                    │ (DBus: org.jnl_os.Player)
                                                    ▼
                                          GNOME Shell 任务栏控件
```

---

## 2. jnlp 桌面播放器

`jnlp`（Java Net Lava Player）是基于 GTK4 + GStreamer 的桌面音乐播放器。

### 2.1 启动方式

- **桌面快捷方式**：双击桌面 "JNL 播放器" 图标
- **终端启动**：
  ```bash
  jnlp                    # 打开播放器并扫描音乐库
  jnlp "歌曲.jnl"         # 直接播放指定 .jnl 文件
  jnlp --help             # 显示帮助
  ```

### 2.2 音乐库目录

jnlp 启动时自动扫描以下目录：

```
~/.local/share/jnl-os/music/*.jnl
```

将 `.jnl` 文件放入此目录即可在歌单中看到。示例歌曲 `sample.jnl` 已预置。

### 2.3 界面说明

```
┌─────────────────────────────────────────────────────────────┐
│  [封面]  歌曲标题                                              │
│          艺术家: xxx                                          │
│          专辑: xxx                                            │
│          时长: 3:43  ·  320kbps                                │
├──────────────────────────┬──────────────────────────────────┤
│  歌词                      │  歌单                              │
│  ...                       │  1. 稻香 - 周杰伦                  │
│  当前歌词（高亮加粗）       │  2. 夜曲 - 周杰伦                  │
│  ...                       │  3. 晴天 - 周杰伦                  │
│                            │  ...                              │
├──────────────────────────┴──────────────────────────────────┤
│  [上一首] [播放/暂停] [下一首] [停止]                          │
│  0:42 ────────●────────────────── 3:43                       │
│  音量 ────────●────                                          │
└─────────────────────────────────────────────────────────────┘
```

### 2.4 功能列表

| 功能 | 操作 |
| --- | --- |
| 播放/暂停 | 点击 "播放" / "暂停" 按钮，或任务栏控件按钮 |
| 上一首/下一首 | 点击对应按钮，或任务栏控件 |
| 停止 | 点击 "停止" 按钮 |
| 跳转进度 | 拖动进度条（拖动期间不回写，释放时跳转） |
| 调节音量 | 拖动音量滑块 |
| 选择歌曲 | 在歌单列表中点击任意行 |
| 歌词同步 | 自动跟随播放进度高亮当前行（每 200ms 刷新） |
| 播放外部文件 | 命令行 `jnlp /path/to/song.jnl`，会临时加入歌单末尾并播放 |

### 2.5 DBus 接口

jnlp 启动后会注册 DBus 服务，供 GNOME Shell 扩展与其他程序远程控制：

- **服务名**：`org.jnl_os.Player`
- **对象路径**：`/org/jnl_os/Player`

#### 方法

| 方法 | 参数 | 返回值 | 说明 |
| --- | --- | --- | --- |
| `Play` | — | — | 播放或恢复 |
| `Pause` | — | — | 暂停 |
| `Stop` | — | — | 停止 |
| `Next` | — | — | 下一首 |
| `Previous` | — | — | 上一首 |
| `PlayTrack` | `i:index` | — | 播放指定索引曲目 |
| `GetStatus` | — | `(sii)` | 返回状态/位置/时长（毫秒） |
| `GetSongInfo` | — | `(sssi)` | 返回标题/艺术家/专辑/时长（秒） |
| `SetVolume` | `d:volume` | — | 设置音量（0.0~1.0） |
| `GetVolume` | — | `(d)` | 返回当前音量 |

#### 信号

| 信号 | 参数 | 说明 |
| --- | --- | --- |
| `SongChanged` | `(ss)` | 切歌时发送，含标题与艺术家 |
| `StatusChanged` | `(s)` | 播放状态变化时发送（playing/paused/stopped） |

#### 属性

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `Status` | `s` | 只读，当前播放状态 |
| `Volume` | `d` | 只读，当前音量 |

#### 命令行测试 DBus

```bash
# 获取当前状态
gdbus call --session --dest org.jnl_os.Player \
    --object-path /org/jnl_os/Player \
    --method org.jnl_os.Player.GetStatus

# 暂停
gdbus call --session --dest org.jnl_os.Player \
    --object-path /org/jnl_os/Player \
    --method org.jnl_os.Player.Pause

# 监听 SongChanged 信号
gdbus monitor --session --dest org.jnl_os.Player
```

---

## 3. 浏览器扩展（QQ音乐下载）

### 3.1 功能说明

Manifest V3 浏览器扩展，在 QQ 音乐网页注入下载按钮：

- 仅在 `y.qq.com` 域名下激活
- 自动获取页面已解密音频流 URL
- 通过 Native Messaging 调用 Python 桥接程序
- 桥接程序下载音频、读取元数据、调用 `jnlc pack` 打包
- 自动保存到 `~/.local/share/jnl-os/music/`，文件名形如 `周杰伦 - 稻香.jnl`
- 打包完成后通知 jnlp 刷新歌单（通过 DBus）

### 3.2 安装扩展

#### Firefox

1. 打开 `about:debugging#/runtime/this-firefox`
2. 点击 **"加载临时附加组件"**
3. 选择 `src/browser-extension/manifest.json`

#### Chromium / Chrome

1. 打开 `chrome://extensions/`
2. 开启右上角 **"开发者模式"**
3. 点击 **"加载已解压的扩展程序"**
4. 选择 `src/browser-extension/` 目录

#### 安装 Native Messaging 桥接

```bash
cd src/browser-extension/native-host/
bash install.sh
```

`install.sh` 会：
- 将 `jnl-bridge.py` 复制到 `/usr/local/bin/`
- 将 `manifest.json`（native messaging 清单）安装到浏览器期望路径
- 设置可执行权限

### 3.3 使用方法

1. 打开 Firefox 或 Chromium
2. 访问 `https://y.qq.com/`
3. 进入任意歌曲详情页或歌单页
4. 在歌曲操作区会出现 **"下载到 JNL OS"** 按钮
5. 点击按钮，扩展自动完成下载与打包
6. 完成后系统通知提示 "已保存：周杰伦 - 稻香.jnl"
7. 打开 jnlp 播放器，新歌曲自动出现在歌单

### 3.4 权限说明

扩展声明的权限（见 `manifest.json`）：

| 权限 | 用途 |
| --- | --- |
| `activeTab` | 访问当前活动标签页 |
| `scripting` | 注入内容脚本 |
| `storage` | 存储扩展设置 |
| `downloads` | 触发浏览器下载 |
| `nativeMessaging` | 与 Python 桥接程序通信 |
| `*://*.qq.com/*` | 访问 QQ 音乐域名 |

---

## 4. 任务栏音乐控件

### 4.1 功能说明

GNOME Shell 扩展 `jnl-music@jnl-os.local` 提供：

- 顶栏显示当前曲目标题（自动滚动）
- 点击图标展开下拉面板：
  - 当前歌曲封面缩略图
  - 标题 / 艺术家
  - 上一首 / 播放暂停 / 下一首 按钮
  - 音量滑块
  - 进度条（只读）
- 监听 DBus 信号实时更新
- 仅在 `jnlp` 运行时显示，关闭 jnlp 后自动隐藏

### 4.2 启用与禁用

扩展随系统启动自动启用（通过 dconf 预配置）。如需手动操作：

```bash
# 启用扩展
gnome-extensions enable jnl-music@jnl-os.local

# 禁用扩展
gnome-extensions disable jnl-music@jnl-os.local

# 查看扩展状态
gnome-extensions info jnl-music@jnl-os.local
```

### 4.3 安装位置

```
/usr/share/gnome-shell/extensions/jnl-music@jnl-os.local/
├── metadata.json
├── extension.js
├── stylesheet.css
└── schemas/
```

### 4.4 与 jnlp 的通信

扩展通过 DBus 调用 `org.jnl_os.Player` 接口：

- 启动时调用 `GetStatus` 与 `GetSongInfo` 初始化界面
- 监听 `SongChanged` 信号更新曲目信息
- 监听 `StatusChanged` 信号更新按钮状态
- 每 500ms 轮询 `GetStatus` 更新进度条
- 按钮点击调用 `Play` / `Pause` / `Next` / `Previous` 方法

---

## 5. .jnl 文件管理（jnlc 工具）

`jnlc`（Java Net Lava Compiler）是 `.jnl` 格式的命令行工具。

### 5.1 子命令

| 子命令 | 语法 | 说明 |
| --- | --- | --- |
| `pack` | `jnlc pack <dir> <output.jnl>` | 打包目录为 .jnl 文件 |
| `unpack` | `jnlc unpack <input.jnl> <dir>` | 解包 .jnl 到目录 |
| `info` | `jnlc info <input.jnl>` | 查看 .jnl 元数据信息 |
| `play` | `jnlc play <input.jnl>` | 播放 .jnl（调用系统播放器） |
| `list` | `jnlc list <dir>` | 列出目录中的 .jnl 文件 |

### 5.2 常用操作

```bash
# 查看某首歌的元数据
jnlc info "周杰伦 - 稻香.jnl"

# 将本地音频目录打包为 .jnl
# 目录需包含 audio.mp3 与可选 meta.json、cover.jpg、lyrics.lrc
jnlc pack ./my-song "./周杰伦 - 稻香.jnl"

# 若目录无 meta.json，jnlc 会自动生成（标题为目录名）
# 若已安装 mutagen，会自动读取音频时长写入 duration 字段

# 解包 .jnl 到目录（用于编辑或提取素材）
jnlc unpack "./周杰伦 - 稻香.jnl" ./my-song

# 播放单首（使用系统默认播放器：mpv > vlc > gst-play > ffplay）
jnlc play "./周杰伦 - 稻香.jnl"

# 列出音乐库中所有 .jnl
jnlc list ~/.local/share/jnl-os/music/
```

### 5.3 打包目录要求

`jnlc pack` 要求源目录包含：

| 文件 | 是否必需 | 说明 |
| --- | --- | --- |
| `audio.<ext>` | 必需 | 音频文件，扩展名须为 `.mp3`/`.flac`/`.ogg`/`.m4a`/`.wav`/`.opus` |
| `meta.json` | 可选 | 元数据。缺失时 jnlc 自动生成（标题为目录名，artist 为 Unknown） |
| `cover.jpg` | 可选 | 封面。也接受 `cover.jpeg`、`cover.png`，统一归档为 `cover.jpg` |
| `lyrics.lrc` | 可选 | LRC 格式歌词 |

### 5.4 安装 jnlc 与 jnlp

JNL OS 中已预装。若在其他 Arch Linux 系统中安装：

```bash
# 使用仓库内的 PKGBUILD
cd src/jnl-tools/jnlc/
makepkg -si

cd src/jnl-tools/jnlp/
makepkg -si
```

---

## 6. 常见问题

### 6.1 播放器相关问题

**Q：jnlp 启动后歌单为空？**

A：检查音乐库目录是否存在 `.jnl` 文件：

```bash
ls ~/.local/share/jnl-os/music/*.jnl
```

若无文件，可通过浏览器扩展下载歌曲，或手动用 `jnlc pack` 打包。

---

**Q：播放时没有声音？**

A：检查：

1. 系统音量是否被静音（`pavucontrol` 查看）
2. GStreamer 插件是否齐全（应安装 `gst-plugins-good`、`gst-plugins-bad`、`gst-plugins-ugly`、`gst-libav`）
3. PipeWire / PulseAudio 服务是否正常运行：`systemctl --user status pipewire`

---

**Q：歌词不显示？**

A：`.jnl` 文件中未包含 `lyrics.lrc`。可：

1. 用 `jnlc unpack` 解包，添加 `lyrics.lrc` 后重新 `jnlc pack`
2. LRC 文件需为 UTF-8 编码，格式 `[mm:ss.xx]歌词文本`

---

**Q：GStreamer 报错 "无法创建 playbin"？**

A：缺少 `gst-plugins-base`。安装：

```bash
sudo pacman -S gst-plugins-base
```

### 6.2 浏览器扩展问题

**Q：下载按钮不出现？**

A：检查：

1. 扩展是否已启用（`about:addons` 查看）
2. 当前域名是否为 `y.qq.com`（扩展仅在此域名激活）
3. 检查浏览器扩展错误日志（F12 → 控制台）

---

**Q：点击下载后无反应？**

A：Native Messaging 桥接可能未安装或失败：

```bash
# 检查桥接程序是否可执行
ls -l /usr/local/bin/jnl-bridge.py

# 手动测试桥接
echo '{"action":"ping"}' | python3 /usr/local/bin/jnl-bridge.py

# 重新安装
cd src/browser-extension/native-host/
bash install.sh
```

---

**Q：下载的歌曲在 jnlp 中看不到？**

A：jnlp 在启动时扫描音乐库。新下载的歌曲需重启 jnlp 或在 jnlp 中按 `Ctrl+R` 刷新歌单（若已实现）。

### 6.3 任务栏控件问题

**Q：顶栏没有音乐控件？**

A：检查：

1. jnlp 是否正在运行（控件仅在 jnlp 运行时显示）
2. 扩展是否启用：
   ```bash
   gnome-extensions info jnl-music@jnl-os.local
   ```
3. 若未启用，执行 `gnome-extensions enable jnl-music@jnl-os.local`
4. 重启 GNOME Shell：X11 下 Alt+F2 输入 `r`；Wayland 下需重新登录

---

**Q：控件显示但不更新歌曲信息？**

A：DBus 连接异常。重启 jnlp，或检查：

```bash
# 测试 DBus 是否响应
gdbus call --session --dest org.jnl_os.Player \
    --object-path /org/jnl_os/Player \
    --method org.jnl_os.Player.GetStatus
```

### 6.4 jnlc 工具问题

**Q：`jnlc pack` 报 "meta.json 不是合法 JSON"？**

A：`meta.json` 文件语法错误。用 `python3 -m json.tool meta.json` 校验。

---

**Q：打包后文件名乱码？**

A：终端 locale 未设置为 UTF-8。执行：

```bash
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
```

---

**Q：`jnlc play` 报 "未找到可用的播放器"？**

A：系统未安装任何受支持的播放器。安装任一：

```bash
sudo pacman -S mpv     # 推荐
# 或
sudo pacman -S vlc
# 或
sudo pacman -S gst-plugins-base  # 提供 gst-play
```

---

## 7. 相关文档

- [jnl-format.md](./jnl-format.md) — `.jnl` 格式规范
- [themes.md](./themes.md) — 12 套主题说明
- [src/jnl-tools/spec/FORMAT.md](../src/jnl-tools/spec/FORMAT.md) — 格式规范源文件
- [src/jnl-tools/jnlc/README.md](../src/jnl-tools/jnlc/README.md) — jnlc 工具说明
- [src/jnl-tools/jnlp/README.md](../src/jnl-tools/jnlp/README.md) — jnlp 播放器说明
- [src/browser-extension/README.md](../src/browser-extension/README.md) — 浏览器扩展说明
