#include <gtk/gtk.h>
#include <stdlib.h>
#include <string.h>

static void on_button_clicked(GtkWidget* widget, gpointer data) {
    GtkWidget* entry = GTK_WIDGET(data);
    const char* text = gtk_button_get_label(GTK_BUTTON(widget));
    
    if (strcmp(text, "=") == 0) {
        const char* expr = gtk_entry_get_text(GTK_ENTRY(entry));
        double result;
        if (sscanf(expr, "%lf", &result) == 1) {
            char buf[64];
            snprintf(buf, sizeof(buf), "%f", result);
            gtk_entry_set_text(GTK_ENTRY(entry), buf);
        } else {
            gtk_entry_set_text(GTK_ENTRY(entry), "Error");
        }
    } else if (strcmp(text, "C") == 0) {
        gtk_entry_set_text(GTK_ENTRY(entry), "");
    } else {
        const char* current = gtk_entry_get_text(GTK_ENTRY(entry));
        char new_text[256];
        snprintf(new_text, sizeof(new_text), "%s%s", current, text);
        gtk_entry_set_text(GTK_ENTRY(entry), new_text);
    }
}

int main(int argc, char* argv[]) {
    gtk_init(&argc, &argv);
    
    GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), "JNL 计算器");
    gtk_window_set_default_size(GTK_WINDOW(window), 280, 320);
    gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
    
    GtkWidget* vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5);
    gtk_container_add(GTK_CONTAINER(window), vbox);
    gtk_container_set_border_width(GTK_CONTAINER(vbox), 10);
    
    GtkWidget* entry = gtk_entry_new();
    gtk_entry_set_alignment(GTK_ENTRY(entry), 1.0);
    gtk_entry_set_max_length(GTK_ENTRY(entry), 30);
    gtk_box_pack_start(GTK_BOX(vbox), entry, FALSE, FALSE, 0);
    
    const char* buttons[] = {"7", "8", "9", "/",
                             "4", "5", "6", "*",
                             "1", "2", "3", "-",
                             "0", ".", "=", "+",
                             "C", NULL};
    
    GtkWidget* grid = gtk_grid_new();
    gtk_grid_set_row_spacing(GTK_GRID(grid), 5);
    gtk_grid_set_column_spacing(GTK_GRID(grid), 5);
    gtk_box_pack_start(GTK_BOX(vbox), grid, TRUE, TRUE, 0);
    
    int row = 0, col = 0;
    for (int i = 0; buttons[i]; i++) {
        GtkWidget* btn = gtk_button_new_with_label(buttons[i]);
        gtk_widget_set_size_request(btn, 60, 60);
        g_signal_connect(btn, "clicked", G_CALLBACK(on_button_clicked), entry);
        gtk_grid_attach(GTK_GRID(grid), btn, col, row, 1, 1);
        col++;
        if (col == 4) { col = 0; row++; }
    }
    
    gtk_widget_show_all(window);
    gtk_main();
    
    return 0;
}
