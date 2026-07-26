#!/usr/bin/env bash
# Java Net Lava OS archiso profile定义
# shellcheck disable=SC2034

iso_name="jnl-os"
iso_label="JNL_OS_$(date +%Y%m)"
iso_publisher="Java Net Lava OS <https://jnl-os.local>"
iso_application="Java Net Lava OS Live/Install ISO"
if [ -f "$(dirname "${BASH_SOURCE[0]}")/../version" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../version"
    iso_version="$VERSION_FULL"
else
    iso_version="1.0.28"
fi
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
architectures=('x86_64')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'lz4' '-b' '1M')
file_permissions=(
  ['/etc/shadow']='0:0:400'
  ['/root']='0:0:750'
  ['/root/customize_airootfs.sh']='0:0:755'
)
