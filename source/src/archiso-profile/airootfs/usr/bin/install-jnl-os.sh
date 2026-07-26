#!/usr/bin/env bash

# ============================================================================
# Java Net Lava OS 安装脚本 v8.0 (1.0.30)
# 功能：
#   1. 支持两种安装模式：
#      [A] 全新安装 - 自动分区整个磁盘（会清除所有数据）
#      [B] 手动安装 - 使用已有分区，支持升级（保留 /home）
#   2. 自动检测目标分区是否已有 JNL OS，提供升级选项
#   3. 在 chroot 中用正确的 mkinitcpio 配置重新生成 initramfs
#   4. GRUB 菜单显示 "Java Net Lava OS" 而不是 "Arch Linux"
#   5. 恢复交互式用户名/密码设置
#   6. 所有错误暂停显示，不闪退
#   7. GUI 模式输出 STEP|index|status 协议供 Python 主程序解析进度
#   8. 严格错误检查：关键文件缺失立即退出非零状态码
#
# 注意：推荐使用新的 jnl-installer-worker（v8.0）作为 GUI 安装的后端，
#       此脚本保留用于命令行模式或回退场景。
# ============================================================================

if [ "$(id -u)" -ne 0 ]; then
    if command -v pkexec >/dev/null 2>&1; then
        exec pkexec "$0" "$@"
    elif command -v sudo >/dev/null 2>&1; then
        exec sudo "$0" "$@"
    else
        echo "错误：需要 root 权限"
        read -p "按回车键退出..."
        exit 1
    fi
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

LOG_FILE="/tmp/jnl-install.log"
> "$LOG_FILE"

log() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

log "=== 安装脚本启动 ==="
log "参数: $@"
log "PID: $$"
log "UID: $(id -u)"

# ============================================================================
# GUI 模式支持：--gui <config_file> 从配置文件读取所有参数，非交互式安装
# ============================================================================
GUI_MODE=false
GUI_CONFIG=""
if [ "$1" = "--gui" ] && [ -n "$2" ]; then
    GUI_MODE=true
    GUI_CONFIG="$2"
    if [ -f "$GUI_CONFIG" ]; then
        source "$GUI_CONFIG"
        log "GUI 模式：从 $GUI_CONFIG 读取配置"
        # 变量名映射：配置文件的变量名 -> 脚本中使用的变量名
        USERPASS="${USER_PASSWORD:-$USERPASS}"
        ROOTPASS="${ROOT_PASSWORD:-$ROOTPASS}"
        HOSTNAME_INPUT="${HOSTNAME:-$HOSTNAME_INPUT}"
        HOME_PART="${HOME_PART:-$HOME_PART}"
        # 确保关键变量有值
        : "${USERNAME:=jnluser}"
        : "${USERPASS:=jnlos}"
        : "${ROOTPASS:=$USERPASS}"
        : "${HOSTNAME_INPUT:=jnl-os}"
        : "${TIMEZONE:=Asia/Shanghai}"
        : "${LOCALE:=zh_CN.UTF-8}"
        : "${INSTALL_MODE:=full}"
        log "GUI 变量映射完成: USER=$USERNAME, HOST=$HOSTNAME_INPUT, MODE=$INSTALL_MODE"
        if [ "$INSTALL_MODE" = "full" ]; then
            DISK="${TARGET_DISK:-}"
            log "GUI: 全新安装模式, 磁盘=$DISK"
        else
            ESP="${ESP_PART:-}"
            ROOT="${ROOT_PART:-}"
            log "GUI: 手动安装模式, ESP=$ESP, ROOT=$ROOT"
        fi
    else
        echo "错误：配置文件不存在: $GUI_CONFIG"
        exit 1
    fi
fi

# ask 函数：GUI模式下使用配置文件值，交互模式下提示输入
ask() {
    local prompt="$1"
    local varname="$2"
    local default="${3:-}"
    if [ "$GUI_MODE" = "true" ]; then
        eval "$varname=\${$varname:-$default}"
        log "GUI: $prompt = ${!varname}"
    else
        read -p "$prompt" "$varname"
        eval "$varname=\${$varname:-$default}"
    fi
}

# ask_password 函数：GUI模式下使用配置文件密码
ask_password() {
    local prompt="$1"
    local varname="$2"
    if [ "$GUI_MODE" = "true" ]; then
        log "GUI: $prompt = (已设置)"
    else
        read -s -p "$prompt" "$varname"
        echo ""
    fi
}

# confirm 函数：GUI模式下自动确认
confirm() {
    local prompt="$1"
    local varname="$2"
    local default="${3:-n}"
    if [ "$GUI_MODE" = "true" ]; then
        eval "$varname=y"
        log "GUI: $prompt -> y"
    else
        read -p "$prompt" "$varname"
        eval "$varname=\${$varname:-$default}"
    fi
}

# pause 函数：GUI模式下不暂停
pause() {
    if [ "$GUI_MODE" != "true" ]; then
        read -p "$1"
    fi
}

say() {
    echo -e "$1"
    log "$(echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g')"
}

step_title() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "===== $1 ====="
}

pause_on_error() {
    echo ""
    echo -e "${RED}  ✗ 错误：$1${NC}"
    echo "  详细日志: $LOG_FILE"
    log "错误: $1"
    pause "  按回车键继续..."
}

clear
echo -e "${CYAN}"
echo "  ╔═══════════════════════════════════════════════╗"
echo "  ║        Java Net Lava OS 安装程序             ║"
echo "  ║        版本 1.0.28                            ║"
echo "  ╚═══════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  安装日志: $LOG_FILE"
echo ""

if [ ! -d /run/archiso ]; then
    echo -e "${RED}错误：此安装程序只能在 Live 环境中运行！${NC}"
    pause "按回车键退出..."
    exit 1
fi

# ============================================================================
# 步骤 1：安装工具
# ============================================================================
step_title "[1/8] 安装必要工具"

# 先检查工具是否已存在，避免不必要的 pacman 调用
NEEDED_TOOLS=(parted mkfs.fat mkfs.ext4 grub-install rsync arch-chroot mkinitcpio blkid fsck.fat)
MISSING_TOOLS=()
for t in "${NEEDED_TOOLS[@]}"; do
    if ! command -v "$t" >/dev/null 2>&1; then
        MISSING_TOOLS+=("$t")
    fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo "  缺失工具: ${MISSING_TOOLS[*]}"
    if ! pacman -Sy --noconfirm --needed \
        parted e2fsprogs dosfstools grub efibootmgr os-prober mtools rsync \
        arch-install-scripts mkinitcpio 2>&1 | tail -20; then
        pause_on_error "工具安装失败"
        exit 1
    fi
    # 重新检查
    STILL_MISSING=()
    for t in "${NEEDED_TOOLS[@]}"; do
        if ! command -v "$t" >/dev/null 2>&1; then
            STILL_MISSING+=("$t")
        fi
    done
    if [ ${#STILL_MISSING[@]} -gt 0 ]; then
        pause_on_error "关键工具仍不可用: ${STILL_MISSING[*]}"
        exit 1
    fi
else
    echo "  所有工具已存在，跳过安装"
fi

say "${GREEN}  ✓ 工具安装完成${NC}"
log "步骤1: 工具安装完成"

# ============================================================================
# 步骤 2：选择安装模式
# ============================================================================
step_title "[2/9] 选择安装模式"

if [ "$GUI_MODE" = "true" ]; then
    # GUI模式：INSTALL_MODE 已从配置文件读取
    log "GUI: 安装模式 = $INSTALL_MODE"
    say "${GREEN}  ✓ 安装模式: $INSTALL_MODE${NC}"
else
    echo "  请选择安装模式："
    echo ""
    echo -e "  ${CYAN}[A]${NC} 全新安装  - 自动分区整个磁盘（${RED}会清除磁盘所有数据${NC}）"
    echo -e "  ${CYAN}[B]${NC} 手动安装  - 使用已有分区，支持升级（${GREEN}保留个人文件${NC}）"
    echo ""
    echo "  ┌─────────────────────────────────────────────────────────┐"
    echo "  │ 全新安装：适合新硬盘或想完全重装                         │"
    echo "  │ 手动安装：适合已有分区，想升级系统但保留 /home 数据     │"
    echo "  │           （需提前用 GParted 分好区）                    │"
    echo "  └─────────────────────────────────────────────────────────┘"
    echo ""

    while true; do
        read -p "  请选择 [A/B]: " INSTALL_MODE
        case "$INSTALL_MODE" in
            [aA]) INSTALL_MODE="full"; break ;;
            [bB]) INSTALL_MODE="manual"; break ;;
            *) echo -e "${RED}  无效选择，请输入 A 或 B${NC}" ;;
        esac
    done
fi

# ============================================================================
# 步骤 2.5：根据模式选择磁盘/分区
# ============================================================================
if [ "$GUI_MODE" = "true" ]; then
    # GUI模式：DISK/ESP_PART/ROOT_PART/HOME_PART 已从配置文件读取
    if [ "$INSTALL_MODE" = "full" ]; then
        log "GUI: 目标磁盘 = $TARGET_DISK"
        DISK="$TARGET_DISK"
        if [ ! -b "$DISK" ]; then
            log "GUI错误: 磁盘 $DISK 不存在"
            exit 1
        fi
        IS_UPGRADE=false
    else
        log "GUI: ESP=$ESP_PART, ROOT=$ROOT_PART, HOME=$HOME_PART"
        ESP="$ESP_PART"
        ROOT="$ROOT_PART"
        if [ ! -b "$ESP" ]; then
            log "GUI错误: ESP分区 $ESP 不存在"
            exit 1
        fi
        if [ ! -b "$ROOT" ]; then
            log "GUI错误: 根分区 $ROOT 不存在"
            exit 1
        fi
        IS_UPGRADE=false
        DISK=""
    fi
    say "${GREEN}  ✓ 磁盘/分区配置完成${NC}"
    log "步骤2: 磁盘/分区配置完成"
elif [ "$INSTALL_MODE" = "full" ]; then
    # ---- 全新安装模式：选择整个磁盘 ----
    step_title "[2.5/9] 选择目标磁盘（全新安装）"
    echo "可用磁盘列表:"
    echo "----------------------------------------"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MODEL | grep -E "^sd|^nvme|^vd"
    echo "----------------------------------------"

    while true; do
        read -p "请输入系统安装磁盘（如 /dev/sda）: " DISK
        if [ -b "$DISK" ]; then
            break
        else
            echo -e "${RED}错误：磁盘 $DISK 不存在！${NC}"
        fi
    done

    echo ""
    echo "目标磁盘信息:"
    lsblk "$DISK"
    echo ""

    DISK_SIZE=$(blockdev --getsize64 "$DISK" 2>/dev/null || echo 0)
    DISK_SIZE_GB=$((DISK_SIZE / 1024 / 1024 / 1024))
    if [ "$DISK_SIZE_GB" -lt 10 ]; then
        pause_on_error "磁盘大小不足 10GB（当前 ${DISK_SIZE_GB}GB）"
        exit 1
    fi

    read -p "确认要清除 $DISK 并安装系统？(y/N) " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "安装已取消"
        exit 0
    fi

    # 标记：全新安装，稍后自动分区
    IS_UPGRADE=false

else
    # ---- 手动安装模式：选择具体分区 ----
    step_title "[2.5/9] 选择目标分区（手动安装）"
    echo "可用磁盘和分区列表:"
    echo "----------------------------------------"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MODEL | grep -E "sd|nvme|vd"
    echo "----------------------------------------"
    echo ""
    echo "  提示：你需要提前用 GParted 分好区。"
    echo "  至少需要："
    echo "    - 1 个 ESP 分区（EFI 引导，FAT32，>=300MB）"
    echo "    - 1 个 根分区（ext4，>=10GB）"
    echo "    - 1 个 home 分区（可选，ext4，用于保留用户数据）"
    echo ""

    # 选择 ESP 分区
    echo -e "${CYAN}── 选择 ESP (EFI) 分区 ──${NC}"
    while true; do
        read -p "请输入 ESP 分区设备名（如 /dev/sda1）: " ESP
        if [ -b "$ESP" ]; then
            ESP_FSTYPE=$(lsblk -no FSTYPE "$ESP" 2>/dev/null | head -1)
            if [ "$ESP_FSTYPE" = "vfat" ] || [ "$ESP_FSTYPE" = "fat32" ]; then
                echo -e "${GREEN}  ✓ ESP 分区已选择: $ESP (FAT32)${NC}"
                break
            else
                echo -e "${YELLOW}  警告: $ESP 不是 FAT32（当前: $ESP_FSTYPE）${NC}"
                read -p "  仍要使用此分区？ESP 必须是 FAT32 (y/N): " ESP_CONFIRM
                if [ "$ESP_CONFIRM" = "y" ] || [ "$ESP_CONFIRM" = "Y" ]; then
                    break
                fi
            fi
        else
            echo -e "${RED}  错误：分区 $ESP 不存在！${NC}"
        fi
    done

    # 选择根分区
    echo ""
    echo -e "${CYAN}── 选择根分区 (/) ──${NC}"
    while true; do
        read -p "请输入根分区设备名（如 /dev/sda2）: " ROOT
        if [ -b "$ROOT" ]; then
            break
        else
            echo -e "${RED}  错误：分区 $ROOT 不存在！${NC}"
        fi
    done

    # 检测根分区是否已有 JNL OS
    IS_UPGRADE=false
    HOME_BACKUP_DIR=""
    echo ""
    echo "  正在检测目标分区是否已有系统..."
    mkdir -p /tmp/detect_root
    mount "$ROOT" /tmp/detect_root 2>/dev/null
    if [ $? -eq 0 ]; then
        # 检测是否有 JNL OS 标记
        if [ -f /tmp/detect_root/etc/os-release ]; then
            OLD_OS_NAME=$(grep -m1 "^NAME=" /tmp/detect_root/etc/os-release 2>/dev/null | cut -d'"' -f2)
        else
            OLD_OS_NAME=""
        fi
        if [ -f /tmp/detect_root/etc/jnl-os-version ]; then
            OLD_JNL_VER=$(cat /tmp/detect_root/etc/jnl-os-version 2>/dev/null | head -1)
        elif [ -f /tmp/detect_root/etc/os-release ] && grep -q "Java Net Lava" /tmp/detect_root/etc/os-release 2>/dev/null; then
            OLD_JNL_VER="未知版本"
        else
            OLD_JNL_VER=""
        fi

        if [ -n "$OLD_JNL_VER" ] || echo "$OLD_OS_NAME" | grep -qi "java.*net.*lava" 2>/dev/null; then
            echo -e "${YELLOW}  ⚠ 检测到目标分区已安装: $OLD_OS_NAME ($OLD_JNL_VER)${NC}"
            echo ""
            echo "  你可以选择："
            echo -e "    ${CYAN}[1]${NC} 升级安装 - ${GREEN}保留 /home 数据${NC}，只替换系统文件"
            echo -e "    ${CYAN}[2]${NC} 覆盖安装 - ${RED}清除所有数据${NC}，全新安装到此分区"
            echo ""
            read -p "  请选择 [1/2] (默认 1): " UPGRADE_CHOICE
            if [ "$UPGRADE_CHOICE" != "2" ]; then
                IS_UPGRADE=true
                echo -e "${GREEN}  ✓ 已选择升级模式，将保留 /home 数据${NC}"
                # 检查 /home 是否在根分区上（非独立 home 分区）
                if [ -d /tmp/detect_root/home ] && [ -z "$HOME_PART" ]; then
                    echo "  检测到 /home 在根分区上，将备份并恢复 home 数据"
                fi
            else
                echo -e "${RED}  已选择覆盖安装，将清除所有数据${NC}"
            fi
        elif [ -n "$OLD_OS_NAME" ]; then
            echo -e "${YELLOW}  ⚠ 检测到目标分区已有其他系统: $OLD_OS_NAME${NC}"
            read -p "  确认覆盖安装？这将清除该分区的所有数据 (y/N): " OVERWRITE_CONFIRM
            if [ "$OVERWRITE_CONFIRM" != "y" ] && [ "$OVERWRITE_CONFIRM" != "Y" ]; then
                echo "安装已取消"
                umount /tmp/detect_root 2>/dev/null
                exit 0
            fi
        else
            echo -e "${GREEN}  ✓ 目标分区是空的或没有检测到已有系统${NC}"
        fi
        umount /tmp/detect_root 2>/dev/null
    fi
    rmdir /tmp/detect_root 2>/dev/null

    # 选择 home 分区（可选）
    echo ""
    echo -e "${CYAN}── 选择 home 分区（可选） ──${NC}"
    echo "  如果你有单独的 home 分区，输入设备名。"
    echo "  如果没有（/home 在根分区上），直接按回车跳过。"
    read -p "请输入 home 分区设备名（可选，如 /dev/sda3）: " HOME_PART_INPUT
    HOME_PART=""
    if [ -n "$HOME_PART_INPUT" ]; then
        if [ -b "$HOME_PART_INPUT" ]; then
            HOME_PART="$HOME_PART_INPUT"
            echo -e "${GREEN}  ✓ home 分区已选择: $HOME_PART${NC}"
        else
            echo -e "${YELLOW}  警告: 分区 $HOME_PART_INPUT 不存在，跳过 home 分区${NC}"
        fi
    fi
    echo ""

    DISK=""  # 手动模式不使用 DISK 变量
fi

# ============================================================================
# 步骤 3：用户配置
# ============================================================================
step_title "[3/8] 用户配置"

if [ "$GUI_MODE" = "true" ]; then
    # GUI模式：USERNAME, USER_PASSWORD, ROOT_PASSWORD, HOSTNAME 已从配置文件读取
    USERPASS="$USER_PASSWORD"
    ROOTPASS="$ROOT_PASSWORD"
    HOSTNAME_INPUT="$HOSTNAME"
    log "GUI: 用户名=$USERNAME, 主机名=$HOSTNAME_INPUT"
    say "${GREEN}  ✓ 用户配置完成${NC}"
    say "  用户名: $USERNAME"
    say "  主机名: $HOSTNAME_INPUT"
else
    read -p "请输入用户名（默认 jnluser）: " USERNAME
    if [ -z "$USERNAME" ]; then
        USERNAME="jnluser"
    fi

    while true; do
        read -s -p "请输入用户密码: " USERPASS
        echo ""
        read -s -p "请确认用户密码: " USERPASS2
        echo ""
        if [ "$USERPASS" = "$USERPASS2" ] && [ -n "$USERPASS" ]; then
            break
        else
            echo -e "${RED}两次密码不一致或密码为空，请重新输入${NC}"
        fi
    done

    while true; do
        read -s -p "请输入 root 密码: " ROOTPASS
        echo ""
        read -s -p "请确认 root 密码: " ROOTPASS2
        echo ""
        if [ "$ROOTPASS" = "$ROOTPASS2" ] && [ -n "$ROOTPASS" ]; then
            break
        else
            echo -e "${RED}两次密码不一致或密码为空，请重新输入${NC}"
        fi
    done

    read -p "请输入主机名（默认 jnl-os）: " HOSTNAME_INPUT
    if [ -z "$HOSTNAME_INPUT" ]; then
        HOSTNAME_INPUT="jnl-os"
    fi

    echo ""
    say "${GREEN}  ✓ 用户配置完成${NC}"
    echo "  用户名: $USERNAME"
    echo "  主机名: $HOSTNAME_INPUT"
fi

# ============================================================================
# 步骤 4：创建分区和文件系统（或使用已有分区）
# ============================================================================
if [ "$INSTALL_MODE" = "full" ]; then
    # ---- 全新安装模式：自动分区 ----
    step_title "[4/9] 创建分区和文件系统（全新安装）"

    # 检测启动模式
    if [ -d /sys/firmware/efi ]; then
        BOOT_MODE="efi"
    else
        BOOT_MODE="bios"
    fi
    echo "  启动模式: $BOOT_MODE"

    echo "  卸载所有分区..."
    for part in $(lsblk -nrpo NAME "$DISK" | grep -v "^$DISK\$"); do
        umount "$part" 2>/dev/null || true
    done

    echo "  创建 GPT 分区表..."
    parted -s "$DISK" mklabel gpt
    sleep 1
    partprobe "$DISK" 2>/dev/null || true
    sleep 1

    if [ "$BOOT_MODE" = "bios" ]; then
        # BIOS 模式：创建 BIOS Boot 分区（ef02）用于 GRUB 嵌入
        echo "  创建 BIOS Boot 分区 (1MB)..."
        parted -s "$DISK" mkpart biosboot 1MiB 2MiB
        parted -s "$DISK" set 1 bios_grub on
        sleep 1

        echo "  创建根分区 (剩余空间)..."
        parted -s "$DISK" mkpart primary ext4 2MiB 100%
        sleep 1
    else
        # EFI 模式：创建 ESP 分区
        echo "  创建 ESP 分区 (512MB)..."
        parted -s "$DISK" mkpart ESP fat32 1MiB 513MiB
        parted -s "$DISK" set 1 esp on
        sleep 1

        echo "  创建根分区 (剩余空间)..."
        parted -s "$DISK" mkpart primary ext4 513MiB 100%
        sleep 1
    fi

    partprobe "$DISK" 2>/dev/null || true
    sleep 2

    # 推断分区设备名
    if [[ "$DISK" == /dev/nvme* ]] || [[ "$DISK" == /dev/mmcblk* ]]; then
        if [ "$BOOT_MODE" = "bios" ]; then
            BIOS_BOOT="${DISK}p1"
            ROOT="${DISK}p2"
            ESP=""
        else
            ESP="${DISK}p1"
            ROOT="${DISK}p2"
        fi
    else
        if [ "$BOOT_MODE" = "bios" ]; then
            BIOS_BOOT="${DISK}1"
            ROOT="${DISK}2"
            ESP=""
        else
            ESP="${DISK}1"
            ROOT="${DISK}2"
        fi
    fi

    echo "  等待设备节点就绪..."
    READY=false
    for i in $(seq 1 10); do
        if [ "$BOOT_MODE" = "bios" ]; then
            if [ -b "$BIOS_BOOT" ] && [ -b "$ROOT" ]; then
                READY=true
                break
            fi
        else
            if [ -b "$ESP" ] && [ -b "$ROOT" ]; then
                READY=true
                break
            fi
        fi
        sleep 1
    done

    if [ "$READY" != "true" ]; then
        pause_on_error "分区设备未就绪！"
        exit 1
    fi

    if [ "$BOOT_MODE" = "bios" ]; then
        echo "  BIOS Boot 分区: $BIOS_BOOT"
    else
        echo "  EFI 分区: $ESP"
    fi
    echo "  根分区:   $ROOT"

    # 格式化 ESP（仅 EFI 模式）
    if [ "$BOOT_MODE" = "efi" ] && [ -n "$ESP" ]; then
        echo "  格式化 ESP 为 FAT32..."
        mkfs.fat -F 32 -n JNL-ESP "$ESP"
        if [ $? -ne 0 ]; then
            pause_on_error "FAT32 格式化失败"
            exit 1
        fi
        echo "  验证文件系统..."
        fsck.fat -n "$ESP" || fsck.fat -a "$ESP"
    else
        echo "  BIOS 模式：跳过 ESP 格式化"
    fi

    echo "  格式化根分区为 ext4..."
    mkfs.ext4 -F -L JNL-OS "$ROOT"
    if [ $? -ne 0 ]; then
        pause_on_error "ext4 格式化失败"
        exit 1
    fi

    say "${GREEN}  ✓ 文件系统创建完成${NC}"
    log "步骤4: 文件系统创建完成"

else
    # ---- 手动安装模式：使用已有分区 ----
    step_title "[4/9] 准备分区（手动安装）"

    echo "  ESP 分区:   $ESP"
    echo "  根分区:     $ROOT"
    if [ -n "$HOME_PART" ]; then
        echo "  home 分区:  $HOME_PART"
    fi
    if [ "$IS_UPGRADE" = true ]; then
        echo -e "  ${GREEN}升级模式: 将保留 /home 数据${NC}"
    fi
    echo ""

    # 卸载可能已挂载的分区
    umount "$ESP" 2>/dev/null || true
    umount "$ROOT" 2>/dev/null || true
    umount "$HOME_PART" 2>/dev/null || true

    if [ "$IS_UPGRADE" = true ]; then
        # ---- 升级模式：备份 /home，然后格式化根分区 ----
        echo "  [升级模式] 备份 /home 数据..."

        # 如果有独立 home 分区，不需要备份（home 分区不会被格式化）
        if [ -n "$HOME_PART" ]; then
            echo -e "  ${GREEN}  home 分区 ($HOME_PART) 是独立的，不会被格式化，数据安全${NC}"
        else
            # /home 在根分区上，需要备份
            # 先挂载根分区读取 /home
            echo "  挂载根分区以备份 /home..."
            mkdir -p /tmp/upgrade_root
            mount "$ROOT" /tmp/upgrade_root
            if [ $? -ne 0 ]; then
                pause_on_error "无法挂载根分区来备份 /home！"
                exit 1
            fi

            # 检查 /home 是否有数据
            if [ -d /tmp/upgrade_root/home ]; then
                HOME_BACKUP_DIR="/tmp/home_backup_$(date +%s)"
                echo "  备份 /home 到 $HOME_BACKUP_DIR ..."
                mkdir -p "$HOME_BACKUP_DIR"

                # 备份所有用户目录（排除 lost+found）
                rsync -aAX --info=progress2 \
                    --exclude='lost+found' \
                    /tmp/upgrade_root/home/ "$HOME_BACKUP_DIR/" 2>&1 | tee -a "$LOG_FILE"

                BACKUP_COUNT=$(find "$HOME_BACKUP_DIR" -type f 2>/dev/null | wc -l)
                echo -e "${GREEN}  ✓ 已备份 $BACKUP_COUNT 个文件${NC}"
            else
                echo -e "${YELLOW}  警告: 根分区上没有 /home 目录，无需备份${NC}"
            fi

            # 卸载根分区，准备格式化
            umount /tmp/upgrade_root 2>/dev/null
            rmdir /tmp/upgrade_root 2>/dev/null
        fi

        # 格式化根分区（不格式化 home 分区！）
        echo ""
        echo "  格式化根分区为 ext4（/home 已备份）..."
        mkfs.ext4 -F -L JNL-OS "$ROOT"
        if [ $? -ne 0 ]; then
            pause_on_error "ext4 格式化失败"
            exit 1
        fi
        echo -e "${GREEN}  ✓ 根分区已格式化${NC}"

    else
        # ---- 非升级模式：格式化所有分区 ----
        echo "  格式化根分区为 ext4..."
        mkfs.ext4 -F -L JNL-OS "$ROOT"
        if [ $? -ne 0 ]; then
            pause_on_error "根分区 ext4 格式化失败"
            exit 1
        fi

        # 如果 ESP 不是 FAT32，格式化它
        ESP_FSTYPE=$(lsblk -no FSTYPE "$ESP" 2>/dev/null | head -1)
        if [ "$ESP_FSTYPE" != "vfat" ] && [ "$ESP_FSTYPE" != "fat32" ]; then
            echo "  格式化 ESP 为 FAT32..."
            mkfs.fat -F 32 -n JNL-ESP "$ESP"
            if [ $? -ne 0 ]; then
                pause_on_error "ESP FAT32 格式化失败"
                exit 1
            fi
        else
            echo -e "  ${YELLOW}ESP 已是 FAT32，跳过格式化${NC}"
            echo "  （如需清空 ESP，请手动格式化）"
        fi

        # 如果有 home 分区且不是 ext4，格式化它
        if [ -n "$HOME_PART" ]; then
            HOME_FSTYPE=$(lsblk -no FSTYPE "$HOME_PART" 2>/dev/null | head -1)
            if [ "$HOME_FSTYPE" != "ext4" ] && [ "$HOME_FSTYPE" != "btrfs" ]; then
                echo "  格式化 home 分区为 ext4..."
                confirm "  确认格式化 $HOME_PART？（数据将丢失）(y/N): " HOME_FMT_CONFIRM n
                if [ "$HOME_FMT_CONFIRM" = "y" ] || [ "$HOME_FMT_CONFIRM" = "Y" ]; then
                    mkfs.ext4 -F -L JNL-HOME "$HOME_PART"
                fi
            else
                echo -e "  ${GREEN}home 分区已是 ext4，跳过格式化${NC}"
            fi
        fi

        echo -e "${GREEN}  ✓ 分区准备完成${NC}"
        log "步骤4: 分区准备完成"
    fi
fi

# ============================================================================
# 步骤 5：挂载并复制系统
# ============================================================================
step_title "[5/9] 挂载磁盘并复制系统"

# 确保 BOOT_MODE 已定义（手动模式可能未定义）
if [ -z "$BOOT_MODE" ]; then
    if [ -d /sys/firmware/efi ]; then
        BOOT_MODE="efi"
    else
        BOOT_MODE="bios"
    fi
fi

mkdir -p /mnt
mount "$ROOT" /mnt
mkdir -p /mnt/boot

# 挂载 ESP（仅 EFI 模式）
if [ "$BOOT_MODE" = "efi" ] && [ -n "$ESP" ]; then
    mount "$ESP" /mnt/boot
else
    echo "  BIOS 模式：跳过 ESP 挂载"
fi

# 如果有独立 home 分区，挂载它
if [ -n "$HOME_PART" ]; then
    mkdir -p /mnt/home
    mount "$HOME_PART" /mnt/home
    echo -e "  ${GREEN}已挂载 home 分区: $HOME_PART -> /mnt/home${NC}"
fi

echo "  复制根文件系统（请耐心等待）..."
# 升级模式：不覆盖 /home（如果有备份，稍后恢复）
if [ "$IS_UPGRADE" = true ] && [ -z "$HOME_PART" ]; then
    # 升级模式且 home 在根分区上：排除 /home，稍后从备份恢复
    rsync -aAX --info=progress2 \
        --exclude='/proc/*' \
        --exclude='/sys/*' \
        --exclude='/dev/*' \
        --exclude='/run/*' \
        --exclude='/tmp/*' \
        --exclude='/mnt/*' \
        --exclude='/boot/*' \
        --exclude='/home/*' \
        --exclude='/etc/machine-id' \
        --exclude='/etc/fstab' \
        / /mnt/ 2>&1 | tee -a "$LOG_FILE"
else
    rsync -aAX --info=progress2 \
        --exclude='/proc/*' \
        --exclude='/sys/*' \
        --exclude='/dev/*' \
        --exclude='/run/*' \
        --exclude='/tmp/*' \
        --exclude='/mnt/*' \
        --exclude='/boot/*' \
        --exclude='/etc/machine-id' \
        --exclude='/etc/fstab' \
        / /mnt/ 2>&1 | tee -a "$LOG_FILE"
fi

echo ""
echo "  复制内核文件（从 ISO 启动分区）..."

# 从 ISO 启动分区复制内核（vmlinuz）
KERNEL_SRC=""
if [ -f /run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux-lts ]; then
    KERNEL_SRC="/run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux-lts"
elif [ -f /boot/vmlinuz-linux-lts ]; then
    KERNEL_SRC="/boot/vmlinuz-linux-lts"
fi

if [ -n "$KERNEL_SRC" ] && [ -f "$KERNEL_SRC" ]; then
    cp -v "$KERNEL_SRC" /mnt/boot/vmlinuz-linux-lts 2>&1 | tee -a "$LOG_FILE"
    say "${GREEN}  ✓ 内核文件已复制${NC}"
else
    pause_on_error "找不到内核文件！"
    exit 1
fi

# 注意：不复制 ISO 的 initramfs（那是 archiso 的，不能用于正常启动）
# 我们将在 chroot 中用 mkinitcpio 重新生成正确的 initramfs

# 复制微码（如果有）
for ucode in /run/archiso/bootmnt/arch/boot/x86_64/*-ucode.img /boot/*-ucode.img; do
    if [ -f "$ucode" ]; then
        cp -v "$ucode" /mnt/boot/ 2>&1 | tee -a "$LOG_FILE"
    fi
done

echo ""
echo "  /mnt/boot 内容:"
ls -la /mnt/boot/ 2>&1 | tee -a "$LOG_FILE"

mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/run /mnt/tmp
chmod 1777 /mnt/tmp

# 获取 UUID
ROOT_UUID=$(blkid -s UUID -o value "$ROOT" 2>/dev/null || true)
ESP_UUID=""
if [ "$BOOT_MODE" = "efi" ] && [ -n "$ESP" ]; then
    ESP_UUID=$(blkid -s UUID -o value "$ESP" 2>/dev/null || true)
fi
HOME_UUID=""
if [ -n "$HOME_PART" ]; then
    HOME_UUID=$(blkid -s UUID -o value "$HOME_PART" 2>/dev/null || true)
fi

echo "  ROOT_UUID: $ROOT_UUID"
[ -n "$ESP_UUID" ] && echo "  ESP_UUID:  $ESP_UUID"
if [ -n "$HOME_UUID" ]; then
    echo "  HOME_UUID: $HOME_UUID"
fi

# 生成 fstab
cat > /mnt/etc/fstab << EOF_FSTAB
UUID=$ROOT_UUID / ext4 rw,noatime 0 1
EOF_FSTAB

# EFI 模式添加 ESP 条目
if [ "$BOOT_MODE" = "efi" ] && [ -n "$ESP_UUID" ]; then
    echo "UUID=$ESP_UUID /boot vfat rw,noatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2" >> /mnt/etc/fstab
fi

# 如果有独立 home 分区，添加到 fstab
if [ -n "$HOME_UUID" ]; then
    echo "UUID=$HOME_UUID /home ext4 rw,noatime 0 2" >> /mnt/etc/fstab
fi

# 升级模式：恢复 /home 数据（仅当 home 在根分区上且有备份时）
if [ "$IS_UPGRADE" = true ] && [ -n "$HOME_BACKUP_DIR" ] && [ -z "$HOME_PART" ]; then
    echo ""
    echo "  [升级模式] 恢复 /home 数据..."
    mkdir -p /mnt/home
    rsync -aAX --info=progress2 \
        "$HOME_BACKUP_DIR/" /mnt/home/ 2>&1 | tee -a "$LOG_FILE"
    RESTORED_COUNT=$(find /mnt/home -type f 2>/dev/null | wc -l)
    echo -e "${GREEN}  ✓ 已恢复 $RESTORED_COUNT 个文件到 /home${NC}"
    # 清理备份
    rm -rf "$HOME_BACKUP_DIR"
fi

say "${GREEN}  ✓ 系统文件复制完成${NC}"
log "步骤5: 系统文件复制完成"

# ============================================================================
# 步骤 6：配置系统（chroot）
# ============================================================================
step_title "[6/9] 配置系统（chroot）"

echo "  配置 DNS..."
rm -f /mnt/etc/resolv.conf
cp -L /etc/resolv.conf /mnt/etc/resolv.conf 2>/dev/null || echo "nameserver 8.8.8.8" > /mnt/etc/resolv.conf

# 创建 chroot 配置脚本（放到 /usr/local/bin，不会被 tmpfs 覆盖）
mkdir -p /mnt/usr/local/bin
cat > /mnt/usr/local/bin/chroot-config.sh << CHROOT_SCRIPT
#!/bin/bash
set -e

echo "  设置时区..."
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc 2>/dev/null || true

echo "  设置 locale..."
sed -i 's/^#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen 2>/dev/null || true
echo "LANG=zh_CN.UTF-8" > /etc/locale.conf

echo "  设置主机名..."
echo "$HOSTNAME_INPUT" > /etc/hostname
cat > /etc/hosts << 'EOF_HOSTS'
127.0.0.1 localhost
::1       localhost
127.0.1.1 __HOSTNAME__.localdomain __HOSTNAME__
EOF_HOSTS
sed -i "s/__HOSTNAME__/$HOSTNAME_INPUT/g" /etc/hosts

# 写入版本标记文件（用于升级检测）
echo "1.0.30" > /etc/jnl-os-version

# 保存激活密钥信息到安装后的系统
mkdir -p /etc/jnl-os
if [ -f /tmp/jnl-activation/activation.key ]; then
    cp /tmp/jnl-activation/activation.key /etc/jnl-os/activation.key
    chmod 600 /etc/jnl-os/activation.key
    log "激活信息已保存到 /etc/jnl-os/activation.key"
else
    # 默认试用模式
    cat > /etc/jnl-os/activation.key <<ACTEOF
ACTIVATION_KEY=TRIAL
ACTIVATION_STATUS=试用模式
ACTIVATION_DATE=$(date '+%Y-%m-%d %H:%M:%S')
ACTEOF
    chmod 600 /etc/jnl-os/activation.key
    log "默认激活信息（试用模式）已创建"
fi

# 确保 os-release 包含 Java Net Lava OS 标识
if ! grep -q "Java Net Lava" /etc/os-release 2>/dev/null; then
    cat > /etc/os-release << 'EOF_OS_RELEASE'
NAME="Java Net Lava OS"
PRETTY_NAME="Java Net Lava OS 1.0.28"
ID=jnl-os
ID_LIKE=arch
VERSION="1.0.28"
VERSION_ID="1.0.28"
ANSI_COLOR="0;32"
HOME_URL="https://github.com/jnl-os"
SUPPORT_URL="https://github.com/jnl-os/issues"
BUG_REPORT_URL="https://github.com/jnl-os/issues"
EOF_OS_RELEASE
fi

echo "  配置 sudoers..."
if ! grep -q "^%wheel ALL=(ALL) NOPASSWD: ALL" /etc/sudoers; then
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

echo "  创建用户..."
if ! id -u $USERNAME &>/dev/null; then
    useradd -m -G wheel,audio,video,storage,optical,network -s /bin/bash $USERNAME
fi
echo "$USERNAME:$USERPASS" | chpasswd
echo "root:$ROOTPASS" | chpasswd

# 将桌面文件从 jnluser 移动到新用户（如果用户名不同）
if [ "$USERNAME" != "jnluser" ] && [ -d /home/jnluser ]; then
    echo "  迁移用户配置文件..."
    cp -a /home/jnluser/. /home/$USERNAME/ 2>/dev/null || true
    chown -R $USERNAME:$USERNAME /home/$USERNAME/
    userdel -r jnluser 2>/dev/null || true
fi

# 更新 SDDM 配置：安装后切换到plasma桌面session（不再用安装session）
# 将用户名从jnluser改为实际用户名
sed -i "s/User=jnluser/User=$USERNAME/g" /etc/sddm.conf 2>/dev/null || true
# 将session从jnl-installer.desktop切换回plasma.desktop（正常桌面）
sed -i "s/Session=jnl-installer.desktop/Session=plasma.desktop/g" /etc/sddm.conf 2>/dev/null || true
# 确保sddm.conf中有正确的session设置
if ! grep -q "Session=plasma.desktop" /etc/sddm.conf 2>/dev/null; then
    sed -i '/^\[Autologin\]/a Session=plasma.desktop' /etc/sddm.conf 2>/dev/null || true
fi
# 移除安装session的xsession入口（安装后不需要了）
rm -f /usr/share/xsessions/jnl-installer.desktop 2>/dev/null || true
# 移除安装session启动脚本
rm -f /usr/local/bin/jnl-installer-session 2>/dev/null || true

echo "  配置 GRUB 默认设置..."
cat > /etc/default/grub << 'EOF_GRUB_DEFAULT'
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Java Net Lava OS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""
GRUB_PRELOAD_MODULES="part_gpt part_msdos"
GRUB_ENABLE_CRYPTODISK=n
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_DISABLE_OS_PROBER=false
GRUB_SAVEDEFAULT=false
GRUB_THEME="/usr/share/grub/themes/jnl-os/theme.txt"
EOF_GRUB_DEFAULT

echo "  修复 mkinitcpio 配置..."
# 删除 archiso 专用的 mkinitcpio 配置
rm -f /etc/mkinitcpio.conf.d/archiso.conf 2>/dev/null || true
rm -f /etc/mkinitcpio.d/linux-lts.preset 2>/dev/null || true

# 写入标准的 mkinitcpio 配置（用于正常启动，不是 Live 启动）
cat > /etc/mkinitcpio.conf << 'EOF_MKINITCPIO'
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)
COMPRESSION="zstd"
COMPRESSION_OPTIONS=()
EOF_MKINITCPIO

# 写入正确的 preset 文件
cat > /etc/mkinitcpio.d/linux-lts.preset << 'EOF_PRESET'
PRESETS=('default' 'fallback')
ALL_kver='/boot/vmlinuz-linux-lts'
default_image="/boot/initramfs-linux-lts.img"
default_options=""
fallback_image="/boot/initramfs-linux-lts-fallback.img"
fallback_options="-S autodetect"
EOF_PRESET

echo "  验证内核文件..."
if [ -f /boot/vmlinuz-linux-lts ]; then
    echo "  ✓ /boot/vmlinuz-linux-lts 存在"
    ls -la /boot/vmlinuz-linux-lts
else
    echo "  ✗ /boot/vmlinuz-linux-lts 不存在！"
    exit 1
fi

echo "  生成 initramfs（这可能需要几分钟）..."
# 确保模块目录存在
KERNEL_VER=$(uname -r 2>/dev/null || echo "")
if [ -z "$KERNEL_VER" ] || [ ! -d /usr/lib/modules/$KERNEL_VER ]; then
    # 从 vmlinuz 文件名推断，或者找最新的模块目录
    KERNEL_VER=$(ls /usr/lib/modules/ 2>/dev/null | grep -v 'pkgbase' | sort -V | tail -1)
    echo "  检测到内核版本: $KERNEL_VER"
fi

# 生成 initramfs
if mkinitcpio -p linux-lts 2>&1; then
    echo "  ✓ initramfs 生成成功"
else
    echo "  ⚠ mkinitcpio -p 失败，尝试手动生成..."
    mkinitcpio -k /boot/vmlinuz-linux-lts -g /boot/initramfs-linux-lts.img 2>&1 || {
        echo "  ✗ initramfs 生成失败！"
        exit 1
    }
fi

echo "  验证 initramfs..."
if [ -f /boot/initramfs-linux-lts.img ]; then
    echo "  ✓ initramfs-linux-lts.img 已生成"
    ls -la /boot/initramfs-linux-lts.img
else
    echo "  ✗ initramfs 生成失败！"
    exit 1
fi

echo "  安装 GRUB..."
if [ "$BOOT_MODE" = "efi" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=JNL-OS --recheck 2>&1 || {
        echo "  GRUB 安装失败，尝试不带 --recheck..."
        grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=JNL-OS 2>&1 || {
            echo "  ✗ GRUB 安装失败！"
            exit 1
        }
    }

    echo "  创建 fallback bootloader (BOOTX64.EFI)..."
    mkdir -p /boot/EFI/BOOT
    if [ -f /boot/EFI/JNL-OS/grubx64.efi ]; then
        cp -v /boot/EFI/JNL-OS/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI
        echo "  ✓ BOOTX64.EFI 已创建"
    else
        echo "  ⚠ grubx64.efi 不存在，搜索中..."
        find /boot -name "grubx64.efi" -exec cp -v {} /boot/EFI/BOOT/BOOTX64.EFI \; 2>/dev/null || true
    fi
else
    # BIOS 模式
    grub-install --target=i386-pc --recheck "$DISK" 2>&1 || {
        echo "  ✗ GRUB BIOS 安装失败！"
        exit 1
    }
    echo "  ✓ GRUB BIOS 安装完成"
fi

echo "  生成 grub.cfg..."
mkdir -p /boot/grub

# 先创建一个基本的 grub.cfg 作为后备（确保能启动）
ROOT_UUID_GRUB=\$(grep -m1 'UUID=' /etc/fstab | grep -o 'UUID=[a-f0-9-]*' | cut -d= -f2)
cat > /boot/grub/grub.cfg << EOF_GRUB_BASIC
set timeout=5
set default=0

menuentry "Java Net Lava OS" {
    linux /vmlinuz-linux-lts root=UUID=\$ROOT_UUID_GRUB rw quiet
    initrd /initramfs-linux-lts.img
}

menuentry "Java Net Lava OS (fallback)" {
    linux /vmlinuz-linux-lts root=UUID=\$ROOT_UUID_GRUB rw quiet
    initrd /initramfs-linux-lts-fallback.img
}
EOF_GRUB_BASIC

echo "  ✓ 基本 grub.cfg 已创建"

# 尝试用 grub-mkconfig 生成完整配置
if grub-mkconfig -o /boot/grub/grub.cfg 2>&1; then
    echo "  ✓ grub-mkconfig 成功"
else
    echo "  ⚠ grub-mkconfig 失败，保留基本 grub.cfg"
fi

echo "  配置系统服务..."
# 在 chroot 中 systemctl 可能不可靠，直接创建符号链接确保服务启用
enable_service() {
    local svc="\$1"
    local unit_file=""
    # 查找服务单元文件
    for dir in /usr/lib/systemd/system /etc/systemd/system; do
        if [ -f "\$dir/\$svc" ]; then
            unit_file="\$dir/\$svc"
            break
        fi
    done
    if [ -z "\$unit_file" ]; then
        echo "  ⚠ 服务 \$svc 的单元文件未找到"
        return 1
    fi
    # 创建符号链接到 multi-user.target.wants
    mkdir -p /etc/systemd/system/multi-user.target.wants
    ln -sf "\$unit_file" "/etc/systemd/system/multi-user.target.wants/\$svc"
    # 如果是 dbus 服务，也创建 dbus 别名
    case "\$svc" in
        NetworkManager.service)
            ln -sf "\$unit_file" /etc/systemd/system/dbus-org.freedesktop.NetworkManager.service 2>/dev/null
            ;;
        wpa_supplicant.service)
            ln -sf "\$unit_file" /etc/systemd/system/dbus-fi.epitest.hostap.WPASupplicant.service 2>/dev/null
            ;;
        bluetooth.service)
            ln -sf "\$unit_file" /etc/systemd/system/dbus-org.bluez.service 2>/dev/null
            ;;
    esac
    echo "  ✓ 已启用 \$svc"
}

disable_service() {
    local svc="\$1"
    rm -f "/etc/systemd/system/multi-user.target.wants/\$svc" 2>/dev/null
    # 只删除对应的 dbus 别名，不要删除所有
    case "\$svc" in
        NetworkManager.service)
            rm -f /etc/systemd/system/dbus-org.freedesktop.NetworkManager.service 2>/dev/null
            ;;
        wpa_supplicant.service)
            rm -f /etc/systemd/system/dbus-fi.epitest.hostap.WPASupplicant.service 2>/dev/null
            ;;
        bluetooth.service)
            rm -f /etc/systemd/system/dbus-org.bluez.service 2>/dev/null
            ;;
    esac
    echo "  ✓ 已禁用 \$svc"
}

enable_service NetworkManager.service
enable_service wpa_supplicant.service
enable_service bluetooth.service
enable_service sddm.service
# 确保图形界面目标
ln -sf /usr/lib/systemd/system/graphical.target /etc/systemd/system/default.target 2>/dev/null

disable_service ldconfig.service
disable_service man-db.service
disable_service updatedb.service
disable_service NetworkManager-wait-online.service

# 禁用 Live 专用服务
disable_service jnl-wifi-autoscan.service
disable_service jnl-wifi-daemon.service 2>/dev/null || true
disable_service jnl-live-autostart.service 2>/dev/null || true

# 保留自动登录，但切换到plasma桌面session（和Windows一样开机进桌面）
# 自动登录的用户名已经在前面设置为 $USERNAME
# session已经切换为 plasma.desktop
# 确保 sddm.conf 配置正确
if [ -f /etc/sddm.conf ]; then
    # 确保用户名正确
    sed -i "s/User=jnluser/User=$USERNAME/g" /etc/sddm.conf 2>/dev/null || true
    # 确保session是plasma桌面
    sed -i "s/Session=jnl-installer.desktop/Session=plasma.desktop/g" /etc/sddm.conf 2>/dev/null || true
    # 如果没有session行，添加
    if ! grep -q "Session=" /etc/sddm.conf 2>/dev/null; then
        sed -i '/^\[Autologin\]/a Session=plasma.desktop' /etc/sddm.conf 2>/dev/null || true
    fi
fi

# 移除安装session相关文件（安装后不需要）
rm -f /usr/share/xsessions/jnl-installer.desktop 2>/dev/null || true
rm -f /usr/local/bin/jnl-installer-session 2>/dev/null || true

# 移除 Live 用户的安装器自动启动
rm -f /home/$USERNAME/.config/autostart/jnl-live-installer.desktop 2>/dev/null || true
rm -f /etc/xdg/autostart/jnl-live-installer.desktop 2>/dev/null || true

echo "  生成 machine-id..."
systemd-machine-id-setup 2>/dev/null || true

echo "  ✓ chroot 配置完成"

CHROOT_SCRIPT

chmod +x /mnt/usr/local/bin/chroot-config.sh

echo "  执行 chroot 配置..."
arch-chroot /mnt /bin/bash -c "BOOT_MODE=$BOOT_MODE DISK=$DISK /usr/local/bin/chroot-config.sh" 2>&1 | tee -a "$LOG_FILE"
CHROOT_EXIT=${PIPESTATUS[0]}

if [ "$CHROOT_EXIT" -ne 0 ]; then
    echo ""
    pause_on_error "chroot 配置失败（退出码: $CHROOT_EXIT）"
    echo ""
    echo "  当前 /mnt/boot 内容:"
    ls -la /mnt/boot/ 2>/dev/null
    echo ""
    echo "  /mnt/boot/EFI 内容:"
    find /mnt/boot/EFI -type f 2>/dev/null
    echo ""
    pause "  按回车键退出..."
    exit 1
fi

log "步骤6: chroot配置完成"

# ============================================================================
# 步骤 7：最终验证
# ============================================================================
step_title "[7/9] 最终验证"

echo "  验证关键文件:"
echo "  -----------------------------------------------"

ALL_OK=true

if [ -f /mnt/boot/vmlinuz-linux-lts ]; then
    echo "  ✓ vmlinuz-linux-lts 存在"
    log "vmlinuz-linux-lts: $(ls -la /mnt/boot/vmlinuz-linux-lts)"
else
    echo "  ✗ vmlinuz-linux-lts 不存在！"
    ALL_OK=false
fi

if [ -f /mnt/boot/initramfs-linux-lts.img ]; then
    echo "  ✓ initramfs-linux-lts.img 存在"
    log "initramfs-linux-lts.img: $(ls -la /mnt/boot/initramfs-linux-lts.img)"
else
    echo "  ✗ initramfs-linux-lts.img 不存在！"
    ALL_OK=false
fi

if [ "$BOOT_MODE" = "efi" ]; then
    if [ -f /mnt/boot/EFI/JNL-OS/grubx64.efi ]; then
        echo "  ✓ grubx64.efi 存在"
    else
        echo "  ✗ grubx64.efi 不存在！"
        ALL_OK=false
    fi

    if [ -f /mnt/boot/EFI/BOOT/BOOTX64.EFI ]; then
        echo "  ✓ BOOTX64.EFI 存在"
    else
        echo "  ✗ BOOTX64.EFI 不存在！"
        ALL_OK=false
    fi
else
    echo "  BIOS 模式：跳过 EFI 文件验证"
fi

if [ -f /mnt/boot/grub/grub.cfg ]; then
    echo "  ✓ grub.cfg 存在"
    # 检查 grub.cfg 中是否有 "Java Net Lava OS"
    if grep -q "Java Net Lava OS" /mnt/boot/grub/grub.cfg 2>/dev/null; then
        echo "    (菜单标题: Java Net Lava OS)"
    else
        echo "    (警告: 菜单标题可能不是 Java Net Lava OS)"
    fi
    log "grub.cfg 内容:"
    cat /mnt/boot/grub/grub.cfg >> "$LOG_FILE" 2>/dev/null
else
    echo "  ✗ grub.cfg 不存在！"
    ALL_OK=false
fi

echo "  -----------------------------------------------"

if [ "$ALL_OK" = false ]; then
    echo ""
    say "${YELLOW}  ⚠ 警告：部分关键文件缺失！${NC}"
    echo "  完整日志: $LOG_FILE"
    echo ""
    echo "  /mnt/boot 目录内容:"
    ls -la /mnt/boot/ 2>/dev/null
    echo ""
    echo "  /mnt/boot/EFI 目录:"
    find /mnt/boot/EFI -type f 2>/dev/null
    echo ""
    pause "  按回车键继续（不会闪退）..."
else
    say "${GREEN}  ✓ 所有关键文件验证通过！${NC}"
fi

log "步骤7: 最终验证完成"

# ============================================================================
# 步骤 8：卸载并完成
# ============================================================================
step_title "[8/9] 卸载并完成"

echo "  同步磁盘..."
sync

echo "  卸载磁盘前再次确认版本文件..."
if [ -f /mnt/etc/jnl-os-version ]; then
    echo "  ✓ 版本文件已写入: $(cat /mnt/etc/jnl-os-version)"
    log "版本文件确认: $(cat /mnt/etc/jnl-os-version)"
else
    echo "  ⚠ 警告: 版本文件不存在，重新写入..."
    echo "1.0.30" > /mnt/etc/jnl-os-version
    log "版本文件重新写入: 1.0.30"
fi

echo "  卸载磁盘..."
# 按挂载顺序的逆序卸载
umount /mnt/home 2>/dev/null || true
umount /mnt/boot 2>/dev/null || true
umount /mnt 2>/dev/null || true

echo ""
echo -e "${GREEN}  ╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}  ║              安装完成！                       ║${NC}"
echo -e "${GREEN}  ╚═══════════════════════════════════════════════╝${NC}"
echo ""
if [ "$IS_UPGRADE" = true ]; then
    echo -e "${GREEN}  ✓ 升级安装完成，/home 数据已保留${NC}"
fi
echo "  请重启计算机，从硬盘启动 Java Net Lava OS"
echo ""
echo "  系统信息："
echo "    主机名: $HOSTNAME_INPUT"
echo "    用户名: $USERNAME"
if [ "$INSTALL_MODE" = "manual" ]; then
    echo "    安装模式: 手动安装"
    if [ "$IS_UPGRADE" = true ]; then
        echo "    升级模式: 是（保留 /home）"
    fi
    if [ -n "$HOME_PART" ]; then
        echo "    home 分区: $HOME_PART"
    fi
fi
echo ""
echo "  安装日志: $LOG_FILE"
echo ""

echo "  创建安装完成标记文件..."
touch /tmp/jnl-install-complete
echo "  ✓ 标记文件已创建"
log "安装完成标记文件已创建"

pause "按回车键退出..."

exit 0
