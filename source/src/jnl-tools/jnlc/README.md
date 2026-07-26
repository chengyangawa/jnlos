# jnlc

**jnlc**（Java Net Lava Compiler）是 Java Net Lava OS 的 `.jnl` 音乐包格式命令行工具。

`.jnl` 是一种基于 ZIP 的音乐打包格式，将一首歌曲的音频（`audio.<ext>`）、元数据（`meta.json`）、封面（`cover.jpg`，可选）和歌词（`lyrics.lrc`，可选）打包为单一文件，便于在系统各组件之间传递与归档。格式规范详见 [`../spec/FORMAT.md`](../spec/FORMAT.md)。

## 功能

| 子命令 | 说明 |
|--------|------|
| `pack <dir> <output.jnl>` | 打包目录为 `.jnl` 文件 |
| `unpack <input.jnl> <dir>` | 解包 `.jnl` 到目录 |
| `info <input.jnl>` | 查看 `.jnl` 元数据信息 |
| `play <input.jnl>` | 调用系统播放器播放 `.jnl` |
| `list <dir>` | 以表格形式列出目录中的 `.jnl` 文件 |

## 安装

### 方式一：直接安装（无需打包）

```bash
chmod +x jnlc
sudo cp jnlc /usr/bin/jnlc
```

### 方式二：通过 makepkg 安装（Arch Linux）

```bash
cd src/jnl-tools/jnlc
makepkg -si
```

安装后即可在任意位置使用 `jnlc` 命令。

## 用法示例

```bash
# 打包：将 ./my-song 目录打包为 .jnl 文件
jnlc pack ./my-song './周杰伦 - 稻香.jnl'

# 查看信息
jnlc info './周杰伦 - 稻香.jnl'

# 解包到目录
jnlc unpack './周杰伦 - 稻香.jnl' ./my-song

# 播放
jnlc play './周杰伦 - 稻香.jnl'

# 列出音乐库
jnlc list ~/.local/share/jnl-os/music/
```

### 打包目录结构示例

```
my-song/
├── audio.mp3       # 必需（也支持 .flac/.ogg/.m4a/.wav/.opus）
├── meta.json       # 可选（缺失时自动生成）
├── cover.jpg       # 可选
└── lyrics.lrc      # 可选
```

若目录中缺少 `meta.json`，`jnlc pack` 会自动生成一份，标题取目录名，艺术家默认 `Unknown`。

## 依赖

- **必需**：Python 3（仅使用标准库：`zipfile`、`argparse`、`json`、`subprocess`、`pathlib` 等）
- **可选**：
  - `mutagen`：用于在缺少 `meta.json` 时自动读取音频时长
  - `mpv` / `vlc` / `gst-play` / `ffplay`：用于 `play` 子命令播放音频（按优先级自动选择）

## 许可证

GPL3
