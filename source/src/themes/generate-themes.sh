#!/usr/bin/env bash
# JNL OS 主题生成器
# 功能：读取 colors/ 下的配色变量，套用 _template/ 模板批量生成 12 套完整 GNOME 主题
# 输出：src/themes/generated/<THEME_NAME>/ （含 GTK3/GTK4/Shell/图标/壁纸）
# 用法：./generate-themes.sh
set -euo pipefail

# ====== 路径定义 ======
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLORS_DIR="$SCRIPT_DIR/colors"
TEMPLATE_DIR="$SCRIPT_DIR/_template"
GENERATED_DIR="$SCRIPT_DIR/generated"
WALLPAPER_SCRIPT="$SCRIPT_DIR/wallpapers/generate-wallpapers.sh"
WALLPAPER_DIR="$SCRIPT_DIR/wallpapers"

# ====== 前置检查 ======
if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "错误: 模板目录不存在 $TEMPLATE_DIR" >&2
  exit 1
fi
if [[ ! -x "$WALLPAPER_SCRIPT" ]] && [[ ! -f "$WALLPAPER_SCRIPT" ]]; then
  echo "错误: 壁纸脚本不存在 $WALLPAPER_SCRIPT" >&2
  exit 1
fi

# ====== CSS 占位符替换函数 ======
# 将 CSS 文件中的 var(--xxx) 占位符替换为实际颜色值（取自当前已 source 的配色变量）
# 注意：accent-hover 必须先于 accent 替换，避免误伤
replace_css_vars() {
  local file="$1"
  sed -i \
    -e "s|var(--accent-hover)|${ACCENT_HOVER}|g" \
    -e "s|var(--accent)|${ACCENT}|g" \
    -e "s|var(--bg-dark)|${BG_DARK}|g" \
    -e "s|var(--bg-mid)|${BG_MID}|g" \
    -e "s|var(--bg-light)|${BG_LIGHT}|g" \
    -e "s|var(--fg-dark)|${FG_DARK}|g" \
    -e "s|var(--fg-mid)|${FG_MID}|g" \
    -e "s|var(--fg-light)|${FG_LIGHT}|g" \
    -e "s|var(--warning)|${WARNING}|g" \
    -e "s|var(--error)|${ERROR}|g" \
    -e "s|var(--success)|${SUCCESS}|g" \
    -e "s|var(--shell-bg)|${SHELL_BG}|g" \
    -e "s|var(--shell-fg)|${SHELL_FG}|g" \
    "$file"
}

# ====== 收集所有配色文件 ======
shopt -s nullglob
color_files=("$COLORS_DIR"/*.sh)
shopt -u nullglob

if [[ ${#color_files[@]} -eq 0 ]]; then
  echo "错误: 未在 $COLORS_DIR 找到任何配色文件" >&2
  exit 1
fi

# 清理旧的生成目录
rm -rf "$GENERATED_DIR"
mkdir -p "$GENERATED_DIR"

# ====== 遍历每套配色生成主题 ======
count=0
generated_paths=()

for color_file in "${color_files[@]}"; do
  # 加载配色变量（THEME_NAME、BG_DARK 等）
  # shellcheck source=/dev/null
  source "$color_file"

  # 主题键（文件名，如 default）与主题名（如 JNL-Default）
  theme_key="$(basename "$color_file" .sh)"
  theme_name="${THEME_NAME}"
  out_dir="$GENERATED_DIR/${theme_name}"

  echo "正在生成主题: ${theme_name}（${THEME_DISPLAY:-}）..."

  # 创建输出目录并复制模板
  rm -rf "$out_dir"
  mkdir -p "$out_dir"
  cp -r "$TEMPLATE_DIR/gtk-3.0" "$out_dir/"
  cp -r "$TEMPLATE_DIR/gtk-4.0" "$out_dir/"
  cp -r "$TEMPLATE_DIR/gnome-shell" "$out_dir/"
  cp -r "$TEMPLATE_DIR/icons" "$out_dir/"

  # 替换 CSS 占位符为实际颜色
  replace_css_vars "$out_dir/gtk-3.0/gtk.css"
  replace_css_vars "$out_dir/gtk-4.0/gtk.css"
  replace_css_vars "$out_dir/gnome-shell/gnome-shell.css"
  replace_css_vars "$out_dir/gnome-shell/pad-osd.css"

  # 替换图标主题索引中的主题名占位符
  sed -i "s|__THEME_NAME__|${theme_name}|g" "$out_dir/icons/index.theme"

  # 生成壁纸到 wallpapers/ 目录，并复制一份到主题目录
  bash "$WALLPAPER_SCRIPT" "$theme_key" "$WALLPAPER_DIR"
  if [[ -f "$WALLPAPER_DIR/${theme_name}.svg" ]]; then
    cp "$WALLPAPER_DIR/${theme_name}.svg" "$out_dir/wallpaper.svg"
  fi

  generated_paths+=("$out_dir")
  count=$((count + 1))
  echo "  -> 完成: $out_dir"
done

# ====== 汇总输出 ======
echo ""
echo "=========================================="
echo "JNL OS 主题生成完成，共生成 ${count} 套主题"
echo "输出目录: $GENERATED_DIR"
echo "------------------------------------------"
for p in "${generated_paths[@]}"; do
  echo "  - $p"
done
echo "=========================================="
