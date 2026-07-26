#include <gtk/gtk.h>
#include <gdk/gdk.h>
#include <stdio.h>
#include <time.h>

static void capture_full_screen() {
    GdkWindow* root = gdk_get_default_root_window();
    gint width, height;
    gdk_window_get_geometry(root, NULL, NULL, &width, &height);
    
    GdkPixbuf* pixbuf = gdk_pixbuf_get_from_window(root, 0, 0, width, height);
    if (!pixbuf) {
        gtk_message_dialog_new(NULL, GTK_DIALOG_MODAL, GTK_MESSAGE_ERROR,
                              GTK_BUTTONS_OK, "截图失败！");
        return;
    }
    
    time_t t = time(NULL);
    char filename[256];
    snprintf(filename, sizeof(filename), "/home/jnluser/Desktop/Screenshot_%ld.png", t);
    
    gdk_pixbuf_save(pixbuf, filename, "png", NULL, NULL);
    g_object_unref(pixbuf);
    
    gtk_message_dialog_new(NULL, GTK_DIALOG_MODAL, GTK_MESSAGE_INFO,
                          GTK_BUTTONS_OK, "截图已保存到:\n%s", filename);
}

static void capture_selection() {
    gtk_message_dialog_new(NULL, GTK_DIALOG_MODAL, GTK_MESSAGE_INFO,
                          GTK_BUTTONS_OK, "区域截图功能开发中...");
}

int main(int argc, char* argv[]) {
    gtk_init(&argc, &argv);
    
    GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), "JNL 截图工具");
    gtk_window_set_default_size(GTK_WINDOW(window), 300, 150);
    gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
    
    GtkWidget* vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_container_add(GTK_CONTAINER(window), vbox);
    gtk_container_set_border_width(GTK_CONTAINER(vbox), 20);
    
    GtkWidget* btn_full = gtk_button_new_with_label("全屏截图");
    g_signal_connect(btn_full, "clicked", G_CALLBACK(capture_full_screen), NULL);
    gtk_box_pack_start(GTK_BOX(vbox), btn_full, TRUE, TRUE, 0);
    
    GtkWidget* btn_area = gtk_button_new_with_label("区域截图");
    g_signal_connect(btn_area, "clicked", G_CALLBACK(capture_selection), NULL);
    gtk_box_pack_start(GTK_BOX(vbox), btn_area, TRUE, TRUE, 0);
    
    gtk_widget_show_all(window);
    gtk_main();
    
    return 0;
}
