#!/bin/bash
set -e

PROFILE_DIR=~/jnl-os-build/src/archiso-profile
AIROOTFS=$PROFILE_DIR/airootfs
WIN_DIR="/mnt/g/FEPT/FEPT/A_industry code/Code/OS/Java Net Lava OS"

echo "=== Task 1: Sync new SVG files ==="

cp "$WIN_DIR/java_net_lava_os.svg" $AIROOTFS/usr/share/icons/jnl-os/java_net_lava_os.svg
cp "$WIN_DIR/os.svg" $AIROOTFS/usr/share/icons/jnl-os/OS.svg
echo "  java_net_lava_os.svg synced"
echo "  os.svg synced"

# Update splash logos
mkdir -p $AIROOTFS/usr/share/plasma/look-and-feel/com.jnlos.desktop/contents/splash
mkdir -p $AIROOTFS/usr/share/plasma/look-and-feel/JNL-OS/contents/splash
cp "$WIN_DIR/os.svg" $AIROOTFS/usr/share/plasma/look-and-feel/com.jnlos.desktop/contents/splash/logo.svg
cp "$WIN_DIR/os.svg" $AIROOTFS/usr/share/plasma/look-and-feel/JNL-OS/contents/splash/logo.svg
echo "  Splash logos updated"

echo ""
echo "=== Task 2: Disable Dolphin trash confirmation ==="

mkdir -p $AIROOTFS/home/jnluser/.local/share/kxmlgui5/dolphin
cat > $AIROOTFS/home/jnluser/.local/share/kxmlgui5/dolphin/dolphinui.rc << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<gui version="3">
  <ActionProperties>
    <Action name="trash">
      <Property name="AskConfirmation">false</Property>
    </Action>
  </ActionProperties>
</gui>
EOF

mkdir -p $AIROOTFS/home/jnluser/.config
cat > $AIROOTFS/home/jnluser/.config/dolphinrc << 'EOF'
[General]
ConfirmTrash=false
EOF

# Also set globally in customize_airootfs.sh
sed -i '/ConfirmTrash/d' $AIROOTFS/root/customize_airootfs.sh
echo "  Dolphin trash confirmation disabled"

echo ""
echo "=== Task 3: Clear build cache ==="

rm -rf ~/jnl-os-build/cache/* ~/jnl-os-build/build/* ~/jnl-os-build/out/* 2>/dev/null || true
rm -rf /tmp/jnl-work* /tmp/jnl-out* 2>/dev/null || true
echo "  Build cache cleared"

echo ""
echo "=== Task 4: Change version to 1.0.0-20260712 ==="

# Update version file
cat > ~/jnl-os-build/version << 'EOF'
VERSION_PHASE=release
VERSION_MAJOR=1
VERSION_MINOR=0
VERSION_PATCH=0
VERSION_DATE=20260712
VERSION_FULL=1.0.0-20260712
VERSION_ISO=1-0-0-20260712
EOF

# Update profiledef.sh
sed -i "s/iso_name=\"jnl-os-classic-4-4\"/iso_name=\"jnl-os-1-0-0-20260712\"/" $PROFILE_DIR/profiledef.sh
sed -i "s/iso_version=\"classic4.4\"/iso_version=\"1.0.0-20260712\"/" $PROFILE_DIR/profiledef.sh

# Update customize_airootfs.sh
sed -i 's/classic4\.4/1.0.0-20260712/g' $AIROOTFS/root/customize_airootfs.sh
sed -i "s/VERSION_ID=\"classic4\.4\"/VERSION_ID=\"1.0.0-20260712\"/" $AIROOTFS/root/customize_airootfs.sh

# Update issue and motd
sed -i 's/classic4\.4/1.0.0-20260712/g' $AIROOTFS/etc/issue
sed -i 's/classic4\.4/1.0.0-20260712/g' $AIROOTFS/etc/motd

# Update C source files
find $AIROOTFS/usr/bin -name '*.c' -exec sed -i 's/classic4\.[0-9][-A-Za-z]*/1.0.0-20260712/g' {} \;

# Update Splash.qml version text
sed -i 's/text: "classic4\.4"/text: "1.0.0-20260712"/g' $AIROOTFS/usr/share/plasma/look-and-feel/com.jnlos.desktop/contents/splash/Splash.qml
sed -i 's/text: "classic4\.4"/text: "1.0.0-20260712"/g' $AIROOTFS/usr/share/plasma/look-and-feel/JNL-OS/contents/splash/Splash.qml

echo "  Version updated to 1.0.0-20260712"

echo ""
echo "=== Verification ==="
echo "SVG files:"
ls -la $AIROOTFS/usr/share/icons/jnl-os/*.svg | head -5
echo ""
echo "Dolphin config:"
cat $AIROOTFS/home/jnluser/.config/dolphinrc
echo ""
echo "Version in customize.sh:"
grep '1.0.0-20260712' $AIROOTFS/root/customize_airootfs.sh | wc -l
echo ""
echo "Version file:"
cat ~/jnl-os-build/version

echo ""
echo "=== All tasks completed ==="
