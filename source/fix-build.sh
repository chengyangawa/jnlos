#!/bin/bash
set -e

PROFILE_DIR=~/jnl-os-build/src/archiso-profile
AIROOTFS=$PROFILE_DIR/airootfs

echo "=== Fix 1: SYSLINUX - Remove all Arch Linux elements ==="
rm -f $PROFILE_DIR/syslinux/splash.png

cat > $PROFILE_DIR/syslinux/syslinux.cfg << 'ENDCFG'
TIMEOUT 0
TOTALTIMEOUT 0
DEFAULT arch
LABEL arch
LINUX /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux-lts
INITRD /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux-lts.img
APPEND archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% plymouth.enable=0 systemd.show_status=1 loglevel=3 quiet
ENDCFG

cat > $PROFILE_DIR/syslinux/archiso_head.cfg << 'ENDCFG'
TIMEOUT 0
TOTALTIMEOUT 0
DEFAULT arch
ENDCFG

cat > $PROFILE_DIR/syslinux/archiso_sys.cfg << 'ENDCFG'
TIMEOUT 0
TOTALTIMEOUT 0
DEFAULT arch
LABEL arch
LINUX /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux-lts
INITRD /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux-lts.img
APPEND archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% plymouth.enable=0 systemd.show_status=1 loglevel=3 quiet
ENDCFG

cat > $PROFILE_DIR/syslinux/archiso_sys-linux.cfg << 'ENDCFG'
LABEL arch
LINUX /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux-lts
INITRD /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux-lts.img
APPEND archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% plymouth.enable=0 systemd.show_status=1 loglevel=3 quiet
ENDCFG

cat > $PROFILE_DIR/syslinux/archiso_tail.cfg << 'ENDCFG'
ENDCFG

echo "SYSLINUX fixed."

echo ""
echo "=== Fix 2: Version number - classic4.4 ==="

sed -i 's/classic4\.3-F/classic4.4/g' $AIROOTFS/root/customize_airootfs.sh
sed -i 's/classic4\.3/classic4.4/g' $AIROOTFS/root/customize_airootfs.sh
sed -i 's/classic4\.3-F/classic4.4/g' $AIROOTFS/etc/issue
sed -i 's/classic4\.3/classic4.4/g' $AIROOTFS/etc/issue
sed -i 's/classic4\.3-F/classic4.4/g' $AIROOTFS/etc/motd
sed -i 's/classic4\.3/classic4.4/g' $AIROOTFS/etc/motd

find $AIROOTFS/usr/bin -name '*.c' -exec sed -i 's/classic4\.[0-9][-A-Za-z]*/classic4.4/g' {} \;

echo 'VERSION_PHASE=classic' > ~/jnl-os-build/version
echo 'VERSION_MAJOR=4' >> ~/jnl-os-build/version
echo 'VERSION_MINOR=4' >> ~/jnl-os-build/version
echo 'VERSION_FULL=classic4.4' >> ~/jnl-os-build/version
echo 'VERSION_ISO=classic-4-4' >> ~/jnl-os-build/version

echo "Version fixed to classic4.4"

echo ""
echo "=== Fix 3: os.svg in splash screen ==="

OS_SVG="/mnt/g/FEPT/FEPT/A_industry code/Code/OS/Java Net Lava OS/os.svg"

cp "$OS_SVG" $AIROOTFS/usr/share/icons/jnl-os/OS.svg

mkdir -p $AIROOTFS/usr/share/plasma/look-and-feel/com.jnlos.desktop/contents/splash
cp "$OS_SVG" $AIROOTFS/usr/share/plasma/look-and-feel/com.jnlos.desktop/contents/splash/logo.svg

mkdir -p $AIROOTFS/usr/share/plasma/look-and-feel/JNL-OS/contents/splash
cp "$OS_SVG" $AIROOTFS/usr/share/plasma/look-and-feel/JNL-OS/contents/splash/logo.svg

# Rewrite Splash.qml for com.jnlos.desktop
cat > $AIROOTFS/usr/share/plasma/look-and-feel/com.jnlos.desktop/contents/splash/Splash.qml << 'ENDQML'
import QtQuick 2.15
import QtQuick.Window 2.15

Rectangle {
    id: root
    color: "#000000"
    anchors.fill: parent

    Column {
        id: centerBox
        anchors.centerIn: parent
        spacing: 20

        Image {
            id: logo
            source: "/usr/share/icons/jnl-os/OS.svg"
            anchors.horizontalCenter: parent.horizontalCenter
            width: 200
            height: 200
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 400
            sourceSize.height: 400
        }

        Text {
            id: sysName
            text: "Java Net Lava OS"
            color: "#ffffff"
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 36
            font.bold: true
        }

        Text {
            id: versionText
            text: "classic4.4"
            color: "#999999"
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 18
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 8
            anchors.topMargin: 40

            Rectangle {
                id: progressBg
                width: parent.width
                height: parent.height
                color: "#2a2a2a"
                radius: 4
            }

            Rectangle {
                id: progressFill
                width: 0
                height: parent.height
                color: "#ec1c24"
                radius: 4
            }
        }
    }

    Timer {
        id: progressTimer
        interval: 150
        running: true
        repeat: true
        property real progress: 0

        onTriggered: {
            progress += 0.8
            if (progress > 95) progress = 95
            progressFill.width = (progress / 100) * 300
        }
    }
}
ENDQML

# Also rewrite JNL-OS Splash.qml
cat > $AIROOTFS/usr/share/plasma/look-and-feel/JNL-OS/contents/splash/Splash.qml << 'ENDQML'
import QtQuick 2.15
import QtQuick.Window 2.15

Rectangle {
    id: root
    color: "#000000"
    anchors.fill: parent

    Column {
        id: centerBox
        anchors.centerIn: parent
        spacing: 20

        Image {
            id: logo
            source: "/usr/share/icons/jnl-os/OS.svg"
            anchors.horizontalCenter: parent.horizontalCenter
            width: 200
            height: 200
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 400
            sourceSize.height: 400
        }

        Text {
            id: sysName
            text: "Java Net Lava OS"
            color: "#ffffff"
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 36
            font.bold: true
        }

        Text {
            id: versionText
            text: "classic4.4"
            color: "#999999"
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 18
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 8
            anchors.topMargin: 40

            Rectangle {
                id: progressBg
                width: parent.width
                height: parent.height
                color: "#2a2a2a"
                radius: 4
            }

            Rectangle {
                id: progressFill
                width: 0
                height: parent.height
                color: "#ec1c24"
                radius: 4
            }
        }
    }

    Timer {
        id: progressTimer
        interval: 150
        running: true
        repeat: true
        property real progress: 0

        onTriggered: {
            progress += 0.8
            if (progress > 95) progress = 95
            progressFill.width = (progress / 100) * 300
        }
    }
}
ENDQML

# Fix customize_airootfs.sh - replace the entire splash section
# Use python to do the replacement
python3 << 'PYEOF'
import re
import os

filepath = os.path.expanduser("~/jnl-os-build/src/archiso-profile/airootfs/root/customize_airootfs.sh")
with open(filepath, 'r') as f:
    content = f.read()

# Replace all classic4.3-F and classic4.3 with classic4.4
content = content.replace('classic4.3-F', 'classic4.4')
content = content.replace('classic4.3', 'classic4.4')

# Replace logo.svg path with absolute path
content = content.replace('source: "logo.svg"', 'source: "/usr/share/icons/jnl-os/OS.svg"')

with open(filepath, 'w') as f:
    f.write(content)

print("customize_airootfs.sh patched")
PYEOF

echo ""
echo "=== All fixes applied ==="
echo "Verification:"
echo "SYSLINUX splash.png exists: $(test -f $PROFILE_DIR/syslinux/splash.png && echo YES || echo NO)"
echo "classic4.3 count in customize.sh: $(grep -c 'classic4.3' $AIROOTFS/root/customize_airootfs.sh)"
echo "classic4.4 count in customize.sh: $(grep -c 'classic4.4' $AIROOTFS/root/customize_airootfs.sh)"
echo "OS.svg exists: $(test -f $AIROOTFS/usr/share/icons/jnl-os/OS.svg && echo YES || echo NO)"
echo "Splash logo.svg exists: $(test -f $AIROOTFS/usr/share/plasma/look-and-feel/com.jnlos.desktop/contents/splash/logo.svg && echo YES || echo NO)"
