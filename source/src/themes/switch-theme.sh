#!/usr/bin/env bash
# JNL OS 主题切换脚本
# 功能：切换 GTK3/GTK4/图标/Shell 主题与桌面壁纸
# 用法：./switch-theme.sh <主题名>
#   主题名取 colors/ 下的文件名，如 default、ocean、forest 等
set -euo pipefail

# ====== 路径定义 ======
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLORS_DIR="$SCRIPT_DIR/colors"
GENERATED_DIR="$SCRIPT_DIR/generated"
WALLPAPER_DIR="$SCRIPT_DIR/wallpapers"

# 系统安装路径（壁纸与主题最终安装位置）
SYS_WALLPAPER_DIR="/usr/share/backgrounds/jnl-os"

# ====== 校验参数 ======
if [[ $# -lt 1 ]]; then
  echo "用法: $0 <主题名>" >&2
  echo "可用主题:" >&2
  shopt -s nullglob
  for f in "$COLORS_DIR"/*.sh; do
    echo "  - $(basename "$f" .sh)" >&2
  done
  shopt -u nullglob
  exit 1
fi

THEME_KEY="$1"
COLOR_FILE="$COLORS_DIR/${THEME_KEY}.sh"

if [[ ! -f "$COLOR_FILE" ]]; then
  echo "错误: 主题 '$THEME_KEY' 不存在（配色文件 $COLOR_FILE 未找到）" >&2
  exit 1
fi

# 加载配色变量
# shellcheck source=/dev/null
source "$COLOR_FILE"

THEME_NAME="${THEME_NAME}"
ICON_THEME="${THEME_NAME}-Icons"
SHELL_THEME="${THEME_NAME}"

# ====== 确定壁纸路径 ======
# 优先使用系统安装路径，回退到生成目录
WALLPAPER_FILE=""
for candidate in \
  "${SYS_WALLPAPER_DIR}/${THEME_NAME}.svg" \
  "${WALLPAPER_DIR}/${THEME_NAME}.svg" \
  "${GENERATED_DIR}/${THEME_NAME}/wallpaper.svg"; do
  if [[ -f "$candidate" ]]; then
    WALLPAPER_FILE="$candidate"
    break
  fi
done

if [[ -z "$WALLPAPER_FILE" ]]; then
  echo "警告: 未找到壁纸文件，请先运行 generate-themes.sh 生成主题" >&2
fi

# ====== 浅色/深色判定（用于 GTK4 color-scheme） ======
# 已知的浅色主题：light、arctic
case "$THEME_KEY" in
  light|arctic)
    COLOR_SCHEME="prefer-light"
    ;;
  *)
    COLOR_SCHEME="prefer-dark"
    ;;
esac

echo "正在切换到主题: ${THEME_DISPLAY:-${THEME_NAME}} ..."

# ====== GTK3 主题 ======
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface gtk-theme "${THEME_NAME}"
  echo "  GTK3 主题 -> ${THEME_NAME}"
else
  echo "  警告: 未找到 gsettings，跳过 GTK3 主题设置" >&2
fi

# ====== GTK4 主题（libadwaita 通过 color-scheme，普通 GTK4 通过 ~/.config/gtk-4.0/gtk.css） ======
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface color-scheme "${COLOR_SCHEME}"
  echo "  GTK4 配色方案 -> ${COLOR_SCHEME}"
fi
GTK4_USER_CSS="$HOME/.config/gtk-4.0/gtk.css"
if [[ -f "$GENERATED_DIR/${THEME_NAME}/gtk-4.0/gtk.css" ]]; then
  mkdir -p "$HOME/.config/gtk-4.0"
  cp "$GENERATED_DIR/${THEME_NAME}/gtk-4.0/gtk.css" "$GTK4_USER_CSS"
  echo "  GTK4 用户样式 -> ${GTK4_USER_CSS}"
else
  echo "  警告: 未找到 GTK4 样式，请先运行 generate-themes.sh" >&2
fi

# ====== 图标主题 ======
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface icon-theme "${ICON_THEME}"
  echo "  图标主题 -> ${ICON_THEME}"
else
  echo "  警告: 未找到 gsettings，跳过图标主题设置" >&2
fi

# ====== GNOME Shell 主题（需 user-theme 扩展） ======
if command -v gsettings >/dev/null 2>&1; then
  if gsettings list-schemas 2>/dev/null | grep -q "org.gnome.shell.extensions.user-theme"; then
    gsettings set org.gnome.shell.extensions.user-theme name "${SHELL_THEME}"
    echo "  Shell 主题 -> ${SHELL_THEME}"
  else
    echo "  警告: 未启用 user-theme 扩展，跳过 Shell 主题设置" >&2
    echo "        请安装并启用 GNOME Shell 扩展 'User Themes'（user-theme）" >&2
  fi
fi

# ====== 桌面壁纸 ======
if [[ -n "$WALLPAPER_FILE" ]]; then
  WALL_URI="file://${WALLPAPER_FILE}"
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.background picture-uri "${WALL_URI}"
    gsettings set org.gnome.desktop.background picture-uri-dark "${WALL_URI}"
    gsettings set org.gnome.desktop.background picture-options "zoom"
    echo "  桌面壁纸 -> ${WALL_URI}"
  fi
  # 锁屏壁纸
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.screensaver picture-uri "${WALL_URI}" 2>/dev/null || true
  fi
fi

echo ""
echo "主题切换完成。"
echo "提示: 若 Shell 主题未生效，请按 Alt+F2 输入 r 重启 GNOME Shell（Wayland 下需重新登录）。"

# ====== GDM 主题同步提示 ======
cat <<GDM_TIP
------------------------------------------
GDM（登录界面）主题同步提示：
GDM 运行于 gdm 用户，无法直接通过 gsettings 切换。如需同步 GDM 主题，可：
  1. 将 Shell 主题资源复制到系统目录：
     sudo cp -r "${GENERATED_DIR}/${THEME_NAME}/gnome-shell" "/usr/share/themes/${THEME_NAME}/"
  2. 编辑 GDM dconf 配置或使用 gsettings 在 gdm 用户下设置：
     sudo -u gdm dbus-launch gsettings set org.gnome.shell.extensions.user-theme name "${SHELL_THEME}"
  3. 重启 GDM：sudo systemctl restart gdm
GDM_TIP
