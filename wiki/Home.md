# Java Net Lava OS

基于 Arch Linux 的桌面发行版，集成 12 套精美主题、`.jnl` 音乐包生态与一键安装体验。

## 快速导航

| 类别 | 页面 |
|------|------|
| 入门 | [安装指南](https://github.com/chengyangawa/jnlos/wiki/Installation) |
| 桌面 | [主题系统](https://github.com/chengyangawa/jnlos/wiki/Themes) |
| 音乐 | [音乐播放器](https://github.com/chengyangawa/jnlos/wiki/Music-Player) |
| 格式 | [.jnl 格式规范](https://github.com/chengyangawa/jnlos/wiki/JNL-Format) |
| 扩展 | [浏览器扩展](https://github.com/chengyangawa/jnlos/wiki/Browser-Extension) |
| 开发 | [构建指南](https://github.com/chengyangawa/jnlos/wiki/Building) |
| 帮助 | [常见问题](https://github.com/chengyangawa/jnlos/wiki/FAQ) |

## 核心特性

- **开机自动进入桌面**：GDM 配置自动登录，开机即进 GNOME（Wayland 优先），无需手动输入用户名密码。
- **12 套原创主题**：覆盖深色/浅色/极光/岩浆/玫瑰等风格，配套 GTK3、GTK4、GNOME Shell、图标、壁纸一站式切换。
- **archinstall 一键安装**：使用 Arch 官方 TUI 安装器 `archinstall`，预置 GNOME 桌面、中文 locale、清华镜像源、jnluser 用户等配置。
- **`.jnl` 音乐包格式**：自定义 ZIP 容器格式，将音频/元数据/封面/歌词打包为单文件。
- **jnlp 桌面播放器**：基于 GTK4 + GStreamer 的图形播放器，支持音乐库扫描、歌词同步、封面展示、DBus 远程控制。
- **QQ音乐下载浏览器扩展**：Manifest V3 扩展，一键将歌曲打包为 `.jnl` 保存到本地音乐库。
- **GNOME Shell 任务栏控件**：顶栏显示当前曲目并提供上一首/下一首/播放暂停按钮。
- **中文开箱即用**：预装 Noto CJK 字体、Fcitx5 中文输入法、Firefox 与 Chromium 中文语言包。

## 下载

最新版本 **1.0.32** 已发布，ISO 文件 8.1 GB，已分割为 9 个分卷。

[前往 Release 页面下载](https://github.com/chengyangawa/jnlos/releases/tag/v1.0.32)

## 许可证

本项目代码与配置文件遵循 MIT 许可证；预装的 Arch Linux 软件包各自遵循其原始许可证。
