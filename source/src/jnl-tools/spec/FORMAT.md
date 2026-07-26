# JNL 音乐包格式规范

> **版本**：1.0  
> **状态**：正式规范  
> **最后更新**：2026-07-01  
> **MIME 类型**：`application/x-jnl`  
> **扩展名**：`.jnl`

---

## 1. 格式概述

`.jnl`（Java Net Lava Music Pack）是 Java Net Lava OS 自定义的音乐打包格式，用于将一首歌曲的音频、元数据、封面和歌词打包为单一文件，便于在系统各组件之间传递与归档。

- **底层容器**：标准 ZIP 压缩包（与 `unzip` 工具完全兼容）
- **文件扩展名**：`.jnl`
- **MIME 类型**：`application/x-jnl`
- **设计目标**：简单、实用、可被通用工具直接解压，便于在 ISO 发布介质中归档
- **适用场景**：QQ 音乐下载浏览器扩展打包、桌面播放器（jnlp）读取、GNOME Shell 音乐控件展示、`jnlc` 命令行工具 pack/unpack/info/play 操作

由于 `.jnl` 本质为 ZIP，任何符合标准的 ZIP 工具（如 `unzip`、`7z`、`jar`）均可直接打开和检查其内容，无需专用解包程序。

---

## 2. 容器结构

`.jnl` 文件解压后必须包含如下目录结构（无嵌套子目录，所有文件位于 ZIP 根目录）：

```
audio.mp3          # 必需，音频文件，支持 mp3/flac/ogg/m4a
meta.json          # 必需，元数据 JSON
cover.jpg          # 可选，封面图片
lyrics.lrc         # 可选，LRC 格式歌词
```

### 2.1 文件说明

| 文件名 | 是否必需 | 说明 |
|--------|----------|------|
| `audio.mp3` | 必需 | 音频主体。**文件名固定为 `audio.<ext>`，扩展名必须与 `meta.json` 中 `audio_codec` 字段一致**（例如 `audio.flac`、`audio.ogg`、`audio.m4a`）。一个 `.jnl` 包中只允许存在一个音频文件。 |
| `meta.json` | 必需 | 元数据描述文件，UTF-8 编码 JSON。详见第 3 节。 |
| `cover.jpg` | 可选 | 封面图片，建议 JPG/PNG，正方形，边长 ≥ 300 像素。 |
| `lyrics.lrc` | 可选 | LRC 格式歌词，UTF-8 编码（可带 BOM 也可不带）。 |

### 2.2 ZIP 打包约束

- 压缩方式：建议使用 `deflate`（标准 ZIP 默认）。音频已为压缩格式，压缩率对体积影响可忽略。
- 所有条目位于 ZIP 根目录，**不允许嵌套子目录**。
- 文件名编码：ZIP 条目名使用 UTF-8（设置 ZIP 通用位标志位 11）。

---

## 3. meta.json 字段规范

### 3.1 完整示例

```json
{
  "format_version": "1.0",
  "title": "歌曲标题",
  "artist": "艺术家",
  "album": "专辑名",
  "duration": 234,
  "source_url": "https://y.qq.com/...",
  "source_platform": "qqmusic",
  "audio_codec": "mp3",
  "audio_bitrate": 320,
  "created_at": "2026-07-01T12:00:00Z",
  "tags": ["流行", "华语"]
}
```

### 3.2 字段说明

| 字段名 | 类型 | 是否必需 | 说明 |
|--------|------|----------|------|
| `format_version` | string | **必需** | 格式版本号，当前规范取值为 `"1.0"`。 |
| `title` | string | **必需** | 歌曲标题，非空字符串。 |
| `artist` | string | **必需** | 艺术家名称，非空字符串。 |
| `album` | string | 可选 | 专辑名称。 |
| `duration` | integer | **必需** | 歌曲时长，单位为秒，正整数。 |
| `source_url` | string | 可选 | 歌曲来源页面 URL。 |
| `source_platform` | string | 可选 | 来源平台标识，建议使用小写英文短名，如 `qqmusic`、`netease`、`local`。 |
| `audio_codec` | string | 可选 | 音频编码，取值：`mp3`、`flac`、`ogg`、`m4a`。默认 `mp3`，且必须与音频文件扩展名一致。 |
| `audio_bitrate` | integer | 可选 | 音频比特率，单位 kbps，正整数。如 `128`、`320`。 |
| `created_at` | string | 可选 | 打包创建时间，ISO 8601 格式（如 `2026-07-01T12:00:00Z`）。 |
| `tags` | array&lt;string&gt; | 可选 | 风格/分类标签列表。 |

### 3.3 编码与约束

- 文件编码：UTF-8（不带 BOM）。
- JSON 顶层为对象（`object`），允许包含未在上述表格中列出的扩展字段（参见第 6 节）。
- `duration` 必须为正整数，且应与实际音频时长一致（允许 ±2 秒误差）。
- `format_version` 在本规范版本下必须严格为 `"1.0"`。

---

## 4. 命名约定

### 4.1 .jnl 文件命名

打包后的 `.jnl` 文件按以下规则命名：

```
<artist> - <title>.jnl
```

- `<artist>` 与 `<title>` 取自 `meta.json` 中对应字段。
- 文件名中不允许出现以下字符，遇到时统一替换为下划线 `_`：

  ```
  / \ : * ? " < > | 以及控制字符
  ```

- 连续的非法字符折叠为单个下划线，首尾不保留下划线。
- 若 `artist` 或 `title` 为空，使用 `unknown` 作为占位。

**示例**：

| artist | title | .jnl 文件名 |
|--------|-------|-------------|
| 周杰伦 | 稻香 | `周杰伦 - 稻香.jnl` |
| AC/DC | Back In Black | `AC_DC - Back In Black.jnl` |
| 佚名 | 示例曲 | `unknown - 示例曲.jnl` |

### 4.2 内部文件命名

ZIP 内部文件名固定（`audio.<ext>`、`meta.json`、`cover.jpg`、`lyrics.lrc`），不随歌曲标题变化，便于工具程序统一解析。

---

## 5. 安全考虑

为保证 `.jnl` 文件可被安全解压，打包工具与解压工具必须遵守以下约束：

1. **禁止绝对路径**：ZIP 条目名不允许以 `/` 或盘符（如 `C:\`）开头，所有条目必须位于根目录（无前导 `./`，无目录前缀）。
2. **禁止路径穿越**：条目名不允许包含 `..` 段，防止解压时写入到目标目录之外。
3. **禁止符号链接**：ZIP 条目中不允许包含符号链接（symlink）或硬链接条目，所有条目必须为普通文件。
4. **禁止可执行属性**：不设置 Unix 可执行位（mode `0o755` 等），文件统一为普通只读文件。
5. **大小限制**：单个 `.jnl` 文件建议不超过 50 MB；`meta.json` 不超过 64 KB；`lyrics.lrc` 不超过 256 KB。
6. **编码校验**：打包时校验 `meta.json` 为合法 JSON 并符合 schema（见 `meta-schema.json`）。

---

## 6. 兼容性

- **标准工具兼容**：所有 `.jnl` 文件必须能被标准 `unzip` 工具直接解压，无需专用程序。
- **向后兼容**：当未来 `format_version` 升级时，新版工具必须能读取 `1.0` 版本的 `.jnl` 文件；旧版工具遇到更高版本时应以警告方式忽略未知字段而非崩溃。
- **扩展字段**：`meta.json` 允许包含未定义字段（`additionalProperties: true`），解析工具应忽略未知字段而非报错。
- **缺失可选文件**：当 `cover.jpg` 或 `lyrics.lrc` 不存在时，播放器与控件应优雅降级（如显示默认封面、不显示歌词）。

---

## 7. 与工具的关系

Java Net Lava OS 中以下组件使用 `.jnl` 格式：

| 工具/组件 | 职责 | 与 .jnl 的交互 |
|-----------|------|----------------|
| `jnlc pack` | 打包 | 接收音频及元数据，生成符合本规范的 `.jnl` 文件；打包时执行 schema 校验。 |
| `jnlc unpack` | 解包 | 将 `.jnl` 解压到指定目录，还原 `audio.*`、`meta.json`、`cover.jpg`、`lyrics.lrc`。 |
| `jnlc info` | 信息 | 读取 `.jnl` 中的 `meta.json`，打印歌曲元数据。 |
| `jnlc play` | 播放 | 解压 `audio.*` 至临时目录并调用播放器播放。 |
| `jnlp` 桌面播放器 | 播放/管理 | 读取整个 `.jnl`，在内存中解压音频与封面进行播放与展示。 |
| GNOME Shell 音乐控件 | 展示 | 读取 `meta.json` 中的 `title`/`artist` 与 `cover.jpg` 在状态栏展示。 |
| QQ 音乐下载浏览器扩展 | 采集 | 将下载的音频与元数据打包为 `.jnl`，供系统其他组件消费。 |

---

## 8. 示例

### 8.1 完整 meta.json 示例

```json
{
  "format_version": "1.0",
  "title": "稻香",
  "artist": "周杰伦",
  "album": "魔杰座",
  "duration": 223,
  "source_url": "https://y.qq.com/n/ryqq/songDetail/001qvvgF38HVc4",
  "source_platform": "qqmusic",
  "audio_codec": "mp3",
  "audio_bitrate": 320,
  "created_at": "2026-07-01T12:00:00Z",
  "tags": ["流行", "华语"]
}
```

### 8.2 .jnl 文件结构示例

解压后的目录结构：

```
周杰伦 - 稻香.jnl   <- ZIP 文件本体
├── audio.mp3       <- 音频（223 秒，320 kbps）
├── meta.json       <- 元数据（如上所示）
├── cover.jpg       <- 专辑封面（500x500）
└── lyrics.lrc      <- LRC 歌词
```

对应的 `lyrics.lrc`：

```
[00:00.00]稻香 - 周杰伦
[00:12.50]对这个世界如果你有太多的抱怨
[00:18.30]跌倒了 就不敢继续往前走
[00:24.10]为什么 人要这么的脆弱 堕落
[00:30.00]请你打开电视看看
```

### 8.3 校验流程示例

```bash
# 1. 用标准 unzip 检查文件结构（应列出根目录的 4 个文件）
unzip -l 周杰伦\ -\ 稻香.jnl

# 2. 用 jnlc 读取元数据
jnlc info 周杰伦\ -\ 稻香.jnl

# 3. 用 jnlc 播放
jnlc play 周杰伦\ -\ 稻香.jnl
```

---

## 附录 A：参考资料

- [ZIP File Format Specification, PKWARE APPNOTE](https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT)
- [JSON Schema Draft 2020-12](https://json-schema.org/draft/2020-12/schema)
- [ISO 8601 日期与时间表示](https://www.iso.org/iso-8601-date-and-time-format.html)
- [LRC 歌词文件格式规范](https://en.wikipedia.org/wiki/LRC_(file_format))
