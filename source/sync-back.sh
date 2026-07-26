#!/bin/bash
set -e

WIN_DIR="/mnt/g/FEPT/FEPT/A_industry code/Code/OS/Java Net Lava OS"
SRC_DIR=~/jnl-os-build/src

echo "Syncing fixed files back to Windows..."

# syslinux
cp -r "$SRC_DIR/archiso-profile/syslinux/syslinux.cfg" "$WIN_DIR/src/archiso-profile/syslinux/"
cp -r "$SRC_DIR/archiso-profile/syslinux/archiso_head.cfg" "$WIN_DIR/src/archiso-profile/syslinux/"
cp -r "$SRC_DIR/archiso-profile/syslinux/archiso_sys.cfg" "$WIN_DIR/src/archiso-profile/syslinux/"
cp -r "$SRC_DIR/archiso-profile/syslinux/archiso_sys-linux.cfg" "$WIN_DIR/src/archiso-profile/syslinux/"
cp -r "$SRC_DIR/archiso-profile/syslinux/archiso_tail.cfg" "$WIN_DIR/src/archiso-profile/syslinux/"
rm -f "$WIN_DIR/src/archiso-profile/syslinux/splash.png"
echo "  syslinux: done"

# customize_airootfs.sh
cp "$SRC_DIR/archiso-profile/airootfs/root/customize_airootfs.sh" "$WIN_DIR/src/archiso-profile/airootfs/root/"
echo "  customize_airootfs.sh: done"

# issue/motd
cp "$SRC_DIR/archiso-profile/airootfs/etc/issue" "$WIN_DIR/src/archiso-profile/airootfs/etc/"
cp "$SRC_DIR/archiso-profile/airootfs/etc/motd" "$WIN_DIR/src/archiso-profile/airootfs/etc/"
echo "  issue/motd: done"

# Splash.qml
mkdir -p "$WIN_DIR/src/archiso-profile/airootfs/usr/share/plasma/look-and-feel/com.jnlos.desktop/contents/splash"
cp "$SRC_DIR/archiso-profile/airootfs/usr/share/plasma/look-and-feel/com.jnlos.desktop/contents/splash/Splash.qml" "$WIN_DIR/src/archiso-profile/airootfs/usr/share/plasma/look-and-feel/com.jnlos.desktop/contents/splash/"
cp "$SRC_DIR/archiso-profile/airootfs/usr/share/plasma/look-and-feel/com.jnlos.desktop/contents/splash/logo.svg" "$WIN_DIR/src/archiso-profile/airootfs/usr/share/plasma/look-and-feel/com.jnlos.desktop/contents/splash/"

mkdir -p "$WIN_DIR/src/archiso-profile/airootfs/usr/share/plasma/look-and-feel/JNL-OS/contents/splash"
cp "$SRC_DIR/archiso-profile/airootfs/usr/share/plasma/look-and-feel/JNL-OS/contents/splash/Splash.qml" "$WIN_DIR/src/archiso-profile/airootfs/usr/share/plasma/look-and-feel/JNL-OS/contents/splash/"
cp "$SRC_DIR/archiso-profile/airootfs/usr/share/plasma/look-and-feel/JNL-OS/contents/splash/logo.svg" "$WIN_DIR/src/archiso-profile/airootfs/usr/share/plasma/look-and-feel/JNL-OS/contents/splash/"
echo "  Splash.qml: done"

# OS.svg
cp "$SRC_DIR/archiso-profile/airootfs/usr/share/icons/jnl-os/OS.svg" "$WIN_DIR/src/archiso-profile/airootfs/usr/share/icons/jnl-os/"
echo "  OS.svg: done"

echo ""
echo "All files synced back to Windows successfully!"
