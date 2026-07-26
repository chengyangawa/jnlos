#!/bin/bash
# Java Net Lava OS - WSL Arch Linux 初始化脚本（修正版）
set -e

echo "=== 配置 pacman 镜像源（清华 + 腾讯）==="
cat > /etc/pacman.d/mirrorlist <<'EOF'
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.cloud.tencent.com/archlinux/$repo/os/$arch
Server = https://mirror.iscas.ac.cn/archlinux/$repo/os/$arch
EOF

echo "=== keyring 已初始化，跳过 ==="

echo ""
echo "=== 同步包数据库 ==="
pacman -Sy --noconfirm

echo ""
echo "=== 安装 archiso 和构建主机依赖 ==="
# 注意：python-gobject / gstreamer 等是目标系统(airootfs)的依赖，
# 通过 packages.x86_64 由 archiso 安装到 ISO 内，构建主机不需要。
pacman -S --noconfirm --needed \
    archiso \
    squashfs-tools \
    rsync \
    python \
    base-devel \
    git \
    dosfstools

echo ""
echo "=== 验证 archiso 安装 ==="
which mkarchiso
mkarchiso --version 2>&1 || true

echo ""
echo "=== WSL Arch 初始化完成 ==="
