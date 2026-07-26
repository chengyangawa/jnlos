#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ICON_PATH "/usr/share/icons/jnl-os/1.0.svg"

static char* run_cmd(const char* cmd) {
    FILE* fp = popen(cmd, "r");
    if (!fp) return strdup("");
    char buf[256];
    if (fgets(buf, sizeof(buf), fp)) {
        size_t len = strlen(buf);
        if (len > 0 && buf[len-1] == '\n') buf[len-1] = '\0';
    } else {
        buf[0] = '\0';
    }
    pclose(fp);
    return strdup(buf);
}

static void add_row(GtkGrid* grid, int row, const char* label, const char* value) {
    GtkWidget* l = gtk_label_new(NULL);
    gchar* markup = g_markup_printf_escaped("<b>%s</b>", label);
    gtk_label_set_markup(GTK_LABEL(l), markup);
    gtk_widget_set_halign(l, GTK_ALIGN_START);
    gtk_grid_attach(grid, l, 0, row, 1, 1);
    g_free(markup);

    GtkWidget* v = gtk_label_new(value);
    gtk_widget_set_halign(v, GTK_ALIGN_START);
    gtk_label_set_selectable(GTK_LABEL(v), TRUE);
    gtk_grid_attach(grid, v, 1, row, 1, 1);
}

int main(int argc, char* argv[]) {
    gtk_init(&argc, &argv);

    GtkWidget* dialog = gtk_dialog_new_with_buttons(
        "系统信息", NULL, GTK_DIALOG_MODAL,
        "确定", GTK_RESPONSE_OK, NULL);
    gtk_window_set_default_size(GTK_WINDOW(dialog), 520, 620);
    gtk_window_set_resizable(GTK_WINDOW(dialog), FALSE);
    gtk_window_set_position(GTK_WINDOW(dialog), GTK_WIN_POS_CENTER);
    gtk_window_set_icon_from_file(GTK_WINDOW(dialog), ICON_PATH, NULL);

    GtkWidget* content = gtk_dialog_get_content_area(GTK_DIALOG(dialog));
    gtk_container_set_border_width(GTK_CONTAINER(content), 24);

    GtkWidget* vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12);
    gtk_container_add(GTK_CONTAINER(content), vbox);

    // SVG Logo - 放大显示
    if (g_file_test(ICON_PATH, G_FILE_TEST_EXISTS)) {
        GtkWidget* img = gtk_image_new_from_file(ICON_PATH);
        gtk_widget_set_size_request(img, 345, 90);
        gtk_box_pack_start(GTK_BOX(vbox), img, FALSE, FALSE, 0);
    } else {
        GtkWidget* title = gtk_label_new(NULL);
        gtk_label_set_markup(GTK_LABEL(title), "<big><b>Java Net Lava OS</b></big>");
        gtk_box_pack_start(GTK_BOX(vbox), title, FALSE, FALSE, 0);
    }

    gtk_box_pack_start(GTK_BOX(vbox), gtk_separator_new(GTK_ORIENTATION_HORIZONTAL), FALSE, FALSE, 4);

    // Info grid
    GtkWidget* grid = gtk_grid_new();
    gtk_grid_set_row_spacing(GTK_GRID(grid), 8);
    gtk_grid_set_column_spacing(GTK_GRID(grid), 16);
    gtk_box_pack_start(GTK_BOX(vbox), grid, FALSE, FALSE, 0);

    char* version = run_cmd("cat /etc/jnl-os-version 2>/dev/null || echo 'classic4.4'");
    char* kernel = run_cmd("uname -r");
    char* cpu = run_cmd("grep -m1 'model name' /proc/cpuinfo | sed 's/.*: //'");
    char* mem = run_cmd("free -h | grep Mem | awk '{print $2}'");
    char* hostname = run_cmd("hostname");
    char* disk = run_cmd("df -h / | grep / | awk '{print $2}'");
    char* gpu = run_cmd("lspci | grep -i vga | head -1 | sed 's/.*: //'");
    char* arch = run_cmd("uname -m");

    add_row(GTK_GRID(grid), 0, "系统版本:", version);
    add_row(GTK_GRID(grid), 1, "开发团队:", "FEPT");
    add_row(GTK_GRID(grid), 2, "发布日期:", "2026年7月");
    gchar* os_str = g_strdup_printf("Java Net Lava OS %s", version);
    add_row(GTK_GRID(grid), 3, "操作系统:", os_str);
    g_free(os_str);
    add_row(GTK_GRID(grid), 4, "内核版本:", kernel);
    add_row(GTK_GRID(grid), 5, "处理器:", cpu);
    add_row(GTK_GRID(grid), 6, "内存:", mem);
    add_row(GTK_GRID(grid), 7, "计算机名:", hostname);
    add_row(GTK_GRID(grid), 8, "系统类型:", "64位操作系统, x64 处理器");
    add_row(GTK_GRID(grid), 9, "磁盘容量:", disk);
    add_row(GTK_GRID(grid), 10, "显卡:", gpu);
    add_row(GTK_GRID(grid), 11, "架构:", arch);

    free(version); free(kernel); free(cpu); free(mem); free(hostname); free(disk); free(gpu); free(arch);

    gtk_box_pack_start(GTK_BOX(vbox), gtk_separator_new(GTK_ORIENTATION_HORIZONTAL), FALSE, FALSE, 4);

    // Copyright
    GtkWidget* copy = gtk_label_new(NULL);
    gtk_label_set_markup(GTK_LABEL(copy), "<i>© 2026 FEPT. 保留所有权利。</i>");
    GtkStyleContext* ctx = gtk_widget_get_style_context(copy);
    gtk_style_context_add_class(ctx, "dim-label");
    gtk_box_pack_start(GTK_BOX(vbox), copy, FALSE, FALSE, 0);

    gtk_widget_show_all(dialog);
    gtk_dialog_run(GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog);

    return 0;
}