# JNL OS Music Tool — 浏览器扩展

Java Net Lava OS 的 QQ 音乐下载浏览器扩展。在 `y.qq.com` 页面右上角注入"Tool"按钮，可一键下载正在播放的音乐，调用系统 `jnlc` 工具打包为 `.jnl` 音乐包并保存到桌面音乐库。

兼容 Manifest V3，支持 Firefox（≥109）与 Chromium 内核浏览器（Chrome / Chromium / Edge）。

## 工作流程

```
y.qq.com 播放音乐
        │
        ▼
content.js 监听 <audio> + MediaSession，记录当前歌曲
        │  点击 "Tool" → "添加指定音乐到桌面音乐"
        ▼
background.js (service worker)
        │  1. fetch 下载音频 / 封面（携带站点 Cookie）
        │  2. 构造 meta.json
        ▼
Native Messaging → jnl-bridge.py
        │  解码 base64 → 临时目录(audio.mp3/cover.jpg/meta.json)
        │  调用 jnlc pack <dir> <output.jnl>
        ▼
~/.local/share/jnl-os/music/<artist> - <title>.jnl
```

`.jnl` 本质为 ZIP，内部固定包含 `audio.mp3`、`meta.json`，可选 `cover.jpg`、`lyrics.lrc`。详见 `src/jnl-tools/spec/FORMAT.md`。

## 目录结构

```
browser-extension/
├── manifest.json          # MV3 清单（兼容 Firefox/Chromium）
├── background.js          # service worker：下载 + 调用 native messaging
├── content.js             # 注入 y.qq.com：工具按钮 / 进度 UI / 歌曲监听
├── content.css            # 按钮 / 菜单 / 进度条样式
├── install.sh             # 扩展安装脚本（复制 + 浏览器策略）
├── _locales/zh_CN/messages.json   # 中文国际化
├── icons/                 # 16/48/128 PNG 图标（见 icons/README.md）
└── native-host/           # Native Messaging 主机
    ├── jnl-bridge.py      # 主机程序：接收消息、调用 jnlc
    ├── manifest.json      # native messaging 注册清单
    └── install.sh         # native host 安装脚本
```

## 前置依赖

- 系统已安装 `jnlc`（路径 `/usr/bin/jnlc`，由 `src/jnl-tools/jnlc/` 提供）
- Python 3（运行 `jnl-bridge.py`，仅用标准库）
- Firefox ≥109 或任意 Chromium 内核浏览器

## 安装

### 一键安装（系统级，需要 root）

在仓库根目录或本目录执行：

```bash
sudo bash src/browser-extension/install.sh
```

该脚本会：

1. 复制扩展文件到 `/usr/share/jnl-os/browser-extension/`
2. 为 Firefox 打包 `.xpi` 并写入全局策略（`force_installed`，重启后自动安装）
3. 为 Chromium / Chrome 写入策略（允许载入）
4. 调用 `native-host/install.sh` 注册 native messaging 主机

### 仅安装 native messaging 主机

```bash
sudo bash src/browser-extension/native-host/install.sh
```

将 `jnl-bridge.py` 装入 `/usr/bin/jnl-bridge.py`，并把 native-messaging 清单注册到：

- `/etc/opt/chrome/native-messaging-hosts/jnl_bridge.json`（Chrome）
- `/etc/chromium/native-messaging-hosts/jnl_bridge.json`（Chromium）
- `/usr/lib/mozilla/native-messaging-hosts/jnl_bridge.json`（Firefox）
- `~/.config/google-chrome/NativeMessagingHosts/jnl_bridge.json`（用户级 Chrome）

### 手动加载（开发调试）

#### Firefox

1. 访问 `about:debugging#/runtime/this-firefox`
2. "加载临时附加组件"，选择本目录下的 `manifest.json`

#### Chrome / Chromium / Edge

1. 访问 `chrome://extensions`
2. 右上角开启"开发者模式"
3. "加载已解压的扩展程序"，选择本目录
4. 记录加载后的扩展 ID，将其写入
   `native-host/manifest.json` 的 `allowed_origins`（格式
   `chrome-extension://<32位ID>/`）后重新执行
   `native-host/install.sh`

## 使用流程

1. 打开 `https://y.qq.com`
2. 播放任意歌曲
3. 点击页面右上角紫色的"⚙️ Tool"按钮
4. 在下拉菜单选择"🎵 添加指定音乐到桌面音乐"
5. 等待进度对话框走完（下载音频 → 下载封面 → 打包 → 保存）
6. 成功后通知会显示保存路径，文件位于
   `~/.local/share/jnl-os/music/<artist> - <title>.jnl`

## 说明与限制

- 扩展依赖 QQ 音乐页面存在 `<audio>` 元素并能获取其 `src`。页面结构或版权保护（如音频流分段加密、blob URL）变化时可能需要调整 `content.js` 中的选择器与抓取逻辑。
- 下载通过 service worker 的 `fetch` 携带站点 Cookie 完成；个别需要 Referer 校验的接口可能失败，此时可考虑改用 `chrome.downloads` API。
- `meta.json` 中 `duration` 在 schema 中要求为不小于 1 的正整数；`background.js` 已做 `Math.max(1, …)` 兜底。
- 图标 PNG 文件需自行生成（见 `icons/README.md`），缺失时浏览器使用默认图标，不影响功能。
