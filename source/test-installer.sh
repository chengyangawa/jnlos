#!/bin/bash
# 测试 GTK3 导入
python3 << 'EOF'
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk
print("GTK3 OK")
EOF

# 检查 jnl-gui-installer 文件是否存在
echo ""
echo "=== 检查安装程序文件 ==="
ls -la /usr/bin/jnl-gui-installer 2>/dev/null || echo "jnl-gui-installer 不存在"
ls -la /usr/bin/jnl-installer-worker 2>/dev/null || echo "jnl-installer-worker 不存在"
ls -la /usr/share/jnl-os/JNL\ install.mp3 2>/dev/null || echo "JNL install.mp3 不存在"

# 检查依赖包
echo ""
echo "=== 检查依赖 ==="
for pkg in python-gobject python3-gobject gtk3 python3-pygame; do
    if pacman -Q "$pkg" 2>/dev/null; then
        echo "✓ $pkg 已安装"
    else
        echo "✗ $pkg 未安装"
    fi
done

# 尝试直接运行安装程序（捕获错误）
echo ""
echo "=== 尝试运行安装程序 ==="
cd /home/jnluser
DISPLAY=:0 python3 /usr/bin/jnl-gui-installer 2>&1 | head -50 || echo "安装程序运行失败"
