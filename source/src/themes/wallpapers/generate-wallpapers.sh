#!/usr/bin/env bash
# JNL OS 壁纸生成脚本
# 功能：根据主题配色生成 1920x1080 的 SVG 渐变壁纸
# 用法：generate-wallpapers.sh <主题名> <输出目录>
#   $1 = 主题名（如 default、ocean，对应 colors/ 下的配色文件）
#   $2 = 输出目录（SVG 文件将写入此目录）
# 说明：SVG 不依赖 ImageMagick/PIL，可直接被 GNOME 壁纸设置使用。
set -euo pipefail

# 脚本所在目录（用于定位 colors 配色文件）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLORS_DIR="$SCRIPT_DIR/../colors"

# 校验参数
if [[ $# -lt 2 ]]; then
  echo "用法: $0 <主题名> <输出目录>" >&2
  echo "示例: $0 default /usr/share/backgrounds/jnl-os" >&2
  exit 1
fi

THEME_KEY="$1"
OUTPUT_DIR="$2"
COLOR_FILE="$COLORS_DIR/${THEME_KEY}.sh"

# 加载配色文件（若 WALLPAPER_COLORS 已在环境中则优先使用）
if [[ -z "${WALLPAPER_COLORS:-}" ]]; then
  if [[ ! -f "$COLOR_FILE" ]]; then
    echo "错误: 找不到配色文件 $COLOR_FILE" >&2
    exit 1
  fi
  # shellcheck source=/dev/null
  source "$COLOR_FILE"
fi

# 校验壁纸配色
if [[ -z "${WALLPAPER_COLORS:-}" ]]; then
  echo "错误: 未设置 WALLPAPER_COLORS" >&2
  exit 1
fi

# 解析三个颜色（空格分隔）
read -r C1 C2 C3 <<< "$WALLPAPER_COLORS"
C1="${C1:-#1e1e2e}"
C2="${C2:-#89b4fa}"
C3="${C3:-#cba6f7}"

# 主题名（用于文件名与水印）
THEME_LABEL="${THEME_DISPLAY:-${THEME_NAME:-JNL-OS}}"

# 确保输出目录存在
mkdir -p "$OUTPUT_DIR"

# 输出文件名：使用 THEME_NAME，回退到主题键
OUT_NAME="${THEME_NAME:-${THEME_KEY}}"
OUT_FILE="$OUTPUT_DIR/${OUT_NAME}.svg"

# 生成 SVG 渐变壁纸
# 三色对角线性渐变 + 居中品牌文字
cat > "$OUT_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
  <defs>
    <linearGradient id="jnl-bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="${C1}"/>
      <stop offset="50%" stop-color="${C2}"/>
      <stop offset="100%" stop-color="${C3}"/>
    </linearGradient>
    <radialGradient id="jnl-glow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="${C2}" stop-opacity="0.35"/>
      <stop offset="100%" stop-color="${C2}" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect fill="url(#jnl-bg)" width="1920" height="1080"/>
  <rect fill="url(#jnl-glow)" width="1920" height="1080"/>
  <text x="960" y="520" font-family="Cantarell, Noto Sans, sans-serif" font-size="64" font-weight="bold" fill="#ffffff" fill-opacity="0.95" text-anchor="middle">Java Net Lava OS</text>
  <text x="960" y="580" font-family="Cantarell, Noto Sans, sans-serif" font-size="32" fill="#ffffff" fill-opacity="0.7" text-anchor="middle">${THEME_LABEL}</text>
</svg>
EOF

echo "已生成壁纸: $OUT_FILE"
