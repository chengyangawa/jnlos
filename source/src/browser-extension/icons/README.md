# 扩展图标

本目录用于存放浏览器扩展图标 PNG 文件。Manifest 引用了以下三个尺寸：

| 文件 | 尺寸 | 用途 |
|------|------|------|
| `icon16.png` | 16×16 | 浏览器标签页 favicon / 工具栏小图标 |
| `icon48.png` | 48×48 | 扩展管理页展示 |
| `icon128.png` | 128×128 | Chrome Web Store / 安装提示 |

## 生成方式

当前仓库未提交实际 PNG 文件。可使用以下任一方式生成，建议使用与
JNL OS 主题一致的紫蓝渐变色（`#667eea` → `#764ba2`）：

```bash
# 1. 使用 Inkscape（推荐）：设计 SVG 后导出各尺寸
inkscape icon.svg --export-type=png --export-filename=icon16.png  -w 16  -h 16
inkscape icon.svg --export-type=png --export-filename=icon48.png  -w 48  -h 48
inkscape icon.svg --export-type=png --export-filename=icon128.png -w 128 -h 128

# 2. 使用 ImageMagick（已有源图时缩放）
convert icon-512.png -resize 16x16   icon16.png
convert icon-512.png -resize 48x48   icon48.png
convert icon-512.png -resize 128x128 icon128.png

# 3. 使用 GIMP：新建 128×128 画布，导出为 icon128.png 后逐级缩放
```

生成后将三个 PNG 文件放入本目录即可，无需修改 manifest.json。
