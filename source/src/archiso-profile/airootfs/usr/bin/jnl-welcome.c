#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LOGO_PATH "/usr/share/icons/jnl-os/OS.svg"

static char* read_file(const char* path) {
    FILE* f = fopen(path, "r");
    if (!f) return strdup("unknown");
    static char buf[256];
    if (fgets(buf, sizeof(buf), f)) {
        size_t len = strlen(buf);
        if (len > 0 && buf[len-1] == '\n') buf[len-1] = '\0';
    } else {
        strcpy(buf, "unknown");
    }
    fclose(f);
    return strdup(buf);
}

static void on_close(GtkWidget* widget, gpointer data) {
    gtk_widget_destroy(widget);
    gtk_main_quit();
}

int main(int argc, char* argv[]) {
    gtk_init(&argc, &argv);

    GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), "欢迎使用");
    gtk_window_set_default_size(GTK_WINDOW(window), 480, 380);
    gtk_window_set_resizable(GTK_WINDOW(window), FALSE);
    gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
    g_signal_connect(window, "destroy", G_CALLBACK(on_close), NULL);

    GtkWidget* vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 16);
    gtk_container_set_border_width(GTK_CONTAINER(vbox), 24);
    gtk_container_add(GTK_CONTAINER(window), vbox);

    if (g_file_test(LOGO_PATH, G_FILE_TEST_EXISTS)) {
        GtkWidget* logo = gtk_image_new_from_file(LOGO_PATH);
        gtk_box_pack_start(GTK_BOX(vbox), logo, FALSE, FALSE, 0);
    }

    char* version = read_file("/etc/jnl-os-version");

    GtkWidget* title = gtk_label_new(NULL);
    gchar* markup = g_strdup_printf("<span size='x-large' weight='bold'>欢迎使用 Java Net Lava OS</span>");
    gtk_label_set_markup(GTK_LABEL(title), markup);
    g_free(markup);
    gtk_box_pack_start(GTK_BOX(vbox), title, FALSE, FALSE, 4);

    GtkWidget* ver_label = gtk_label_new(NULL);
    gchar* ver_markup = g_strdup_printf("<span size='medium'>版本：<b>%s</b></span>", version);
    gtk_label_set_markup(GTK_LABEL(ver_label), ver_markup);
    g_free(ver_markup);
    gtk_box_pack_start(GTK_BOX(vbox), ver_label, FALSE, FALSE, 0);

    GtkWidget* sep = gtk_separator_new(GTK_ORIENTATION_HORIZONTAL);
    gtk_box_pack_start(GTK_BOX(vbox), sep, FALSE, FALSE, 8);

    GtkWidget* btn_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
    gtk_box_pack_start(GTK_BOX(vbox), btn_box, FALSE, FALSE, 8);

    GtkWidget* btn_start = gtk_button_new_with_label("开始使用");
    gtk_widget_set_hexpand(btn_start, TRUE);
    g_signal_connect_swapped(btn_start, "clicked", G_CALLBACK(gtk_widget_destroy), window);
    g_signal_connect_swapped(btn_start, "clicked", G_CALLBACK(gtk_main_quit), NULL);
    gtk_box_pack_start(GTK_BOX(btn_box), btn_start, TRUE, TRUE, 0);

    GtkWidget* btn_info = gtk_button_new_with_label("系统信息");
    g_signal_connect(btn_info, "clicked", G_CALLBACK(on_close), NULL);
    gtk_box_pack_start(GTK_BOX(btn_box), btn_info, TRUE, TRUE, 0);

    GtkWidget* copy = gtk_label_new(NULL);
    gtk_label_set_markup(GTK_LABEL(copy), "<span size='small' color='gray'>© 2026 FEPT. All rights reserved.</span>");
    gtk_box_pack_end(GTK_BOX(vbox), copy, FALSE, FALSE, 0);

    free(version);

    gtk_widget_show_all(window);
    gtk_main();

    return 0;
}
