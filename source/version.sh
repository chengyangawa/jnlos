#!/usr/bin/env bash
# 版本号管理工具
# 用法：
#   version.sh show          显示当前版本
#   version.sh bump-minor    小版本+1（每次编译）
#   version.sh bump-major    大版本+1（功能大更新）
#   version.sh bump-phase    超大版本升级（alpha -> beta -> class -> release）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/VERSION"

if [ ! -f "$VERSION_FILE" ]; then
    echo "错误：未找到 VERSION 文件" >&2
    exit 1
fi

source "$VERSION_FILE"

show_version() {
    echo "当前版本: $VERSION_FULL"
    echo "  阶段: $VERSION_PHASE"
    echo "  大版本: $VERSION_MAJOR"
    echo "  小版本: $VERSION_MINOR"
}

write_version() {
    cat > "$VERSION_FILE" <<EOF
VERSION_PHASE="$VERSION_PHASE"
VERSION_MAJOR="$VERSION_MAJOR"
VERSION_MINOR="$VERSION_MINOR"
VERSION_FULL="\${VERSION_PHASE}\${VERSION_MAJOR}.\${VERSION_MINOR}"
VERSION_ISO="\${VERSION_PHASE}-\${VERSION_MAJOR}-\${VERSION_MINOR}"
EOF
    echo "新版本: ${VERSION_PHASE}${VERSION_MAJOR}.${VERSION_MINOR}"
}

case "${1:-show}" in
    show)
        show_version
        ;;
    bump-minor)
        VERSION_MINOR=$((VERSION_MINOR + 1))
        write_version
        ;;
    bump-major)
        VERSION_MAJOR=$((VERSION_MAJOR + 1))
        VERSION_MINOR=0
        write_version
        ;;
    bump-phase)
        case "$VERSION_PHASE" in
            alpha) VERSION_PHASE="beta" ;;
            beta)  VERSION_PHASE="class" ;;
            class) VERSION_PHASE="release" ;;
            release)
                echo "已经是正式版，无法再升级阶段" >&2
                exit 1
                ;;
            *)
                echo "未知阶段: $VERSION_PHASE" >&2
                exit 1
                ;;
        esac
        VERSION_MINOR=0
        write_version
        ;;
    *)
        echo "用法: $0 {show|bump-minor|bump-major|bump-phase}" >&2
        exit 1
        ;;
esac
