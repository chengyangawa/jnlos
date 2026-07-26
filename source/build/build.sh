#!/usr/bin/env bash
# ============================================================================
# Java Net Lava OS 一键构建脚本
# ----------------------------------------------------------------------------
# 在 WSL Arch Linux 中执行，完成以下 7 个步骤：
#   1. 调用 wsl-setup.sh  检查并准备 WSL Arch 环境（安装 archiso 等依赖）
#   2. 调用 sync-to-wsl.sh 同步 src/ 到 WSL 的 ~/jnl-os-build/src/
#   3. 将 themes/、jnl-tools/、browser-extension/、gnome-extension/ 注入
#      到 archiso profile 的 airootfs/root/ 下，供 customize_airootfs.sh 使用
#   4. 在 WSL 中执行 mkarchiso 生成 ISO 镜像
#   5. 将 ISO 复制到 Windows 挂载的输出目录（/mnt/g/.../out/）
#   6. 计算 ISO 的 SHA256 校验值并保存到 out/*.iso.sha256sum
#   7. 显示构建结果与 ISO 路径
#
# 用法：在 WSL Arch Linux 中执行 bash build.sh
# ============================================================================
set -euo pipefail

# ============================================================================
# 颜色定义（用于终端彩色输出）
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color（重置颜色）

# ============================================================================
# 项目路径定义
# ----------------------------------------------------------------------------
# SCRIPT_DIR   - 本脚本所在目录（build/）
# PROJECT_ROOT - 项目根目录（Java Net Lava OS/）
# SRC_DIR      - 源码目录（src/，含 themes/jnl-tools/archiso-profile 等）
# BUILD_DIR    - 构建脚本目录（build/）
# OUT_DIR      - Windows 侧输出目录（out/，仅用于路径推算）
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 优先使用 Windows 挂载路径作为项目根目录，确保 WSL 中的构建始终同步 Windows 侧源码
WIN_PROJECT_ROOT="/mnt/g/FEPT/FEPT/A_industry code/Code/OS/Java Net Lava OS"
if [ -d "$WIN_PROJECT_ROOT" ]; then
    PROJECT_ROOT="$WIN_PROJECT_ROOT"
else
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
fi
SRC_DIR="$PROJECT_ROOT/src"
BUILD_DIR="$PROJECT_ROOT/build"
OUT_DIR="$PROJECT_ROOT/out"

# ============================================================================
# WSL 工作目录定义
# ----------------------------------------------------------------------------
# WSL_WORK_DIR     - WSL 中的工作根目录（~/jnl-os-build）
# WSL_SRC_DIR      - 同步到 WSL 的源码目录（~/jnl-os-build/src）
# WSL_PROFILE_DIR  - archiso profile 目录（~/jnl-os-build/src/archiso-profile）
# ============================================================================
WSL_WORK_DIR="$HOME/jnl-os-build"
WSL_SRC_DIR="$WSL_WORK_DIR/src"
WSL_PROFILE_DIR="$WSL_SRC_DIR/archiso-profile"

# ============================================================================
# Windows 挂载的输出目录
# ----------------------------------------------------------------------------
# WSL 中通过 /mnt/g/... 访问 Windows 的 G 盘
# 将 ISO 复制到这里，Windows 即可直接访问 out/ 目录
# 路径中的空格需在引用时正确处理
# ============================================================================
WIN_OUT_DIR="/mnt/g/FEPT/FEPT/A_industry code/Code/OS/Java Net Lava OS/out"

# 版本号（从 version/VERSION 文件读取）
# 使用 grep 直接读取，避免 source 导致的变量展开问题
VERSION_FULL="classic4.4"
VERSION_ISO="classic-4-4"
VERSION_FILE=""
if [ -f "$WSL_WORK_DIR/version" ]; then
    VERSION_FILE="$WSL_WORK_DIR/version"
elif [ -f "$PROJECT_ROOT/version" ]; then
    VERSION_FILE="$PROJECT_ROOT/version"
elif [ -f "$PROJECT_ROOT/VERSION" ]; then
    VERSION_FILE="$PROJECT_ROOT/VERSION"
elif [ -f "/mnt/g/FEPT/FEPT/A_industry code/Code/OS/Java Net Lava OS/version" ]; then
    VERSION_FILE="/mnt/g/FEPT/FEPT/A_industry code/Code/OS/Java Net Lava OS/version"
fi
if [ -n "$VERSION_FILE" ]; then
    VERSION_FULL=$(grep "^VERSION_FULL=" "$VERSION_FILE" | cut -d= -f2)
    VERSION_ISO=$(grep "^VERSION_ISO=" "$VERSION_FILE" | cut -d= -f2)
    echo -e "${BLUE}版本文件: ${VERSION_FILE}${NC}"
    echo -e "${BLUE}VERSION_FULL: ${VERSION_FULL}${NC}"
    echo -e "${BLUE}VERSION_ISO: ${VERSION_ISO}${NC}"
else
    echo -e "${RED}警告：未找到 version 文件，使用默认版本${NC}"
fi

# archiso 构建工作目录与输出目录（位于 /tmp，构建结束后清理）
WORK_DIR="/tmp/jnl-work"
ISO_OUT_DIR="/tmp/jnl-out"

# 包缓存目录（加速构建）
CACHE_DIR="$HOME/jnl-os-cache"

# ============================================================================
# 输出构建起始信息
# ============================================================================
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Java Net Lava OS 构建脚本${NC}"
echo -e "${BLUE}================================================${NC}"
echo
echo -e "${BLUE}项目根目录：${PROJECT_ROOT}${NC}"
echo -e "${BLUE}WSL 工作目录：${WSL_WORK_DIR}${NC}"
echo -e "${BLUE}输出目录：${WIN_OUT_DIR}${NC}"
echo

# ============================================================================
# 步骤 1：检查并准备 WSL Arch 环境
# ----------------------------------------------------------------------------
# 调用 wsl-setup.sh：
#   - 校验当前发行版为 Arch Linux
#   - 安装 archiso / squashfs-tools / rsync / python / gstreamer 等依赖
#   - 创建工作目录 ~/jnl-os-build/
# ============================================================================
echo -e "${YELLOW}[1/7] 检查 WSL Arch Linux 环境...${NC}"
bash "$BUILD_DIR/wsl-setup.sh"

# ============================================================================
# 步骤 2：同步源码到 WSL 工作目录
# ----------------------------------------------------------------------------
# 调用 sync-to-wsl.sh：
#   - 将 PROJECT_ROOT/src/ 同步到 ~/jnl-os-build/src/
#   - 使用 rsync -av --delete，排除 __pycache__ 与 *.pyc
#   - 同步后 archiso profile 位于 ~/jnl-os-build/src/archiso-profile/
# ============================================================================
echo -e "${YELLOW}[2/7] 同步源码到 WSL 工作目录...${NC}"
bash "$BUILD_DIR/sync-to-wsl.sh" "$SRC_DIR" "$WSL_WORK_DIR"

# 校验 archiso profile 目录存在
if [ ! -d "$WSL_PROFILE_DIR" ]; then
    echo -e "${RED}错误：archiso profile 目录不存在：${WSL_PROFILE_DIR}${NC}"
    echo -e "${RED}请确认源码已正确同步。${NC}"
    exit 1
fi

# 校验 customize_airootfs.sh 存在（构建必需）
if [ ! -f "$WSL_PROFILE_DIR/airootfs/root/customize_airootfs.sh" ]; then
    echo -e "${RED}错误：未找到 customize_airootfs.sh${NC}"
    echo -e "${RED}路径：${WSL_PROFILE_DIR}/airootfs/root/customize_airootfs.sh${NC}"
    exit 1
fi

# 修复 Windows CRLF 换行符问题
echo -e "${YELLOW}修复文件换行符...${NC}"
find "$WSL_PROFILE_DIR" -type f \( -name "*.sh" -o -name "*.conf" -o -name "*.cfg" -o -name "*.preset" -o -name "*.desktop" \) -exec sed -i 's/\r$//' {} + 2>/dev/null || true
echo -e "${GREEN}  换行符修复完成${NC}"

# ============================================================================
# 步骤 3：注入主题、工具、扩展到 archiso profile 的 airootfs/root/
# ----------------------------------------------------------------------------
# 将以下源码目录复制到 airootfs/root/ 下，customize_airootfs.sh 在构建时
# 会从这些目录读取并安装到 Live 系统的对应位置：
#   src/themes/             -> airootfs/root/jnl-os-themes/
#   src/jnl-tools/          -> airootfs/root/jnl-os-tools/
#   src/browser-extension/  -> airootfs/root/jnl-os-browser-ext/
#   src/gnome-extension/    -> airootfs/root/jnl-os-gnome-ext/
#   src/installer/          -> airootfs/root/（合并，含 install-jnl-os.sh）
# ============================================================================
echo -e "${YELLOW}[3/7] 注入主题与工具到 archiso profile...${NC}"

# airootfs 的 /root 目录（Live 系统的 root 用户主目录）
AIROOTFS_ROOT="$WSL_PROFILE_DIR/airootfs/root"

# ---- 3.1 主题目录 ----------------------------------------------------------
# 复制 themes/ 全部内容（含 _template/、colors/、generated/、wallpapers/、
# switch-theme.sh、generate-themes.sh），供 customize_airootfs.sh 安装到
# /usr/share/themes/、/usr/share/icons/、/usr/share/backgrounds/jnl-os/
rm -rf "$AIROOTFS_ROOT/jnl-os-themes"
mkdir -p "$AIROOTFS_ROOT/jnl-os-themes"
if [ -d "$WSL_SRC_DIR/themes" ]; then
    # 复制 themes/ 下所有文件到 jnl-os-themes/
    cp -r "$WSL_SRC_DIR/themes/"* "$AIROOTFS_ROOT/jnl-os-themes/" 2>/dev/null || true
    # 若 generated/ 主题不存在且存在生成器，则运行生成器预生成主题
    if [ ! -d "$AIROOTFS_ROOT/jnl-os-themes/generated" ] \
       && [ -f "$AIROOTFS_ROOT/jnl-os-themes/generate-themes.sh" ]; then
        echo "  未发现预生成主题，运行主题生成器..."
        (cd "$AIROOTFS_ROOT/jnl-os-themes" && bash generate-themes.sh) \
            || echo -e "${YELLOW}  警告：主题生成失败，将使用默认主题${NC}"
    fi
    echo -e "${GREEN}  主题已注入：jnl-os-themes/${NC}"
else
    echo -e "${YELLOW}  警告：未找到 src/themes/，跳过主题注入${NC}"
fi

# ---- 3.2 工具目录（jnlc、jnlp） --------------------------------------------
# jnlc：.jnl 格式命令行工具（pack/unpack/info/play/list）
# jnlp：桌面音乐播放器（GTK4 + GStreamer + DBus）
rm -rf "$AIROOTFS_ROOT/jnl-os-tools"
mkdir -p "$AIROOTFS_ROOT/jnl-os-tools/jnlc" "$AIROOTFS_ROOT/jnl-os-tools/jnlp"
if [ -d "$WSL_SRC_DIR/jnl-tools" ]; then
    # 复制 jnlc 主程序
    [ -f "$WSL_SRC_DIR/jnl-tools/jnlc/jnlc" ] \
        && cp "$WSL_SRC_DIR/jnl-tools/jnlc/jnlc" "$AIROOTFS_ROOT/jnl-os-tools/jnlc/" \
        && chmod 755 "$AIROOTFS_ROOT/jnl-os-tools/jnlc/jnlc"
    # 复制 jnlp 主程序与桌面入口
    [ -f "$WSL_SRC_DIR/jnl-tools/jnlp/jnlp" ] \
        && cp "$WSL_SRC_DIR/jnl-tools/jnlp/jnlp" "$AIROOTFS_ROOT/jnl-os-tools/jnlp/" \
        && chmod 755 "$AIROOTFS_ROOT/jnl-os-tools/jnlp/jnlp"
    [ -f "$WSL_SRC_DIR/jnl-tools/jnlp/jnlp.desktop" ] \
        && cp "$WSL_SRC_DIR/jnl-tools/jnlp/jnlp.desktop" "$AIROOTFS_ROOT/jnl-os-tools/jnlp/"
    # 复制 spec/（格式规范与示例，便于运行时引用）
    if [ -d "$WSL_SRC_DIR/jnl-tools/spec" ]; then
        cp -r "$WSL_SRC_DIR/jnl-tools/spec" "$AIROOTFS_ROOT/jnl-os-tools/"
    fi
    echo -e "${GREEN}  工具已注入：jnl-os-tools/（jnlc、jnlp）${NC}"
else
    echo -e "${YELLOW}  警告：未找到 src/jnl-tools/，跳过工具注入${NC}"
fi

# ---- 3.3 浏览器扩展 --------------------------------------------------------
# QQ 音乐下载浏览器扩展（Manifest V3，含 native-host 通信桥）
rm -rf "$AIROOTFS_ROOT/jnl-os-browser-ext"
if [ -d "$WSL_SRC_DIR/browser-extension" ]; then
    cp -r "$WSL_SRC_DIR/browser-extension" "$AIROOTFS_ROOT/jnl-os-browser-ext"
    echo -e "${GREEN}  浏览器扩展已注入：jnl-os-browser-ext/${NC}"
else
    echo -e "${YELLOW}  警告：未找到 src/browser-extension/，跳过浏览器扩展注入${NC}"
fi

# ---- 3.4 GNOME 扩展 --------------------------------------------------------
# GNOME Shell 任务栏音乐控件扩展（监听 org.jnl_os.Player DBus 信号）
rm -rf "$AIROOTFS_ROOT/jnl-os-gnome-ext"
if [ -d "$WSL_SRC_DIR/gnome-extension" ]; then
    cp -r "$WSL_SRC_DIR/gnome-extension" "$AIROOTFS_ROOT/jnl-os-gnome-ext"
    echo -e "${GREEN}  GNOME 扩展已注入：jnl-os-gnome-ext/${NC}"
else
    echo -e "${YELLOW}  警告：未找到 src/gnome-extension/，跳过 GNOME 扩展注入${NC}"
fi

# ---- 3.5 安装器 ------------------------------------------------------------
# 将 installer/ 下的内容合并到 airootfs/root/，customize_airootfs.sh 会
# 进一步处理（例如 install-jnl-os.sh 包装器与 archinstall 配置）
if [ -d "$WSL_SRC_DIR/installer" ]; then
    cp -r "$WSL_SRC_DIR/installer/"* "$AIROOTFS_ROOT/" 2>/dev/null || true
    echo -e "${GREEN}  安装器已合并到 airootfs/root/${NC}"
fi

# ---- 3.6 图标集 ------------------------------------------------------------
# 科技感/Windows 11 风格图标集
if [ -d "$WSL_SRC_DIR/themes/icons" ]; then
    rm -rf "$AIROOTFS_ROOT/jnl-os-icons"
    cp -r "$WSL_SRC_DIR/themes/icons" "$AIROOTFS_ROOT/jnl-os-icons"
    echo -e "${GREEN}  图标集已注入：jnl-os-icons/${NC}"
fi

# ---- 3.7 JNL Desktop -------------------------------------------------------
# 基于 Qt6 的桌面环境（任务栏、开始菜单、桌面图标、系统托盘）
if [ -d "$WSL_SRC_DIR/jnl-desktop" ]; then
    rm -rf "$AIROOTFS_ROOT/jnl-os-desktop"
    cp -r "$WSL_SRC_DIR/jnl-desktop" "$AIROOTFS_ROOT/jnl-os-desktop"
    echo -e "${GREEN}  JNL Desktop 已注入：jnl-os-desktop/${NC}"
fi

# ---- 3.8 JNL Browser -------------------------------------------------------
# 基于 Qt WebEngine 的浏览器，内置 QQ 音乐下载
if [ -d "$WSL_SRC_DIR/jnl-browser" ]; then
    rm -rf "$AIROOTFS_ROOT/jnl-os-browser"
    cp -r "$WSL_SRC_DIR/jnl-browser" "$AIROOTFS_ROOT/jnl-os-browser"
    echo -e "${GREEN}  JNL Browser 已注入：jnl-os-browser/${NC}"
fi

# ---- 3.9 GRUB 主题 ----------------------------------------------------------
# 自定义 GRUB 引导主题（科技感/Windows 11 风格）
if [ -d "$WSL_SRC_DIR/archiso-profile/grub-theme" ]; then
    rm -rf "$AIROOTFS_ROOT/jnl-os-grub-theme"
    cp -r "$WSL_SRC_DIR/archiso-profile/grub-theme" "$AIROOTFS_ROOT/jnl-os-grub-theme"
    echo -e "${GREEN}  GRUB 主题已注入：jnl-os-grub-theme/${NC}"
fi

# ---- 3.10 JNL Player --------------------------------------------------------
# 基于 Qt6 的媒体播放器（全新 UI）
if [ -d "$WSL_SRC_DIR/jnl-player" ]; then
    rm -rf "$AIROOTFS_ROOT/jnl-os-player"
    cp -r "$WSL_SRC_DIR/jnl-player" "$AIROOTFS_ROOT/jnl-os-player"
    echo -e "${GREEN}  JNL Player 已注入：jnl-os-player/${NC}"
fi

# ---- 3.11 Microsoft Edge 预下载 --------------------------------------------
# 预先下载 Edge 浏览器 deb 包，构建时直接解压安装
EDGE_DEB_URL="https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-stable/microsoft-edge-stable_126.0.2592.113-1_amd64.deb"
EDGE_DEB_PATH="$CACHE_DIR/microsoft-edge-stable.deb"
edge_downloaded=false
if [ ! -f "$EDGE_DEB_PATH" ] || [ $(stat -c%s "$EDGE_DEB_PATH" 2>/dev/null || echo 0) -lt 10000000 ]; then
    echo -e "${YELLOW}  正在下载 Microsoft Edge 浏览器...${NC}"
    mkdir -p "$CACHE_DIR"
    if { curl -L -o "$EDGE_DEB_PATH" "$EDGE_DEB_URL" 2>/dev/null && [ $(stat -c%s "$EDGE_DEB_PATH" 2>/dev/null || echo 0) -gt 10000000 ]; } \
       || { wget -O "$EDGE_DEB_PATH" "$EDGE_DEB_URL" 2>/dev/null && [ $(stat -c%s "$EDGE_DEB_PATH" 2>/dev/null || echo 0) -gt 10000000 ]; }; then
        echo -e "${GREEN}  Edge 下载完成${NC}"
        edge_downloaded=true
    else
        echo -e "${YELLOW}  Edge 下载失败，构建时再尝试${NC}"
        rm -f "$EDGE_DEB_PATH"
    fi
else
    edge_downloaded=true
    echo -e "${GREEN}  Edge 使用缓存${NC}"
fi
# 复制到 airootfs/usr/share/jnl-os/ 供构建时使用（/tmp 可能被清理）
if [ "$edge_downloaded" = true ] && [ -f "$EDGE_DEB_PATH" ] && [ $(stat -c%s "$EDGE_DEB_PATH" 2>/dev/null || echo 0) -gt 10000000 ]; then
    mkdir -p "$WSL_PROFILE_DIR/airootfs/usr/share/jnl-os"
    cp "$EDGE_DEB_PATH" "$WSL_PROFILE_DIR/airootfs/usr/share/jnl-os/microsoft-edge-stable.deb"
    echo -e "${GREEN}  Edge 浏览器已准备预装${NC}"
fi

# ---- 3.13 注入安装程序文件 --------------------------------------------------
# 将图形化安装程序和 worker 脚本注入到 airootfs/root/，供 customize_airootfs.sh 复制到最终位置
INSTALLER_DIR="$AIROOTFS_ROOT/airootfs/usr/bin"
mkdir -p "$INSTALLER_DIR"
if [ -f "$WSL_PROFILE_DIR/airootfs/usr/bin/jnl-gui-installer" ]; then
    cp -v "$WSL_PROFILE_DIR/airootfs/usr/bin/jnl-gui-installer" "$INSTALLER_DIR/jnl-gui-installer"
    chmod 0755 "$INSTALLER_DIR/jnl-gui-installer"
    echo -e "${GREEN}  jnl-gui-installer 已注入${NC}"
else
    echo -e "${YELLOW}  ! jnl-gui-installer 源文件不存在${NC}"
fi
if [ -f "$WSL_PROFILE_DIR/airootfs/usr/bin/jnl-installer-worker" ]; then
    cp -v "$WSL_PROFILE_DIR/airootfs/usr/bin/jnl-installer-worker" "$INSTALLER_DIR/jnl-installer-worker"
    chmod 0755 "$INSTALLER_DIR/jnl-installer-worker"
    echo -e "${GREEN}  jnl-installer-worker 已注入${NC}"
else
    echo -e "${YELLOW}  ! jnl-installer-worker 源文件不存在${NC}"
fi

# ---- 3.14 安装 GTK3/Python 依赖 ---------------------------------------------
# 图形化安装程序需要 python-gobject (PyGObject) 和 gtk3
echo -e "${YELLOW}[3.14/7] 安装图形化安装程序依赖...${NC}"
sudo pacman -S --noconfirm --needed python-gobject gtk3 2>&1 | tail -5
if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ GTK3 + PyGObject 依赖安装完成${NC}"
else
    echo -e "${RED}  ✗ GTK3 + PyGObject 安装失败${NC}"
    echo -e "${RED}  安装程序将无法启动！${NC}"
fi

# ---- 3.15 JNL install.wav 安装音乐 ----------------------------------------
# 注入安装音乐到 airootfs/usr/share/jnl-os，安装程序启动后循环播放
INSTALL_MUSIC_SRC="$PROJECT_ROOT/JNL install.wav"
if [ -f "$INSTALL_MUSIC_SRC" ]; then
    mkdir -p "$WSL_PROFILE_DIR/airootfs/usr/share/jnl-os"
    cp -v "$INSTALL_MUSIC_SRC" "$WSL_PROFILE_DIR/airootfs/usr/share/jnl-os/JNL install.wav" 2>&1 | sed 's/^/  /'
    echo -e "${GREEN}  JNL install.wav 已注入${NC}"
    # 也注入一份到 airootfs/root/，供 customize_airootfs.sh 复制到最终位置
    cp -v "$INSTALL_MUSIC_SRC" "$AIROOTFS_ROOT/JNL install.wav" 2>&1 | sed 's/^/  /' || true
else
    echo -e "${YELLOW}  ! 未找到 JNL install.wav，安装时不会播放音乐${NC}"
    echo -e "${YELLOW}  ! 期望路径: ${INSTALL_MUSIC_SRC}${NC}"
fi

# ---- 3.8 示例 .jnl 文件 ----------------------------------------------------
# 将 spec/examples/sample-song/ 打包为示例 .jnl，放到 jnluser 的音乐库
# 目录中，便于首次进入 Live 系统即可体验播放器
SAMPLE_MUSIC_DIR="$WSL_PROFILE_DIR/airootfs/home/jnluser/.local/share/jnl-os/music"
mkdir -p "$SAMPLE_MUSIC_DIR"
if [ -d "$WSL_SRC_DIR/jnl-tools/spec/examples/sample-song" ]; then
    if command -v python3 >/dev/null 2>&1; then
        # 使用 jnlc pack 打包示例歌曲
        python3 "$WSL_SRC_DIR/jnl-tools/jnlc/jnlc" pack \
            "$WSL_SRC_DIR/jnl-tools/spec/examples/sample-song" \
            "$SAMPLE_MUSIC_DIR/sample.jnl" 2>/dev/null \
            && echo -e "${GREEN}  示例 .jnl 已生成：sample.jnl${NC}" \
            || echo -e "${YELLOW}  警告：示例 .jnl 打包失败，跳过${NC}"
    fi
fi
# 修正 jnluser 主目录属主为 UID/GID 1000（Live 系统中 jnluser 的默认 ID）
chown -R 1000:1000 "$WSL_PROFILE_DIR/airootfs/home/jnluser" 2>/dev/null || true

# ---- 3.7 设置脚本权限 -------------------------------------------------------
# customize_airootfs.sh 由 archiso 在构建时以 root 执行，必须可执行
chmod 755 "$AIROOTFS_ROOT/customize_airootfs.sh" 2>/dev/null || true
# switch-theme.sh 同样需要可执行权限
[ -f "$AIROOTFS_ROOT/jnl-os-themes/switch-theme.sh" ] \
    && chmod 755 "$AIROOTFS_ROOT/jnl-os-themes/switch-theme.sh"
[ -f "$AIROOTFS_ROOT/jnl-os-themes/generate-themes.sh" ] \
    && chmod 755 "$AIROOTFS_ROOT/jnl-os-themes/generate-themes.sh"
# jnl-installer-worker 同样需要可执行权限（被 GUI 安装程序通过 pkexec 调用）
[ -f "$WSL_PROFILE_DIR/airootfs/usr/bin/jnl-installer-worker" ] \
    && chmod 755 "$WSL_PROFILE_DIR/airootfs/usr/bin/jnl-installer-worker"
# jnl-installer.c 安装程序源码（C + GTK3），由 customize_airootfs.sh 在构建时编译
[ -f "$WSL_PROFILE_DIR/airootfs/usr/bin/jnl-installer.c" ] \
    && chmod 644 "$WSL_PROFILE_DIR/airootfs/usr/bin/jnl-installer.c"
# jnl-gui-installer 旧版 Python 安装程序（保留兼容）
[ -f "$WSL_PROFILE_DIR/airootfs/usr/bin/jnl-gui-installer" ] \
    && chmod 755 "$WSL_PROFILE_DIR/airootfs/usr/bin/jnl-gui-installer"

# 汇总注入情况
echo -e "${BLUE}airootfs/root/ 注入内容：${NC}"
ls -la "$AIROOTFS_ROOT" | grep jnl-os || true

# ============================================================================
# 步骤 3.5：版本号替换
# ----------------------------------------------------------------------------
# 将 customize_airootfs.sh 中的 __VERSION_FULL__ 替换为实际版本号
# ============================================================================
echo -e "${YELLOW}[3.5/7] 注入版本号 ${VERSION_FULL}...${NC}"
if [ -f "$AIROOTFS_ROOT/customize_airootfs.sh" ]; then
    sed -i "s/__VERSION_FULL__/$VERSION_FULL/g" "$AIROOTFS_ROOT/customize_airootfs.sh"
    echo -e "${GREEN}  版本号已注入: customize_airootfs.sh${NC}"
fi

if [ -f "$WSL_PROFILE_DIR/airootfs/etc/issue" ]; then
    sed -i "s/__VERSION_FULL__/$VERSION_FULL/g" "$WSL_PROFILE_DIR/airootfs/etc/issue"
    echo -e "${GREEN}  版本号已注入: airootfs/etc/issue${NC}"
fi

if [ -f "$WSL_PROFILE_DIR/airootfs/etc/motd" ]; then
    sed -i "s/__VERSION_FULL__/$VERSION_FULL/g" "$WSL_PROFILE_DIR/airootfs/etc/motd"
    echo -e "${GREEN}  版本号已注入: airootfs/etc/motd${NC}"
fi

if [ -d "$AIROOTFS_ROOT/jnl-os-desktop" ]; then
    find "$AIROOTFS_ROOT/jnl-os-desktop" \( -name "*.cpp" -o -name "*.h" \) -exec sed -i "s/__VERSION_FULL__/$VERSION_FULL/g" {} +
    echo -e "${GREEN}  版本号已注入: jnl-desktop 源码${NC}"
fi

# 注入版本号到 C 程序源码
for c_file in "$WSL_PROFILE_DIR/airootfs/usr/bin/"*.c; do
    if [ -f "$c_file" ]; then
        sed -i "s/classic4\.[0-9][-A-Za-z]*/$VERSION_FULL/g" "$c_file" 2>/dev/null || true
    fi
done

# 同时更新 profiledef.sh 中的 iso_name 和 iso_version
if [ -f "$WSL_PROFILE_DIR/profiledef.sh" ]; then
    sed -i "s/iso_name=\"jnl-os[^\" ]*\"/iso_name=\"jnl-os-${VERSION_ISO}\"/" "$WSL_PROFILE_DIR/profiledef.sh"
    sed -i "s/iso_version=\"[^\"]*\"/iso_version=\"${VERSION_FULL}\"/" "$WSL_PROFILE_DIR/profiledef.sh"
fi

# 复制项目根目录的 os.svg 到开机动画目录
if [ -f "$PROJECT_ROOT/os.svg" ]; then
    mkdir -p "$WSL_PROFILE_DIR/airootfs/usr/share/plasma/look-and-feel/com.jnlos.desktop/contents/splash"
    cp "$PROJECT_ROOT/os.svg" "$WSL_PROFILE_DIR/airootfs/usr/share/plasma/look-and-feel/com.jnlos.desktop/contents/splash/logo.svg"
    mkdir -p "$WSL_PROFILE_DIR/airootfs/usr/share/icons/jnl-os"
    cp "$PROJECT_ROOT/os.svg" "$WSL_PROFILE_DIR/airootfs/usr/share/icons/jnl-os/OS.svg"
    cp "$PROJECT_ROOT/os.svg" "$WSL_PROFILE_DIR/airootfs/usr/share/icons/jnl-os/os.svg"
    echo -e "${GREEN}  已复制 os.svg 到开机动画和图标目录${NC}"
fi

# 复制项目根目录的 1.0.svg 到系统信息图标目录（系统信息程序使用）
if [ -f "$PROJECT_ROOT/1.0.svg" ]; then
    mkdir -p "$WSL_PROFILE_DIR/airootfs/usr/share/icons/jnl-os"
    cp "$PROJECT_ROOT/1.0.svg" "$WSL_PROFILE_DIR/airootfs/usr/share/icons/jnl-os/1.0.svg"
    echo -e "${GREEN}  已复制 1.0.svg 到系统信息图标目录${NC}"
fi

# ============================================================================
# 步骤 4：执行 mkarchiso 构建 ISO
# ============================================================================
echo -e "${YELLOW}[4/7] 执行 mkarchiso 构建...${NC}"
echo

# 清理旧的构建工作目录与输出目录
echo -e "${YELLOW}清理旧的构建目录...${NC}"
sudo rm -rf "$WORK_DIR" "$ISO_OUT_DIR"
mkdir -p "$WORK_DIR" "$ISO_OUT_DIR"

# 优化：配置可靠镜像源
echo -e "${YELLOW}优化镜像源...${NC}"
cat > /tmp/jnl-mirrorlist <<'MIRROR'
## Arch Linux 国内镜像源
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.zju.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.neusoft.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.aliyun.com/archlinux/$repo/os/$arch
Server = https://mirrors.hit.edu.cn/archlinux/$repo/os/$arch
MIRROR
sudo cp /tmp/jnl-mirrorlist /etc/pacman.d/mirrorlist

# 设置并行下载与编译加速
export MAKEFLAGS="-j$(nproc)"
if ! grep -q "ParallelDownloads" /etc/pacman.conf; then
    echo "ParallelDownloads = 20" | sudo tee -a /etc/pacman.conf
else
    sudo sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 20/' /etc/pacman.conf
fi
if ! grep -q "DisableDownloadTimeout" /etc/pacman.conf; then
    echo "DisableDownloadTimeout" | sudo tee -a /etc/pacman.conf
fi
if ! grep -q "ILoveCandy" /etc/pacman.conf; then
    echo "ILoveCandy" | sudo tee -a /etc/pacman.conf
fi

# 创建包缓存目录
echo -e "${YELLOW}准备包缓存...${NC}"
mkdir -p "$CACHE_DIR"

# 执行 archiso 构建（直接输出，不通过管道，避免缓冲区溢出）
echo -e "${YELLOW}执行 mkarchiso 构建（输出实时显示）...${NC}"
echo "================================================"
sudo mkarchiso -v -w "$WORK_DIR" -o "$ISO_OUT_DIR" "$WSL_PROFILE_DIR"
MKARCHISO_EXIT=$?
echo "================================================"
echo "mkarchiso 退出码: $MKARCHISO_EXIT"

if [ "$MKARCHISO_EXIT" -ne 0 ]; then
    echo -e "${RED}错误：mkarchiso 构建失败（退出码 $MKARCHISO_EXIT）${NC}"
    exit 1
fi

# 校验 ISO 是否成功生成
shopt -s nullglob
ISO_FILES=("$ISO_OUT_DIR"/*.iso)
shopt -u nullglob
if [ ${#ISO_FILES[@]} -eq 0 ]; then
    echo -e "${RED}错误：mkarchiso 执行完毕但未在 ${ISO_OUT_DIR} 中找到 ISO${NC}"
    exit 1
fi
echo -e "${GREEN}ISO 构建完成。${NC}"

# ============================================================================
# 步骤 5：复制 ISO 到 Windows 输出目录
# ----------------------------------------------------------------------------
# WSL 中通过 /mnt/g/... 访问 Windows 的 G 盘
# 将 ISO 复制到 Windows 项目目录的 out/ 子目录，便于在 Windows 中直接访问
# ============================================================================
echo -e "${YELLOW}[5/7] 复制 ISO 到 Windows 输出目录...${NC}"

# 确保 Windows 输出目录存在（/mnt/g 已由 WSL 自动挂载）
mkdir -p "$WIN_OUT_DIR"

# 复制所有 ISO 文件到 Windows 输出目录
for iso in "${ISO_FILES[@]}"; do
    iso_name="$(basename "$iso")"
    echo -e "${YELLOW}复制：${iso_name} -> ${WIN_OUT_DIR}/${NC}"
    cp -v "$iso" "$WIN_OUT_DIR/" || {
        echo -e "${RED}错误：无法复制 ISO 到 ${WIN_OUT_DIR}${NC}"
        echo "ISO 位于：${ISO_OUT_DIR}/"
        ls -lh "$ISO_OUT_DIR/"
        exit 1
    }
done

# ============================================================================
# 步骤 6：生成 SHA256 校验和
# ----------------------------------------------------------------------------
# 为每个 ISO 生成对应的 .sha256sum 文件，便于用户校验 ISO 完整性
# 文件格式：'<hash>  <iso_name>'，与 sha256sum -c 兼容
# ============================================================================
echo -e "${YELLOW}[6/7] 生成 SHA256 校验和...${NC}"
cd "$WIN_OUT_DIR"
for iso in *.iso; do
    [ -f "$iso" ] || continue
    sha256sum "$iso" > "${iso}.sha256sum"
    echo -e "${GREEN}  生成：${iso}.sha256sum${NC}"
done

# ============================================================================
# 步骤 7：构建完成，显示结果
# ============================================================================
echo -e "${YELLOW}[7/7] 构建完成${NC}"
echo
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}   Java Net Lava OS ISO 构建成功！${NC}"
echo -e "${GREEN}================================================${NC}"
echo
echo "ISO 文件位置："
ls -lh "$WIN_OUT_DIR"/*.iso 2>/dev/null || ls -lh "$ISO_OUT_DIR"/*.iso
echo
echo "校验文件："
ls -lh "$WIN_OUT_DIR"/*.sha256sum 2>/dev/null || true
echo
echo -e "${BLUE}使用说明：${NC}"
echo "  1. 将 ISO 写入 U 盘："
echo "     sudo dd if=jnl-os-*.iso of=/dev/sdX bs=4M status=progress"
echo "  2. 或在 Windows 中使用 Rufus / balenaEtcher 写入 U 盘"
echo "  3. 从 U 盘启动进入 Java Net Lava OS"
echo "  4. 在桌面双击“安装 Java Net Lava OS”进行系统安装"
echo
echo -e "${BLUE}校验 ISO 完整性：${NC}"
echo "  cd out/"
echo "  sha256sum -c jnl-os-*.iso.sha256sum"
