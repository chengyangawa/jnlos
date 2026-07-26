#!/bin/bash
set -e
cd "/mnt/g/FEPT/FEPT/A_industry code/Code/OS/Java Net Lava OS/src/archiso-profile/airootfs/usr/bin/"
gcc -O2 $(pkg-config --cflags gtk+-3.0) jnl-installer.c -o /tmp/jnl-installer $(pkg-config --libs gtk+-3.0) 2>&1
echo "编译结果: $?"
ls -la /tmp/jnl-installer 2>/dev/null || echo "编译失败"
