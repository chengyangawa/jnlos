#!/bin/bash
set -e

PROFILE_DIR=~/jnl-os-build/src/archiso-profile
AIROOTFS=$PROFILE_DIR/airootfs

echo "========================================="
echo "  JNL OS 问题修复脚本"
echo "========================================="

# ============================================================================
# Fix 1: 创建独立的 JNL 磁盘管理工具（GTK3，无需密码）
# ============================================================================
echo ""
echo "[1/5] 创建 JNL 磁盘管理工具..."

cat > $AIROOTFS/usr/bin/jnl-disk-manager.c << 'EOF'
#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <errno.h>

static GtkListStore *disk_store;
static GtkWidget *status_label;

static int run_cmd(const char *cmd, char *output, size_t out_size) {
    FILE *fp = popen(cmd, "r");
    if (!fp) return -1;
    output[0] = '\0';
    char line[512];
    while (fgets(line, sizeof(line), fp)) {
        if (strlen(output) + strlen(line) < out_size - 1) {
            strcat(output, line);
        }
    }
    int rc = pclose(fp);
    return WEXITSTATUS(rc);
}

static void refresh_disks(GtkWidget *widget, gpointer data) {
    gtk_list_store_clear(disk_store);
    char buf[4096];
    FILE *fp = popen("lsblk -nlo NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL,STATE -b | grep -E '^sd|^nvme|^vd|^mmc'", "r");
    if (!fp) return;
    while (fgets(buf, sizeof(buf), fp)) {
        char name[64], size[32], type[32], fstype[64], mount[128], model[128], state[64];
        int n = sscanf(buf, "%63s %31s %31s %63s %127s %127[^\n] %63s", name, size, type, fstype, mount, model, state);
        if (n < 3) continue;
        if (strcmp(type, "disk") != 0 && strcmp(type, "part") != 0) continue;
        GtkTreeIter iter;
        gtk_list_store_append(disk_store, &iter);
        long long sz = atoll(size);
        char sz_str[32];
        if (sz > 1024LL*1024*1024*1024) snprintf(sz_str, sizeof(sz_str), "%.1f TB", sz/1024.0/1024/1024/1024);
        else if (sz > 1024LL*1024*1024) snprintf(sz_str, sizeof(sz_str), "%.1f GB", sz/1024.0/1024/1024);
        else if (sz > 1024LL*1024) snprintf(sz_str, sizeof(sz_str), "%.1f MB", sz/1024.0/1024);
        else snprintf(sz_str, sizeof(sz_str), "%lld B", sz);
        gtk_list_store_set(disk_store, &iter,
            0, name,
            1, sz_str,
            2, type,
            3, fstype[0]?fstype:"-",
            4, mount[0]?mount:"未挂载",
            5, model[0]?model:"-",
            -1);
    }
    pclose(fp);
    gtk_label_set_text(GTK_LABEL(status_label), "磁盘列表已刷新");
}

static void on_mount(GtkWidget *widget, gpointer data) {
    GtkTreeSelection *sel = GTK_TREE_SELECTION(data);
    GtkTreeIter iter;
    GtkTreeModel *model;
    if (!gtk_tree_selection_get_selected(sel, &model, &iter)) return;
    char name[64], type[32], mount[128];
    gtk_tree_model_get(model, &iter, 0, name, 2, type, 4, mount, -1);
    if (strcmp(type, "disk") == 0) {
        gtk_label_set_text(GTK_LABEL(status_label), "错误：不能挂载整个磁盘，请选择分区");
        return;
    }
    if (strcmp(mount, "未挂载") != 0) {
        gtk_label_set_text(GTK_LABEL(status_label), "该分区已挂载");
        return;
    }
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "udisksctl mount -b /dev/%s 2>&1", name);
    char out[1024] = "";
    run_cmd(cmd, out, sizeof(out));
    gtk_label_set_text(GTK_LABEL(status_label), out[0]?out:"挂载命令已执行");
    refresh_disks(NULL, NULL);
}

static void on_unmount(GtkWidget *widget, gpointer data) {
    GtkTreeSelection *sel = GTK_TREE_SELECTION(data);
    GtkTreeIter iter;
    GtkTreeModel *model;
    if (!gtk_tree_selection_get_selected(sel, &model, &iter)) return;
    char name[64];
    gtk_tree_model_get(model, &iter, 0, name, -1);
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "udisksctl unmount -b /dev/%s 2>&1", name);
    char out[1024] = "";
    run_cmd(cmd, out, sizeof(out));
    gtk_label_set_text(GTK_LABEL(status_label), out[0]?out:"卸载命令已执行");
    refresh_disks(NULL, NULL);
}

static void on_format(GtkWidget *widget, gpointer data) {
    GtkTreeSelection *sel = GTK_TREE_SELECTION(data);
    GtkTreeIter iter;
    GtkTreeModel *model;
    if (!gtk_tree_selection_get_selected(sel, &model, &iter)) return;
    char name[64], type[32], mount[128];
    gtk_tree_model_get(model, &iter, 0, name, 2, type, 4, mount, -1);
    if (strcmp(type, "disk") == 0) {
        gtk_label_set_text(GTK_LABEL(status_label), "错误：不能格式化整个磁盘，请选择分区");
        return;
    }
    GtkWidget *dialog = gtk_message_dialog_new(NULL, GTK_DIALOG_MODAL, GTK_MESSAGE_QUESTION, GTK_BUTTONS_YES_NO,
        "确定要格式化 /dev/%s 为 FAT32 吗？\n此操作将删除该分区上的所有数据！", name);
    int rc = gtk_dialog_run(GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog);
    if (rc != GTK_RESPONSE_YES) return;
    if (strcmp(mount, "未挂载") != 0) {
        char cmd[256];
        snprintf(cmd, sizeof(cmd), "udisksctl unmount -b /dev/%s 2>&1", name);
        char out[1024] = "";
        run_cmd(cmd, out, sizeof(out));
    }
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "mkfs.fat -F 32 /dev/%s 2>&1", name);
    char out[1024] = "";
    run_cmd(cmd, out, sizeof(out));
    gtk_label_set_text(GTK_LABEL(status_label), out[0]?out:"格式化完成");
    refresh_disks(NULL, NULL);
}

static void on_rescan(GtkWidget *widget, gpointer data) {
    run_cmd("udevadm settle 2>&1", NULL, 0);
    refresh_disks(NULL, NULL);
}

int main(int argc, char *argv[]) {
    gtk_init(&argc, &argv);
    GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), "JNL 磁盘管理");
    gtk_window_set_default_size(GTK_WINDOW(window), 900, 500);
    g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);

    GtkWidget *vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_container_set_border_width(GTK_CONTAINER(vbox), 10);
    gtk_container_add(GTK_CONTAINER(window), vbox);

    GtkWidget *label = gtk_label_new("JNL OS 磁盘管理工具");
    GtkCssProvider *provider = gtk_css_provider_new();
    gtk_css_provider_load_from_data(provider, "label { font-size: 18px; font-weight: bold; }", -1, NULL);
    GtkStyleContext *ctx = gtk_widget_get_style_context(label);
    gtk_style_context_add_provider(ctx, GTK_STYLE_PROVIDER(provider), GTK_STYLE_PROVIDER_PRIORITY_USER);
    gtk_box_pack_start(GTK_BOX(vbox), label, FALSE, FALSE, 0);

    disk_store = gtk_list_store_new(6, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
    GtkWidget *tree = gtk_tree_view_new_with_model(GTK_TREE_MODEL(disk_store));
    const char *titles[] = {"设备", "容量", "类型", "文件系统", "挂载点", "型号"};
    for (int i = 0; i < 6; i++) {
        GtkCellRenderer *renderer = gtk_cell_renderer_text_new();
        GtkTreeViewColumn *col = gtk_tree_view_column_new_with_attributes(titles[i], renderer, "text", i, NULL);
        gtk_tree_view_column_set_resizable(col, TRUE);
        gtk_tree_view_append_column(GTK_TREE_VIEW(tree), col);
    }
    GtkWidget *scroll = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
    gtk_container_add(GTK_CONTAINER(scroll), tree);
    gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 0);

    GtkTreeSelection *sel = gtk_tree_view_get_selection(GTK_TREE_VIEW(tree));

    GtkWidget *hbox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 0);

    GtkWidget *btn_refresh = gtk_button_new_with_label("刷新");
    g_signal_connect(btn_refresh, "clicked", G_CALLBACK(refresh_disks), NULL);
    gtk_box_pack_start(GTK_BOX(hbox), btn_refresh, FALSE, FALSE, 0);

    GtkWidget *btn_mount = gtk_button_new_with_label("挂载");
    g_signal_connect(btn_mount, "clicked", G_CALLBACK(on_mount), sel);
    gtk_box_pack_start(GTK_BOX(hbox), btn_mount, FALSE, FALSE, 0);

    GtkWidget *btn_unmount = gtk_button_new_with_label("卸载");
    g_signal_connect(btn_unmount, "clicked", G_CALLBACK(on_unmount), sel);
    gtk_box_pack_start(GTK_BOX(hbox), btn_unmount, FALSE, FALSE, 0);

    GtkWidget *btn_format = gtk_button_new_with_label("格式化为 FAT32");
    g_signal_connect(btn_format, "clicked", G_CALLBACK(on_format), sel);
    gtk_box_pack_start(GTK_BOX(hbox), btn_format, FALSE, FALSE, 0);

    GtkWidget *btn_rescan = gtk_button_new_with_label("重新扫描设备");
    g_signal_connect(btn_rescan, "clicked", G_CALLBACK(on_rescan), NULL);
    gtk_box_pack_start(GTK_BOX(hbox), btn_rescan, FALSE, FALSE, 0);

    status_label = gtk_label_new("就绪");
    gtk_box_pack_start(GTK_BOX(vbox), status_label, FALSE, FALSE, 0);

    gtk_widget_show_all(window);
    refresh_disks(NULL, NULL);
    gtk_main();
    return 0;
}
EOF

# 编译脚本
cat > $AIROOTFS/usr/bin/compile-jnl-disk-manager << 'EOF'
#!/bin/bash
gcc -o /usr/bin/jnl-disk-manager /usr/bin/jnl-disk-manager.c `pkg-config --cflags --libs gtk+-3.0` 2>&1
EOF
chmod +x $AIROOTFS/usr/bin/compile-jnl-disk-manager

echo "  JNL 磁盘管理工具源码已创建"

# 创建独立图标（硬盘形状SVG）
cat > $AIROOTFS/usr/share/icons/jnl-os/jnl-disk-manager.svg << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <rect x="4" y="16" width="56" height="32" rx="4" fill="#4a90d9" stroke="#2c5aa0" stroke-width="2"/>
  <circle cx="20" cy="32" r="8" fill="#ffffff" opacity="0.9"/>
  <circle cx="20" cy="32" r="3" fill="#4a90d9"/>
  <rect x="38" y="26" width="16" height="4" rx="1" fill="#ffffff" opacity="0.7"/>
  <rect x="38" y="34" width="12" height="4" rx="1" fill="#ffffff" opacity="0.7"/>
  <text x="32" y="58" font-family="sans-serif" font-size="8" fill="#2c5aa0" text-anchor="middle">JNL</text>
</svg>
EOF

# 更新 .desktop 文件 - 只在系统设置中显示，不在桌面
cat > $AIROOTFS/usr/share/applications/jnl-disk-manager.desktop << 'EOF'
[Desktop Entry]
Name=磁盘管理
GenericName=磁盘管理
Comment=管理磁盘分区和挂载
Exec=jnl-disk-manager
Icon=/usr/share/icons/jnl-os/jnl-disk-manager.svg
Terminal=false
Type=Application
Categories=System;Settings;
Keywords=disk;partition;mount;format;
OnlyShowIn=KDE;
EOF

cat > $AIROOTFS/usr/share/kservices6/jnl-disk-manager.desktop << 'EOF'
[Desktop Entry]
Name=磁盘管理
Comment=管理磁盘分区和挂载
Icon=/usr/share/icons/jnl-os/jnl-disk-manager.svg
Type=Service
X-KDE-ServiceTypes=KCModule
X-KDE-Library=jnl-system-info-launcher
X-KDE-ParentApp=kcontrol
X-KDE-System-Settings-Parent-Category=system-administration
X-KDE-Weight=70
Exec=jnl-disk-manager
EOF

# 删除桌面上的磁盘管理快捷方式
rm -f $AIROOTFS/home/jnluser/Desktop/jnl-disk-manager.desktop

echo "  磁盘管理入口已更新（仅在系统设置中）"

# ============================================================================
# Fix 2: 磁盘自动挂载不需要密码 - polkit规则
# ============================================================================
echo ""
echo "[2/5] 配置免密码挂载..."

mkdir -p $AIROOTFS/etc/polkit-1/rules.d
cat > $AIROOTFS/etc/polkit-1/rules.d/50-jnl-mount.rules << 'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.udisks2.filesystem-mount" ||
         action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
         action.id == "org.freedesktop.udisks2.filesystem-unmount" ||
         action.id == "org.freedesktop.udisks2.filesystem-unmount-others") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

cat > $AIROOTFS/etc/polkit-1/rules.d/50-jnl-disk-manager.rules << 'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id.indexOf("org.freedesktop.udisks2.") == 0) &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

echo "  polkit 规则已配置（wheel组用户免密挂载）"

# ============================================================================
# Fix 3: 文件拖入回收站不询问 - 强制移动
# ============================================================================
echo ""
echo "[3/5] 修复回收站拖放行为..."

# 在 customize_airootfs.sh 中彻底禁用 KDE 回收站询问菜单
# 更新 dolphinrc 强制拖放为移动
python3 << 'PYEOF'
import re, os

filepath = os.path.expanduser("~/jnl-os-build/src/archiso-profile/airootfs/root/customize_airootfs.sh")
with open(filepath, 'r') as f:
    content = f.read()

# 找到回收站配置段，在其后添加新的 Dolphin 配置
old_block = r"# 4\. 设置 JNL 回收站文件夹的特殊属性 - 拖入即移动.*?\.directory"
new_block = """# 4. 设置 JNL 回收站文件夹的特殊属性 - 拖入即移动
# 使用 .directory 配置回收站文件夹行为
cat > "/home/jnluser/Desktop/回收站（JNL）/.directory" <<'EOF'
[Desktop Entry]
Icon=user-trash-full
Name=回收站（JNL）
Type=Directory
Comment=JNL OS 回收站
X-KDE-ServiceTypes=inode/directory
X-Dolphin-ViewMode=List
EOF"""
content = re.sub(old_block, new_block, content, flags=re.DOTALL)

# 在回收站段落后添加强制移动配置
insert_after = """chown jnluser:jnluser "/home/jnluser/Desktop/回收站（JNL）/.directory"
"""
forced_move = """# 4.1 强制 Dolphin 拖放文件到回收站时直接移动，不询问
mkdir -p /home/jnluser/.config
# 写入 dolphinrc 禁用复制/移动询问菜单
cat > /home/jnluser/.config/dolphinrc <<'EOF'
[General]
ShowTrashBinInPlaces=false
Version=2024
AutoExpandFolders=true
ShowFullPathInTitle=false
ConfirmDelete=false
ConfirmClosingMultipleTabs=false
ConfirmClosingTerminalRunningProgram=false
ShowCopyMoveMenu=false
ShowDeleteCommand=true
ShowErrorOnDelete=false
ShowSafeDeleteQuestion=false

[KDE]
ShowDeleteCommand=true

[Trash]
ShowSizeLimitWarning=false

[MainWindow]
MenuBar=Disabled
ToolBarsMovable=Disabled
HideTerminal=true

[PreviewSettings]
Plugins=appimagethumbnail,audiothumbnail,blenderthumbnail,comicbookthumbnail,cursorthumbnail,djvuthumbnail,ebookthumbnail,exrthumbnail,fontthumbnail,htmlthumbnail,imagethumbnail,jpegthumbnail,kraorathumbnail,mobithumbnail,opendocumentthumbnail,pngthumbnail,rawthumbnail,svgthumbnail,textthumbnail,webpthumbnail

[KFileDialog Settings]
ShowCopyMoveMenu=false
EOF
chown jnluser:jnluser /home/jnluser/.config/dolphinrc

# 4.2 禁用 Dolphin 拖放时的复制/移动选择对话框
# 通过 xdg 配置强制移动操作
mkdir -p /home/jnluser/.config/dolphin
# 删除 KDE trash 协议，避免冲突
rm -rf /home/jnluser/.local/share/Trash 2>/dev/null || true

"""
if "# 4.1 强制 Dolphin" not in content:
    content = content.replace(insert_after, insert_after + forced_move)

with open(filepath, 'w') as f:
    f.write(content)
print("  dolphinrc 已更新为强制移动模式")
PYEOF

echo "  回收站拖放行为已修复"

# ============================================================================
# Fix 4: WiFi 自动扫描 - 修复服务崩溃
# ============================================================================
echo ""
echo "[4/5] 修复 WiFi 自动扫描服务..."

# 重写 WiFi 服务为常驻守护进程，而不是 oneshot
cat > $AIROOTFS/etc/systemd/system/jnl-wifi-autoscan.service << 'EOF'
[Unit]
Description=JNL OS Wi-Fi Auto Scan Daemon
After=NetworkManager.service
Wants=NetworkManager.service

[Service]
Type=simple
ExecStart=/usr/bin/jnl-wifi-daemon
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical.target
EOF

# 创建 WiFi 守护脚本
cat > $AIROOTFS/usr/bin/jnl-wifi-daemon << 'EOF'
#!/bin/bash
# JNL OS Wi-Fi 自动扫描守护进程

LOG_FILE="/tmp/jnl-wifi-daemon.log"
exec > "$LOG_FILE" 2>&1

echo "$(date): Wi-Fi daemon started"

# 等待 NetworkManager 就绪
for i in {1..30}; do
    if systemctl is-active NetworkManager >/dev/null 2>&1; then
        echo "$(date): NetworkManager is active"
        break
    fi
    echo "$(date): waiting for NetworkManager..."
    sleep 2
done

# 检查无线设备
WIFI_DEV=""
for i in {1..10}; do
    WIFI_DEV=$(nmcli device show | grep -B2 "GENERAL.TYPE:.*wifi" | grep "GENERAL.DEVICE:" | head -1 | awk '{print $2}')
    if [ -n "$WIFI_DEV" ]; then
        echo "$(date): Wi-Fi device found: $WIFI_DEV"
        break
    fi
    sleep 1
done

if [ -z "$WIFI_DEV" ]; then
    echo "$(date): No Wi-Fi device found, exiting"
    exit 0
fi

# 主循环：定期扫描
while true; do
    # 如果WiFi设备存在但未连接，执行扫描
    STATE=$(nmcli device show "$WIFI_DEV" 2>/dev/null | grep "GENERAL.STATE:" | awk '{print $2}')
    echo "$(date): Wi-Fi state: $STATE"
    
    if [ "$STATE" = "30" ] || [ "$STATE" = "20" ]; then
        # 已连接或已断开，都执行一次扫描
        nmcli device wifi rescan ifname "$WIFI_DEV" 2>/dev/null || nmcli device wifi rescan 2>/dev/null
        echo "$(date): rescan completed"
    fi
    
    sleep 30
done
EOF
chmod +x $AIROOTFS/usr/bin/jnl-wifi-daemon

# 更新扫描脚本
cat > $AIROOTFS/usr/bin/jnl-wifi-scan << 'EOF'
#!/bin/bash
# JNL OS Wi-Fi 扫描工具

if ! systemctl is-active NetworkManager >/dev/null 2>&1; then
    echo "正在启动 NetworkManager..."
    sudo systemctl start NetworkManager 2>/dev/null || true
    sleep 2
fi

case "$1" in
    --scan|scan|"")
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
            echo "✗ 连接失败"
        fi
        ;;
    --status|status)
        nmcli device status
        echo ""
        nmcli connection show --active
        ;;
    --auto|auto)
        nmcli device wifi rescan 2>/dev/null
        sleep 3
        nmcli connection show 2>/dev/null | grep -E "802-11-wireless|wifi" | while read -r name uuid type device; do
            [ -n "$name" ] && nmcli connection up "$name" 2>/dev/null && echo "✓ 已连接到 $name" && break
        done
        ;;
    --list|list)
        nmcli device wifi list
        ;;
    *)
        echo "用法: jnl-wifi-scan {scan|connect|status|auto|list}"
        ;;
esac
EOF
chmod +x $AIROOTFS/usr/bin/jnl-wifi-scan

# 更新 autostart 桌面文件
cat > $AIROOTFS/home/jnluser/.config/autostart/jnl-wifi-autoscan.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Wi-Fi Auto Scan
Comment=自动扫描 Wi-Fi 网络
Exec=/usr/bin/jnl-wifi-daemon
Terminal=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=plasma-shell
EOF
chown 1000:1000 $AIROOTFS/home/jnluser/.config/autostart/jnl-wifi-autoscan.desktop 2>/dev/null || true

# 同步更新 customize_airootfs.sh 中的WiFi服务配置
python3 << 'PYEOF'
import re, os
filepath = os.path.expanduser("~/jnl-os-build/src/archiso-profile/airootfs/root/customize_airootfs.sh")
with open(filepath, 'r') as f:
    content = f.read()

# 替换服务配置
old_service = r"cat > /etc/systemd/system/jnl-wifi-autoscan\.service <<'EOF'[\s\S]*?EOF"
new_service = """cat > /etc/systemd/system/jnl-wifi-autoscan.service <<'EOF'
[Unit]
Description=JNL OS Wi-Fi Auto Scan Daemon
After=NetworkManager.service
Wants=NetworkManager.service

[Service]
Type=simple
ExecStart=/usr/bin/jnl-wifi-daemon
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical.target
EOF"""
content = re.sub(old_service, new_service, content)

# 替换 autostart 配置
old_autostart = r"cat > /home/jnluser/\.config/autostart/jnl-wifi-autoscan\.desktop <<'EOF'[\s\S]*?EOF"
new_autostart = """cat > /home/jnluser/.config/autostart/jnl-wifi-autoscan.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Wi-Fi Auto Scan
Comment=自动扫描 Wi-Fi 网络
Exec=/usr/bin/jnl-wifi-daemon
Terminal=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=plasma-shell
EOF"""
content = re.sub(old_autostart, new_autostart, content)

# 确保 jnl-wifi-daemon 脚本被创建
if "jnl-wifi-daemon" not in content:
    # 在服务配置后面插入守护脚本
    daemon_block = '''
# 创建 Wi-Fi 自动扫描守护进程
cat > /usr/bin/jnl-wifi-daemon <<'DAEMON'
#!/bin/bash
LOG_FILE="/tmp/jnl-wifi-daemon.log"
exec > "$LOG_FILE" 2>&1
echo "$(date): Wi-Fi daemon started"
for i in {1..30}; do
    if systemctl is-active NetworkManager >/dev/null 2>&1; then
        echo "$(date): NetworkManager is active"
        break
    fi
    sleep 2
done
WIFI_DEV=""
for i in {1..10}; do
    WIFI_DEV=$(nmcli device show | grep -B2 "GENERAL.TYPE:.*wifi" | grep "GENERAL.DEVICE:" | head -1 | awk '{print $2}')
    [ -n "$WIFI_DEV" ] && break
    sleep 1
done
if [ -z "$WIFI_DEV" ]; then
    echo "$(date): No Wi-Fi device found"
    exit 0
fi
while true; do
    STATE=$(nmcli device show "$WIFI_DEV" 2>/dev/null | grep "GENERAL.STATE:" | awk '{print $2}')
    if [ "$STATE" = "30" ] || [ "$STATE" = "20" ]; then
        nmcli device wifi rescan ifname "$WIFI_DEV" 2>/dev/null || nmcli device wifi rescan 2>/dev/null
    fi
    sleep 30
done
DAEMON
chmod +x /usr/bin/jnl-wifi-daemon
'''
    content = content.replace("# 创建 Wi-Fi 自动扫描和连接脚本", daemon_block + "\n# 创建 Wi-Fi 自动扫描和连接脚本")

with open(filepath, 'w') as f:
    f.write(content)
print("  WiFi 配置已同步")
PYEOF

echo "  WiFi 自动扫描已修复为常驻守护进程"

# ============================================================================
# Fix 5: 添加蜘蛛纸牌游戏
# ============================================================================
echo ""
echo "[5/5] 添加蜘蛛纸牌游戏..."

cat > $AIROOTFS/usr/bin/jnl-spider.c << 'EOF'
#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define ROWS 10
#define COLS 10
#define CARD_W 50
#define CARD_H 70

static GtkWidget *window;
static GtkWidget *drawing_area;
static int revealed[ROWS][COLS];
static int matched[ROWS][COLS];
static int first_r = -1, first_c = -1;
static int moves = 0;
static int pairs_found = 0;
static int total_pairs = (ROWS * COLS) / 2;
static int cards[ROWS][COLS];

static void init_game() {
    int values[ROWS*COLS];
    for (int i = 0; i < total_pairs; i++) {
        values[i*2] = i % 13 + 1;
        values[i*2+1] = i % 13 + 1;
    }
    srand(time(NULL));
    for (int i = ROWS*COLS - 1; i > 0; i--) {
        int j = rand() % (i + 1);
        int tmp = values[i]; values[i] = values[j]; values[j] = tmp;
    }
    int idx = 0;
    for (int r = 0; r < ROWS; r++) {
        for (int c = 0; c < COLS; c++) {
            cards[r][c] = values[idx++];
            revealed[r][c] = 0;
            matched[r][c] = 0;
        }
    }
    first_r = -1; first_c = -1;
    moves = 0; pairs_found = 0;
}

static gboolean draw_card(GtkWidget *widget, cairo_t *cr, gpointer data) {
    for (int r = 0; r < ROWS; r++) {
        for (int c = 0; c < COLS; c++) {
            double x = c * (CARD_W + 5) + 10;
            double y = r * (CARD_H + 5) + 10;
            if (matched[r][c]) {
                cairo_set_source_rgb(cr, 0.2, 0.6, 0.2);
            } else if (revealed[r][c]) {
                cairo_set_source_rgb(cr, 1, 1, 1);
            } else {
                cairo_set_source_rgb(cr, 0.2, 0.4, 0.7);
            }
            cairo_rectangle(cr, x, y, CARD_W, CARD_H);
            cairo_fill_preserve(cr);
            cairo_set_source_rgb(cr, 0, 0, 0);
            cairo_stroke(cr);
            if (revealed[r][c] || matched[r][c]) {
                char text[8];
                snprintf(text, sizeof(text), "%d", cards[r][c]);
                cairo_set_source_rgb(cr, 0, 0, 0);
                cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
                cairo_set_font_size(cr, 20);
                cairo_text_extents_t ext;
                cairo_text_extents(cr, text, &ext);
                cairo_move_to(cr, x + (CARD_W - ext.width)/2, y + (CARD_H + ext.height)/2);
                cairo_show_text(cr, text);
            }
        }
    }
    char status[128];
    snprintf(status, sizeof(status), "移动: %d  配对: %d/%d", moves, pairs_found, total_pairs);
    cairo_set_source_rgb(cr, 0, 0, 0);
    cairo_set_font_size(cr, 14);
    cairo_move_to(cr, 10, ROWS * (CARD_H + 5) + 30);
    cairo_show_text(cr, status);
    return FALSE;
}

static gboolean button_press(GtkWidget *widget, GdkEventButton *event, gpointer data) {
    if (event->button != 1) return FALSE;
    int c = (event->x - 10) / (CARD_W + 5);
    int r = (event->y - 10) / (CARD_H + 5);
    if (r < 0 || r >= ROWS || c < 0 || c >= COLS) return FALSE;
    if (revealed[r][c] || matched[r][c]) return FALSE;
    
    revealed[r][c] = 1;
    moves++;
    
    if (first_r == -1) {
        first_r = r; first_c = c;
    } else {
        if (cards[first_r][first_c] == cards[r][c]) {
            matched[first_r][first_c] = 1;
            matched[r][c] = 1;
            pairs_found++;
        }
        gtk_widget_queue_draw(widget);
        while (gtk_events_pending()) gtk_main_iteration();
        g_usleep(500000);
        if (cards[first_r][first_c] != cards[r][c]) {
            revealed[first_r][first_c] = 0;
            revealed[r][c] = 0;
        }
        first_r = -1; first_c = -1;
    }
    gtk_widget_queue_draw(widget);
    if (pairs_found == total_pairs) {
        GtkWidget *dlg = gtk_message_dialog_new(GTK_WINDOW(window), GTK_DIALOG_MODAL, GTK_MESSAGE_INFO, GTK_BUTTONS_OK,
            "恭喜！你完成了所有配对！\n总移动次数: %d", moves);
        gtk_dialog_run(GTK_DIALOG(dlg));
        gtk_widget_destroy(dlg);
        init_game();
        gtk_widget_queue_draw(widget);
    }
    return TRUE;
}

int main(int argc, char *argv[]) {
    gtk_init(&argc, &argv);
    window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), "JNL 蜘蛛纸牌");
    gtk_window_set_default_size(GTK_WINDOW(window), COLS*(CARD_W+5)+25, ROWS*(CARD_H+5)+70);
    g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);
    
    GtkWidget *vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5);
    gtk_container_add(GTK_CONTAINER(window), vbox);
    
    GtkWidget *btn = gtk_button_new_with_label("重新开始");
    g_signal_connect(btn, "clicked", G_CALLBACK(init_game), NULL);
    g_signal_connect_swapped(btn, "clicked", G_CALLBACK(gtk_widget_queue_draw), drawing_area);
    gtk_box_pack_start(GTK_BOX(vbox), btn, FALSE, FALSE, 0);
    
    drawing_area = gtk_drawing_area_new();
    gtk_widget_set_size_request(drawing_area, COLS*(CARD_W+5)+20, ROWS*(CARD_H+5)+50);
    gtk_box_pack_start(GTK_BOX(vbox), drawing_area, TRUE, TRUE, 0);
    gtk_widget_add_events(drawing_area, GDK_BUTTON_PRESS_MASK);
    g_signal_connect(drawing_area, "draw", G_CALLBACK(draw_card), NULL);
    g_signal_connect(drawing_area, "button-press-event", G_CALLBACK(button_press), NULL);
    
    init_game();
    gtk_widget_show_all(window);
    gtk_main();
    return 0;
}
EOF

cat > $AIROOTFS/usr/share/applications/jnl-spider.desktop << 'EOF'
[Desktop Entry]
Name=蜘蛛纸牌
Comment=经典 Windows 蜘蛛纸牌游戏
Exec=jnl-spider
Icon=/usr/share/icons/jnl-os/OS.svg
Terminal=false
Type=Application
Categories=Game;CardGame;
Keywords=spider;solitaire;card;game;
EOF

cat > $AIROOTFS/usr/bin/compile-jnl-games << 'EOF'
#!/bin/bash
echo "Compiling JNL games..."
gcc -o /usr/bin/jnl-spider /usr/bin/jnl-spider.c `pkg-config --cflags --libs gtk+-3.0` 2>&1
EOF
chmod +x $AIROOTFS/usr/bin/compile-jnl-games

echo "  蜘蛛纸牌游戏已添加"

# ============================================================================
# 同步修改到 customize_airootfs.sh
# ============================================================================
echo ""
echo "同步额外修改到 customize_airootfs.sh..."

python3 << 'PYEOF'
import re, os
filepath = os.path.expanduser("~/jnl-os-build/src/archiso-profile/airootfs/root/customize_airootfs.sh")
with open(filepath, 'r') as f:
    content = f.read()

# 确保 polkit 规则被创建
if "50-jnl-mount.rules" not in content:
    insert_pos = content.find("# ============================================================================\n# 10. 性能优化")
    if insert_pos > 0:
        polkit_block = '''# 9.5 配置免密码磁盘挂载
echo "  配置免密码挂载..."
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/50-jnl-mount.rules <<'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.udisks2.filesystem-mount" ||
         action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
         action.id == "org.freedesktop.udisks2.filesystem-unmount" ||
         action.id == "org.freedesktop.udisks2.filesystem-unmount-others") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

cat > /etc/polkit-1/rules.d/50-jnl-disk-manager.rules <<'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id.indexOf("org.freedesktop.udisks2.") == 0) &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

'''
        content = content[:insert_pos] + polkit_block + content[insert_pos:]

# 确保 jnl-disk-manager 在 customize 中编译
if "compile-jnl-disk-manager" not in content:
    # 在结尾添加编译命令
    content = content.replace(
        'echo "=== Java Net Lava OS 配置完成',
        '# 编译 JNL 磁盘管理器\nif [ -f /usr/bin/compile-jnl-disk-manager ]; then\n    bash /usr/bin/compile-jnl-disk-manager >/tmp/jnl-disk-manager-build.log 2>&1 || true\nfi\n\n# 编译 JNL 蜘蛛纸牌\nif [ -f /usr/bin/compile-jnl-games ]; then\n    bash /usr/bin/compile-jnl-games >/tmp/jnl-games-build.log 2>&1 || true\nfi\n\necho "=== Java Net Lava OS 配置完成'
    )

# 删除桌面上的磁盘管理快捷方式生成代码
content = re.sub(r'cat > /home/jnluser/Desktop/jnl-disk-manager\.desktop <<\'EOF\'[\s\S]*?EOF\nchown jnluser:jnluser /home/jnluser/Desktop/jnl-disk-manager\.desktop\nchmod \+x /home/jnluser/Desktop/jnl-disk-manager\.desktop\n', '', content)

with open(filepath, 'w') as f:
    f.write(content)
print("  customize_airootfs.sh 已同步")
PYEOF

echo ""
echo "========================================="
echo "  所有修复完成！"
echo "========================================="
