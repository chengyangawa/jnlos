#!/usr/bin/env bash
# JNL OS 浏览器扩展安装脚本
# - 复制扩展文件到 /usr/share/jnl-os/browser-extension/
# - 为 Firefox 创建全局策略（force_installed，从本地 .xpi 安装）
# - 为 Chromium/Chrome 创建策略（允许加载，开发者模式载入未打包扩展）
# - 调用 native-host/install.sh 注册 native messaging 主机
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_DIR="/usr/share/jnl-os/browser-extension"
XPI_PATH="/usr/share/jnl-os/jnl-music-tool.xpi"

FIREFOX_ID="jnl-music-tool@jnl-os.local"

# Chromium 扩展 ID：未签名扩展加载后由 chrome://extensions 显示。
# 此处策略仅"允许"载入，需在开发者模式下手动"加载已解压的扩展程序"。
FIREFOX_POLICIES_DIR="/etc/firefox/policies"
CHROME_POLICIES_DIR="/etc/opt/chrome/policies/managed"
CHROMIUM_POLICIES_DIR="/etc/chromium/policies/managed"

echo "==> 安装 JNL OS 浏览器扩展"

if [[ $EUID -ne 0 ]]; then
  echo "需要 root 权限，请使用 sudo 运行本脚本" >&2
  exit 1
fi

# 1. 复制扩展文件到系统目录
echo "  复制扩展文件到 $EXT_DIR"
install -d -m755 "$EXT_DIR"
# 同步扩展本体（manifest / 脚本 / 样式 / 图标 / 语言包），排除 native-host 与脚本自身
rsync -a --delete \
  --exclude='native-host' \
  --exclude='install.sh' \
  "$SCRIPT_DIR/" "$EXT_DIR/"

# 2. 为 Firefox 打包 .xpi（ZIP）并写入全局策略 force_installed
echo "  构建 Firefox .xnl 包"
( cd "$EXT_DIR" && rm -f "$XPI_PATH" && zip -qr "$XPI_PATH" . \
  -x 'native-host/*' 'install.sh' )

install -d -m755 "$FIREFOX_POLICIES_DIR"
cat > "$FIREFOX_POLICIES_DIR/policies.json" <<EOF
{
  "policies": {
    "ExtensionSettings": {
      "$FIREFOX_ID": {
        "installation_mode": "force_installed",
        "install_url": "file://$XPI_PATH"
      }
    }
  }
}
EOF
echo "  已写入 Firefox 策略: $FIREFOX_POLICIES_DIR/policies.json"

# 3. 为 Chromium/Chrome 写入策略：允许载入（开发者模式下加载已解压扩展）
write_chrome_policy() {
  local dir="$1"
  install -d -m755 "$dir"
  cat > "$dir/jnl-os.json" <<EOF
{
  "ExtensionSettings": {
    "*": {
      "installation_mode": "allowed"
    }
  }
}
EOF
  echo "  已写入 Chrome/Chromium 策略: $dir/jnl-os.json"
}
write_chrome_policy "$CHROME_POLICIES_DIR"
write_chrome_policy "$CHROMIUM_POLICIES_DIR"

# 4. 安装 native messaging 主机
echo "==> 注册 native messaging 主机"
if [[ -x "$SCRIPT_DIR/native-host/install.sh" ]]; then
  bash "$SCRIPT_DIR/native-host/install.sh"
else
  echo "  警告: 未找到 native-host/install.sh，请手动执行" >&2
fi

cat <<'NOTE'
==> 扩展安装完成

Firefox: 已通过策略自动安装（force_installed），重启浏览器后生效。
Chromium/Chrome: 请打开 chrome://extensions，启用"开发者模式"，
  点击"加载已解压的扩展程序"，选择目录:
  /usr/share/jnl-os/browser-extension/
  并将 native-host/manifest.json 中的 allowed_origins 替换为
  实际加载后的 chrome-extension://<ID>/ 。

使用流程: 打开 y.qq.com 播放音乐 -> 右上角"Tool"按钮 -> "添加指定音乐到桌面音乐"
NOTE
