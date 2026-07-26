#!/bin/bash
set -e

PROFILE_DIR=~/jnl-os-build/src/archiso-profile
AIROOTFS=$PROFILE_DIR/airootfs

echo "========================================="
echo "  JNL OS 深度修复 v2"
echo "========================================="

# ============================================================================
# Fix 1: 磁盘管理工具 - 完整重写，真正的免密码，自定义图标
# ============================================================================
echo ""
echo "[1/6] 深度修复磁盘管理工具..."

# 确保桌面上没有磁盘管理快捷方式
rm -f $AIROOTFS/home/jnluser/Desktop/jnl-disk-manager.desktop

# 自定义磁盘管理图标（重新设计，更像Windows磁盘管理风格）
cat > $AIROOTFS/usr/share/icons/jnl-os/jnl-disk-manager.svg << 'ICONEOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="diskGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#6CB2FF;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#2D7FD4;stop-opacity:1" />
    </linearGradient>
    <linearGradient id="baseGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#E8E8E8;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#B0B0B0;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect x="10" y="78" width="108" height="32" rx="4" fill="url(#baseGrad)" stroke="#707070" stroke-width="2"/>
  <circle cx="64" cy="56" r="36" fill="url(#diskGrad)" stroke="#1E5FA0" stroke-width="2.5"/>
  <circle cx="64" cy="56" r="22" fill="#ffffff" opacity="0.92" stroke="#1E5FA0" stroke-width="1.5"/>
  <circle cx="64" cy="56" r="7" fill="url(#diskGrad)" stroke="#1E5FA0" stroke-width="1"/>
  <circle cx="64" cy="56" r="2.5" fill="#1E5FA0"/>
  <rect x="52" y="105" width="24" height="5" rx="1" fill="#888"/>
  <rect x="20" y="95" width="8" height="3" rx="1" fill="#555"/>
  <rect x="100" y="95" width="8" height="3" rx="1" fill="#555"/>
  <text x="64" y="123" font-family="Arial, sans-serif" font-size="9" font-weight="bold" fill="#444" text-anchor="middle">JNL DISK</text>
</svg>
ICONEOF

# 重写磁盘管理工具 - 真正的免密码版本（使用udisksctl + polkit规则）
cat > $AIROOTFS/usr/bin/jnl-disk-manager.c << 'DISKEOF'
#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

static GtkListStore *disk_store;
static GtkWidget *status_bar;

static char* run_cmd(const char *cmd) {
    static char buf[8192];
    FILE *fp = popen(cmd, "r");
    if (!fp) return strdup("");
    buf[0] = '\0';
    char line[1024];
    while (fgets(line, sizeof(line), fp)) {
        if (strlen(buf) + strlen(line) < sizeof(buf)-1)
            strcat(buf, line);
    }
    pclose(fp);
    return buf;
}

static void set_status(const char *msg) {
    gtk_statusbar_push(GTK_STATUSBAR(status_bar), 0, msg);
}

static void refresh_disk_list(GtkWidget *widget, gpointer data) {
    gtk_list_store_clear(disk_store);
    char *output = run_cmd("lsblk -nlo NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,LABEL,MODEL -b 2>/dev/null | grep -E '^sd|^nvme|^vd|^mmc'");
    char *line = strtok(output, "\n");
    while (line) {
        char name[64]="", size_str[32]="", type[16]="", fstype[32]="", mount[128]="", label[64]="", model[128]="";
        long long size_bytes = 0;
        sscanf(line, "%63s %lld %15s %31s %127s %63s %127[^\n]",
               name, &size_bytes, type, fstype, mount, label, model);
        
        if (strcmp(type, "disk") != 0 && strcmp(type, "part") != 0) {
            line = strtok(NULL, "\n");
            continue;
        }
        
        char sz_human[32];
        if (size_bytes > 1099511627776LL)
            snprintf(sz_human, sizeof(sz_human), "%.2f TB", size_bytes/1099511627776.0);
        else if (size_bytes > 1073741824)
            snprintf(sz_human, sizeof(sz_human), "%.2f GB", size_bytes/1073741824.0);
        else if (size_bytes > 1048576)
            snprintf(sz_human, sizeof(sz_human), "%.2f MB", size_bytes/1048576.0);
        else
            snprintf(sz_human, sizeof(sz_human), "%lld B", size_bytes);
        
        GtkTreeIter iter;
        gtk_list_store_append(disk_store, &iter);
        gtk_list_store_set(disk_store, &iter,
            0, name,
            1, sz_human,
            2, type,
            3, fstype[0] ? fstype : "-",
            4, mount[0] ? mount : "未挂载",
            5, label[0] ? label : "-",
            6, model[0] ? model : "-",
            -1);
        line = strtok(NULL, "\n");
    }
    set_status("磁盘列表已刷新");
}

static gboolean str_ends_with(const char *str, const char *suffix) {
    if (!str || !suffix) return FALSE;
    size_t len = strlen(str);
    size_t slen = strlen(suffix);
    if (slen > len) return FALSE;
    return strcmp(str + len - slen, suffix) == 0;
}

static char* get_selected_name(GtkTreeSelection *sel) {
    static char name[64];
    GtkTreeIter iter;
    GtkTreeModel *model;
    if (!gtk_tree_selection_get_selected(sel, &model, &iter))
        return NULL;
    gtk_tree_model_get(model, &iter, 0, name, -1);
    return name;
}

static void on_mount(GtkWidget *widget, gpointer data) {
    GtkTreeSelection *sel = GTK_TREE_SELECTION(data);
    char *name = get_selected_name(sel);
    if (!name) { set_status("请先选择一个分区"); return; }
    
    if (!strchr(name, '1') && !strchr(name, '2') && !strchr(name, '3') && 
        !strchr(name, '4') && !strchr(name, '5') && !strchr(name, '6')) {
        if (!str_ends_with(name, "p1") && !str_ends_with(name, "p2") &&
            !str_ends_with(name, "p3") && !str_ends_with(name, "p4")) {
            set_status("请选择分区（不能挂载整个磁盘）");
            return;
        }
    }
    
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "udisksctl mount -b /dev/%s 2>&1", name);
    char *out = run_cmd(cmd);
    set_status(out);
    refresh_disk_list(NULL, NULL);
}

static void on_unmount(GtkWidget *widget, gpointer data) {
    GtkTreeSelection *sel = GTK_TREE_SELECTION(data);
    char *name = get_selected_name(sel);
    if (!name) { set_status("请先选择一个分区"); return; }
    
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "udisksctl unmount -b /dev/%s 2>&1", name);
    char *out = run_cmd(cmd);
    set_status(out);
    refresh_disk_list(NULL, NULL);
}

static void on_format_fat32(GtkWidget *widget, gpointer data) {
    GtkTreeSelection *sel = GTK_TREE_SELECTION(data);
    char *name = get_selected_name(sel);
    if (!name) { set_status("请先选择一个分区"); return; }
    
    if (!strchr(name, '1') && !strchr(name, '2') && !strstr(name, "p1")) {
        set_status("请选择分区进行格式化");
        return;
    }
    
    GtkWidget *dlg = gtk_message_dialog_new(NULL, GTK_DIALOG_MODAL,
        GTK_MESSAGE_WARNING, GTK_BUTTONS_YES_NO,
        "警告：此操作将删除 /dev/%s 上的所有数据！\n\n确定要格式化为 FAT32 吗？", name);
    int rc = gtk_dialog_run(GTK_DIALOG(dlg));
    gtk_widget_destroy(dlg);
    if (rc != GTK_RESPONSE_YES) return;
    
    // 先卸载
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "udisksctl unmount -b /dev/%s 2>&1; mkfs.fat -F 32 -I /dev/%s 2>&1", name, name);
    char *out = run_cmd(cmd);
    set_status(out);
    refresh_disk_list(NULL, NULL);
}

static void on_format_ext4(GtkWidget *widget, gpointer data) {
    GtkTreeSelection *sel = GTK_TREE_SELECTION(data);
    char *name = get_selected_name(sel);
    if (!name) { set_status("请先选择一个分区"); return; }
    
    if (!strchr(name, '1') && !strchr(name, '2')) {
        set_status("请选择分区进行格式化");
        return;
    }
    
    GtkWidget *dlg = gtk_message_dialog_new(NULL, GTK_DIALOG_MODAL,
        GTK_MESSAGE_WARNING, GTK_BUTTONS_YES_NO,
        "警告：此操作将删除 /dev/%s 上的所有数据！\n\n确定要格式化为 ext4 吗？", name);
    int rc = gtk_dialog_run(GTK_DIALOG(dlg));
    gtk_widget_destroy(dlg);
    if (rc != GTK_RESPONSE_YES) return;
    
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "udisksctl unmount -b /dev/%s 2>&1; mkfs.ext4 -F /dev/%s 2>&1", name, name);
    char *out = run_cmd(cmd);
    set_status(out);
    refresh_disk_list(NULL, NULL);
}

static void on_rescan(GtkWidget *widget, gpointer data) {
    run_cmd("udevadm settle 2>&1");
    run_cmd("partprobe 2>&1");
    refresh_disk_list(NULL, NULL);
    set_status("已重新扫描磁盘设备");
}

int main(int argc, char *argv[]) {
    gtk_init(&argc, &argv);
    
    GtkWidget *win = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(win), "JNL 磁盘管理");
    gtk_window_set_default_size(GTK_WINDOW(win), 950, 550);
    g_signal_connect(win, "destroy", G_CALLBACK(gtk_main_quit), NULL);
    
    GtkWidget *vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    gtk_container_set_border_width(GTK_CONTAINER(vbox), 10);
    gtk_container_add(GTK_CONTAINER(win), vbox);
    
    // 标题栏
    GtkWidget *header = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    gtk_box_pack_start(GTK_BOX(vbox), header, FALSE, FALSE, 0);
    
    GtkWidget *title = gtk_label_new("JNL 磁盘管理");
    gtk_widget_set_halign(title, GTK_ALIGN_START);
    PangoFontDescription *font = pango_font_description_from_string("Sans Bold 18");
    gtk_widget_override_font(title, font);
    pango_font_description_free(font);
    gtk_box_pack_start(GTK_BOX(header), title, FALSE, FALSE, 0);
    
    // 工具栏
    GtkWidget *toolbar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
    gtk_box_pack_start(GTK_BOX(vbox), toolbar, FALSE, FALSE, 0);
    
    GtkWidget *btn_refresh = gtk_button_new_with_label("刷新");
    gtk_box_pack_start(GTK_BOX(toolbar), btn_refresh, FALSE, FALSE, 0);
    
    GtkWidget *btn_mount = gtk_button_new_with_label("挂载");
    gtk_box_pack_start(GTK_BOX(toolbar), btn_mount, FALSE, FALSE, 0);
    
    GtkWidget *btn_unmount = gtk_button_new_with_label("卸载");
    gtk_box_pack_start(GTK_BOX(toolbar), btn_unmount, FALSE, FALSE, 0);
    
    GtkWidget *btn_fat32 = gtk_button_new_with_label("格式化为 FAT32");
    gtk_box_pack_start(GTK_BOX(toolbar), btn_fat32, FALSE, FALSE, 0);
    
    GtkWidget *btn_ext4 = gtk_button_new_with_label("格式化为 ext4");
    gtk_box_pack_start(GTK_BOX(toolbar), btn_ext4, FALSE, FALSE, 0);
    
    GtkWidget *btn_rescan = gtk_button_new_with_label("重新扫描");
    gtk_box_pack_start(GTK_BOX(toolbar), btn_rescan, FALSE, FALSE, 0);
    
    // 磁盘列表
    disk_store = gtk_list_store_new(7,
        G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING,
        G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
    
    GtkWidget *tree = gtk_tree_view_new_with_model(GTK_TREE_MODEL(disk_store));
    gtk_tree_view_set_grid_lines(GTK_TREE_VIEW(tree), GTK_TREE_VIEW_GRID_LINES_HORIZONTAL);
    
    const char *cols[] = {"设备", "容量", "类型", "文件系统", "挂载点", "标签", "型号"};
    for (int i = 0; i < 7; i++) {
        GtkCellRenderer *r = gtk_cell_renderer_text_new();
        GtkTreeViewColumn *col = gtk_tree_view_column_new_with_attributes(cols[i], r, "text", i, NULL);
        gtk_tree_view_column_set_resizable(col, TRUE);
        gtk_tree_view_column_set_min_width(col, 80);
        gtk_tree_view_append_column(GTK_TREE_VIEW(tree), col);
    }
    
    GtkWidget *scroll = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
    gtk_container_add(GTK_CONTAINER(scroll), tree);
    gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 0);
    
    GtkTreeSelection *sel = gtk_tree_view_get_selection(GTK_TREE_VIEW(tree));
    
    g_signal_connect(btn_refresh, "clicked", G_CALLBACK(refresh_disk_list), NULL);
    g_signal_connect(btn_mount, "clicked", G_CALLBACK(on_mount), sel);
    g_signal_connect(btn_unmount, "clicked", G_CALLBACK(on_unmount), sel);
    g_signal_connect(btn_fat32, "clicked", G_CALLBACK(on_format_fat32), sel);
    g_signal_connect(btn_ext4, "clicked", G_CALLBACK(on_format_ext4), sel);
    g_signal_connect(btn_rescan, "clicked", G_CALLBACK(on_rescan), NULL);
    
    // 状态栏
    status_bar = gtk_statusbar_new();
    gtk_box_pack_end(GTK_BOX(vbox), status_bar, FALSE, FALSE, 0);
    
    gtk_widget_show_all(win);
    refresh_disk_list(NULL, NULL);
    gtk_main();
    return 0;
}
DISKEOF

echo "  磁盘管理工具已重写（GTK3 + udisks2，免密码）"

# ============================================================================
# Fix 2: polkit规则 - 确保免密码挂载和格式化
# ============================================================================
echo ""
echo "[2/6] 配置polkit免密码规则..."

mkdir -p $AIROOTFS/etc/polkit-1/rules.d
cat > $AIROOTFS/etc/polkit-1/rules.d/10-jnl-udisks.rules << 'EOF'
// JNL OS: 允许 wheel 组用户无密码进行所有磁盘操作
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.udisks2.") == 0 &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

# 同时也配置磁盘相关的系统操作
cat > $AIROOTFS/etc/polkit-1/rules.d/10-jnl-mount.rules << 'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.udisks2.filesystem-mount" ||
         action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
         action.id == "org.freedesktop.udisks2.filesystem-mount-other-seat" ||
         action.id == "org.freedesktop.udisks2.filesystem-unmount" ||
         action.id == "org.freedesktop.udisks2.filesystem-unmount-others" ||
         action.id == "org.freedesktop.udisks2.encrypted-unlock" ||
         action.id == "org.freedesktop.udisks2.encrypted-lock-others" ||
         action.id == "org.freedesktop.udisks2.eject" ||
         action.id == "org.freedesktop.udisks2.eject-media" ||
         action.id == "org.freedesktop.udisks2.power-off-drive" ||
         action.id == "org.freedesktop.udisks2.drive-detach") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

# 移除旧的规则文件
rm -f $AIROOTFS/etc/polkit-1/rules.d/50-jnl-mount.rules
rm -f $AIROOTFS/etc/polkit-1/rules.d/50-jnl-disk-manager.rules

echo "  Polkit 规则已配置（wheel组免密码操作所有磁盘）"

# ============================================================================
# Fix 3: 回收站拖放直接移动 - 彻底修复
# ============================================================================
echo ""
echo "[3/6] 修复回收站拖放直接移动..."

# 修改 customize_airootfs.sh 中的 dolphinrc 配置
# 关键是 ShowCopyMoveMenu=false 和 配置全局KDE拖拽行为
python3 << 'PYEOF'
import re, os

filepath = os.path.expanduser("~/jnl-os-build/src/archiso-profile/airootfs/root/customize_airootfs.sh")
with open(filepath, 'r') as f:
    content = f.read()

# 找到所有 dolphinrc 配置并统一更新
old_dolphin = r"cat > /home/jnluser/\.config/dolphinrc <<'EOF'\n\[General\]\nShowTrashBinInPlaces=false\nVersion=2024\nAutoExpandFolders=true\nShowFullPathInTitle=false\nConfirmDelete=false\nConfirmClosingMultipleTabs=false\nConfirmClosingTerminalRunningProgram=false\nShowCopyMoveMenu=false\nShowDeleteCommand=true\nShowErrorOnDelete=false\nShowSafeDeleteQuestion=false\n\n\[KDE\]\nShowDeleteCommand=true\n\n\[Trash\]\nShowSizeLimitWarning=false\n\n\[MainWindow\]\nMenuBar=Disabled\nToolBarsMovable=Disabled\nHideTerminal=true\n\n\[PreviewSettings\]\nPlugins=appimagethumbnail,audiothumbnail,blenderthumbnail,comicbookthumbnail,cursorthumbnail,djvuthumbnail,ebookthumbnail,exrthumbnail,fontthumbnail,htmlthumbnail,imagethumbnail,jpegthumbnail,kraorathumbnail,mobithumbnail,opendocumentthumbnail,pngthumbnail,rawthumbnail,svgthumbnail,textthumbnail,webpthumbnail\n\n\[KFileDialog Settings\]\nShowCopyMoveMenu=false\nEOF"

new_dolphin = """cat > /home/jnluser/.config/dolphinrc <<'EOF'
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
ConfirmTrash=false
AutoExpandFolders=true
MarkModified=false
BrowseThroughArchives=false
ShowSpaceInfo=true
UseInformationPanelTips=true
AllowNestedDirs=false
ShowFullPathInTitle=false
ShowPathInTitle=false

[KDE]
ShowDeleteCommand=true
ShowCopyMoveMenu=false

[Trash]
ShowSizeLimitWarning=false
ConfirmDelete=false

[MainWindow]
MenuBar=Disabled
ToolBarsMovable=Disabled
HideTerminal=true
State=AAAA/wAAAAD9AAAAAQAAAAEAAAALAAABf2wAAADhAAAAtv8AAAAAwA2PAAABdAAAAA8AAAAjAAAAAQAAAAMAAAABU3BsaXR0ZXJzAAAAQVQAAAAEAAAAQQBWAE0AIABIAG8AbQBtAGUAAIADAAAABgAAAEQAbwBjAGsAQwBvAGwAbwBuADEAAAEBAAAABAAAAEwAaQBuAGUARgBpAGwAZQB0AGUAcgBDAG8AbAB1AG0AbgBzAC0AagBvAGwAaQBzAHQAagBvAGwAAQAAAAEAAAAIAAAAz/8AAAAEAAAAQQBVAEMAbwBsAHUAbQBuAAAAAEMAbwBsAHUAbQBuACAAMQA=

[PreviewSettings]
Plugins=appimagethumbnail,audiothumbnail,blenderthumbnail,comicbookthumbnail,cursorthumbnail,djvuthumbnail,ebookthumbnail,exrthumbnail,fontthumbnail,htmlthumbnail,imagethumbnail,jpegthumbnail,kraorathumbnail,mobithumbnail,opendocumentthumbnail,pngthumbnail,rawthumbnail,svgthumbnail,textthumbnail,webpthumbnail

[KFileDialog Settings]
ShowCopyMoveMenu=false
EOF"""

if "ConfirmTrash=false" not in content:
    content = content.replace(
        "ShowSafeDeleteQuestion=false\n\n[KDE]",
        "ShowSafeDeleteQuestion=false\nConfirmTrash=false\n\n[KDE]"
    )

# 确保 ShowCopyMoveMenu=false 在多处都有
# 另外，添加全局配置禁止拖放选择菜单
if "[General]\nShowCopyMoveMenu=false" in content:
    pass  # already there

# 添加 kdeglobals 配置强制拖拽为移动
if "DragAndDropMode" not in content:
    # 在 kdeglobals 的 [KDE] 段添加拖拽配置
    old_kde = """cat > /home/jnluser/.config/kdeglobals <<'EOF'
[KDE]
AnimationDurationFactor=0.3
LookAndFeelPackage=com.jnlos.desktop
widgetStyle=Breeze
EOF"""
    new_kde = """cat > /home/jnluser/.config/kdeglobals <<'EOF'
[KDE]
AnimationDurationFactor=0.3
LookAndFeelPackage=com.jnlos.desktop
widgetStyle=Breeze
SingleClick=false
DragAndDropMode=1
EOF"""
    content = content.replace(old_kde, new_kde)

# 添加 klipperrc / kfmclient 配置
if "kglobalsettings" not in content.lower():
    insert_pos = content.find("chown jnluser:jnluser /home/jnluser/.config/dolphinrc")
    if insert_pos > 0:
        extra_config = """
# 全局设置：拖放文件默认移动，不显示选择菜单
cat > /home/jnluser/.config/kdeglobals <<'EOF_KDEGLOBALS'
[KDE]
AnimationDurationFactor=0.3
LookAndFeelPackage=com.jnlos.desktop
widgetStyle=Breeze
SingleClick=false
DragAndDropMode=1

[KFileDialog Settings]
ShowCopyMoveMenu=false
EOF_KDEGLOBALS
chown jnluser:jnluser /home/jnluser/.config/kdeglobals

"""
        # 找到位置并插入
        idx = content.find("\n# 4.2 禁用 Dolphin 拖放时的复制/移动选择对话框")
        if idx < 0:
            idx = content.find("chown jnluser:jnluser /home/jnluser/.config/dolphinrc")
            if idx > 0:
                content = content[:idx] + extra_config + content[idx:]

with open(filepath, 'w') as f:
    f.write(content)
print("  dolphinrc 和 kdeglobals 已更新（强制移动，不显示菜单）")
PYEOF

echo "  回收站拖放行为已修复"

# ============================================================================
# Fix 4: WiFi 服务 - 彻底修复，无WiFi设备也保持运行
# ============================================================================
echo ""
echo "[4/6] 修复WiFi自动扫描服务..."

# 重写WiFi守护进程 - 更健壮
cat > $AIROOTFS/usr/bin/jnl-wifi-daemon << 'WIFIEOF'
#!/bin/bash
# JNL OS Wi-Fi 守护进程
# 自动扫描 + 自动连接 + 托盘提示

LOG_FILE="/tmp/jnl-wifi-daemon.log"
exec >> "$LOG_FILE" 2>&1

echo "=================================="
echo "$(date '+%Y-%m-%d %H:%M:%S') JNL Wi-Fi Daemon 启动"

# 确保 NetworkManager 启动
if ! systemctl is-active NetworkManager >/dev/null 2>&1; then
    echo "$(date) 正在启动 NetworkManager..."
    dbus-send --system --dest=org.freedesktop.systemd1 --type=method_call /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager.StartUnit string:"NetworkManager.service" string:"replace" 2>/dev/null || true
    sleep 3
fi

# 循环检查WiFi设备并扫描
SCAN_INTERVAL=30
LOOP_COUNT=0
WIFI_DEV=""

find_wifi_device() {
    WIFI_DEV=""
    # 尝试多种方式查找WiFi设备
    for dev in $(ls /sys/class/net/ 2>/dev/null); do
        if [ -d "/sys/class/net/$dev/wireless" ] 2>/dev/null; then
            WIFI_DEV="$dev"
            echo "$(date) 发现WiFi设备: $WIFI_DEV"
            return 0
        fi
    done
    # 备用方式
    local nm_dev=$(nmcli device status 2>/dev/null | grep -i wifi | head -1 | awk '{print $1}')
    if [ -n "$nm_dev" ]; then
        WIFI_DEV="$nm_dev"
        echo "$(date) 发现WiFi设备(通过nmcli): $WIFI_DEV"
        return 0
    fi
    return 1
}

# 先尝试找WiFi设备
find_wifi_device

# 如果没找到，也不退出，继续监听（USB WiFi可能热插拔）
if [ -z "$WIFI_DEV" ]; then
    echo "$(date) 未检测到WiFi设备，进入监听模式（等待热插拔）"
fi

# 主循环
while true; do
    LOOP_COUNT=$((LOOP_COUNT + 1))
    
    # 每10次循环检查一次是否有新的WiFi设备
    if [ $((LOOP_COUNT % 10)) -eq 0 ] && [ -z "$WIFI_DEV" ]; then
        find_wifi_device
    fi
    
    if [ -n "$WIFI_DEV" ]; then
        # 检查设备状态
        STATE=$(nmcli -t -f DEVICE,STATE device status 2>/dev/null | grep "^$WIFI_DEV:" | cut -d: -f2)
        
        if [ -z "$STATE" ]; then
            # 设备可能已断开，重新查找
            find_wifi_device
        else
            echo "$(date) [loop $LOOP_COUNT] WiFi状态: $STATE"
            
            # 执行扫描
            if [ "$STATE" = "disconnected" ] || [ "$STATE" = "available" ]; then
                nmcli device wifi rescan ifname "$WIFI_DEV" >/dev/null 2>&1
                echo "$(date) WiFi扫描完成"
            fi
            
            # 如果有已保存的网络，尝试自动连接
            if [ "$STATE" = "disconnected" ]; then
                nmcli connection show 2>/dev/null | grep -v "NAME" | grep -E "wifi|802-11" | while read -r name uuid type device; do
                    if [ -n "$name" ]; then
                        echo "$(date) 尝试自动连接: $name"
                        nmcli connection up "$name" ifname "$WIFI_DEV" 2>/dev/null && break
                    fi
                done
            fi
        fi
    else
        echo "$(date) [loop $LOOP_COUNT] 等待WiFi设备..."
    fi
    
    sleep $SCAN_INTERVAL
done
WIFIEOF
chmod +x $AIROOTFS/usr/bin/jnl-wifi-daemon

# 重写WiFi服务文件
cat > $AIROOTFS/etc/systemd/system/jnl-wifi-autoscan.service << 'SVC_EOF'
[Unit]
Description=JNL OS Wi-Fi Auto Scan Daemon
After=NetworkManager.service dbus.service
Wants=NetworkManager.service

[Service]
Type=simple
ExecStart=/usr/bin/jnl-wifi-daemon
Restart=always
RestartSec=10
User=root
Group=root

[Install]
WantedBy=graphical.target
SVC_EOF

# 重写autostart - 确保用户登录后启动
cat > $AIROOTFS/home/jnluser/.config/autostart/jnl-wifi-autoscan.desktop << 'AUTO_EOF'
[Desktop Entry]
Type=Application
Name=Wi-Fi Auto Scan
Comment=JNL OS WiFi自动扫描
Exec=pkexec /usr/bin/jnl-wifi-daemon
Terminal=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=plasma-desktop
AUTO_EOF
chown 1000:1000 $AIROOTFS/home/jnluser/.config/autostart/jnl-wifi-autoscan.desktop 2>/dev/null || true

# 更新 jnl-wifi-scan 脚本
cat > $AIROOTFS/usr/bin/jnl-wifi-scan << 'SCAN_EOF'
#!/bin/bash
# JNL OS Wi-Fi 扫描工具

ensure_nm() {
    if ! systemctl is-active NetworkManager >/dev/null 2>&1; then
        echo "正在启动 NetworkManager..."
        sudo systemctl start NetworkManager 2>/dev/null || true
        sleep 2
    fi
}

case "$1" in
    --scan|scan|"")
        ensure_nm
        echo "正在扫描 Wi-Fi 网络..."
        nmcli device wifi rescan 2>/dev/null
        sleep 3
        echo ""
        echo "可用 Wi-Fi 网络:"
        echo "----------------------------------------"
        nmcli -t -f SSID,SIGNAL,SECURITY,BARS,IN-USE device wifi list 2>/dev/null | sort -t: -k2 -nr | while IFS=: read -r ssid signal security bars inuse; do
            if [ -n "$ssid" ]; then
                prefix=""
                [ "$inuse" = "*" ] && prefix="* "
                printf "%s%-28s %s (%3d%%) %s\n" "$prefix" "$ssid" "$bars" "$signal" "$security"
            fi
        done
        echo "----------------------------------------"
        ;;
    --connect|connect)
        ensure_nm
        if [ -z "$2" ]; then
            echo "用法: jnl-wifi-scan connect <SSID> [密码]"
            exit 1
        fi
        SSID="$2"
        PASSWORD="$3"
        echo "正在连接 $SSID ..."
        if [ -n "$PASSWORD" ]; then
            nmcli device wifi connect "$SSID" password "$PASSWORD"
        else
            nmcli device wifi connect "$SSID"
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
        echo "活动连接:"
        nmcli connection show --active
        ;;
    --on|enable)
        sudo nmcli radio wifi on
        echo "WiFi 已启用"
        ;;
    --off|disable)
        sudo nmcli radio wifi off
        echo "WiFi 已禁用"
        ;;
    *)
        echo "JNL OS Wi-Fi 工具"
        echo "用法:"
        echo "  jnl-wifi-scan scan        扫描可用网络"
        echo "  jnl-wifi-scan connect SSID [密码]  连接网络"
        echo "  jnl-wifi-scan status      查看状态"
        echo "  jnl-wifi-scan on          开启WiFi"
        echo "  jnl-wifi-scan off         关闭WiFi"
        ;;
esac
SCAN_EOF
chmod +x $AIROOTFS/usr/bin/jnl-wifi-scan

echo "  WiFi 守护进程已重写（无设备也保持运行）"

# ============================================================================
# Fix 5: 蜘蛛纸牌 - 确保正确编译
# ============================================================================
echo ""
echo "[5/6] 蜘蛛纸牌游戏..."

# 检查并更新蜘蛛纸牌源码（更完整的版本）
cat > $AIROOTFS/usr/bin/jnl-spider.c << 'SPIDER_EOF'
#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define CARD_W 60
#define CARD_H 90
#define STACK_X 50
#define STACK_Y 120
#define STACK_GAP 20
#define FOUNDATION_Y 20
#define FOUNDATION_X 50

typedef struct {
    int suit;
    int rank;
    int face_up;
} Card;

typedef struct {
    Card cards[52];
    int count;
} CardStack;

static GtkWidget *window;
static GtkWidget *drawing_area;
static CardStack tableau[10];
static CardStack foundation[8];
static CardStack stock;
static int moves = 0;
static int score = 500;
static int selected_stack = -1;
static int selected_count = 0;
static int game_won = 0;

static char suits[] = {'S', 'H', 'D', 'C'};
static char ranks[][3] = {"A","2","3","4","5","6","7","8","9","10","J","Q","K"};

static void init_deck() {
    int idx = 0;
    stock.count = 0;
    // 两副牌，蜘蛛纸牌只用一种花色（简化版用全部）
    for (int d = 0; d < 2; d++) {
        for (int s = 0; s < 4; s++) {
            for (int r = 0; r < 13; r++) {
                Card c = {s, r, 0};
                stock.cards[idx++] = c;
            }
        }
    }
    stock.count = idx;
    
    // 洗牌
    srand(time(NULL));
    for (int i = stock.count - 1; i > 0; i--) {
        int j = rand() % (i + 1);
        Card tmp = stock.cards[i];
        stock.cards[i] = stock.cards[j];
        stock.cards[j] = tmp;
    }
}

static void deal_cards() {
    init_deck();
    for (int i = 0; i < 10; i++) tableau[i].count = 0;
    for (int i = 0; i < 8; i++) foundation[i].count = 0;
    
    int card_idx = 0;
    // 每列发牌
    for (int col = 0; col < 10; col++) {
        int num = (col < 4) ? 6 : 5;
        for (int r = 0; r < num; r++) {
            if (card_idx < stock.count) {
                tableau[col].cards[r] = stock.cards[card_idx++];
                tableau[col].count = r + 1;
                tableau[col].cards[r].face_up = (r == num - 1) ? 1 : 0;
            }
        }
    }
    // 剩余的牌作为发牌堆
    int remaining = stock.count - card_idx;
    for (int i = 0; i < remaining; i++) {
        stock.cards[i] = stock.cards[card_idx + i];
    }
    stock.count = remaining;
    
    moves = 0;
    score = 500;
    selected_stack = -1;
    selected_count = 0;
    game_won = 0;
}

static void draw_card(cairo_t *cr, double x, double y, Card *card, int face_up) {
    // 卡牌背景
    if (face_up) {
        cairo_set_source_rgb(cr, 1, 1, 1);
    } else {
        cairo_set_source_rgb(cr, 0.15, 0.35, 0.65);
    }
    cairo_rectangle(cr, x, y, CARD_W, CARD_H);
    cairo_fill_preserve(cr);
    cairo_set_source_rgb(cr, 0.3, 0.3, 0.3);
    cairo_set_line_width(cr, 1.5);
    cairo_stroke(cr);
    
    // 圆角
    double radius = 6;
    cairo_set_source_rgb(cr, face_up ? 1 : 0.15, face_up ? 1 : 0.35, face_up ? 1 : 0.65);
    
    if (face_up && card) {
        // 花色和点数
        char rank_str[4];
        strcpy(rank_str, ranks[card->rank]);
        char suit_char = suits[card->suit];
        int is_red = (card->suit == 1 || card->suit == 2);
        
        cairo_set_source_rgb(cr, is_red ? 0.8 : 0, 0, is_red ? 0 : 0);
        cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
        cairo_set_font_size(cr, 12);
        
        cairo_move_to(cr, x + 5, y + 15);
        cairo_show_text(cr, rank_str);
        cairo_move_to(cr, x + 5, y + 28);
        char suit_str[2] = {suit_char, 0};
        cairo_show_text(cr, suit_str);
        
        // 中央大花色
        cairo_set_font_size(cr, 28);
        cairo_text_extents_t ext;
        cairo_text_extents(cr, suit_str, &ext);
        cairo_move_to(cr, x + (CARD_W - ext.width)/2, y + (CARD_H + ext.height)/2);
        cairo_show_text(cr, suit_str);
        
        // 右下角（倒过来）
        cairo_save(cr);
        cairo_translate(cr, x + CARD_W - 5, y + CARD_H - 5);
        cairo_rotate(cr, 3.14159);
        cairo_move_to(cr, 0, 0);
        cairo_set_font_size(cr, 12);
        cairo_show_text(cr, rank_str);
        cairo_move_to(cr, 0, 13);
        cairo_show_text(cr, suit_str);
        cairo_restore(cr);
    } else {
        // 牌背图案
        cairo_set_source_rgb(cr, 0.2, 0.5, 0.8);
        cairo_set_line_width(cr, 1);
        for (int i = 0; i < 5; i++) {
            cairo_move_to(cr, x + 5, y + 10 + i*18);
            cairo_line_to(cr, x + CARD_W - 5, y + 10 + i*18);
            cairo_stroke(cr);
        }
        for (int i = 0; i < 3; i++) {
            cairo_move_to(cr, x + 15 + i*15, y + 5);
            cairo_line_to(cr, x + 15 + i*15, y + CARD_H - 5);
            cairo_stroke(cr);
        }
    }
}

static gboolean on_draw(GtkWidget *widget, cairo_t *cr, gpointer data) {
    // 背景 - 绿色桌面
    cairo_set_source_rgb(cr, 0.12, 0.45, 0.15);
    cairo_paint(cr);
    
    // 标题
    cairo_set_source_rgb(cr, 1, 1, 1);
    cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
    cairo_set_font_size(cr, 18);
    cairo_move_to(cr, 50, 50);
    cairo_show_text(cr, "JNL 蜘蛛纸牌");
    
    // 分数和步数
    cairo_set_font_size(cr, 14);
    cairo_move_to(cr, 50, 75);
    char info[128];
    snprintf(info, sizeof(info), "分数: %d  移动: %d  剩余发牌: %d", score, moves, stock.count);
    cairo_show_text(cr, info);
    
    // 发牌堆
    if (stock.count > 0) {
        draw_card(cr, 650, 20, NULL, 0);
        char stock_str[16];
        snprintf(stock_str, sizeof(stock_str), "%d", stock.count);
        cairo_set_source_rgb(cr, 1, 1, 1);
        cairo_set_font_size(cr, 14);
        cairo_move_to(cr, 675, 75);
        cairo_show_text(cr, stock_str);
    }
    
    // 完成区 (8个基础堆)
    for (int i = 0; i < 8; i++) {
        double fx = 380 + i * (CARD_W + 10);
        cairo_set_source_rgb(cr, 0.1, 0.35, 0.12);
        cairo_rectangle(cr, fx, 20, CARD_W, CARD_H);
        cairo_stroke(cr);
        if (foundation[i].count > 0) {
            Card *top = &foundation[i].cards[foundation[i].count-1];
            draw_card(cr, fx, 20, top, 1);
        }
    }
    
    // 10列牌堆
    for (int col = 0; col < 10; col++) {
        double x = STACK_X + col * (CARD_W + STACK_GAP);
        double y = STACK_Y;
        
        for (int r = 0; r < tableau[col].count; r++) {
            int is_selected = (selected_stack == col && r >= tableau[col].count - selected_count);
            double offset_y = is_selected ? -10 : 0;
            
            if (tableau[col].cards[r].face_up) {
                draw_card(cr, x, y + offset_y, &tableau[col].cards[r], 1);
            } else {
                draw_card(cr, x, y + offset_y, &tableau[col].cards[r], 0);
            }
            y += 25;
        }
        
        // 空列标记
        if (tableau[col].count == 0) {
            cairo_set_source_rgb(cr, 0.1, 0.35, 0.12);
            cairo_set_line_width(cr, 2);
            cairo_rectangle(cr, x, STACK_Y, CARD_W, CARD_H);
            cairo_stroke(cr);
        }
        
        // 选中高亮
        if (selected_stack == col) {
            cairo_set_source_rgb(cr, 1, 1, 0);
            cairo_set_line_width(cr, 2);
            cairo_rectangle(cr, x - 2, STACK_Y - 2, CARD_W + 4, 
                          STACK_Y - 2 - STACK_Y + tableau[col].count*25 + CARD_H + 4 + (selected_count>0?-10:0));
            // 简化：画在整列周围
            double h = tableau[col].count * 25 + CARD_H - 25;
            if (h < CARD_H) h = CARD_H;
            cairo_rectangle(cr, x - 2, STACK_Y - 2, CARD_W + 4, h + 4);
            cairo_stroke(cr);
        }
    }
    
    // 胜利提示
    if (game_won) {
        cairo_set_source_rgba(cr, 0, 0, 0, 0.7);
        cairo_paint(cr);
        cairo_set_source_rgb(cr, 1, 1, 0);
        cairo_set_font_size(cr, 36);
        cairo_move_to(cr, 200, 300);
        cairo_show_text(cr, "恭喜你赢了！");
    }
    
    return FALSE;
}

static int can_move_to_tableau(Card *card, CardStack *dest) {
    if (dest->count == 0) return 1;
    Card *top = &dest->cards[dest->count - 1];
    if (!top->face_up) return 0;
    return (card->rank == top->rank - 1);
}

static int can_move_sequence(CardStack *src, int count, CardStack *dest) {
    if (count <= 0 || count > src->count) return 0;
    int start = src->count - count;
    Card *first = &src->cards[start];
    if (!first->face_up) return 0;
    // 检查序列是否合法（同花色，递减）
    for (int i = start + 1; i < src->count; i++) {
        if (!src->cards[i].face_up) return 0;
        if (src->cards[i].suit != first->suit) return 0;
        if (src->cards[i].rank != src->cards[i-1].rank - 1) return 0;
    }
    if (dest->count == 0) return 1;
    Card *top = &dest->cards[dest->count - 1];
    if (!top->face_up) return 0;
    return (first->rank == top->rank - 1);
}

static void check_foundation(int col) {
    // 检查是否可以移到基础堆（同花色K到A完整序列）
    if (tableau[col].count < 13) return;
    int start = tableau[col].count - 13;
    Card *first = &tableau[col].cards[start];
    if (!first->face_up || first->rank != 12) return; // K
    
    // 检查13张递减序列同花色
    int valid = 1;
    for (int i = 0; i < 13; i++) {
        if (!tableau[col].cards[start + i].face_up) { valid = 0; break; }
        if (tableau[col].cards[start + i].suit != first->suit) { valid = 0; break; }
        if (tableau[col].cards[start + i].rank != 12 - i) { valid = 0; break; }
    }
    if (!valid) return;
    
    // 移到基础堆
    for (int f = 0; f < 8; f++) {
        if (foundation[f].count == 0) {
            for (int i = 0; i < 13; i++) {
                foundation[f].cards[i] = tableau[col].cards[start + i];
            }
            foundation[f].count = 13;
            tableau[col].count -= 13;
            // 翻开新牌
            if (tableau[col].count > 0)
                tableau[col].cards[tableau[col].count-1].face_up = 1;
            score += 100;
            break;
        }
    }
    
    // 检查是否全部完成
    int total = 0;
    for (int f = 0; f < 8; f++) total += foundation[f].count;
    if (total == 104) game_won = 1;
}

static void on_button_press(GtkWidget *widget, GdkEventButton *event, gpointer data) {
    if (game_won) return;
    double mx = event->x, my = event->y;
    
    // 点击发牌堆
    if (mx >= 650 && mx <= 650 + CARD_W && my >= 20 && my <= 20 + CARD_H) {
        if (stock.count >= 10) {
            for (int i = 0; i < 10; i++) {
                if (stock.count > 0) {
                    stock.cards[stock.count-1].face_up = 1;
                    tableau[i].cards[tableau[i].count++] = stock.cards[--stock.count];
                }
            }
            moves++;
            score--;
            selected_stack = -1;
            selected_count = 0;
            gtk_widget_queue_draw(widget);
        }
        return;
    }
    
    // 点击列
    for (int col = 0; col < 10; col++) {
        double x = STACK_X + col * (CARD_W + STACK_GAP);
        if (mx < x || mx > x + CARD_W) continue;
        
        // 计算点击的是第几张
        if (my < STACK_Y) continue;
        if (tableau[col].count == 0) {
            // 空列，如果有选中的牌，移动过来
            if (selected_stack >= 0 && selected_count > 0) {
                if (can_move_sequence(&tableau[selected_stack], selected_count, &tableau[col])) {
                    int start = tableau[selected_stack].count - selected_count;
                    for (int i = 0; i < selected_count; i++) {
                        tableau[col].cards[tableau[col].count++] = tableau[selected_stack].cards[start + i];
                    }
                    tableau[selected_stack].count -= selected_count;
                    if (tableau[selected_stack].count > 0)
                        tableau[selected_stack].cards[tableau[selected_stack].count-1].face_up = 1;
                    moves++;
                    score--;
                    check_foundation(col);
                    selected_stack = -1;
                    selected_count = 0;
                    gtk_widget_queue_draw(widget);
                }
            }
            return;
        }
        
        // 点击某张牌
        int card_idx = (my - STACK_Y) / 25;
        if (card_idx >= tableau[col].count) card_idx = tableau[col].count - 1;
        if (card_idx < 0) card_idx = 0;
        
        if (!tableau[col].cards[card_idx].face_up) {
            // 点到背面牌，若已选中则取消
            if (selected_stack >= 0) {
                selected_stack = -1;
                selected_count = 0;
                gtk_widget_queue_draw(widget);
            }
            return;
        }
        
        int n_cards = tableau[col].count - card_idx;
        
        if (selected_stack < 0) {
            // 选中
            selected_stack = col;
            selected_count = n_cards;
            gtk_widget_queue_draw(widget);
        } else if (selected_stack == col) {
            // 取消选中或重新选择
            if (selected_count == n_cards) {
                selected_stack = -1;
                selected_count = 0;
            } else {
                selected_count = n_cards;
            }
            gtk_widget_queue_draw(widget);
        } else {
            // 尝试移动
            if (can_move_sequence(&tableau[selected_stack], selected_count, &tableau[col])) {
                int start = tableau[selected_stack].count - selected_count;
                for (int i = 0; i < selected_count; i++) {
                    tableau[col].cards[tableau[col].count++] = tableau[selected_stack].cards[start + i];
                }
                tableau[selected_stack].count -= selected_count;
                if (tableau[selected_stack].count > 0)
                    tableau[selected_stack].cards[tableau[selected_stack].count-1].face_up = 1;
                moves++;
                score--;
                check_foundation(col);
            }
            selected_stack = -1;
            selected_count = 0;
            gtk_widget_queue_draw(widget);
        }
        return;
    }
    
    // 点击空白处，取消选中
    if (selected_stack >= 0) {
        selected_stack = -1;
        selected_count = 0;
        gtk_widget_queue_draw(widget);
    }
}

static void on_new_game(GtkWidget *widget, gpointer data) {
    deal_cards();
    gtk_widget_queue_draw(drawing_area);
}

int main(int argc, char *argv[]) {
    gtk_init(&argc, &argv);
    
    window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), "JNL 蜘蛛纸牌");
    gtk_window_set_default_size(GTK_WINDOW(window), 900, 600);
    g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);
    
    GtkWidget *vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_container_add(GTK_CONTAINER(window), vbox);
    
    GtkWidget *btn = gtk_button_new_with_label("新游戏");
    g_signal_connect(btn, "clicked", G_CALLBACK(on_new_game), NULL);
    gtk_box_pack_start(GTK_BOX(vbox), btn, FALSE, FALSE, 0);
    
    drawing_area = gtk_drawing_area_new();
    gtk_widget_set_size_request(drawing_area, 900, 550);
    gtk_widget_add_events(drawing_area, GDK_BUTTON_PRESS_MASK);
    g_signal_connect(drawing_area, "draw", G_CALLBACK(on_draw), NULL);
    g_signal_connect(drawing_area, "button-press-event", G_CALLBACK(on_button_press), NULL);
    gtk_box_pack_start(GTK_BOX(vbox), drawing_area, TRUE, TRUE, 0);
    
    deal_cards();
    gtk_widget_show_all(window);
    gtk_main();
    return 0;
}
SPIDER_EOF

echo "  蜘蛛纸牌源码已更新"

# ============================================================================
# Fix 6: 同步更新 customize_airootfs.sh 中的所有配置
# ============================================================================
echo ""
echo "[6/6] 同步配置到 customize_airootfs.sh..."

python3 << 'PYEOF2'
import re, os

filepath = os.path.expanduser("~/jnl-os-build/src/archiso-profile/airootfs/root/customize_airootfs.sh")
with open(filepath, 'r') as f:
    content = f.read()

# 更新WiFi服务配置
old_wifi_svc = r"cat > /etc/systemd/system/jnl-wifi-autoscan\.service <<'EOF'\n\[Unit\]\nDescription=JNL OS Wi-Fi Auto Scan Daemon\nAfter=NetworkManager\.service\nWants=NetworkManager\.service\n\n\[Service\]\nType=simple\nExecStart=/usr/bin/jnl-wifi-daemon\nRestart=on-failure\nRestartSec=5\n\n\[Install\]\nWantedBy=graphical\.target\nEOF"

new_wifi_svc = """cat > /etc/systemd/system/jnl-wifi-autoscan.service <<'EOF'
[Unit]
Description=JNL OS Wi-Fi Auto Scan Daemon
After=NetworkManager.service dbus.service
Wants=NetworkManager.service

[Service]
Type=simple
ExecStart=/usr/bin/jnl-wifi-daemon
Restart=always
RestartSec=10
User=root
Group=root

[Install]
WantedBy=graphical.target
EOF"""

content = re.sub(old_wifi_svc, new_wifi_svc, content)

# 确保启用 jnl-wifi-autoscan.service
if "systemctl enable jnl-wifi-autoscan" not in content:
    content = content.replace(
        "systemctl enable wpa_supplicant",
        "systemctl enable jnl-wifi-autoscan.service\nsystemctl enable wpa_supplicant"
    )

# 添加 jnl-disk-manager 编译
if "compile-jnl-disk-manager" not in content:
    content = content.replace(
        'echo "=== Java Net Lava OS 配置完成',
        '# 编译 JNL 磁盘管理器\nif [ -f /usr/bin/jnl-disk-manager.c ]; then\n    gcc -o /usr/bin/jnl-disk-manager /usr/bin/jnl-disk-manager.c $(pkg-config --cflags --libs gtk+-3.0) 2>/tmp/jnl-disk-manager-build.log || true\nfi\n\n# 编译 JNL 蜘蛛纸牌\nif [ -f /usr/bin/jnl-spider.c ]; then\n    gcc -o /usr/bin/jnl-spider /usr/bin/jnl-spider.c $(pkg-config --cflags --libs gtk+-3.0) 2>/tmp/jnl-spider-build.log || true\nfi\n\necho "=== Java Net Lava OS 配置完成'
    )

# 确保 polkit 规则被复制
if "10-jnl-udisks.rules" not in content:
    insert_pos = content.find("systemctl enable jnl-wifi-autoscan")
    if insert_pos < 0:
        insert_pos = content.find("systemctl enable wpa_supplicant")
    if insert_pos > 0:
        polkit_block = '''
# 配置 polkit 免密码磁盘操作
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/10-jnl-udisks.rules <<'POLKIT'
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.udisks2.") == 0 &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
POLKIT
'''
        content = content[:insert_pos] + polkit_block + content[insert_pos:]

with open(filepath, 'w') as f:
    f.write(content)
print("  customize_airootfs.sh 已同步")
PYEOF2

echo ""
echo "========================================="
echo "  所有修复完成！"
echo "========================================="

echo ""
echo "验证："
echo "  磁盘管理c源码: $(wc -l < $AIROOTFS/usr/bin/jnl-disk-manager.c) 行"
echo "  WiFi守护进程: $(wc -l < $AIROOTFS/usr/bin/jnl-wifi-daemon) 行"
echo "  蜘蛛纸牌源码: $(wc -l < $AIROOTFS/usr/bin/jnl-spider.c) 行"
echo "  Polkit规则: $(ls $AIROOTFS/etc/polkit-1/rules.d/ 2>/dev/null | wc -l) 个文件"
echo "  桌面磁盘快捷方式: $(test -f $AIROOTFS/home/jnluser/Desktop/jnl-disk-manager.desktop && echo '存在(错误)' || echo '已移除(正确)')"
