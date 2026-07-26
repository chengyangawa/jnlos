#!/bin/bash
cd /tmp/build-test
CF=$(pkg-config --cflags gtk+-3.0)
LB=$(pkg-config --libs gtk+-3.0)
gcc -O2 $CF jnl-installer.c -o jnl-installer $LB 2>compile.log
RC=$?
if [ $RC -eq 0 ]; then
    echo "SUCCESS"
    ls -la jnl-installer
else
    echo "FAILED RC=$RC"
    cat compile.log
fi
