# Java Net Lava OS

> 基于 Arch Linux 的桌面发行版，集成 12 套精美主题、`.jnl` 音乐包生态与一键安装体验。

## 项目介绍

**Java Net Lava OS**（简称 **JNL OS**）是基于 [archiso](https://wiki.archlinux.org/title/Archiso) 构建工具链定制的 Arch Linux 桌面发行版。它面向桌面用户，预装 GNOME 桌面环境与一整套原创音乐相关功能，开箱即用。

整套构建流程运行于 WSL（Windows Subsystem for Linux）中的 Arch Linux 环境，便于在 Windows 主机上一键产出可启动的 ISO 镜像，无需双系统或虚拟机即可完成发行版构建。

## 核心特性

- **开机自动进入桌面**：GDM 配置自动登录，开机即进 GNOME（Wayland 优先），无需手动输入用户名密码。
- **12 套原创主题**：覆盖深色/浅色/极光/岩浆/玫瑰等风格，配套 GTK3、GTK4、GNOME Shell、图标、壁纸一站式切换。详见 [themes.md](./themes.md)。
- **archinstall 一键安装**：使用 Arch 官方 TUI 安装器 `archinstall`，预置 GNOME 桌面、中文 locale、清华镜像源、jnluser 用户等配置，桌面双击即可启动安装。
- **`.jnl` 音乐包格式**：自定义 ZIP 容器格式，将音频/元数据/封面/歌词打包为单文件，MIME 注册为 `application/x-jnl`。详见 [jnl-format.md](./jnl-format.md)。
- **jnlp 桌面播放器**：基于 GTK4 + GStreamer 的图形播放器，支持音乐库扫描、歌词同步、封面展示、进度拖动、DBus 远程控制。
- **QQ音乐下载浏览器扩展**：Manifest V3 扩展，在 QQ 音乐页面注入下载按钮，一键将歌曲打包为 `.jnl` 保存到本地音乐库。详见 [music-feature.md](./music-feature.md)。
- **GNOME Shell 任务栏控件**：原创 Shell 扩展，通过 DBus 监听 `org.jnl_os.Player`，在顶栏显示当前曲目并提供上一首/下一首/播放暂停按钮。
- **中文开箱即用**：预装 Noto CJK 字体、Fcitx5 中文输入法、Firefox 与 Chromium 中文语言包。

## 目录结构

```
Java Net Lava OS/
├── src/                         # 源码目录
│   ├── archiso-profile/         # archiso profile 配置
│   │   ├── profiledef.sh        # profile 定义（ISO 名称、压缩方式等）
│   │   ├── packages.x86_64      # 软件包清单
│   │   ├── pacman.conf          # pacman 配置（含镜像与仓库）
│   │   ├── airootfs/            # Live 系统根文件系统
│   │   │   ├── etc/             # 系统配置（fstab、machine-id）
│   │   │   └── root/
│   │   │       └── customize_airootfs.sh   # 系统定制脚本
│   │   ├── bootloader-files/    # GRUB 与 syslinux 引导配置
│   │   └── efiboot/             # UEFI 启动项配置
│   ├── themes/                  # 12 套桌面主题
│   │   ├── _template/           # 主题模板（GTK3/GTK4/Shell/图标）
│   │   ├── colors/              # 12 套配色变量文件（*.sh）
│   │   ├── wallpapers/          # 壁纸生成脚本与产物
│   │   ├── generated/           # 主题生成器产物（构建时生成）
│   │   ├── generate-themes.sh   # 主题批量生成脚本
│   │   └── switch-theme.sh      # 主题切换脚本
│   ├── jnl-tools/               # .jnl 格式工具
│   │   ├── jnlc/                # 命令行工具（pack/unpack/info/play/list）
│   │   ├── jnlp/                # 桌面播放器（GTK4 + GStreamer）
│   │   └── spec/                # 格式规范与示例
│   │       ├── FORMAT.md        # .jnl 格式规范
│   │       ├── meta-schema.json # meta.json 的 JSON Schema
│   │       └── examples/sample-song/  # 示例歌曲（audio.mp3 + meta.json + lyrics.lrc）
│   ├── browser-extension/       # 浏览器扩展（QQ音乐下载）
│   │   ├── manifest.json        # Manifest V3 清单
│   │   ├── background.js         # Service Worker
│   │   ├── content.js            # 内容脚本
│   │   ├── content.css           # 页面样式
│   │   └── native-host/         # 原生消息通信桥（Python）
│   ├── gnome-extension/        # GNOME Shell 任务栏音乐控件
│   └── installer/              # archinstall 配置与系统安装脚本
├── build/                      # 构建脚本目录
│   ├── wsl-setup.sh             # WSL Arch 环境准备脚本
│   ├── sync-to-wsl.sh           # 源码同步到 WSL 工作目录脚本
│   ├── build.sh                 # 构建主脚本（在 WSL 中执行）
│   ├── build.ps1                # PowerShell 入口脚本（在 Windows 中执行）
│   └── README.md                # 构建说明文档
├── docs/                       # 文档目录
│   ├── README.md                # 本文档
│   ├── jnl-format.md            # .jnl 格式规范说明
│   ├── themes.md                # 12 套主题说明
│   └── music-feature.md         # 音乐功能使用指南
└── out/                        # ISO 输出目录（构建产物，已 gitignore）
```

## 快速开始

### 1. 环境要求

| 项目 | 要求 |
| --- | --- |
| 操作系统 | Windows 10 1809+ 或 Windows 11 |
| WSL | WSL2 已启用 |
| WSL 发行版 | Arch Linux（推荐 [ArchWSL](https://github.com/yuk7/ArchWSL)） |
| 磁盘空间 | 至少 10 GB（构建中间产物约 5 GB，ISO 约 2 GB） |
| 网络 | 需访问 Arch Linux 镜像源（建议国内使用清华或中科大镜像） |
| 权限 | WSL 中需 sudo 权限（用于安装 archiso 等依赖） |

### 2. 构建镜像

在 Windows PowerShell 中执行：

```powershell
cd "g:\FEPT\FEPT\A_industry code\Code\OS\Java Net Lava OS"
.\build\build.ps1
```

`build.ps1` 会自动完成：
1. 检测 WSL 与 Arch Linux 发行版
2. 同步 build 脚本到 WSL 工作目录
3. 在 WSL 中执行 `build.sh`，完成 archiso 构建
4. 将 ISO 与 SHA256 校验文件输出到 `out\` 目录

构建耗时约 30–60 分钟（取决于网络速度与机器性能）。

### 3. 写入 U 盘

推荐以下任一工具将 ISO 写入 U 盘：

- **Rufus**（Windows）：https://rufus.ie/
- **balenaEtcher**（跨平台）：https://etcher.balena.io/
- **dd 命令**（Linux/macOS）：
  ```bash
  sudo dd if=jnl-os-*.iso of=/dev/sdX bs=4M status=progress
  ```

### 4. 启动体验

1. 将 U 盘插入目标电脑，进入 BIOS/UEFI 设置 USB 启动
2. 选择 "Java Net Lava OS" 启动项
3. 进入 Live GNOME 桌面（自动以 jnluser 登录，密码 `jnlos`）
4. 体验桌面主题、音乐播放器、浏览器扩展等功能
5. 桌面双击 **"安装 Java Net Lava OS"** 启动 archinstall 安装到硬盘

## 功能详细说明

### 主题切换

JNL OS 预装 12 套原创主题，可通过以下任一方式切换：

- **桌面快捷方式**：双击桌面 "主题切换" 图标，弹出 zenity 列表选择
- **命令行**：`switch-theme.sh <主题名>`，例如 `switch-theme.sh ocean`
- **GNOME 设置**：打开 "调整" → "外观" → 选择 GTK 与 Shell 主题

切换会自动应用 GTK3、GTK4（libadwaita color-scheme）、图标、Shell、壁纸与锁屏壁纸。详见 [themes.md](./themes.md)。

### 音乐播放器

`jnlp` 是 JNL OS 自带的桌面音乐播放器，特性：

- 扫描 `~/.local/share/jnl-os/music/*.jnl` 自动构建歌单
- GStreamer 解码播放（支持 mp3/flac/ogg/m4a）
- 时间同步 LRC 歌词显示（当前行高亮）
- 封面、专辑、时长、比特率显示
- 进度条拖动跳转、音量调节
- 注册 DBus 服务 `org.jnl_os.Player`，供 GNOME 扩展远程控制
- 双击 `.jnl` 文件直接播放（MIME 关联）

启动方式：桌面双击 "JNL 播放器"，或终端执行 `jnlp`。详见 [music-feature.md](./music-feature.md)。

### 浏览器扩展

QQ音乐下载扩展基于 Manifest V3 实现：

- 在 `y.qq.com` 页面注入下载按钮（位于歌曲操作区）
- 调用页面已解密音频流 URL，触发下载
- 通过 Native Messaging 与 Python 桥接程序通信
- Python 桥接程序接收音频与元数据，调用 `jnlc pack` 打包为 `.jnl`
- 自动保存到 `~/.local/share/jnl-os/music/`，文件名形如 `周杰伦 - 稻香.jnl`

安装：在 Firefox / Chromium 中通过 "加载已解压的扩展程序" 加载 `src/browser-extension/` 目录。详见 [music-feature.md](./music-feature.md#浏览器扩展)。

### 任务栏音乐控件

GNOME Shell 扩展 `jnl-music@jnl-os.local` 提供顶栏音乐控件：

- 监听 DBus 信号 `SongChanged` 与 `StatusChanged`
- 顶栏显示当前曲目标题（滚动文本）
- 下拉菜单提供上一首/暂停/下一首按钮与音量滑块
- 显示当前歌曲封面缩略图
- 仅在 `jnlp` 运行时显示

扩展随系统启用（`customize_airootfs.sh` 中通过 dconf 预启用）。

### archinstall 安装步骤

JNL OS 使用 Arch 官方 `archinstall` 工具进行系统安装，预置配置文件位于 Live 系统的 `/etc/jnl-os/`：

1. 桌面双击 **"安装 Java Net Lava OS"**，或在终端执行：
   ```bash
   sudo /usr/local/bin/install-jnl-os.sh
   ```
2. `archinstall` 启动并加载预配置：
   - 主机名：`jnl-os`
   - 时区：`Asia/Shanghai`
   - locale：`zh_CN.UTF-8`
   - 内核：`linux`
   - 桌面：GNOME
   - 引导：GRUB
   - 镜像源：清华 TUNA
   - 用户：`jnluser`（密码 `jnlos`，sudo 启用）
3. 按提示选择目标磁盘、是否格式化、是否启用 swap
4. 确认配置后开始安装，约 10–30 分钟
5. 安装完成后重启进入新系统

预置配置文件路径：
- 主配置：`/etc/jnl-os/archinstall.conf`
- 凭据：`/etc/jnl-os/creds.conf`
- 包装器：`/usr/local/bin/install-jnl-os.sh`

## 技术架构

### 构建链

- **archiso**：Arch 官方 ISO 构建工具，基于 releng profile
- **squashfs + xz**：根文件系统压缩方式，压缩率高、随机读取性能优
- **GRUB + syslinux**：双引导支持（UEFI 用 GRUB，BIOS 用 syslinux）
- **profiledef.sh**：定义 ISO 元数据、引导项、文件系统布局

### 桌面环境

- **GNOME**：默认桌面环境，最新稳定版
- **GDM**：图形登录管理器，配置自动登录 jnluser
- **Wayland**：默认显示协议（WaylandEnable=true），X11 作为兜底
- **PipeWire**：音频服务器（archinstall 配置 `audio: pipewire`）
- **Fcitx5**：中文输入法

### 工具链

- **Python 3**：jnlc 与 jnlp 主语言，仅依赖标准库
- **PyGObject**：Python 绑定 GTK4 / GStreamer / GdkPixbuf / GLib / Gio
- **GStreamer**：媒体解码与播放后端（含 good/bad/ugly/base/libav 插件集）
- **GTK4**：jnlp 播放器与 GNOME 4.x 应用 UI 框架
- **DBus**：jnlp 注册 `org.jnl_os.Player` 服务，供 GNOME 扩展调用
- **rsync**：源码从 Windows 同步到 WSL 的工作目录

### 系统组件关系

```
┌─────────────────────────────────────────────────────────────┐
│                    Java Net Lava OS                          │
├─────────────────────────────────────────────────────────────┤
│  GNOME Shell  ◄──── DBus ──── jnlp (org.jnl_os.Player)        │
│  ├─ 顶栏音乐控件扩展            │  ├─ GStreamer 播放后端       │
│  ├─ 主题（user-theme 扩展）      │  ├─ GTK4 界面               │
│  └─ GDM 自动登录 jnluser        │  └─ 扫描 ~/.local/.../music/  │
│                                  └──────▲─────────────────────┤
│  Firefox / Chromium                                          │
│  └─ QQ音乐下载扩展 ── Native Messaging ── jnl-bridge.py      │
│                                              │                │
│                                              ▼                │
│                                          jnlc pack           │
│                                          （生成 .jnl）         │
└─────────────────────────────────────────────────────────────┘
```

## 相关文档

- [build/README.md](../build/README.md) — 构建脚本使用说明
- [jnl-format.md](./jnl-format.md) — `.jnl` 音乐包格式规范
- [themes.md](./themes.md) — 12 套主题详细说明
- [music-feature.md](./music-feature.md) — 音乐功能使用指南
- [src/jnl-tools/spec/FORMAT.md](../src/jnl-tools/spec/FORMAT.md) — 格式规范源文件

## 许可证

本项目代码与配置文件遵循 MIT 许可证；预装的 Arch Linux 软件包各自遵循其原始许可证。

## 致谢

- [Arch Linux](https://archlinux.org/) — 上游发行版
- [archiso](https://wiki.archlinux.org/title/Archiso) — ISO 构建工具
- [ArchWSL](https://github.com/yuk7/ArchWSL) — WSL 中的 Arch Linux
- [GNOME](https://www.gnome.org/) — 桌面环境
- [GStreamer](https://gstreamer.freedesktop.org/) — 多媒体框架
