#!/bin/bash
set -e

PROFILE_DIR=~/jnl-os-build/src/archiso-profile
AIROOTFS=$PROFILE_DIR/airootfs
WIN_DIR="/mnt/g/FEPT/FEPT/A_industry code/Code/OS/Java Net Lava OS"

echo "========================================="
echo "  Java Net Lava OS 综合修复脚本"
echo "========================================="

# ============================================================================
# Fix 1: 安装脚本 - 修复安装后不从本地系统启动的问题
# ============================================================================
echo ""
echo "[1/4] 修复安装脚本 - 确保从本地磁盘启动..."

cat > $AIROOTFS/usr/bin/install-jnl-os.sh << 'INSTALL_EOF'
#!/usr/bin/env bash

# 自动检测 root 权限
if [ "$(id -u)" -ne 0 ]; then
    if command -v pkexec >/dev/null 2>&1; then
        exec pkexec "$0" "$@"
    elif command -v sudo >/dev/null 2>&1; then
        exec sudo "$0" "$@"
    else
        echo "错误：需要 root 权限运行此脚本。"
        read -p "按回车键退出..."
        exit 1
    fi
fi

clear
echo "========================================="
echo "     Java Net Lava OS 安装程序"
echo "========================================="
echo

LOG_FILE="/tmp/jnl-install.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查是否在 Live 环境中运行
if [ ! -d /run/archiso ]; then
    echo -e "${RED}错误：此安装程序只能在 Live 环境中运行！${NC}"
    read -p "按回车键退出..."
    exit 1
fi

# 安装必要工具
echo -e "${YELLOW}[1/8] 安装必要工具...${NC}"
pacman -S --noconfirm --needed parted e2fsprogs dosfstools grub efibootmgr os-prober mtools rsync 2>/dev/null || true
echo -e "${GREEN}  ✓ 工具安装完成${NC}"

# 列出可用磁盘并让用户选择
echo -e "${YELLOW}[2/8] 选择目标磁盘${NC}"
echo
echo "可用磁盘列表:"
echo "----------------------------------------"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MODEL | grep -E "^sd|^nvme|^vd"
echo "----------------------------------------"
echo

while true; do
    read -p "请输入目标磁盘（如 /dev/sda）: " DISK
    if [ -b "$DISK" ]; then
        break
    else
        echo -e "${RED}错误：磁盘 $DISK 不存在！${NC}"
    fi
done

# 确认磁盘信息
echo
echo "目标磁盘信息:"
lsblk "$DISK"
echo
read -p "确认要在 $DISK 上安装系统？这将清除所有数据！(y/N) " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "安装已取消"
    exit 0
fi

# 检查磁盘空间
DISK_SIZE=$(blockdev --getsize64 "$DISK" 2>/dev/null || echo 0)
DISK_SIZE_GB=$((DISK_SIZE / 1024 / 1024 / 1024))
if [ "$DISK_SIZE_GB" -lt 20 ]; then
    echo -e "${RED}错误：磁盘大小不足 20GB（当前 ${DISK_SIZE_GB}GB）！${NC}"
    read -p "按回车键退出..."
    exit 1
fi

# 创建分区
echo -e "${YELLOW}[3/8] 创建分区...${NC}"
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB 512MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 512MiB 100%

# 检测分区名称
if [[ "$DISK" == /dev/nvme* ]] || [[ "$DISK" == /dev/mmcblk* ]]; then
    ESP="${DISK}p1"
    ROOT="${DISK}p2"
else
    ESP="${DISK}1"
    ROOT="${DISK}2"
fi

echo "  EFI 分区: $ESP"
echo "  根分区: $ROOT"

# 创建文件系统
echo -e "${YELLOW}[4/8] 创建文件系统...${NC}"
mkfs.fat -F 32 "$ESP" 2>/dev/null
mkfs.ext4 -F "$ROOT" 2>/dev/null
echo -e "${GREEN}  ✓ 文件系统创建完成${NC}"

# 挂载磁盘
echo -e "${YELLOW}[5/8] 挂载磁盘...${NC}"
mkdir -p /mnt
mount "$ROOT" /mnt
mkdir -p /mnt/boot
mount "$ESP" /mnt/boot

echo "目标磁盘已挂载:"
df -h /mnt

# 复制系统文件
echo -e "${YELLOW}[6/8] 复制系统文件到目标磁盘...${NC}"
echo "  这可能需要几分钟，请耐心等待..."

rsync -aAXv \
    --exclude=/dev/* \
    --exclude=/proc/* \
    --exclude=/sys/* \
    --exclude=/tmp/* \
    --exclude=/run/* \
    --exclude=/mnt/* \
    --exclude=/media/* \
    --exclude=/lost+found \
    --exclude=/etc/fstab \
    --exclude=/etc/machine-id \
    / /mnt/ 2>&1 | tail -5

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ 系统文件复制完成${NC}"
else
    echo -e "${RED}  ✗ 系统文件复制失败！${NC}"
    read -p "按回车键退出..."
    exit 1
fi

# 创建必要的目录
mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/run /mnt/tmp
chmod 1777 /mnt/tmp

# 生成 fstab
echo -e "${YELLOW}[7/8] 配置系统...${NC}"
echo "  生成 fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# 重新生成 machine-id
rm -f /mnt/etc/machine-id
systemd-firstboot --root=/mnt --setup-machine-id 2>/dev/null || true

# 配置系统（arch-chroot 内执行）
arch-chroot /mnt /bin/bash << 'EOF_CHROOT'

# 设置时区
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc

# 设置 locale
sed -i 's/^#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen 2>/dev/null || true
echo "LANG=zh_CN.UTF-8" > /etc/locale.conf

# 设置 hostname
echo "jnl-os" > /etc/hostname
cat > /etc/hosts << 'EOF_HOSTS'
127.0.0.1 localhost
::1       localhost
127.0.1.1 jnl-os.localdomain jnl-os
EOF_HOSTS

# 确保 root 密码
echo "root:root" | chpasswd

# 确保用户 jnluser 存在
if ! id -u jnluser &>/dev/null; then
    useradd -m -G wheel,audio,video,storage,optical,network -s /bin/bash jnluser
    echo "jnluser:jnlos" | chpasswd
fi

# 配置 sudo
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# 安装 GRUB 引导
echo "  安装 GRUB 引导..."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=JNL-OS --removable --no-nvram 2>/dev/null
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=JNL-OS 2>/dev/null
grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null

# 同时安装到 EFI 默认路径（确保兼容性）
mkdir -p /boot/EFI/BOOT
cp /boot/EFI/JNL-OS/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI 2>/dev/null || true

# 设置 EFI 启动项为第一优先（使用 efibootmgr）
if command -v efibootmgr >/dev/null 2>&1; then
    # 获取当前所有启动项
    CURRENT_BOOT=$(efibootmgr 2>/dev/null | grep "BootOrder" | awk -F: '{print $2}' | tr -d ' ')
    JNL_BOOT=$(efibootmgr 2>/dev/null | grep "JNL-OS" | head -1 | awk -F'*' '{print $1}' | tr -d ' ')
    
    if [ -n "$JNL_BOOT" ]; then
        # 将 JNL-OS 设为启动项的第一位
        NEW_ORDER="${JNL_BOOT}"
        # 保留其他启动项（排除 JNL-OS 避免重复）
        for item in $(echo "$CURRENT_BOOT" | tr ',' '\n'); do
            if [ "$item" != "$JNL_BOOT" ]; then
                NEW_ORDER="${NEW_ORDER},${item}"
            fi
        done
        efibootmgr -o "$NEW_ORDER" 2>/dev/null || true
        echo "  EFI 启动顺序已设置：JNL-OS 优先"
    fi
fi

# 启用所有必要的服务
systemctl enable sddm 2>/dev/null || true
systemctl enable NetworkManager 2>/dev/null || true
systemctl enable bluetooth 2>/dev/null || true
systemctl enable sshd 2>/dev/null || true
systemctl enable jnl-wifi-autoscan.service 2>/dev/null || true
systemctl enable wpa_supplicant 2>/dev/null || true
systemctl enable jnl-automount.service 2>/dev/null || true

# 禁用慢启动服务
systemctl disable ldconfig.service 2>/dev/null || true
systemctl disable man-db.service 2>/dev/null || true
systemctl disable updatedb.service 2>/dev/null || true
systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
systemctl disable reflector.service 2>/dev/null || true

# 设置默认启动目标
systemctl set-default graphical.target 2>/dev/null || true

echo "  系统配置完成"

EOF_CHROOT

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ 系统配置完成${NC}"
else
    echo -e "${RED}  ✗ 系统配置失败！${NC}"
    read -p "按回车键退出..."
    exit 1
fi

# 卸载磁盘
echo -e "${YELLOW}[8/8] 卸载磁盘...${NC}"
sync
umount /mnt/boot
umount /mnt
echo -e "${GREEN}  ✓ 磁盘已卸载${NC}"

echo
echo "========================================="
echo "     安装完成！"
echo "========================================="
echo -e "${GREEN}系统已成功安装到 $DISK${NC}"
echo
echo "请按以下步骤操作："
echo "  1. 移除安装介质（USB/ISO）"
echo "  2. 重启计算机"
echo "  3. 系统将自动从硬盘启动"
echo
echo "默认账号：jnluser / jnlos"
echo "root 密码：root"
echo
read -p "按回车键退出..."
INSTALL_EOF
chmod +x $AIROOTFS/usr/bin/install-jnl-os.sh
echo "  安装脚本已修复（GRUB双写+EFI启动顺序）"

# ============================================================================
# Fix 2: 启动时自动挂载所有磁盘 + 按大小优先扫描系统
# ============================================================================
echo ""
echo "[2/4] 创建自动挂载服务..."

cat > $AIROOTFS/usr/bin/jnl-automount << 'MOUNT_EOF'
#!/bin/bash
# JNL OS 自动挂载所有磁盘
# 策略：按磁盘大小从大到小扫描，自动挂载所有分区

MOUNT_BASE="/media"
LOCK_FILE="/run/jnl-automount.lock"

# 防止重复运行
if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -d "/proc/$OLD_PID" ] 2>/dev/null; then
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"

# 等待 udev 稳定
sleep 2

log() {
    echo "[JNL-AutoMount] $1"
}

# 获取所有块设备分区，按大小从大到小排序
get_partitions() {
    lsblk -nlo NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE -b | \
        awk '$5=="part" && $4=="" && $3!="" {print $1, $2, $3}' | \
        sort -k2 -nr
}

# 挂载单个分区
mount_partition() {
    local devname="$1"
    local size="$2"
    local fstype="$3"
    local device="/dev/$devname"
    
    # 跳过已挂载的
    if findmnt "$device" >/dev/null 2>&1; then
        return 0
    fi
    
    # 跳过 swap
    if [ "$fstype" = "swap" ]; then
        return 0
    fi
    
    # 跳过 LVM 等特殊设备
    if [ "$fstype" = "LVM2_member" ] || [ "$fstype" = "crypto_LUKS" ]; then
        return 0
    fi
    
    # 生成挂载点名称
    local label=$(lsblk -no LABEL "$device" 2>/dev/null | tr -d ' ')
    local uuid=$(lsblk -no UUID "$device" 2>/dev/null | head -c 8)
    
    if [ -n "$label" ]; then
        mountpoint="$MOUNT_BASE/$label"
    else
        local size_gb=$((size / 1024 / 1024 / 1024))
        mountpoint="$MOUNT_BASE/${devname}_${size_gb}GB"
    fi
    
    # 确保挂载点唯一
    if [ -d "$mountpoint" ] && mountpoint -q "$mountpoint" 2>/dev/null; then
        mountpoint="${mountpoint}_${uuid}"
    fi
    
    mkdir -p "$mountpoint"
    
    # 根据文件系统类型选择挂载选项
    local options="rw,noatime"
    case "$fstype" in
        vfat|fat32|ntfs|ntfs-3g)
            options="rw,noatime,uid=1000,gid=1000,umask=022,exec"
            ;;
        ext4|btrfs|xfs|f2fs)
            options="rw,noatime"
            ;;
    esac
    
    # 尝试挂载
    if mount -o "$options" "$device" "$mountpoint" 2>/dev/null; then
        log "已挂载 $device ($fstype) -> $mountpoint"
    else
        # 尝试用 ntfs-3g 挂载 NTFS
        if [ "$fstype" = "ntfs" ] && command -v mount.ntfs-3g >/dev/null 2>&1; then
            mount.ntfs-3g -o "$options" "$device" "$mountpoint" 2>/dev/null && \
                log "已挂载 $device (ntfs-3g) -> $mountpoint" && return 0
        fi
        rmdir "$mountpoint" 2>/dev/null
        log "挂载失败: $device"
    fi
}

log "开始自动挂载磁盘..."

# 按大小从大到小扫描并挂载
get_partitions | while read devname size fstype; do
    mount_partition "$devname" "$size" "$fstype"
done

log "自动挂载完成"

# 清理锁文件
rm -f "$LOCK_FILE"
MOUNT_EOF
chmod +x $AIROOTFS/usr/bin/jnl-automount

# 创建 systemd 服务
cat > $AIROOTFS/etc/systemd/system/jnl-automount.service << 'SERVICE_EOF'
[Unit]
Description=JNL OS Auto Mount All Disks
After=local-fs.target
Wants=local-fs.target
After=udisks2.service

[Service]
Type=oneshot
ExecStart=/usr/bin/jnl-automount
RemainAfterExit=yes
TimeoutSec=30

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# 启用自动挂载服务
ln -sf /etc/systemd/system/jnl-automount.service $AIROOTFS/etc/systemd/system/multi-user.target.wants/jnl-automount.service 2>/dev/null || true

echo "  自动挂载服务已创建（按大小优先挂载）"

# ============================================================================
# Fix 3: 设置中增加磁盘管理
# ============================================================================
echo ""
echo "[3/4] 添加磁盘管理到系统设置..."

# 创建磁盘管理桌面入口（系统设置可见）
cat > $AIROOTFS/usr/share/applications/jnl-disk-manager.desktop << 'DISK_EOF'
[Desktop Entry]
Name=磁盘管理
GenericName=磁盘管理
Comment=分区和格式化磁盘
Exec=kdesu gparted
Icon=/usr/share/icons/jnl-os/OS.svg
Terminal=false
Type=Application
Categories=System;Settings;DiskManagement;
Keywords=disk;partition;format;gparted;
OnlyShowIn=KDE;
DISK_EOF

# 创建 KDE 系统设置中的磁盘管理 KCM 入口
cat > $AIROOTFS/usr/share/kservices6/jnl-disk-manager.desktop << 'KCM_EOF'
[Desktop Entry]
Name=磁盘管理
Comment=分区和格式化磁盘
Icon=/usr/share/icons/jnl-os/OS.svg
Type=Service
X-KDE-ServiceTypes=KCModule
X-KDE-Library=jnl-system-info-launcher
X-KDE-ParentApp=kcontrol
X-KDE-System-Settings-Parent-Category=system-administration
X-KDE-Weight=70
Exec=kdesu gparted
KCM_EOF

# 在桌面也创建一个磁盘管理快捷方式
cat > $AIROOTFS/home/jnluser/Desktop/jnl-disk-manager.desktop << 'DESKTOP_EOF'
[Desktop Entry]
Name=磁盘管理
Comment=分区和格式化磁盘
Exec=kdesu gparted
Icon=/usr/share/icons/jnl-os/OS.svg
Terminal=false
Type=Application
Categories=System;Settings;
DESKTOP_EOF
chown 1000:1000 $AIROOTFS/home/jnluser/Desktop/jnl-disk-manager.desktop 2>/dev/null || true
chmod +x $AIROOTFS/home/jnluser/Desktop/jnl-disk-manager.desktop 2>/dev/null || true

echo "  磁盘管理已添加到系统设置和桌面"

# ============================================================================
# Fix 4: 修复 WiFi 自动扫描
# ============================================================================
echo ""
echo "[4/4] 修复 WiFi 自动扫描..."

# 重写 WiFi 自动扫描服务 - 改为简单可靠的方式
cat > $AIROOTFS/etc/systemd/system/jnl-wifi-autoscan.service << 'WIFI_SVC_EOF'
[Unit]
Description=JNL OS Wi-Fi Auto Scan
After=NetworkManager.service
Wants=NetworkManager.service

[Service]
Type=oneshot
ExecStartPre=/usr/bin/sleep 8
ExecStart=/usr/bin/nmcli device wifi rescan
RemainAfterExit=yes
TimeoutSec=20

[Install]
WantedBy=graphical.target
WIFI_SVC_EOF

# 重写 WiFi 扫描脚本 - 增强可靠性
cat > $AIROOTFS/usr/bin/jnl-wifi-scan << 'WIFI_SCRIPT_EOF'
#!/bin/bash
# JNL OS Wi-Fi 自动扫描和连接工具

# 确保 NetworkManager 正在运行
if ! systemctl is-active NetworkManager >/dev/null 2>&1; then
    sudo systemctl start NetworkManager 2>/dev/null || true
    sleep 3
fi

case "$1" in
    --scan|scan)
        echo "正在扫描 Wi-Fi 网络..."
        nmcli device wifi rescan 2>/dev/null
        sleep 3
        echo ""
        echo "可用 Wi-Fi 网络:"
        echo "-----------------------------------"
        nmcli -t -f SSID,SIGNAL,SECURITY,BARS device wifi list 2>/dev/null | sort -t: -k2 -nr | while IFS=: read -r ssid signal security bars; do
            if [ -n "$ssid" ]; then
                printf "%-30s %s (%d%%) %s\n" "$ssid" "$bars" "$signal" "$security"
            fi
        done
        echo "-----------------------------------"
        echo "使用: jnl-wifi-scan connect <SSID> [密码]"
        ;;
    --connect|connect)
        if [ -z "$2" ]; then
            echo "用法: jnl-wifi-scan connect <SSID> [密码]"
            exit 1
        fi
        SSID="$2"
        PASSWORD="$3"
        if [ -n "$PASSWORD" ]; then
            nmcli device wifi connect "$SSID" password "$PASSWORD" 2>/dev/null
        else
            nmcli device wifi connect "$SSID" 2>/dev/null
        fi
        if [ $? -eq 0 ]; then
            echo "✓ 已连接到 $SSID"
        else
            echo "✗ 连接失败，请检查密码"
        fi
        ;;
    --status|status)
        nmcli device status
        echo ""
        nmcli connection show --active
        ;;
    --auto|auto)
        echo "正在自动扫描 Wi-Fi..."
        nmcli device wifi rescan 2>/dev/null
        sleep 3
        # 尝试自动连接已保存的网络
        nmcli connection show 2>/dev/null | grep -v "NAME" | while read -r name type device; do
            if [ "$type" = "802-11-wireless" ]; then
                nmcli connection up "$name" 2>/dev/null && echo "✓ 已连接到 $name" && break
            fi
        done
        echo "Wi-Fi 自动连接完成"
        ;;
    --list|list)
        # 简单列表模式
        nmcli device wifi list
        ;;
    *)
        echo "JNL OS Wi-Fi 工具"
        echo "用法:"
        echo "  jnl-wifi-scan scan          扫描可用 Wi-Fi"
        echo "  jnl-wifi-scan connect SSID  连接到 Wi-Fi"
        echo "  jnl-wifi-scan status        查看网络状态"
        echo "  jnl-wifi-scan auto          自动扫描并连接"
        echo "  jnl-wifi-scan list          列表显示 Wi-Fi"
        ;;
esac
WIFI_SCRIPT_EOF
chmod +x $AIROOTFS/usr/bin/jnl-wifi-scan

# 重写用户级自动扫描 - 使用 nm-applet 在系统托盘显示WiFi
cat > $AIROOTFS/home/jnluser/.config/autostart/jnl-wifi-autoscan.desktop << 'AUTOSTART_EOF'
[Desktop Entry]
Type=Application
Name=Wi-Fi Auto Scan
Comment=自动扫描并连接 Wi-Fi 网络
Exec=sh -c "sleep 5 && nmcli device wifi rescan 2>/dev/null && nm-applet --indicator 2>/dev/null &"
Terminal=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=plasma-shell
AUTOSTART_EOF
chown 1000:1000 $AIROOTFS/home/jnluser/.config/autostart/jnl-wifi-autoscan.desktop 2>/dev/null || true

# 启用 WiFi 服务
ln -sf /etc/systemd/system/jnl-wifi-autoscan.service $AIROOTFS/etc/systemd/system/graphical.target.wants/jnl-wifi-autoscan.service 2>/dev/null || true

# 修改 NetworkManager 配置 - 更激进的扫描
cat > $AIROOTFS/etc/NetworkManager/NetworkManager.conf << 'NM_EOF'
[main]
plugins=keyfile

[device]
wifi.scan-rand-mac-address=no
wifi.scan-backoff-factor=1

[wifi]
scan-backoff-factor=1
powersave=2

[connection]
wifi.powersave=2

[connectivity]
uri=http://connectivity-check.ubuntu.com/
interval=300
NM_EOF

echo "  WiFi 自动扫描已修复（简化服务+nm-applet托盘）"

# ============================================================================
# 同步修改到 customize_airootfs.sh
# ============================================================================
echo ""
echo "同步修改到 customize_airootfs.sh..."

# 用 python3 替换 customize_airootfs.sh 中的相关段落
python3 << 'PYEOF'
import os, re

filepath = os.path.expanduser("~/jnl-os-build/src/archiso-profile/airootfs/root/customize_airootfs.sh")
with open(filepath, 'r') as f:
    content = f.read()

# 1. 替换 jnl-wifi-autoscan.service 段落
old_service = r"cat > /etc/systemd/system/jnl-wifi-autoscan\.service <<'EOF'[\s\S]*?EOF"
new_service = """cat > /etc/systemd/system/jnl-wifi-autoscan.service <<'EOF'
[Unit]
Description=JNL OS Wi-Fi Auto Scan
After=NetworkManager.service
Wants=NetworkManager.service

[Service]
Type=oneshot
ExecStartPre=/usr/bin/sleep 8
ExecStart=/usr/bin/nmcli device wifi rescan
RemainAfterExit=yes
TimeoutSec=20

[Install]
WantedBy=graphical.target
EOF"""
content = re.sub(old_service, new_service, content)

# 2. 替换 autostart desktop 段落
old_autostart = r"cat > /home/jnluser/\.config/autostart/jnl-wifi-autoscan\.desktop <<'EOF'[\s\S]*?EOF"
new_autostart = """cat > /home/jnluser/.config/autostart/jnl-wifi-autoscan.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Wi-Fi Auto Scan
Comment=自动扫描并连接 Wi-Fi 网络
Exec=sh -c "sleep 5 && nmcli device wifi rescan 2>/dev/null && nm-applet --indicator 2>/dev/null &"
Terminal=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=plasma-shell
EOF"""
content = re.sub(old_autostart, new_autostart, content)

# 3. 替换 NetworkManager.conf 段落
old_nm = r"cat > /etc/NetworkManager/NetworkManager\.conf <<'EOF'[\s\S]*?EOF"
new_nm = """cat > /etc/NetworkManager/NetworkManager.conf <<'EOF'
[main]
plugins=keyfile

[device]
wifi.scan-rand-mac-address=no
wifi.scan-backoff-factor=1

[wifi]
scan-backoff-factor=1
powersave=2

[connection]
wifi.powersave=2

[connectivity]
uri=http://connectivity-check.ubuntu.com/
interval=300
EOF"""
content = re.sub(old_nm, new_nm, content)

# 4. 在 "9. 系统设置" 段落末尾添加磁盘管理和自动挂载
disk_section = '''
# 磁盘管理入口（系统设置 + 桌面）
echo "  添加磁盘管理..."
cat > /usr/share/applications/jnl-disk-manager.desktop <<'EOF'
[Desktop Entry]
Name=磁盘管理
GenericName=磁盘管理
Comment=分区和格式化磁盘
Exec=kdesu gparted
Icon=/usr/share/icons/jnl-os/OS.svg
Terminal=false
Type=Application
Categories=System;Settings;DiskManagement;
Keywords=disk;partition;format;
OnlyShowIn=KDE;
EOF

cat > /usr/share/kservices6/jnl-disk-manager.desktop <<'EOF'
[Desktop Entry]
Name=磁盘管理
Comment=分区和格式化磁盘
Icon=/usr/share/icons/jnl-os/OS.svg
Type=Service
X-KDE-ServiceTypes=KCModule
X-KDE-Library=jnl-system-info-launcher
X-KDE-ParentApp=kcontrol
X-KDE-System-Settings-Parent-Category=system-administration
X-KDE-Weight=70
Exec=kdesu gparted
EOF

cat > /home/jnluser/Desktop/jnl-disk-manager.desktop <<'EOF'
[Desktop Entry]
Name=磁盘管理
Comment=分区和格式化磁盘
Exec=kdesu gparted
Icon=/usr/share/icons/jnl-os/OS.svg
Terminal=false
Type=Application
Categories=System;Settings;
EOF
chown jnluser:jnluser /home/jnluser/Desktop/jnl-disk-manager.desktop
chmod +x /home/jnluser/Desktop/jnl-disk-manager.desktop

# 自动挂载所有磁盘服务
echo "  配置自动挂载..."
cat > /usr/bin/jnl-automount <<'MOUNTSCRIPT'
#!/bin/bash
# JNL OS 自动挂载所有磁盘 - 按大小优先

MOUNT_BASE="/media"
LOCK_FILE="/run/jnl-automount.lock"

if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -d "/proc/$OLD_PID" ] 2>/dev/null; then exit 0; fi
fi
echo $$ > "$LOCK_FILE"

sleep 2

# 获取所有未挂载分区，按大小从大到小排序
lsblk -nlo NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE -b 2>/dev/null | \\
    awk '$5=="part" && $4=="" && $3!="" && $3!="swap" && $3!="LVM2_member" && $3!="crypto_LUKS" {print $1, $2, $3}' | \\
    sort -k2 -nr | \\
    while read devname size fstype; do
        device="/dev/$devname"
        label=$(lsblk -no LABEL "$device" 2>/dev/null | tr -d ' ')
        uuid=$(lsblk -no UUID "$device" 2>/dev/null | head -c 8)
        
        if [ -n "$label" ]; then
            mp="$MOUNT_BASE/$label"
        else
            size_gb=$((size / 1024 / 1024 / 1024))
            mp="$MOUNT_BASE/${devname}_${size_gb}GB"
        fi
        
        [ -d "$mp" ] && mountpoint -q "$mp" 2>/dev/null && mp="${mp}_${uuid}"
        
        mkdir -p "$mp"
        
        case "$fstype" in
            vfat|fat32|ntfs)
                options="rw,noatime,uid=1000,gid=1000,umask=022,exec"
                ;;
            *)
                options="rw,noatime"
                ;;
        esac
        
        if mount -o "$options" "$device" "$mp" 2>/dev/null; then
            echo "[JNL-AutoMount] $device -> $mp"
        else
            [ "$fstype" = "ntfs" ] && mount.ntfs-3g -o "$options" "$device" "$mp" 2>/dev/null
            mountpoint -q "$mp" 2>/dev/null || rmdir "$mp" 2>/dev/null
        fi
    done

rm -f "$LOCK_FILE"
MOUNTSCRIPT
chmod +x /usr/bin/jnl-automount

cat > /etc/systemd/system/jnl-automount.service <<'EOF'
[Unit]
Description=JNL OS Auto Mount All Disks
After=local-fs.target udisks2.service

[Service]
Type=oneshot
ExecStart=/usr/bin/jnl-automount
RemainAfterExit=yes
TimeoutSec=30

[Install]
WantedBy=multi-user.target
EOF

systemctl enable jnl-automount.service 2>/dev/null || true

'''

# 在 "10. 性能优化" 之前插入
if "磁盘管理" not in content:
    content = content.replace(
        "# ============================================================================\n# 10. 性能优化",
        disk_section + "\n# ============================================================================\n# 10. 性能优化"
    )

with open(filepath, 'w') as f:
    f.write(content)

print("  customize_airootfs.sh 已更新")
PYEOF

echo ""
echo "========================================="
echo "  所有修复完成！"
echo "========================================="
echo ""
echo "验证："
echo "  安装脚本: $(head -1 $AIROOTFS/usr/bin/install-jnl-os.sh)"
echo "  自动挂载服务: $(test -f $AIROOTFS/etc/systemd/system/jnl-automount.service && echo YES || echo NO)"
echo "  磁盘管理: $(test -f $AIROOTFS/usr/share/applications/jnl-disk-manager.desktop && echo YES || echo NO)"
echo "  WiFi服务: $(test -f $AIROOTFS/etc/systemd/system/jnl-wifi-autoscan.service && echo YES || echo NO)"
