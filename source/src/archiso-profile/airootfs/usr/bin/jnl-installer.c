#include <gtk/gtk.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <stdarg.h>
#include <signal.h>

#define VERSION "1.0.31"
#define LOG_FILE "/tmp/jnl-installer.log"
#define OS_ICON_PATH "/usr/share/icons/jnl-os/os.svg"
#define MUSIC_PATH "/usr/share/jnl-os/JNL install.wav"
#define NUM_STEPS 9

typedef struct {
    char language[32];
    char keyboard[32];
    char timezone[64];
    char hostname[64];
    char username[32];
    char password[64];
    char root_password[64];
    char disk[32];
    char mouse_theme[64];
    int auto_install;
} InstallerConfig;

static InstallerConfig config = {
    "zh_CN", "us", "Asia/Shanghai", "JNL-OS", "jnluser", "jnlos", "jnlos", "", "Breeze_Snow", 1
};

static GtkWidget *window;
static GtkWidget *notebook;
static GtkWidget *progress_bar;
static GtkWidget *overall_progress_bar;
static GtkWidget *status_label;
static GtkWidget *log_textview;
static GtkTextBuffer *log_buffer;
static GtkWidget *btn_next;
static GtkWidget *btn_back;
static FILE *log_file;
static gboolean install_running = FALSE;
static GPid worker_pid = 0;
static guint worker_timeout = 0;
static int current_step = 0;
static int last_log_line = 0;

static const char *step_names[NUM_STEPS] = {
    "欢迎", "语言", "许可", "类型", "磁盘", "分区", "用户", "确认", "安装"
};

static const char *step_icons[NUM_STEPS] = {
    "os", "preferences-desktop-locale", "text-x-generic", "drive-harddisk",
    "drive-removable-media", "gparted", "user-info", "dialog-information", "system-run"
};

static const char *TECH_CSS =
    "window { background-color: #050a15; }"
    ".tech-titlebar {"
    "  background: linear-gradient(135deg, rgba(0,100,255,0.35), rgba(0,200,255,0.15));"
    "  border-bottom: 1px solid rgba(0,212,255,0.3);"
    "  padding: 10px 16px;"
    "}"
    ".tech-panel { background-color: rgba(5,10,21,0.98); }"
    ".tech-header {"
    "  background: linear-gradient(135deg, rgba(0,100,255,0.18), rgba(0,200,255,0.08));"
    "  border-bottom: 1px solid rgba(0,212,255,0.2);"
    "  padding: 12px 20px;"
    "}"
    ".tech-card {"
    "  background: linear-gradient(135deg, rgba(20,35,75,0.7), rgba(10,20,50,0.5));"
    "  border: 1px solid rgba(0,212,255,0.25);"
    "  border-radius: 12px;"
    "  padding: 28px;"
    "  box-shadow: 0 0 25px rgba(0,212,255,0.08), inset 0 1px 0 rgba(255,255,255,0.03);"
    "}"
    ".tech-btn {"
    "  background: linear-gradient(135deg, #0077ff, #00b8ff);"
    "  color: white;"
    "  border: none;"
    "  border-radius: 8px;"
    "  padding: 10px 30px;"
    "  font-weight: bold;"
    "  font-size: 14px;"
    "  text-shadow: 0 1px 2px rgba(0,0,0,0.3);"
    "  box-shadow: 0 0 15px rgba(0,180,255,0.4);"
    "}"
    ".tech-btn:hover {"
    "  background: linear-gradient(135deg, #0099ff, #00ddff);"
    "  box-shadow: 0 0 25px rgba(0,220,255,0.6);"
    "}"
    ".tech-btn:active {"
    "  background: linear-gradient(135deg, #0055cc, #0099ee);"
    "  box-shadow: 0 0 10px rgba(0,168,255,0.3);"
    "}"
    ".tech-btn-secondary {"
    "  background: transparent;"
    "  color: #00d4ff;"
    "  border: 1px solid rgba(0,212,255,0.45);"
    "  border-radius: 8px;"
    "  padding: 10px 30px;"
    "  font-weight: bold;"
    "  font-size: 14px;"
    "}"
    ".tech-btn-secondary:hover {"
    "  background: rgba(0,212,255,0.12);"
    "  border-color: rgba(0,212,255,0.8);"
    "  box-shadow: 0 0 15px rgba(0,212,255,0.25);"
    "}"
    ".tech-progress trough {"
    "  background-color: #0a0a15;"
    "  border-radius: 0;"
    "  border: 1px solid #1a3a5a;"
    "  min-height: 20px;"
    "}"
    ".tech-progress progress {"
    "  background: #00aaff;"
    "  border-radius: 0;"
    "  box-shadow: 0 0 10px rgba(0,170,255,0.5);"
    "}"
    ".tech-progress {"
    "  color: #ffffff;"
    "  font-weight: bold;"
    "  font-size: 12px;"
    "}"
    ".tech-log {"
    "  background: rgba(2,5,15,0.95);"
    "  border: 1px solid rgba(0,212,255,0.2);"
    "  border-radius: 8px;"
    "  color: #00ff99;"
    "  font-family: 'Consolas', 'Monaco', monospace;"
    "  font-size: 11px;"
    "  padding: 10px;"
    "}"
    ".tech-label {"
    "  color: #ffffff;"
    "  font-size: 14px;"
    "  font-weight: 500;"
    "}"
    ".tech-label-bright {"
    "  color: #ffffff;"
    "  font-size: 16px;"
    "  font-weight: bold;"
    "}"
    ".tech-title {"
    "  color: #ffffff;"
    "  font-size: 22px;"
    "  font-weight: bold;"
    "  text-shadow: 0 0 20px rgba(0,212,255,0.6);"
    "}"
    ".tech-subtitle {"
    "  color: #00d4ff;"
    "  font-size: 13px;"
    "}"
    ".tech-entry {"
    "  background: rgba(5,10,30,0.9);"
    "  border: 1px solid rgba(0,212,255,0.35);"
    "  border-radius: 6px;"
    "  color: #ffffff;"
    "  padding: 10px 14px;"
    "  font-size: 14px;"
    "}"
    ".tech-entry:focus {"
    "  border-color: #00d4ff;"
    "  box-shadow: 0 0 10px rgba(0,212,255,0.4);"
    "}"
    ".tech-combo {"
    "  background: rgba(5,10,30,0.9);"
    "  border: 1px solid rgba(0,212,255,0.35);"
    "  border-radius: 6px;"
    "  color: #ffffff;"
    "  padding: 8px 12px;"
    "  font-size: 14px;"
    "}"
    ".tech-check {"
    "  color: #ffffff;"
    "  font-size: 14px;"
    "}"
    ".tech-radio {"
    "  color: #ffffff;"
    "  font-size: 14px;"
    "}"
    ".tech-textview {"
"  background: rgba(2,5,15,0.95);"
"  border: 1px solid rgba(0,212,255,0.2);"
"  border-radius: 8px;"
"  color: #d0e0f0;"
"  padding: 14px;"
"}"
    ".tech-listbox {"
    "  background: rgba(5,10,30,0.8);"
    "  border: 1px solid rgba(0,212,255,0.25);"
    "  border-radius: 8px;"
    "  color: #ffffff;"
    "}"
    ".tech-listbox row {"
"  background: transparent;"
"  border-bottom: 1px solid rgba(0,212,255,0.1);"
"  padding: 12px 18px;"
"  color: #d0e0f0;"
"}"
    ".tech-listbox row:selected {"
    "  background: linear-gradient(90deg, rgba(0,100,255,0.35), rgba(0,200,255,0.18));"
    "  color: #ffffff;"
    "  border-left: 3px solid #00d4ff;"
    "}"
    ".tech-warning {"
    "  color: #ff6b6b;"
    "  font-weight: bold;"
    "}"
    ".tech-success {"
    "  color: #00ff88;"
    "  font-weight: bold;"
    "}"
    ".metro-step-active {"
    "  background: linear-gradient(135deg, #0088ff, #00d4ff);"
    "  box-shadow: 0 0 20px rgba(0,212,255,0.7);"
    "  border-color: #00ffff;"
    "}"
    ".metro-step-done {"
    "  background: rgba(0,255,136,0.3);"
    "  border-color: #00ff88;"
    "}"
    ".metro-step-pending {"
    "  background: rgba(100,120,150,0.2);"
    "  border-color: rgba(150,170,200,0.4);"
    "}";

static void log_msg(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    char buf[1024];
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    if (log_file) { fprintf(log_file, "[%s] %s\n", VERSION, buf); fflush(log_file); }
    if (log_buffer) {
        GtkTextIter iter;
        gtk_text_buffer_get_end_iter(log_buffer, &iter);
        gtk_text_buffer_insert(log_buffer, &iter, buf, -1);
        gtk_text_buffer_insert(log_buffer, &iter, "\n", -1);
        gtk_text_view_scroll_to_mark(GTK_TEXT_VIEW(log_textview),
            gtk_text_buffer_get_insert(log_buffer), 0.0, TRUE, 0.0, 1.0);
    }
    g_print("[JNL] %s\n", buf);
}

static void apply_tech_style(GtkWidget *widget) {
    GtkCssProvider *provider = gtk_css_provider_new();
    gtk_css_provider_load_from_data(provider, TECH_CSS, -1, NULL);
    GdkScreen *screen = gtk_widget_get_screen(widget);
    gtk_style_context_add_provider_for_screen(screen, GTK_STYLE_PROVIDER(provider), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(provider);
}

static void add_css_class(GtkWidget *widget, const char *class_name) {
    gtk_style_context_add_class(gtk_widget_get_style_context(widget), class_name);
}

static void remove_css_class(GtkWidget *widget, const char *class_name) {
    gtk_style_context_remove_class(gtk_widget_get_style_context(widget), class_name);
}

static GdkPixbuf *load_icon_pixbuf(const char *path, int size) {
    if (path && access(path, F_OK) == 0) {
        GError *err = NULL;
        GdkPixbuf *pb = gdk_pixbuf_new_from_file_at_size(path, size, size, &err);
        if (pb) return pb;
        if (err) { g_print("加载图标失败 %s: %s\n", path, err->message); g_error_free(err); }
    }
    return NULL;
}

static GtkWidget *create_icon_image(const char *icon_name, int size) {
    GdkPixbuf *pb = NULL;
    if (strcmp(icon_name, "os") == 0) pb = load_icon_pixbuf(OS_ICON_PATH, size);
    if (pb) {
        GtkWidget *img = gtk_image_new_from_pixbuf(pb);
        g_object_unref(pb);
        return img;
    }
    GtkIconTheme *theme = gtk_icon_theme_get_default();
    if (gtk_icon_theme_has_icon(theme, icon_name))
        return gtk_image_new_from_icon_name(icon_name, GTK_ICON_SIZE_DIALOG);
    return gtk_image_new_from_icon_name("image-missing", GTK_ICON_SIZE_DIALOG);
}

static void play_music() {
    if (access(MUSIC_PATH, F_OK) != 0) {
        log_msg("音乐文件不存在: %s", MUSIC_PATH);
        return;
    }
    const char *players[] = {
        "mpv --no-video --loop=inf --volume=100",
        "paplay --volume=65535 --loop=9999",
        "mplayer -loop 0 -volume 100",
        "ffplay -nodisp -loop 0 -volume 100",
        NULL
    };
    for (int i = 0; players[i]; i++) {
        char cmd[1024];
        snprintf(cmd, sizeof(cmd), "%s \"%s\" >/dev/null 2>&1 &", players[i], MUSIC_PATH);
        int ret = system(cmd);
        if (ret == 0) {
            log_msg("音乐播放已启动 (使用: %s)", players[i]);
            return;
        }
    }
    log_msg("警告：无法播放音乐");
}

static void stop_music() {
    system("pkill -f 'mpv.*JNL.*install' 2>/dev/null || true");
    system("pkill -f 'paplay.*JNL' 2>/dev/null || true");
    system("pkill -f 'mplayer.*JNL' 2>/dev/null || true");
    system("pkill -f 'ffplay.*JNL' 2>/dev/null || true");
}

/* ========== Windows 10风格步骤指示器 ========== */

static void update_metro_steps(int step) {
    current_step = step;
}

static GtkWidget *create_metro_bar() {
    GtkWidget *bar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    add_css_class(bar, "tech-header");
    gtk_widget_set_size_request(bar, -1, 0);
    return bar;
}

/* ========== 页面创建函数 ========== */
static GtkWidget *create_page_header(const char *icon_name, const char *title_text, const char *subtitle_text) {
    GtkWidget *header = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
    add_css_class(header, "tech-header");
    gtk_container_set_border_width(GTK_CONTAINER(header), 12);
    
    GtkWidget *icon = create_icon_image(icon_name, 36);
    gtk_box_pack_start(GTK_BOX(header), icon, FALSE, FALSE, 0);
    
    GtkWidget *vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 3);
    GtkWidget *title = gtk_label_new("");
    char *tm = g_strdup_printf("<span weight='bold' color='#ffffff' size='large'>%s</span>", title_text);
    gtk_label_set_markup(GTK_LABEL(title), tm);
    g_free(tm);
    gtk_box_pack_start(GTK_BOX(vbox), title, FALSE, FALSE, 0);
    
    GtkWidget *sub = gtk_label_new("");
    char *sm = g_strdup_printf("<span color='#00d4ff' size='small'>%s</span>", subtitle_text);
    gtk_label_set_markup(GTK_LABEL(sub), sm);
    g_free(sm);
    gtk_box_pack_start(GTK_BOX(vbox), sub, FALSE, FALSE, 0);
    
    gtk_box_pack_start(GTK_BOX(header), vbox, FALSE, FALSE, 0);
    return header;
}

static GtkWidget *create_card() {
    GtkWidget *card = gtk_box_new(GTK_ORIENTATION_VERTICAL, 14);
    add_css_class(card, "tech-card");
    gtk_container_set_border_width(GTK_CONTAINER(card), 24);
    return card;
}

/* ========== 欢迎页面 ========== */
static void on_welcome_install_clicked(GtkButton *btn, gpointer data) {
    gtk_notebook_set_current_page(GTK_NOTEBOOK(notebook), 1);
}

static GtkWidget *create_welcome_page() {
    GtkWidget *page = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    GtkCssProvider *wp = gtk_css_provider_new();
    gtk_css_provider_load_from_data(wp, 
        "* { background: linear-gradient(180deg, #0a1628 0%, #1a1a2e 50%, #16213e 100%); }", 
        -1, NULL);
    gtk_style_context_add_provider(gtk_widget_get_style_context(page), GTK_STYLE_PROVIDER(wp), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(wp);
    gtk_container_set_border_width(GTK_CONTAINER(page), 0);
    
    GtkWidget *center = gtk_box_new(GTK_ORIENTATION_VERTICAL, 24);
    gtk_widget_set_halign(center, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(center, GTK_ALIGN_CENTER);
    gtk_box_pack_start(GTK_BOX(page), center, TRUE, TRUE, 0);
    
    GtkWidget *icon = create_icon_image("os", 120);
    gtk_widget_set_halign(icon, GTK_ALIGN_CENTER);
    gtk_box_pack_start(GTK_BOX(center), icon, FALSE, FALSE, 0);
    
    GtkWidget *title = gtk_label_new("");
    gtk_label_set_markup(GTK_LABEL(title), "<span size='xx-large' weight='bold' color='#ffffff'>Java Net Lava OS</span>");
    gtk_widget_set_halign(title, GTK_ALIGN_CENTER);
    gtk_box_pack_start(GTK_BOX(center), title, FALSE, FALSE, 20);
    
    GtkWidget *btn_install = gtk_button_new_with_label("现在安装");
    GtkCssProvider *bp = gtk_css_provider_new();
    gtk_css_provider_load_from_data(bp,
        ".win10-btn {"
        "  background: linear-gradient(135deg, #0066cc, #0055aa);"
        "  color: white;"
        "  border: 1px solid rgba(255,255,255,0.2);"
        "  border-radius: 4px;"
        "  padding: 12px 40px;"
        "  font-weight: bold;"
        "  font-size: 14px;"
        "}"
        ".win10-btn:hover {"
        "  background: linear-gradient(135deg, #0077dd, #0066bb);"
        "}"
        ".win10-btn:active {"
        "  background: linear-gradient(135deg, #0055aa, #004499);"
        "}", -1, NULL);
    gtk_style_context_add_provider(gtk_widget_get_style_context(btn_install), GTK_STYLE_PROVIDER(bp), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(bp);
    gtk_widget_set_name(btn_install, "win10-btn");
    gtk_widget_set_size_request(btn_install, 180, 44);
    gtk_widget_set_halign(btn_install, GTK_ALIGN_CENTER);
    gtk_box_pack_start(GTK_BOX(center), btn_install, FALSE, FALSE, 30);
    g_signal_connect(btn_install, "clicked", G_CALLBACK(on_welcome_install_clicked), NULL);
    
    GtkWidget *footer = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    gtk_widget_set_halign(footer, GTK_ALIGN_CENTER);
    gtk_box_pack_end(GTK_BOX(page), footer, FALSE, FALSE, 40);
    
    GtkWidget *repair = gtk_link_button_new_with_label("", "修复计算机");
    gtk_link_button_set_uri(GTK_LINK_BUTTON(repair), "");
    gtk_label_set_markup(GTK_LABEL(gtk_bin_get_child(GTK_BIN(repair))), "<span color='#00d4ff'>修复计算机</span>");
    gtk_widget_set_halign(repair, GTK_ALIGN_CENTER);
    gtk_box_pack_start(GTK_BOX(footer), repair, FALSE, FALSE, 0);
    
    GtkWidget *copy = gtk_label_new("");
    gtk_label_set_markup(GTK_LABEL(copy), "<span color='#607090' size='small'>© 2024-2026 Java Net Lava OS. 保留所有权利.</span>");
    gtk_widget_set_halign(copy, GTK_ALIGN_CENTER);
    gtk_box_pack_start(GTK_BOX(footer), copy, FALSE, FALSE, 5);
    
    return page;
}

/* ========== 语言选择 ========== */
static void on_lang_changed(GtkComboBox *combo, gpointer data) {
    const char *text = gtk_combo_box_text_get_active_text(GTK_COMBO_BOX_TEXT(combo));
    if (text) strncpy(config.language, text, sizeof(config.language)-1);
}
static void on_kbd_changed(GtkComboBox *combo, gpointer data) {
    const char *text = gtk_combo_box_text_get_active_text(GTK_COMBO_BOX_TEXT(combo));
    if (text) strncpy(config.keyboard, text, sizeof(config.keyboard)-1);
}
static void on_tz_changed(GtkComboBox *combo, gpointer data) {
    const char *text = gtk_combo_box_text_get_active_text(GTK_COMBO_BOX_TEXT(combo));
    if (text) strncpy(config.timezone, text, sizeof(config.timezone)-1);
}

static GtkWidget *create_language_page() {
    GtkWidget *page = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    add_css_class(page, "tech-panel");
    
    GtkWidget *card = create_card();
    GtkWidget *grid = gtk_grid_new();
    gtk_grid_set_row_spacing(GTK_GRID(grid), 18);
    gtk_grid_set_column_spacing(GTK_GRID(grid), 20);
    
    GtkWidget *lang_lbl = gtk_label_new("语言");
    add_css_class(lang_lbl, "tech-label");
    gtk_widget_set_halign(lang_lbl, GTK_ALIGN_END);
    gtk_label_set_xalign(GTK_LABEL(lang_lbl), 1.0);
    gtk_grid_attach(GTK_GRID(grid), lang_lbl, 0, 0, 1, 1);
    GtkWidget *lang = gtk_combo_box_text_new();
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(lang), "简体中文");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(lang), "English");
    gtk_combo_box_set_active(GTK_COMBO_BOX(lang), 0);
    add_css_class(lang, "tech-combo");
    gtk_widget_set_size_request(lang, 220, -1);
    gtk_widget_set_halign(lang, GTK_ALIGN_START);
    gtk_grid_attach(GTK_GRID(grid), lang, 1, 0, 1, 1);
    
    GtkWidget *kbd_lbl = gtk_label_new("键盘布局");
    add_css_class(kbd_lbl, "tech-label");
    gtk_widget_set_halign(kbd_lbl, GTK_ALIGN_END);
    gtk_label_set_xalign(GTK_LABEL(kbd_lbl), 1.0);
    gtk_grid_attach(GTK_GRID(grid), kbd_lbl, 0, 1, 1, 1);
    GtkWidget *kbd = gtk_combo_box_text_new();
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(kbd), "us");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(kbd), "cn");
    gtk_combo_box_set_active(GTK_COMBO_BOX(kbd), 0);
    add_css_class(kbd, "tech-combo");
    gtk_widget_set_size_request(kbd, 220, -1);
    gtk_widget_set_halign(kbd, GTK_ALIGN_START);
    gtk_grid_attach(GTK_GRID(grid), kbd, 1, 1, 1, 1);
    
    GtkWidget *tz_lbl = gtk_label_new("时区");
    add_css_class(tz_lbl, "tech-label");
    gtk_widget_set_halign(tz_lbl, GTK_ALIGN_END);
    gtk_label_set_xalign(GTK_LABEL(tz_lbl), 1.0);
    gtk_grid_attach(GTK_GRID(grid), tz_lbl, 0, 2, 1, 1);
    GtkWidget *tz = gtk_combo_box_text_new();
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(tz), "Asia/Shanghai");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(tz), "America/New_York");
    gtk_combo_box_set_active(GTK_COMBO_BOX(tz), 0);
    add_css_class(tz, "tech-combo");
    gtk_widget_set_size_request(tz, 220, -1);
    gtk_widget_set_halign(tz, GTK_ALIGN_START);
    gtk_grid_attach(GTK_GRID(grid), tz, 1, 2, 1, 1);
    
    gtk_box_pack_start(GTK_BOX(card), grid, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(page), card, FALSE, FALSE, 20);
    gtk_widget_set_margin_start(card, 40);
    gtk_widget_set_margin_end(card, 40);
    
    g_signal_connect(lang, "changed", G_CALLBACK(on_lang_changed), NULL);
    g_signal_connect(kbd, "changed", G_CALLBACK(on_kbd_changed), NULL);
    g_signal_connect(tz, "changed", G_CALLBACK(on_tz_changed), NULL);
    return page;
}

/* ========== 许可协议 ========== */
static GtkWidget *create_license_page() {
    GtkWidget *page = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    add_css_class(page, "tech-panel");
    
    GtkWidget *card = create_card();
    GtkWidget *sw = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(sw), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
    gtk_widget_set_size_request(sw, -1, 240);
    
    GtkWidget *tv = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(tv), FALSE);
    gtk_text_view_set_cursor_visible(GTK_TEXT_VIEW(tv), FALSE);
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(tv), GTK_WRAP_WORD);
    add_css_class(tv, "tech-textview");
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(GTK_TEXT_VIEW(tv)),
        "Java Net Lava OS 许可协议\n\n"
        "版权所有 (C) 2026 Java Net Lava OS 开发团队\n\n"
        "本软件是一款开源操作系统，基于 Arch Linux 构建。\n\n"
        "您可以自由使用、复制和分发本软件，但必须遵守以下条款：\n\n"
        "1. 本软件仅供学习和研究目的使用。\n"
        "2. 在分发本软件时，必须包含原始的许可证文件。\n"
        "3. 不得将本软件用于任何非法活动。\n"
        "4. 本软件不提供任何形式的担保或保证。\n"
        "5. 开发者不对因使用本软件造成的任何损失负责。\n", -1);
    gtk_container_add(GTK_CONTAINER(sw), tv);
    gtk_box_pack_start(GTK_BOX(card), sw, TRUE, TRUE, 0);
    
    GtkWidget *check = gtk_check_button_new_with_label("我接受许可协议");
    add_css_class(check, "tech-check");
    gtk_box_pack_start(GTK_BOX(card), check, FALSE, FALSE, 12);
    
    gtk_box_pack_start(GTK_BOX(page), card, FALSE, FALSE, 20);
    gtk_widget_set_margin_start(card, 20);
    gtk_widget_set_margin_end(card, 20);
    g_object_set_data(G_OBJECT(page), "license_check", check);
    return page;
}

/* ========== 安装类型 ========== */
static void on_auto_toggled(GtkToggleButton *btn, gpointer data) {
    config.auto_install = gtk_toggle_button_get_active(btn) ? 1 : 0;
}

static GtkWidget *create_install_type_page() {
    GtkWidget *page = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    add_css_class(page, "tech-panel");
    
    GtkWidget *card = create_card();
    GtkWidget *vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 14);
    
    GtkWidget *auto_radio = gtk_radio_button_new_with_label(NULL, "自动安装（推荐）");
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(auto_radio), TRUE);
    add_css_class(auto_radio, "tech-radio");
    gtk_box_pack_start(GTK_BOX(vbox), auto_radio, FALSE, FALSE, 0);
    
    GtkWidget *auto_desc = gtk_label_new("系统将自动分区整个磁盘，清除所有数据。适合全新安装。");
    gtk_label_set_line_wrap(GTK_LABEL(auto_desc), TRUE);
    gtk_widget_set_margin_start(auto_desc, 30);
    gtk_label_set_markup(GTK_LABEL(auto_desc), "<span color='#b0c0d8'>系统将自动分区整个磁盘，清除所有数据。适合全新安装。</span>");
    gtk_box_pack_start(GTK_BOX(vbox), auto_desc, FALSE, FALSE, 0);
    
    GtkWidget *manual_radio = gtk_radio_button_new_with_label_from_widget(GTK_RADIO_BUTTON(auto_radio), "手动安装");
    add_css_class(manual_radio, "tech-radio");
    gtk_box_pack_start(GTK_BOX(vbox), manual_radio, FALSE, FALSE, 8);
    
    GtkWidget *manual_desc = gtk_label_new("手动选择分区和文件系统。适合高级用户。");
    gtk_label_set_line_wrap(GTK_LABEL(manual_desc), TRUE);
    gtk_widget_set_margin_start(manual_desc, 30);
    gtk_label_set_markup(GTK_LABEL(manual_desc), "<span color='#b0c0d8'>手动选择分区和文件系统。适合高级用户。</span>");
    gtk_box_pack_start(GTK_BOX(vbox), manual_desc, FALSE, FALSE, 0);
    
    gtk_box_pack_start(GTK_BOX(card), vbox, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(page), card, FALSE, FALSE, 20);
    gtk_widget_set_margin_start(card, 20);
    gtk_widget_set_margin_end(card, 20);
    
    g_signal_connect(auto_radio, "toggled", G_CALLBACK(on_auto_toggled), NULL);
    return page;
}

/* ========== 磁盘选择 ========== */
static GtkWidget *create_disk_page() {
    GtkWidget *page = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    add_css_class(page, "tech-panel");
    
    GtkWidget *card = create_card();
    GtkWidget *sw = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(sw), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
    gtk_widget_set_size_request(sw, -1, 200);
    
    GtkWidget *listbox = gtk_list_box_new();
    gtk_list_box_set_selection_mode(GTK_LIST_BOX(listbox), GTK_SELECTION_SINGLE);
    add_css_class(listbox, "tech-listbox");
    
    FILE *fp = popen("lsblk -nrpo NAME,TYPE,SIZE,MODEL 2>/dev/null", "r");
    if (fp) {
        char line[256], name[64], type[32], size[32], model[128];
        while (fgets(line, sizeof(line), fp)) {
            if (sscanf(line, "%63s %31s %31s %127[^\n]", name, type, size, model) >= 3) {
                if (strcmp(type, "disk") == 0) {
                    GtkWidget *row = gtk_list_box_row_new();
                    char *lt = g_strdup_printf("%s  (%s)  %s", name, size, model);
                    GtkWidget *label = gtk_label_new(lt);
                    gtk_widget_set_halign(label, GTK_ALIGN_START);
                    gtk_label_set_line_wrap(GTK_LABEL(label), TRUE);
                    gtk_container_add(GTK_CONTAINER(row), label);
                    gtk_list_box_insert(GTK_LIST_BOX(listbox), row, -1);
                    g_object_set_data_full(G_OBJECT(row), "disk_name", g_strdup(name), g_free);
                    g_free(lt);
                }
            }
        }
        pclose(fp);
    }
    
    gtk_container_add(GTK_CONTAINER(sw), listbox);
    gtk_box_pack_start(GTK_BOX(card), sw, TRUE, TRUE, 0);
    
    GtkWidget *warn = gtk_label_new("");
    gtk_label_set_markup(GTK_LABEL(warn), "<span color='#ff6b6b'><b>警告：安装将清除目标磁盘上的所有数据！</b></span>");
    gtk_box_pack_start(GTK_BOX(card), warn, FALSE, FALSE, 10);
    
    gtk_box_pack_start(GTK_BOX(page), card, FALSE, FALSE, 20);
    gtk_widget_set_margin_start(card, 20);
    gtk_widget_set_margin_end(card, 20);
    g_object_set_data(G_OBJECT(page), "disk_list", listbox);
    return page;
}

/* ========== 分区管理（手动模式）========== */
static void on_new_partition(GtkButton *btn, gpointer data) {
    if (!config.disk[0]) return;
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "gparted %s", config.disk);
    system(cmd);
}

static void on_edit_partition(GtkButton *btn, gpointer data) {
    if (!config.disk[0]) return;
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "gparted %s", config.disk);
    system(cmd);
}

static void on_delete_partition(GtkButton *btn, gpointer data) {
    if (!config.disk[0]) return;
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "gparted %s", config.disk);
    system(cmd);
}

static GtkWidget *create_partition_page() {
    GtkWidget *page = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    add_css_class(page, "tech-panel");
    
    GtkWidget *card = create_card();
    GtkWidget *sw = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(sw), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
    gtk_widget_set_size_request(sw, -1, 200);
    
    GtkWidget *listbox = gtk_list_box_new();
    gtk_list_box_set_selection_mode(GTK_LIST_BOX(listbox), GTK_SELECTION_NONE);
    add_css_class(listbox, "tech-listbox");
    
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "lsblk -nrpo NAME,TYPE,SIZE,FSTYPE,MOUNTPOINT 2>/dev/null");
    FILE *fp = popen(cmd, "r");
    if (fp) {
        char line[512], name[64], type[32], size[32], fstype[32], mount[128];
        while (fgets(line, sizeof(line), fp)) {
            if (sscanf(line, "%63s %31s %31s %31s %127[^\n]", name, type, size, fstype, mount) >= 4) {
                if (strncmp(name, config.disk, strlen(config.disk)) == 0) {
                    GtkWidget *row = gtk_list_box_row_new();
                    GtkWidget *hbox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
                    char *lt = g_strdup_printf("<b>%s</b>  (%s)  <span color='#00d4ff'>%s</span>  %s", 
                        name, size, fstype[0] ? fstype : "未格式化", mount[0] ? mount : "未挂载");
                    GtkWidget *label = gtk_label_new("");
                    gtk_label_set_markup(GTK_LABEL(label), lt);
                    gtk_widget_set_halign(label, GTK_ALIGN_START);
                    gtk_container_add(GTK_CONTAINER(hbox), label);
                    gtk_container_add(GTK_CONTAINER(row), hbox);
                    gtk_list_box_insert(GTK_LIST_BOX(listbox), row, -1);
                    g_free(lt);
                }
            }
        }
        pclose(fp);
    }
    
    gtk_container_add(GTK_CONTAINER(sw), listbox);
    gtk_box_pack_start(GTK_BOX(card), sw, TRUE, TRUE, 0);
    
    GtkWidget *btn_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    GtkWidget *btn_new = gtk_button_new_with_label("新建分区");
    add_css_class(btn_new, "tech-btn");
    gtk_box_pack_start(GTK_BOX(btn_box), btn_new, FALSE, FALSE, 0);
    g_signal_connect(btn_new, "clicked", G_CALLBACK(on_new_partition), NULL);
    
    GtkWidget *btn_edit = gtk_button_new_with_label("编辑分区");
    add_css_class(btn_edit, "tech-btn-secondary");
    gtk_box_pack_start(GTK_BOX(btn_box), btn_edit, FALSE, FALSE, 0);
    g_signal_connect(btn_edit, "clicked", G_CALLBACK(on_edit_partition), NULL);
    
    GtkWidget *btn_del = gtk_button_new_with_label("删除分区");
    add_css_class(btn_del, "tech-btn-secondary");
    gtk_box_pack_start(GTK_BOX(btn_box), btn_del, FALSE, FALSE, 0);
    g_signal_connect(btn_del, "clicked", G_CALLBACK(on_delete_partition), NULL);
    
    gtk_box_pack_start(GTK_BOX(card), btn_box, FALSE, FALSE, 10);
    
    GtkWidget *warn = gtk_label_new("");
    gtk_label_set_markup(GTK_LABEL(warn), "<span color='#ff6b6b'><b>警告：手动分区操作将清除分区数据！</b></span>");
    gtk_box_pack_start(GTK_BOX(card), warn, FALSE, FALSE, 10);
    
    gtk_box_pack_start(GTK_BOX(page), card, FALSE, FALSE, 20);
    gtk_widget_set_margin_start(card, 20);
    gtk_widget_set_margin_end(card, 20);
    
    g_object_set_data(G_OBJECT(page), "partition_list", listbox);
    return page;
}

/* ========== 用户配置 ========== */
static void on_host_changed(GtkEditable *e, gpointer d) { strncpy(config.hostname, gtk_entry_get_text(GTK_ENTRY(e)), sizeof(config.hostname)-1); }
static void on_user_changed(GtkEditable *e, gpointer d) { strncpy(config.username, gtk_entry_get_text(GTK_ENTRY(e)), sizeof(config.username)-1); }
static void on_pass_changed(GtkEditable *e, gpointer d) { strncpy(config.password, gtk_entry_get_text(GTK_ENTRY(e)), sizeof(config.password)-1); }
static void on_root_pass_changed(GtkEditable *e, gpointer d) { strncpy(config.root_password, gtk_entry_get_text(GTK_ENTRY(e)), sizeof(config.root_password)-1); }

static GtkWidget *create_user_page() {
    GtkWidget *page = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    add_css_class(page, "tech-panel");
    
    GtkWidget *content = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 40);
    gtk_widget_set_halign(content, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(content, GTK_ALIGN_CENTER);
    gtk_box_pack_start(GTK_BOX(page), content, TRUE, TRUE, 0);
    
    GtkWidget *left = gtk_box_new(GTK_ORIENTATION_VERTICAL, 16);
    gtk_widget_set_halign(left, GTK_ALIGN_CENTER);
    
    GtkWidget *user_icon = create_icon_image("user-info", 100);
    gtk_widget_set_halign(user_icon, GTK_ALIGN_CENTER);
    gtk_box_pack_start(GTK_BOX(left), user_icon, FALSE, FALSE, 0);
    
    GtkWidget *deco_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    GtkWidget *dot1 = gtk_drawing_area_new();
    gtk_widget_set_size_request(dot1, 20, 20);
    GtkCssProvider *dp1 = gtk_css_provider_new();
    gtk_css_provider_load_from_data(dp1, "* { background: #00d4ff; border-radius: 50%; }", -1, NULL);
    gtk_style_context_add_provider(gtk_widget_get_style_context(dot1), GTK_STYLE_PROVIDER(dp1), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(dp1);
    gtk_box_pack_start(GTK_BOX(deco_box), dot1, FALSE, FALSE, 0);
    
    GtkWidget *dot2 = gtk_drawing_area_new();
    gtk_widget_set_size_request(dot2, 20, 20);
    GtkCssProvider *dp2 = gtk_css_provider_new();
    gtk_css_provider_load_from_data(dp2, "* { background: #00d4ff; border-radius: 50%; opacity: 0.6; }", -1, NULL);
    gtk_style_context_add_provider(gtk_widget_get_style_context(dot2), GTK_STYLE_PROVIDER(dp2), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(dp2);
    gtk_box_pack_start(GTK_BOX(deco_box), dot2, FALSE, FALSE, 0);
    
    gtk_box_pack_start(GTK_BOX(left), deco_box, FALSE, FALSE, 20);
    gtk_box_pack_start(GTK_BOX(content), left, FALSE, FALSE, 0);
    
    GtkWidget *right = gtk_box_new(GTK_ORIENTATION_VERTICAL, 20);
    gtk_widget_set_halign(right, GTK_ALIGN_START);
    
    GtkWidget *title = gtk_label_new("");
    gtk_label_set_markup(GTK_LABEL(title), "<span size='large' weight='bold' color='#ffffff'>创建用户账户</span>");
    gtk_widget_set_halign(title, GTK_ALIGN_START);
    gtk_box_pack_start(GTK_BOX(right), title, FALSE, FALSE, 0);
    
    GtkWidget *desc = gtk_label_new("");
    gtk_label_set_markup(GTK_LABEL(desc), "<span color='#b0c0d8' size='small'>设置您的用户名和密码，用于登录系统。</span>");
    gtk_label_set_line_wrap(GTK_LABEL(desc), TRUE);
    gtk_widget_set_size_request(desc, 400, -1);
    gtk_widget_set_halign(desc, GTK_ALIGN_START);
    gtk_box_pack_start(GTK_BOX(right), desc, FALSE, FALSE, 5);
    
    GtkWidget *form = gtk_box_new(GTK_ORIENTATION_VERTICAL, 18);
    gtk_widget_set_margin_top(form, 20);
    
    GtkWidget *host_row = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4);
    GtkWidget *host_lbl = gtk_label_new("主机名");
    gtk_label_set_markup(GTK_LABEL(host_lbl), "<span color='#00d4ff' size='small'>主机名</span>");
    gtk_widget_set_halign(host_lbl, GTK_ALIGN_START);
    gtk_box_pack_start(GTK_BOX(host_row), host_lbl, FALSE, FALSE, 0);
    GtkWidget *host_entry = gtk_entry_new();
    gtk_entry_set_text(GTK_ENTRY(host_entry), "JNL-OS");
    gtk_widget_set_size_request(host_entry, 320, 40);
    add_css_class(host_entry, "tech-entry");
    gtk_box_pack_start(GTK_BOX(host_row), host_entry, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(form), host_row, FALSE, FALSE, 0);
    g_signal_connect(host_entry, "changed", G_CALLBACK(on_host_changed), NULL);
    
    GtkWidget *user_row = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4);
    GtkWidget *user_lbl = gtk_label_new("用户名");
    gtk_label_set_markup(GTK_LABEL(user_lbl), "<span color='#00d4ff' size='small'>用户名</span>");
    gtk_widget_set_halign(user_lbl, GTK_ALIGN_START);
    gtk_box_pack_start(GTK_BOX(user_row), user_lbl, FALSE, FALSE, 0);
    GtkWidget *user_entry = gtk_entry_new();
    gtk_entry_set_text(GTK_ENTRY(user_entry), "jnluser");
    gtk_widget_set_size_request(user_entry, 320, 40);
    add_css_class(user_entry, "tech-entry");
    gtk_box_pack_start(GTK_BOX(user_row), user_entry, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(form), user_row, FALSE, FALSE, 0);
    g_signal_connect(user_entry, "changed", G_CALLBACK(on_user_changed), NULL);
    
    GtkWidget *pass_row = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4);
    GtkWidget *pass_lbl = gtk_label_new("密码");
    gtk_label_set_markup(GTK_LABEL(pass_lbl), "<span color='#00d4ff' size='small'>密码</span>");
    gtk_widget_set_halign(pass_lbl, GTK_ALIGN_START);
    gtk_box_pack_start(GTK_BOX(pass_row), pass_lbl, FALSE, FALSE, 0);
    GtkWidget *pass_entry = gtk_entry_new();
    gtk_entry_set_text(GTK_ENTRY(pass_entry), "jnlos");
    gtk_entry_set_visibility(GTK_ENTRY(pass_entry), FALSE);
    gtk_widget_set_size_request(pass_entry, 320, 40);
    add_css_class(pass_entry, "tech-entry");
    gtk_box_pack_start(GTK_BOX(pass_row), pass_entry, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(form), pass_row, FALSE, FALSE, 0);
    g_signal_connect(pass_entry, "changed", G_CALLBACK(on_pass_changed), NULL);
    
    GtkWidget *root_pass_row = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4);
    GtkWidget *root_pass_lbl = gtk_label_new("管理员密码");
    gtk_label_set_markup(GTK_LABEL(root_pass_lbl), "<span color='#00d4ff' size='small'>管理员密码</span>");
    gtk_widget_set_halign(root_pass_lbl, GTK_ALIGN_START);
    gtk_box_pack_start(GTK_BOX(root_pass_row), root_pass_lbl, FALSE, FALSE, 0);
    GtkWidget *root_pass_entry = gtk_entry_new();
    gtk_entry_set_text(GTK_ENTRY(root_pass_entry), "jnlos");
    gtk_entry_set_visibility(GTK_ENTRY(root_pass_entry), FALSE);
    gtk_widget_set_size_request(root_pass_entry, 320, 40);
    add_css_class(root_pass_entry, "tech-entry");
    gtk_box_pack_start(GTK_BOX(root_pass_row), root_pass_entry, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(form), root_pass_row, FALSE, FALSE, 0);
    g_signal_connect(root_pass_entry, "changed", G_CALLBACK(on_root_pass_changed), NULL);
    
    gtk_box_pack_start(GTK_BOX(right), form, FALSE, FALSE, 0);
    
    gtk_box_pack_start(GTK_BOX(content), right, FALSE, FALSE, 0);
    
    return page;
}

/* ========== 安装确认 ========== */
static GtkWidget *create_confirm_page() {
    GtkWidget *page = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    add_css_class(page, "tech-panel");
    
    GtkWidget *card = create_card();
    GtkWidget *grid = gtk_grid_new();
    gtk_grid_set_row_spacing(GTK_GRID(grid), 10);
    gtk_grid_set_column_spacing(GTK_GRID(grid), 24);
    
    const char *labels[] = {"语言", "键盘", "时区", "主机名", "用户名", "安装类型", "目标磁盘"};
    const char *values[] = {
        config.language, config.keyboard, config.timezone,
        config.hostname, config.username,
        config.auto_install ? "自动安装" : "手动安装",
        config.disk[0] ? config.disk : "未选择"
    };
    for (int i = 0; i < 7; i++) {
        GtkWidget *l = gtk_label_new("");
        gtk_label_set_markup(GTK_LABEL(l), g_strdup_printf("<span color='#00d4ff'>%s</span>", labels[i]));
        gtk_widget_set_halign(l, GTK_ALIGN_END);
        gtk_label_set_xalign(GTK_LABEL(l), 1.0);
        gtk_grid_attach(GTK_GRID(grid), l, 0, i, 1, 1);
        GtkWidget *v = gtk_label_new(values[i]);
        gtk_label_set_markup(GTK_LABEL(v), g_strdup_printf("<span color='#ffffff'>%s</span>", values[i]));
        gtk_widget_set_halign(v, GTK_ALIGN_START);
        gtk_label_set_line_wrap(GTK_LABEL(v), TRUE);
        gtk_grid_attach(GTK_GRID(grid), v, 1, i, 1, 1);
    }
    
    gtk_box_pack_start(GTK_BOX(card), grid, FALSE, FALSE, 0);
    GtkWidget *warn = gtk_label_new("");
    gtk_label_set_markup(GTK_LABEL(warn), "<span color='#ff6b6b'><b>警告：点击\"安装\"后将开始安装，此过程无法取消！</b></span>");
    gtk_label_set_line_wrap(GTK_LABEL(warn), TRUE);
    gtk_box_pack_start(GTK_BOX(card), warn, FALSE, FALSE, 15);
    
    gtk_box_pack_start(GTK_BOX(page), card, FALSE, FALSE, 20);
    gtk_widget_set_margin_start(card, 40);
    gtk_widget_set_margin_end(card, 40);
    return page;
}

/* ========== 正在安装 ========== */
static GtkWidget *create_install_page() {
    GtkWidget *page = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    add_css_class(page, "tech-panel");
    
    GtkWidget *card = create_card();
    GtkWidget *vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 14);
    
    progress_bar = gtk_progress_bar_new();
    gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(progress_bar), 0.0);
    gtk_progress_bar_set_text(GTK_PROGRESS_BAR(progress_bar), "准备安装...");
    gtk_progress_bar_set_show_text(GTK_PROGRESS_BAR(progress_bar), TRUE);
    add_css_class(progress_bar, "tech-progress");
    gtk_widget_set_size_request(progress_bar, -1, 20);
    gtk_box_pack_start(GTK_BOX(vbox), progress_bar, FALSE, FALSE, 0);
    
    status_label = gtk_label_new("等待开始...");
    gtk_widget_set_halign(status_label, GTK_ALIGN_START);
    gtk_label_set_markup(GTK_LABEL(status_label), "<span color='#00d4ff'>等待开始...</span>");
    gtk_box_pack_start(GTK_BOX(vbox), status_label, FALSE, FALSE, 0);
    
    log_textview = gtk_text_view_new();
    log_buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(log_textview));
    gtk_text_view_set_editable(GTK_TEXT_VIEW(log_textview), FALSE);
    gtk_text_view_set_cursor_visible(GTK_TEXT_VIEW(log_textview), FALSE);
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(log_textview), GTK_WRAP_WORD_CHAR);
    add_css_class(log_textview, "tech-log");
    
    PangoFontDescription *fd = pango_font_description_from_string("Monospace 11");
    gtk_widget_override_font(log_textview, fd);
    pango_font_description_free(fd);
    
    GtkWidget *sw = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(sw), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
    gtk_widget_set_size_request(sw, -1, 200);
    gtk_container_add(GTK_CONTAINER(sw), log_textview);
    gtk_box_pack_start(GTK_BOX(vbox), sw, TRUE, TRUE, 0);
    
    gtk_box_pack_start(GTK_BOX(card), vbox, TRUE, TRUE, 0);
    gtk_box_pack_start(GTK_BOX(page), card, TRUE, TRUE, 20);
    gtk_widget_set_margin_start(card, 20);
    gtk_widget_set_margin_end(card, 20);
    return page;
}

/* ========== 个性化设置 ========== */
static void on_mouse_changed(GtkComboBox *combo, gpointer data) {
    const char *text = gtk_combo_box_text_get_active_text(GTK_COMBO_BOX_TEXT(combo));
    if (text) strncpy(config.mouse_theme, text, sizeof(config.mouse_theme)-1);
}

static GtkWidget *create_personalize_page() {
    GtkWidget *page = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    add_css_class(page, "tech-panel");
    
    GtkWidget *card = create_card();
    GtkWidget *grid = gtk_grid_new();
    gtk_grid_set_row_spacing(GTK_GRID(grid), 18);
    gtk_grid_set_column_spacing(GTK_GRID(grid), 16);
    
    GtkWidget *mouse_lbl = gtk_label_new("鼠标指针样式");
    add_css_class(mouse_lbl, "tech-label");
    gtk_widget_set_halign(mouse_lbl, GTK_ALIGN_END);
    gtk_grid_attach(GTK_GRID(grid), mouse_lbl, 0, 0, 1, 1);
    GtkWidget *mouse = gtk_combo_box_text_new();
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(mouse), "Breeze_Snow (白色)");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(mouse), "Breeze_Dark (黑色)");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(mouse), "Adwaita (默认)");
    gtk_combo_box_set_active(GTK_COMBO_BOX(mouse), 0);
    add_css_class(mouse, "tech-combo");
    gtk_widget_set_size_request(mouse, 200, -1);
    gtk_grid_attach(GTK_GRID(grid), mouse, 1, 0, 1, 1);
    
    GtkWidget *net_lbl = gtk_label_new("网络设置");
    add_css_class(net_lbl, "tech-label");
    gtk_widget_set_halign(net_lbl, GTK_ALIGN_END);
    gtk_grid_attach(GTK_GRID(grid), net_lbl, 0, 1, 1, 1);
    GtkWidget *net = gtk_label_new("网络管理器已自动配置\nWiFi 和以太网连接可用");
    gtk_label_set_line_wrap(GTK_LABEL(net), TRUE);
    gtk_widget_set_halign(net, GTK_ALIGN_START);
    gtk_label_set_markup(GTK_LABEL(net), "<span color='#b0c0d8'>网络管理器已自动配置\nWiFi 和以太网连接可用</span>");
    gtk_grid_attach(GTK_GRID(grid), net, 1, 1, 1, 1);
    
    gtk_box_pack_start(GTK_BOX(card), grid, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(page), card, FALSE, FALSE, 20);
    gtk_widget_set_margin_start(card, 20);
    gtk_widget_set_margin_end(card, 20);
    
    g_signal_connect(mouse, "changed", G_CALLBACK(on_mouse_changed), NULL);
    return page;
}

/* ========== 安装完成 ========== */
static GtkWidget *create_done_page() {
    GtkWidget *page = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    add_css_class(page, "tech-panel");
    
    GtkWidget *card = create_card();
    GtkWidget *vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 18);
    gtk_widget_set_halign(vbox, GTK_ALIGN_CENTER);
    
    GtkWidget *big_icon = create_icon_image("emblem-ok", 70);
    gtk_widget_set_halign(big_icon, GTK_ALIGN_CENTER);
    gtk_box_pack_start(GTK_BOX(vbox), big_icon, FALSE, FALSE, 0);
    
    GtkWidget *desc = gtk_label_new("");
    gtk_label_set_markup(GTK_LABEL(desc),
        "<span color='#ffffff'>Java Net Lava OS 已成功安装！</span>\n\n"
        "<span color='#b0c0d8'>安装信息：\n"
        "版本: 1.0.31\n"
        "用户名: jnluser\n"
        "主机名: JNL-OS\n\n"
        "请移除安装介质（U盘），然后点击\"重启\"按钮。</span>");
    gtk_label_set_line_wrap(GTK_LABEL(desc), TRUE);
    gtk_widget_set_halign(desc, GTK_ALIGN_CENTER);
    gtk_box_pack_start(GTK_BOX(vbox), desc, FALSE, FALSE, 0);
    
    gtk_box_pack_start(GTK_BOX(card), vbox, TRUE, TRUE, 0);
    gtk_box_pack_start(GTK_BOX(page), card, TRUE, TRUE, 20);
    gtk_widget_set_margin_start(card, 20);
    gtk_widget_set_margin_end(card, 20);
    return page;
}

/* ========== 安装启动 ========== */
static void save_config() {
    FILE *f = fopen("/tmp/jnl-installer-config.json", "w");
    if (!f) { log_msg("无法保存配置文件"); return; }
    fprintf(f, "{\n");
    fprintf(f, "  \"language\": \"%s\",\n", config.language);
    fprintf(f, "  \"keyboard\": \"%s\",\n", config.keyboard);
    fprintf(f, "  \"timezone\": \"%s\",\n", config.timezone);
    fprintf(f, "  \"hostname\": \"%s\",\n", config.hostname);
    fprintf(f, "  \"username\": \"%s\",\n", config.username);
    fprintf(f, "  \"user_password\": \"%s\",\n", config.password);
    fprintf(f, "  \"root_password\": \"%s\",\n", config.root_password);
    fprintf(f, "  \"target_disk\": \"%s\",\n", config.disk);
    fprintf(f, "  \"install_mode\": \"%s\",\n", config.auto_install ? "auto" : "manual");
    fprintf(f, "  \"mouse_theme\": \"%s\"\n", config.mouse_theme);
    fprintf(f, "}\n");
    fclose(f);
    log_msg("配置已保存");
}

static void on_worker_exit(GPid pid, gint status, gpointer data) {
    g_spawn_close_pid(pid);
    worker_pid = 0;

    if (!install_running) return;

    if (access("/tmp/jnl-install-complete", F_OK) == 0) {
        log_msg("安装完成！");
        install_running = FALSE;
        stop_music();
        gtk_notebook_set_current_page(GTK_NOTEBOOK(notebook), 9);
        gtk_widget_set_sensitive(btn_next, TRUE);
        gtk_widget_set_sensitive(btn_back, FALSE);
        return;
    }

    if (access("/tmp/jnl-installer-error", F_OK) == 0) {
        log_msg("安装出错！");
    } else {
        log_msg("安装进程异常退出 (状态码: %d)", status);
        FILE *fp = fopen("/tmp/jnl-installer-error", "w");
        if (fp) {
            fprintf(fp, "安装进程异常退出，状态码: %d\n", status);
            fclose(fp);
        }
    }
    install_running = FALSE;
    stop_music();
    gtk_label_set_markup(GTK_LABEL(status_label), "<span color='#ff6b6b'>安装失败，请查看日志</span>");
    gtk_widget_set_sensitive(btn_back, TRUE);
}

static gboolean check_worker(gpointer data) {
    if (!install_running) return FALSE;

    char buf[2048];
    FILE *fp = popen("cat /tmp/jnl-installer-worker.log 2>/dev/null", "r");
    if (fp) {
        int line_count = 0;
        while (fgets(buf, sizeof(buf), fp)) {
            line_count++;
        }
        pclose(fp);

        if (line_count == last_log_line) {
            return TRUE;
        }
        last_log_line = line_count;

        fp = popen("cat /tmp/jnl-installer-worker.log 2>/dev/null", "r");
        if (fp) {
            gtk_text_buffer_set_text(log_buffer, "", -1);
            while (fgets(buf, sizeof(buf), fp)) {
                buf[strcspn(buf, "\n")] = 0;
                if (strncmp(buf, "STEP|", 5) == 0) {
                    int step, total = NUM_STEPS;
                    char status[256] = {0};
                    if (sscanf(buf, "STEP|%d|%255[^\n]", &step, status) == 2) {
                        double frac = (double)(step + 1) / total;
                        if (frac > 1.0) frac = 1.0;
                        gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(progress_bar), frac);
                        gtk_progress_bar_set_text(GTK_PROGRESS_BAR(progress_bar), status);
                        char *markup = g_strdup_printf("<span color='#00d4ff'>%s</span>", status);
                        gtk_label_set_markup(GTK_LABEL(status_label), markup);
                        g_free(markup);

                        if (overall_progress_bar) {
                            double pre_install_frac = 0.3;
                            double install_range = 0.7;
                            double overall_frac = pre_install_frac + frac * install_range;
                            if (overall_frac > 1.0) overall_frac = 1.0;
                            char percent[64];
                            snprintf(percent, sizeof(percent), "%.0f%% - %s", overall_frac * 100, status);
                            gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(overall_progress_bar), overall_frac);
                            gtk_progress_bar_set_text(GTK_PROGRESS_BAR(overall_progress_bar), percent);
                        }
                    }
                }
                if (strlen(buf) > 0) {
                    log_msg("%s", buf);
                }
            }
            pclose(fp);
        }
    }

    if (access("/tmp/jnl-install-complete", F_OK) == 0) {
        log_msg("安装完成！");
        install_running = FALSE;
        stop_music();
        gtk_notebook_set_current_page(GTK_NOTEBOOK(notebook), 9);
        gtk_widget_set_sensitive(btn_next, TRUE);
        gtk_widget_set_sensitive(btn_back, FALSE);
        return FALSE;
    }

    if (access("/tmp/jnl-installer-error", F_OK) == 0) {
        log_msg("安装出错！");
        install_running = FALSE;
        stop_music();
        gtk_widget_set_sensitive(btn_back, TRUE);
        return FALSE;
    }

    return TRUE;
}

static void start_install() {
    install_running = TRUE;
    gtk_widget_set_sensitive(btn_next, FALSE);
    gtk_widget_set_sensitive(btn_back, FALSE);

    save_config();

    /* 清理旧标记文件 */
    unlink("/tmp/jnl-install-complete");
    unlink("/tmp/jnl-installer-error");
    unlink("/tmp/jnl-installer-worker.log");

    gchar *methods[4][3] = {
        {"/usr/bin/pkexec", "/usr/bin/jnl-installer-worker", "/tmp/jnl-installer-config.json"},
        {"pkexec", "/usr/bin/jnl-installer-worker", "/tmp/jnl-installer-config.json"},
        {"sudo", "/usr/bin/jnl-installer-worker", "/tmp/jnl-installer-config.json"},
        {"/usr/bin/jnl-installer-worker", "/tmp/jnl-installer-config.json", NULL}
    };

    gboolean result = FALSE;
    GError *err = NULL;

    for (int i = 0; i < 4; i++) {
        gchar **args = g_new(gchar*, 4);
        int idx = 0;
        for (int j = 0; j < 3 && methods[i][j]; j++) {
            args[idx++] = (gchar*)methods[i][j];
        }
        args[idx] = NULL;

        err = NULL;
        result = g_spawn_async(
            NULL, args, NULL, G_SPAWN_DO_NOT_REAP_CHILD,
            NULL, NULL, &worker_pid, &err);

        g_free(args);

        if (result) {
            log_msg("安装进程已启动 (PID: %d, 方法: %s)", worker_pid, methods[i][0]);
            break;
        }
        if (err) {
            log_msg("尝试方法 %d 失败: %s", i, err->message);
            g_error_free(err);
        }
    }

    if (!result) {
        install_running = FALSE;
        gtk_widget_set_sensitive(btn_back, TRUE);
        gtk_label_set_markup(GTK_LABEL(status_label), "<span color='#ff6b6b'>安装启动失败，无法获取管理员权限</span>");
        return;
    }

    log_msg("安装进程已启动 (PID: %d)", worker_pid);
    gtk_label_set_markup(GTK_LABEL(status_label), "<span color='#00d4ff'>安装进行中...</span>");

    /* 监控子进程退出 */
    g_child_watch_add(worker_pid, on_worker_exit, NULL);

    worker_timeout = g_timeout_add(300, check_worker, NULL);
}

/* ========== 导航 ========== */
static void on_next(GtkButton *btn, gpointer data) {
    int current = gtk_notebook_get_current_page(GTK_NOTEBOOK(notebook));
    int n_pages = gtk_notebook_get_n_pages(GTK_NOTEBOOK(notebook));

    if (current == 2) {
        GtkWidget *check = g_object_get_data(G_OBJECT(gtk_notebook_get_nth_page(GTK_NOTEBOOK(notebook), 2)), "license_check");
        if (!gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(check))) {
            g_print("请先接受许可协议\n");
            return;
        }
    }

    if (current == 4) {
        GtkWidget *listbox = g_object_get_data(G_OBJECT(gtk_notebook_get_nth_page(GTK_NOTEBOOK(notebook), 4)), "disk_list");
        GtkListBoxRow *row = gtk_list_box_get_selected_row(GTK_LIST_BOX(listbox));
        if (!row) {
            g_print("请选择目标磁盘\n");
            return;
        }
        const char *disk = g_object_get_data(G_OBJECT(row), "disk_name");
        if (disk) strncpy(config.disk, disk, sizeof(config.disk)-1);
        log_msg("选择磁盘: %s", config.disk);
    }

    if (current == 4 && !config.auto_install) {
        gtk_notebook_set_current_page(GTK_NOTEBOOK(notebook), 5);
        return;
    }

    if (current == 5 && !config.auto_install) {
        gtk_notebook_set_current_page(GTK_NOTEBOOK(notebook), 6);
        return;
    }

    if (current == 6 && config.auto_install) {
        start_install();
        gtk_notebook_set_current_page(GTK_NOTEBOOK(notebook), 7);
        return;
    }

    if (current == 7 && !config.auto_install) {
        start_install();
        gtk_notebook_set_current_page(GTK_NOTEBOOK(notebook), 8);
        return;
    }

    if (current == n_pages - 1) {
        system("reboot");
        return;
    }

    gtk_notebook_set_current_page(GTK_NOTEBOOK(notebook), current + 1);
}

static void on_back(GtkButton *btn, gpointer data) {
    int current = gtk_notebook_get_current_page(GTK_NOTEBOOK(notebook));
    if (current > 0) {
        gtk_notebook_set_current_page(GTK_NOTEBOOK(notebook), current - 1);
    }
}

static void on_switch_page(GtkNotebook *nb, GtkWidget *page, guint page_num, gpointer data) {
    int n_pages = gtk_notebook_get_n_pages(nb);

    if (page_num == 0) {
        gtk_widget_hide(btn_back);
        gtk_widget_hide(btn_next);
        update_metro_steps(0);
        if (overall_progress_bar) {
            gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(overall_progress_bar), 0.0);
            gtk_progress_bar_set_text(GTK_PROGRESS_BAR(overall_progress_bar), "0% - 欢迎");
        }
        return;
    } else {
        gtk_widget_show(btn_back);
        gtk_widget_show(btn_next);
    }

    update_metro_steps(page_num);

    if (overall_progress_bar && !install_running) {
        double pre_install_frac = 0.3;
        double frac;
        if (page_num < NUM_STEPS - 1) {
            frac = (double)page_num / (NUM_STEPS - 2) * pre_install_frac;
        } else {
            frac = pre_install_frac;
        }
        char percent[64];
        snprintf(percent, sizeof(percent), "%.0f%% - %s", frac * 100, step_names[page_num]);
        gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(overall_progress_bar), frac);
        gtk_progress_bar_set_text(GTK_PROGRESS_BAR(overall_progress_bar), percent);
    }

    gtk_widget_set_sensitive(btn_back, page_num > 0 && !install_running);

    if (page_num == n_pages - 1) {
        /* 完成页面 */
        gtk_button_set_label(GTK_BUTTON(btn_next), "重启");
        gtk_widget_set_sensitive(btn_next, TRUE);
        gtk_widget_set_sensitive(btn_back, FALSE);
        if (overall_progress_bar) {
            gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(overall_progress_bar), 1.0);
            gtk_progress_bar_set_text(GTK_PROGRESS_BAR(overall_progress_bar), "100% - 完成");
        }
    } else if (page_num == 7) {
        /* 确认页面 */
        gtk_button_set_label(GTK_BUTTON(btn_next), "安装");
        gtk_widget_set_sensitive(btn_next, TRUE);
    } else if (page_num == 8) {
        /* 安装中页面 */
        gtk_button_set_label(GTK_BUTTON(btn_next), "安装中...");
        gtk_widget_set_sensitive(btn_next, FALSE);
        gtk_widget_set_sensitive(btn_back, FALSE);
        return;
    } else {
        /* 其他页面 */
        gtk_button_set_label(GTK_BUTTON(btn_next), "下一步");
        gtk_widget_set_sensitive(btn_next, TRUE);
    }
}

/* ========== 关闭确认对话框 ========== */
static gboolean on_window_delete(GtkWidget *widget, GdkEvent *event, gpointer data) {
    GtkWidget *dialog = gtk_dialog_new_with_buttons(
        "确认关闭",
        GTK_WINDOW(window),
        GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
        "取消", GTK_RESPONSE_CANCEL,
        "确认", GTK_RESPONSE_OK,
        NULL);

    GtkWidget *content = gtk_dialog_get_content_area(GTK_DIALOG(dialog));
    GtkWidget *label = gtk_label_new("请输入校验码以关闭安装程序：");
    gtk_label_set_markup(GTK_LABEL(label), "<span color='#ffffff'>请输入校验码以关闭安装程序：</span>");
    gtk_box_pack_start(GTK_BOX(content), label, FALSE, FALSE, 8);

    GtkWidget *entry = gtk_entry_new();
    gtk_entry_set_visibility(GTK_ENTRY(entry), TRUE);
    gtk_widget_set_size_request(entry, 250, -1);
    gtk_box_pack_start(GTK_BOX(content), entry, FALSE, FALSE, 8);

    gtk_widget_show_all(content);

    gint response = gtk_dialog_run(GTK_DIALOG(dialog));
    
    if (response == GTK_RESPONSE_OK) {
        const char *code = gtk_entry_get_text(GTK_ENTRY(entry));
        if (strcmp(code, "FEPT20190513") == 0) {
            stop_music();
            gtk_main_quit();
        } else {
            GtkWidget *err_dialog = gtk_message_dialog_new(
                GTK_WINDOW(dialog),
                GTK_DIALOG_MODAL,
                GTK_MESSAGE_ERROR,
                GTK_BUTTONS_OK,
                "校验码错误！");
            gtk_dialog_run(GTK_DIALOG(err_dialog));
            gtk_widget_destroy(err_dialog);
        }
    }
    
    gtk_widget_destroy(dialog);
    return TRUE;
}

/* ========== Win+X 快捷键处理 ========== */
static void on_command_enter(GtkWidget *entry, gpointer data);

static gboolean on_key_press(GtkWidget *widget, GdkEventKey *event, gpointer data) {
    if ((event->state & GDK_SUPER_MASK) && event->keyval == GDK_KEY_x) {
        GtkWidget *terminal = gtk_window_new(GTK_WINDOW_TOPLEVEL);
        gtk_window_set_title(GTK_WINDOW(terminal), "JNL OS 命令行");
        gtk_window_set_default_size(GTK_WINDOW(terminal), 800, 500);
        gtk_window_set_transient_for(GTK_WINDOW(terminal), GTK_WINDOW(window));
        
        GtkWidget *vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
        gtk_container_add(GTK_CONTAINER(terminal), vbox);
        
        GtkWidget *toolbar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
        gtk_widget_set_margin_start(toolbar, 8);
        gtk_widget_set_margin_end(toolbar, 8);
        gtk_widget_set_margin_top(toolbar, 8);
        gtk_box_pack_start(GTK_BOX(vbox), toolbar, FALSE, FALSE, 0);
        
        GtkWidget *prompt = gtk_label_new("");
        gtk_label_set_markup(GTK_LABEL(prompt), "<span color='#00ff88'>JNL-OS > </span>");
        gtk_box_pack_start(GTK_BOX(toolbar), prompt, FALSE, FALSE, 0);
        
        GtkWidget *entry = gtk_entry_new();
        gtk_widget_set_hexpand(entry, TRUE);
        gtk_box_pack_start(GTK_BOX(toolbar), entry, TRUE, TRUE, 0);
        
        GtkWidget *output = gtk_text_view_new();
        gtk_text_view_set_editable(GTK_TEXT_VIEW(output), FALSE);
        gtk_text_view_set_cursor_visible(GTK_TEXT_VIEW(output), FALSE);
        GtkTextBuffer *out_buf = gtk_text_view_get_buffer(GTK_TEXT_VIEW(output));
        
        GtkWidget *sw = gtk_scrolled_window_new(NULL, NULL);
        gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(sw), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
        gtk_container_add(GTK_CONTAINER(sw), output);
        gtk_box_pack_start(GTK_BOX(vbox), sw, TRUE, TRUE, 0);
        
        gtk_widget_show_all(terminal);
        
        g_signal_connect(entry, "activate", G_CALLBACK(on_command_enter), out_buf);
        
        return TRUE;
    }
    return FALSE;
}

static void on_command_enter(GtkWidget *entry, gpointer data) {
    GtkTextBuffer *buf = GTK_TEXT_BUFFER(data);
    const char *cmd = gtk_entry_get_text(GTK_ENTRY(entry));
    
    if (strcmp(cmd, "install os") == 0) {
        gtk_text_buffer_insert_at_cursor(buf, "\n正在启动安装脚本...\n", -1);
        system("/usr/bin/jnl-installer-worker /tmp/jnl-installer-config.json &");
        gtk_text_buffer_insert_at_cursor(buf, "安装脚本已启动\n", -1);
    } else if (strcmp(cmd, "exit") == 0 || strcmp(cmd, "quit") == 0) {
        GtkWidget *win = gtk_widget_get_toplevel(entry);
        gtk_widget_destroy(win);
        return;
    } else {
        char output[2048];
        snprintf(output, sizeof(output), "\n执行: %s\n", cmd);
        gtk_text_buffer_insert_at_cursor(buf, output, -1);
        
        FILE *fp = popen(cmd, "r");
        if (fp) {
            while (fgets(output, sizeof(output), fp)) {
                gtk_text_buffer_insert_at_cursor(buf, output, -1);
            }
            pclose(fp);
        } else {
            gtk_text_buffer_insert_at_cursor(buf, "命令执行失败\n", -1);
        }
    }
    
    gtk_entry_set_text(GTK_ENTRY(entry), "");
}

/* ========== 主函数 ========== */
int main(int argc, char *argv[]) {
    log_file = fopen(LOG_FILE, "w");
    if (!log_file) fprintf(stderr, "无法打开日志文件\n");

    gtk_init(&argc, &argv);
    gtk_icon_theme_append_search_path(gtk_icon_theme_get_default(), "/usr/share/icons/jnl-os");

    window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), "Java Net Lava OS 安装程序");
    gtk_window_set_default_size(GTK_WINDOW(window), 900, 650);
    gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
    gtk_window_maximize(GTK_WINDOW(window));
    gtk_window_set_resizable(GTK_WINDOW(window), TRUE);

    GdkPixbuf *win_icon = load_icon_pixbuf(OS_ICON_PATH, 48);
    if (win_icon) {
        gtk_window_set_icon(GTK_WINDOW(window), win_icon);
        g_object_unref(win_icon);
    }

    apply_tech_style(window);

    GtkWidget *main_vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_container_add(GTK_CONTAINER(window), main_vbox);

    GtkWidget *titlebar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    add_css_class(titlebar, "tech-titlebar");
    gtk_container_set_border_width(GTK_CONTAINER(titlebar), 10);
    
    GtkWidget *title_icon = create_icon_image("os", 26);
    gtk_box_pack_start(GTK_BOX(titlebar), title_icon, FALSE, FALSE, 0);
    
    GtkWidget *title_lbl = gtk_label_new("");
    gtk_label_set_markup(GTK_LABEL(title_lbl), "<span weight='bold' color='#ffffff'>Java Net Lava OS</span>");
    gtk_box_pack_start(GTK_BOX(titlebar), title_lbl, FALSE, FALSE, 0);
    
    GtkWidget *title_sub = gtk_label_new("");
    gtk_label_set_markup(GTK_LABEL(title_sub), "<span color='#00d4ff' size='small'>安装程序</span>");
    gtk_box_pack_start(GTK_BOX(titlebar), title_sub, FALSE, FALSE, 0);
    
    GtkWidget *ver = gtk_label_new("");
    char *vm = g_strdup_printf("<span color='#00d4ff' size='small'>v%s</span>", VERSION);
    gtk_label_set_markup(GTK_LABEL(ver), vm);
    g_free(vm);
    gtk_box_pack_end(GTK_BOX(titlebar), ver, FALSE, FALSE, 0);
    
    gtk_box_pack_start(GTK_BOX(main_vbox), titlebar, FALSE, FALSE, 0);
    
    gtk_box_pack_start(GTK_BOX(main_vbox), create_metro_bar(), FALSE, FALSE, 0);

    notebook = gtk_notebook_new();
    gtk_notebook_set_show_tabs(GTK_NOTEBOOK(notebook), FALSE);
    gtk_notebook_set_show_border(GTK_NOTEBOOK(notebook), FALSE);
    gtk_box_pack_start(GTK_BOX(main_vbox), notebook, TRUE, TRUE, 0);

    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), create_welcome_page(), NULL);
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), create_language_page(), NULL);
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), create_license_page(), NULL);
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), create_install_type_page(), NULL);
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), create_disk_page(), NULL);
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), create_partition_page(), NULL);
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), create_user_page(), NULL);
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), create_confirm_page(), NULL);
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), create_install_page(), NULL);
    gtk_notebook_append_page(GTK_NOTEBOOK(notebook), create_done_page(), NULL);

    g_signal_connect(notebook, "switch-page", G_CALLBACK(on_switch_page), NULL);

    /* 底部状态栏：整体进度条 + 按钮 */
    GtkWidget *bottom_area = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    add_css_class(bottom_area, "tech-header");

    /* 进度标记栏 */
    GtkWidget *marker_bar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_set_size_request(marker_bar, -1, 18);
    
    GtkWidget *marker_1 = gtk_label_new("1");
    gtk_label_set_markup(GTK_LABEL(marker_1), "<span color='#00d4ff' font_size='small'>1</span>");
    gtk_widget_set_halign(marker_1, GTK_ALIGN_START);
    gtk_box_pack_start(GTK_BOX(marker_bar), marker_1, TRUE, TRUE, 0);
    
    GtkWidget *marker_2 = gtk_label_new("2");
    gtk_label_set_markup(GTK_LABEL(marker_2), "<span color='#00d4ff' font_size='small'>2</span>");
    gtk_widget_set_halign(marker_2, GTK_ALIGN_END);
    gtk_box_pack_end(GTK_BOX(marker_bar), marker_2, TRUE, TRUE, 0);
    
    gtk_box_pack_start(GTK_BOX(bottom_area), marker_bar, FALSE, FALSE, 4);

    /* 整体进度条 */
    overall_progress_bar = gtk_progress_bar_new();
    gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(overall_progress_bar), 0.0);
    gtk_progress_bar_set_text(GTK_PROGRESS_BAR(overall_progress_bar), "0% - 欢迎");
    gtk_progress_bar_set_show_text(GTK_PROGRESS_BAR(overall_progress_bar), TRUE);
    add_css_class(overall_progress_bar, "tech-progress");
    gtk_widget_set_size_request(overall_progress_bar, -1, 22);
    gtk_box_pack_start(GTK_BOX(bottom_area), overall_progress_bar, FALSE, FALSE, 4);

    /* 按钮栏 */
    GtkWidget *btn_bar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
    gtk_container_set_border_width(GTK_CONTAINER(btn_bar), 10);

    btn_back = gtk_button_new_with_label("上一步");
    add_css_class(btn_back, "tech-btn-secondary");
    gtk_widget_set_size_request(btn_back, 120, 38);
    g_signal_connect(btn_back, "clicked", G_CALLBACK(on_back), NULL);
    gtk_box_pack_start(GTK_BOX(btn_bar), btn_back, FALSE, FALSE, 0);

    btn_next = gtk_button_new_with_label("下一步");
    add_css_class(btn_next, "tech-btn");
    gtk_widget_set_size_request(btn_next, 120, 38);
    g_signal_connect(btn_next, "clicked", G_CALLBACK(on_next), NULL);
    gtk_box_pack_end(GTK_BOX(btn_bar), btn_next, FALSE, FALSE, 0);

    gtk_box_pack_start(GTK_BOX(bottom_area), btn_bar, FALSE, FALSE, 0);
    gtk_box_pack_end(GTK_BOX(main_vbox), bottom_area, FALSE, FALSE, 0);

    g_signal_connect(window, "delete-event", G_CALLBACK(on_window_delete), NULL);
    g_signal_connect(window, "key-press-event", G_CALLBACK(on_key_press), NULL);

    /* 默认隐藏按钮（欢迎页面不需要） */
    gtk_widget_hide(btn_back);
    gtk_widget_hide(btn_next);

    /* 启动音乐 */
    play_music();

    /* 显示窗口 */
    gtk_widget_show_all(window);
    on_switch_page(GTK_NOTEBOOK(notebook), NULL, 0, NULL);

    /* 信号 */
    g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);

    log_msg("JNL 安装程序启动 (版本 %s)", VERSION);
    gtk_main();

    if (log_file) fclose(log_file);
    return 0;
}