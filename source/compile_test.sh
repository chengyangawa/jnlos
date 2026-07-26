#!/bin/bash
cd "/mnt/g/FEPT/FEPT/A_industry code/Code/OS/Java Net Lava OS/src/archiso-profile/airootfs/usr/bin"
gcc -O2 $(pkg-config --cflags gtk+-3.0) jnl-installer.c -o jnl-installer $(pkg-config --libs gtk+-3.0) 2>&1
echo "Exit code: $?"
ls -la jnl-installer 2>&1