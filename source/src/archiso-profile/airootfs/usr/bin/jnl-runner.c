#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_WIDGETS 100

typedef struct {
    char type[32];
    char name[64];
    char label[256];
    char action[256];
    int x, y, width, height;
} Widget;

typedef struct {
    char title[128];
    int width, height;
    Widget widgets[MAX_WIDGETS];
    int widget_count;
} JNLApp;

static void on_button_clicked(GtkWidget* widget, gpointer data) {
    printf("按钮点击: %s\n", (char*)data);
    gtk_message_dialog_new(NULL, GTK_DIALOG_MODAL, GTK_MESSAGE_INFO, 
                          GTK_BUTTONS_OK, "按钮 '%s' 被点击！", (char*)data);
}

static void load_jnl_file(const char* filename, JNLApp* app) {
    FILE* fp = fopen(filename, "r");
    if (!fp) return;
    
    char line[512];
    int in_widget = 0;
    Widget current_widget;
    
    while (fgets(line, sizeof(line), fp)) {
        line[strcspn(line, "\n")] = 0;
        
        if (strstr(line, "[window]")) {
            in_widget = 0;
            continue;
        }
        
        char* key = strtok(line, "=");
        char* value = strtok(NULL, "=");
        
        if (!key || !value) continue;
        
        if (!in_widget) {
            if (strcmp(key, "title") == 0) strncpy(app->title, value, sizeof(app->title)-1);
            else if (strcmp(key, "width") == 0) app->width = atoi(value);
            else if (strcmp(key, "height") == 0) app->height = atoi(value);
            else if (strcmp(key, "[widget]") == 0) {
                in_widget = 1;
                memset(&current_widget, 0, sizeof(current_widget));
            }
        } else {
            if (strcmp(key, "type") == 0) strncpy(current_widget.type, value, sizeof(current_widget.type)-1);
            else if (strcmp(key, "name") == 0) strncpy(current_widget.name, value, sizeof(current_widget.name)-1);
            else if (strcmp(key, "label") == 0) strncpy(current_widget.label, value, sizeof(current_widget.label)-1);
            else if (strcmp(key, "action") == 0) strncpy(current_widget.action, value, sizeof(current_widget.action)-1);
            else if (strcmp(key, "[/widget]") == 0) {
                in_widget = 0;
                if (app->widget_count < MAX_WIDGETS) {
                    app->widgets[app->widget_count++] = current_widget;
                }
            }
        }
    }
    fclose(fp);
}

int main(int argc, char* argv[]) {
    gtk_init(&argc, &argv);
    
    if (argc < 2) {
        printf("用法: jnl-runner <文件.jnl>\n");
        return 1;
    }
    
    JNLApp app = {0};
    app.width = 400;
    app.height = 300;
    strcpy(app.title, "JNL Application");
    
    load_jnl_file(argv[1], &app);
    
    GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), app.title);
    gtk_window_set_default_size(GTK_WINDOW(window), app.width, app.height);
    
    GtkWidget* vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_container_add(GTK_CONTAINER(window), vbox);
    
    for (int i = 0; i < app.widget_count; i++) {
        Widget* w = &app.widgets[i];
        if (strcmp(w->type, "button") == 0) {
            GtkWidget* btn = gtk_button_new_with_label(w->label);
            g_signal_connect(btn, "clicked", G_CALLBACK(on_button_clicked), g_strdup(w->label));
            gtk_box_pack_start(GTK_BOX(vbox), btn, TRUE, TRUE, 0);
        } else if (strcmp(w->type, "label") == 0) {
            GtkWidget* lbl = gtk_label_new(w->label);
            gtk_box_pack_start(GTK_BOX(vbox), lbl, TRUE, TRUE, 0);
        } else if (strcmp(w->type, "entry") == 0) {
            GtkWidget* entry = gtk_entry_new();
            gtk_entry_set_placeholder_text(GTK_ENTRY(entry), w->label);
            gtk_box_pack_start(GTK_BOX(vbox), entry, TRUE, TRUE, 0);
        } else if (strcmp(w->type, "textview") == 0) {
            GtkWidget* textview = gtk_text_view_new();
            gtk_box_pack_start(GTK_BOX(vbox), textview, TRUE, TRUE, 0);
        } else if (strcmp(w->type, "separator") == 0) {
            GtkWidget* sep = gtk_separator_new(GTK_ORIENTATION_HORIZONTAL);
            gtk_box_pack_start(GTK_BOX(vbox), sep, TRUE, TRUE, 0);
        }
    }
    
    gtk_widget_show_all(window);
    gtk_main();
    
    return 0;
}
