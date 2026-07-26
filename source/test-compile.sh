#!/bin/bash
cd /tmp/build-test
CF=$(pkg-config --cflags gtk+-3.0)
LB=$(pkg-config --libs gtk+-3.0)
echo "CF=$CF"
echo "LB=$LB"
gcc -O2 $CF jnl-installer.c -o jnl-installer $LB 2>compile.log
echo "RC=$?"
ls -la jnl-installer 2>/dev/null
cat compile.log
