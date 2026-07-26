#!/bin/bash
# 检查 ISO 的启动配置文件
set -e

ISO="/mnt/g/FEPT/FEPT/A_industry code/Code/OS/Java Net Lava OS/out/jnl-os-2026.07.02-x86_64.iso"

echo "=== ISO 信息 ==="
isoinfo -d -i "$ISO" 2>/dev/null | grep -iE "(volume id|volume size)"
echo ""

echo "=== 提取 ISO 内容 ==="
mkdir -p /tmp/isocheck
rm -rf /tmp/isocheck/*

xorriso -osirrox on -indev "$ISO" -extract / /tmp/isocheck 2>/dev/null || {
    echo "xorriso 提取失败，尝试 isoinfo 列出目录..."
    isoinfo -l -i "$ISO" 2>/dev/null | head -40
    exit 1
}

echo "ISO 根目录："
ls /tmp/isocheck/
echo ""

echo "=== 查找启动配置文件 ==="
find /tmp/isocheck -name "*.conf" 2>/dev/null
echo ""

echo "=== EFI 启动条目 ==="
for f in /tmp/isocheck/loader/entries/*.conf; do
    if [ -f "$f" ]; then
        echo "--- $f ---"
        cat "$f"
        echo ""
    fi
done

echo "=== syslinux 配置 ==="
for f in /tmp/isocheck/boot/syslinux/*.cfg; do
    if [ -f "$f" ]; then
        echo "--- $f ---"
        cat "$f"
        echo ""
    fi
done

echo "=== 检查 EFI 启动镜像 ==="
EFI_IMG=$(find /tmp/isocheck -name '*.img' -size +1M 2>/dev/null | head -1)
echo "EFI 镜像: $EFI_IMG"
if [ -n "$EFI_IMG" ]; then
    mkdir -p /tmp/efimount
    mount -o loop "$EFI_IMG" /tmp/efimount 2>&1 && {
        echo "EFI 分区内容："
        find /tmp/efimount -type f 2>/dev/null
        echo ""
        for f in $(find /tmp/efimount -name '*.conf' 2>/dev/null); do
            echo "--- $f ---"
            cat "$f"
            echo ""
        done
        umount /tmp/efimount
    } || echo "挂载 EFI 镜像失败"
fi

echo "=== ISO 标签检查 ==="
blkid "$ISO" 2>/dev/null || isoinfo -d -i "$ISO" 2>/dev/null | grep -i "volume id"

echo ""
echo "=== 完成 ==="
