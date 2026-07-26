# .jnl 格式规范

## 概述

`.jnl` 是 JNL OS 自定义的音乐包格式，基于 ZIP 压缩，将音频文件、元数据、封面图片和歌词打包为单一文件。

## 文件结构

```
song.jnl/
├── audio/
│   └── song.mp3          # 音频文件（MP3/FLAC/WAV）
├── cover/
│   └── cover.jpg         # 封面图片（JPEG/PNG）
├── lyrics/
│   └── lyrics.lrc        # 歌词文件（LRC格式）
└── metadata.json         # 元数据JSON文件
```

## 元数据格式

`metadata.json` 文件包含歌曲的所有元数据：

```json
{
  "title": "歌曲标题",
  "artist": "艺术家名称",
  "album": "专辑名称",
  "year": 2024,
  "trackNumber": 5,
  "genre": "流行",
  "duration": 245,
  "bitrate": 320,
  "format": "mp3",
  "language": "zh",
  "description": "歌曲描述",
  "releaseDate": "2024-01-15",
  "composer": "作曲家",
  "lyricist": "作词人",
  "publisher": "发行商"
}
```

### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| title | string | 是 | 歌曲标题 |
| artist | string | 是 | 艺术家名称 |
| album | string | 否 | 专辑名称 |
| year | number | 否 | 发行年份 |
| trackNumber | number | 否 | 曲目编号 |
| genre | string | 否 | 音乐类型 |
| duration | number | 是 | 歌曲时长（秒） |
| bitrate | number | 否 | 比特率（kbps） |
| format | string | 是 | 音频格式（mp3/flac/wav） |
| language | string | 否 | 语言代码（zh/en/ja等） |
| description | string | 否 | 歌曲描述 |
| releaseDate | string | 否 | 发行日期（YYYY-MM-DD） |
| composer | string | 否 | 作曲家 |
| lyricist | string | 否 | 作词人 |
| publisher | string | 否 | 发行商 |

## 音频格式

支持的音频格式：

| 格式 | 扩展名 | 说明 |
|------|--------|------|
| MP3 | .mp3 | 最常用，兼容性好 |
| FLAC | .flac | 无损压缩 |
| WAV | .wav | 无损原始格式 |
| Ogg | .ogg | 开源格式 |
| M4A | .m4a | Apple格式 |

## 封面格式

支持的封面图片格式：

| 格式 | 扩展名 | 推荐尺寸 |
|------|--------|----------|
| JPEG | .jpg | 500x500 |
| PNG | .png | 500x500 |

## 歌词格式

歌词使用标准 LRC 格式：

```
[00:00.00] 歌词第一句
[00:03.50] 歌词第二句
[00:07.00] 歌词第三句
```

## 创建 .jnl 文件

### 使用命令行工具

```bash
# 创建 .jnl 文件
jnl-pack -a song.mp3 -c cover.jpg -l lyrics.lrc -m metadata.json output.jnl

# 查看 .jnl 文件信息
jnl-info song.jnl

# 解压 .jnl 文件
jnl-unpack song.jnl /path/to/dest
```

### 手动创建

1. 创建目录结构：

```bash
mkdir -p song.jnl/{audio,cover,lyrics}
```

2. 放入文件：

```bash
cp song.mp3 song.jnl/audio/
cp cover.jpg song.jnl/cover/
cp lyrics.lrc song.jnl/lyrics/
cp metadata.json song.jnl/
```

3. 压缩为 ZIP：

```bash
cd song.jnl
zip -r ../song.jnl *
```

## 验证 .jnl 文件

```bash
# 验证格式是否正确
jnl-validate song.jnl

# 检查文件完整性
jnl-check song.jnl
```

## 示例

完整的 `.jnl` 文件示例：

```
example.jnl
├── audio/
│   └── example.mp3
├── cover/
│   └── cover.jpg
├── lyrics/
│   └── lyrics.lrc
└── metadata.json
```

`metadata.json`:

```json
{
  "title": "Example Song",
  "artist": "JNL Artist",
  "album": "JNL Album",
  "year": 2024,
  "trackNumber": 1,
  "genre": "Electronic",
  "duration": 180,
  "bitrate": 320,
  "format": "mp3",
  "language": "en",
  "description": "An example song for JNL OS",
  "releaseDate": "2024-01-01",
  "composer": "JNL Composer",
  "lyricist": "JNL Lyricist",
  "publisher": "JNL Records"
}
```

## 版本历史

| 版本 | 变更 |
|------|------|
| 1.0 | 初始版本 |
| 1.1 | 添加语言和描述字段 |
| 1.2 | 支持 FLAC 格式 |
| 1.3 | 添加作曲家、作词人、发行商字段 |
