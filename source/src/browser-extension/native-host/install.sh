#!/usr/bin/env bash
# jnl-bridge native messaging 主机安装脚本
# 将 jnl-bridge.py 与 native-messaging-hosts 清单注册到
# Chrome / Chromium / Firefox，使浏览器扩展可与 jnlc 通信。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRIDGE_SRC="$SCRIPT_DIR/jnl-bridge.py"
MANIFEST_SRC="$SCRIPT_DIR/manifest.json"

BRIDGE_DST="/usr/bin/jnl-bridge.py"
NM_NAME="jnl_bridge"

# 各浏览器的 native-messaging-hosts 目录
CHROME_NM="/etc/opt/chrome/native-messaging-hosts"
CHROMIUM_NM="/etc/chromium/native-messaging-hosts"
FIREFOX_NM="/usr/lib/mozilla/native-messaging-hosts"
CHROME_USER_NM="$HOME/.config/google-chrome/NativeMessagingHosts"

echo "==> 安装 jnl-bridge native messaging 主机"

if [[ $EUID -ne 0 ]]; then
  echo "需要 root 权限，请使用 sudo 运行本脚本" >&2
  exit 1
fi

# 1. 安装 jnl-bridge.py 到 /usr/bin 并赋予可执行权限
install -Dm755 "$BRIDGE_SRC" "$BRIDGE_DST"
echo "  已安装桥接程序: $BRIDGE_DST"

# 2. 注册 native-messaging-hosts 清单到各浏览器
install -Dm644 "$MANIFEST_SRC" "$CHROME_NM/${NM_NAME}.json"
install -Dm644 "$MANIFEST_SRC" "$CHROMIUM_NM/${NM_NAME}.json"
install -Dm644 "$MANIFEST_SRC" "$FIREFOX_NM/${NM_NAME}.json"

echo "  已注册清单:"
echo "    - $CHROME_NM/${NM_NAME}.json"
echo "    - $CHROMIUM_NM/${NM_NAME}.json"
echo "    - $FIREFOX_NM/${NM_NAME}.json"

# 3. 为当前真实用户创建音乐输出目录（jnl-bridge 运行时也会自动创建）
REAL_USER="${SUDO_USER:-$USER}"
if [[ -n "$REAL_USER" && "$REAL_USER" != "root" ]]; then
  REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6 || true)"
  if [[ -n "$REAL_HOME" ]]; then
    MUSIC_DIR="$REAL_HOME/.local/share/jnl-os/music"
    install -d -m755 -o "$REAL_USER" "$MUSIC_DIR"
    echo "  已创建音乐目录: $MUSIC_DIR"
  fi
fi

# 4. 同时注册到当前用户的 Chrome NativeMessagingHosts 目录（便于非系统级测试）
if [[ -n "$REAL_USER" && "$REAL_USER" != "root" ]]; then
  install -d -m755 -o "$REAL_USER" "$(dirname "$CHROME_USER_NM")"
  install -Dm644 "$MANIFEST_SRC" "$CHROME_USER_NM/${NM_NAME}.json" || true
  chown "$REAL_USER" "$CHROME_USER_NM/${NM_NAME}.json" 2>/dev/null || true
  echo "    - $CHROME_USER_NM/${NM_NAME}.json"
fi

echo "==> native messaging 主机安装完成"
echo "    请确认 jnlc 已安装（/usr/bin/jnlc），否则打包步骤将失败"
