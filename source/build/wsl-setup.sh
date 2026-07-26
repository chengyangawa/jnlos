#!/usr/bin/env bash
# ============================================================
# wsl-setup.sh - WSL Arch Linux 环境准备脚本
#
# 功能：
#   1. 检测当前是否运行在 Arch Linux WSL 中
#   2. 检测并安装 archiso 构建所需的依赖包
#   3. 创建工作目录 ~/jnl-os-build/
#
# 用法：在 WSL 中执行 bash wsl-setup.sh
# ============================================================
set -euo pipefail

# 颜色定义（用于终端彩色输出）
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'
COLOR_RESET='\033[0m'

# ------------------------------------------------------------
# 步骤 1：检测是否运行在 Arch Linux WSL 中
# 通过读取 /etc/os-release 中的 ID 字段判断发行版
# ------------------------------------------------------------
echo -e "${COLOR_YELLOW}[1/3] 检测 WSL 发行版...${COLOR_RESET}"

if [[ ! -f /etc/os-release ]]; then
    echo -e "${COLOR_RED}错误：未找到 /etc/os-release，无法判断当前发行版。${COLOR_RESET}"
    echo -e "${COLOR_RED}请确认已在 WSL 中运行本脚本。${COLOR_RESET}"
    exit 1
fi

# 提取 ID 字段
# shellcheck disable=SC1091
. /etc/os-release

if [[ "${ID:-}" != "arch" ]]; then
    echo -e "${COLOR_RED}错误：当前发行版为 '${ID:-未知}'，不是 Arch Linux。${COLOR_RESET}"
    echo -e "${COLOR_RED}请使用 Arch Linux WSL 镜像安装并重试。${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}提示：可从 https://github.com/yuk7/ArchWSL 获取 ArchWSL 镜像。${COLOR_RESET}"
    exit 1
fi

echo -e "${COLOR_GREEN}已确认运行在 Arch Linux WSL 中。${COLOR_RESET}"

# ------------------------------------------------------------
# 步骤 2：检测并安装构建依赖
# 依赖说明：
#   archiso          - ISO 构建工具
#   squashfs-tools   - squashfs 文件系统工具
#   rsync            - 文件同步工具
#   python           - Python 运行时
#   python-gobject   - Python GObject 绑定
#   gstreamer        - 多媒体框架
#   gst-plugins-good - GStreamer 插件（good）
#   gst-plugins-bad  - GStreamer 插件（bad）
#   gst-plugins-ugly - GStreamer 插件（ugly）
#   lib32-glibc      - 32 位 glibc（多库支持）
# ------------------------------------------------------------
echo -e "${COLOR_YELLOW}[2/3] 检测并安装构建依赖...${COLOR_RESET}"

# 构建主机依赖包列表
# 注意：python-gobject / gstreamer / gst-plugins-* 是目标系统(airootfs)
# 的依赖，会通过 packages.x86_64 由 archiso 安装到 ISO 内，
# 构建主机本身只需要 archiso 及其直接依赖。
DEPS=(
    archiso
    squashfs-tools
    rsync
    python
    base-devel
    git
    dosfstools
)

# 同步包数据库（不强制升级整个系统，避免耗时）
# 如果网络不可用，检查依赖是否已安装，如果已安装则跳过
echo -e "${COLOR_YELLOW}同步包数据库并安装构建依赖...${COLOR_RESET}"
if sudo pacman -Sy --noconfirm --needed "${DEPS[@]}" 2>/dev/null; then
    echo -e "${COLOR_GREEN}构建依赖已全部就绪。${COLOR_RESET}"
else
    echo -e "${COLOR_YELLOW}网络同步失败，检查已安装的依赖...${COLOR_RESET}"
    ALL_INSTALLED=true
    for dep in "${DEPS[@]}"; do
        if ! pacman -Q "$dep" >/dev/null 2>&1; then
            echo -e "${COLOR_RED}依赖 $dep 未安装且无法在线安装${COLOR_RESET}"
            ALL_INSTALLED=false
        fi
    done
    if [ "$ALL_INSTALLED" = true ]; then
        echo -e "${COLOR_GREEN}所有构建依赖已安装（使用缓存）。${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}错误：部分依赖未安装且网络不可用${COLOR_RESET}"
        exit 1
    fi
fi

# ------------------------------------------------------------
# 步骤 3：创建工作目录 ~/jnl-os-build/
# 该目录用于存放同步过来的源码及构建中间产物
# ------------------------------------------------------------
echo -e "${COLOR_YELLOW}[3/3] 创建工作目录...${COLOR_RESET}"

WORK_DIR="${HOME}/jnl-os-build"
mkdir -p "${WORK_DIR}"

echo -e "${COLOR_GREEN}工作目录已就绪：${WORK_DIR}${COLOR_RESET}"

# ------------------------------------------------------------
# 完成
# ------------------------------------------------------------
echo ""
echo -e "${COLOR_GREEN}================================================${COLOR_RESET}"
echo -e "${COLOR_GREEN} WSL Arch 环境已就绪${COLOR_RESET}"
echo -e "${COLOR_GREEN}================================================${COLOR_RESET}"
