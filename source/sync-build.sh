#!/bin/bash
SRC_ROOT='/mnt/g/FEPT/FEPT/A_industry code/Code/OS/Java Net Lava OS/src'
DST_ROOT='/root/jnl-os-build/src'
BUILD_SRC='/mnt/g/FEPT/FEPT/A_industry code/Code/OS/Java Net Lava OS/build'
BUILD_DST='/root/jnl-os-build/build'
VERSION_SRC='/mnt/g/FEPT/FEPT/A_industry code/Code/OS/Java Net Lava OS/version'

rsync -a --delete "$SRC_ROOT/" "$DST_ROOT/" 2>/dev/null
echo "源码同步完成"

rsync -a --delete "$BUILD_SRC/" "$BUILD_DST/" 2>/dev/null
echo "build脚本同步完成"

cp "$VERSION_SRC" /root/jnl-os-build/version 2>/dev/null
echo "version文件同步完成"

rm -rf /tmp/jnl-work /tmp/jnl-out
echo "构建缓存已清理"

echo "=== 验证 ==="
grep "classic4" "$DST_ROOT/archiso-profile/airootfs/root/customize_airootfs.sh" | head -3
cat /root/jnl-os-build/version | grep VERSION_FULL
