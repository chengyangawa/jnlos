#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "正在构建 JNL Desktop..."

if ! command -v qmake6 >/dev/null 2>&1; then
    echo "警告: 未找到 qmake6，尝试 qmake..."
    QMAKE=qmake
else
    QMAKE=qmake6
fi

mkdir -p build
cd build

echo "运行 qmake..."
$QMAKE ..

echo "运行 make..."
make -j$(nproc)

echo "JNL Desktop 构建完成！"
echo "输出: $SCRIPT_DIR/build/jnl-desktop"
