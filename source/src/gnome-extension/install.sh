#!/usr/bin/env bash
# ============================================================================
# JNL Music Control GNOME Shell 扩展安装脚本
# ----------------------------------------------------------------------------
# 在 archiso 构建阶段被 customize_airootfs.sh 调用，将扩展文件复制到系统级
# GNOME Shell 扩展目录，使用户登录后自动启用顶栏音乐控件。
#
# 目标目录：/usr/share/gnome-shell/extensions/jnl-music@jnl-os.local/
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_UUID="jnl-music@jnl-os.local"
EXT_DIR="/usr/share/gnome-shell/extensions/${EXT_UUID}"

echo "==> 安装 JNL Music Control GNOME Shell 扩展"

# ----------------------------------------------------------------------------
# 1. 权限检查
# ----------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "需要 root 权限，请使用 sudo 运行本脚本" >&2
  exit 1
fi

# ----------------------------------------------------------------------------
# 2. 创建扩展目录并复制文件
# ----------------------------------------------------------------------------
echo "  复制扩展文件到 ${EXT_DIR}"
install -d -m755 "${EXT_DIR}"

# 复制扩展必需文件（metadata / extension / stylesheet）
install -m644 "${SCRIPT_DIR}/metadata.json"  "${EXT_DIR}/metadata.json"
install -m644 "${SCRIPT_DIR}/extension.js"   "${EXT_DIR}/extension.js"
install -m644 "${SCRIPT_DIR}/stylesheet.css" "${EXT_DIR}/stylesheet.css"

# ----------------------------------------------------------------------------
# 3. 创建 schemas 目录（预留，当前扩展未使用 GSettings）
# ----------------------------------------------------------------------------
if [ -d "${SCRIPT_DIR}/schemas" ]; then
  echo "  安装 schemas"
  install -d -m755 "${EXT_DIR}/schemas"
  install -m644 "${SCRIPT_DIR}/schemas"/*.xml "${EXT_DIR}/schemas/" 2>/dev/null || true
  if [ -f "${SCRIPT_DIR}/schemas/gschemas.compiled" ]; then
    install -m644 "${SCRIPT_DIR}/schemas/gschemas.compiled" "${EXT_DIR}/schemas/"
  fi
fi

# ----------------------------------------------------------------------------
# 4. 确保扩展目录属主为 root
# ----------------------------------------------------------------------------
chown -R root:root "${EXT_DIR}"

echo "  扩展已安装到 ${EXT_DIR}"
echo "==> GNOME Shell 扩展安装完成"
