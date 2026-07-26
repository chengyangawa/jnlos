#include <gtk/gtk.h>
#include <dirent.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

static GtkListStore* liststore;
static char current_path[1024];

static void load_directory(const char* path) {
    strncpy(current_path, path, sizeof(current_path)-1);
    
    gtk_list_store_clear(GTK_LIST_STORE(liststore));
    
    DIR* dir = opendir(path);
    if (!dir) return;
    
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] == '.') continue;
        
        char fullpath[1024];
        snprintf(fullpath, sizeof(fullpath), "%s/%s", path, entry->d_name);
        
        struct stat st;
        stat(fullpath, &st);
        
        const char* icon = "text-x-generic";
        if (S_ISDIR(st.st_mode)) icon = "folder";
        else if (strstr(entry->d_name, ".png") || strstr(entry->d_name, ".jpg")) icon = "image";
        else if (strstr(entry->d_name, ".mp3") || strstr(entry->d_name, ".wav")) icon = "audio";
        else if (strstr(entry->d_name, ".txt") || strstr(entry->d_name, ".jnl")) icon = "text";
        
        GtkTreeIter iter;
        gtk_list_store_append(GTK_LIST_STORE(liststore), &iter);
        gtk_list_store_set(GTK_LIST_STORE(liststore), &iter, 0, entry->d_name, -1);
    }
    closedir(dir);
}

static void on_file_activated(GtkTreeView* view, GtkTreePath* path, GtkTreeViewColumn* col, gpointer data) {
    GtkTreeIter iter;
    char filename[256];
    
    if (!gtk_tree_model_get_iter(GTK_TREE_MODEL(liststore), &iter, path)) return;
    gtk_tree_model_get(GTK_TREE_MODEL(liststore), &iter, 0, filename, -1);
    
    char fullpath[1024];
    snprintf(fullpath, sizeof(fullpath), "%s/%s", current_path, filename);
    
    struct stat st;
    if (stat(fullpath, &st) == 0 && S_ISDIR(st.st_mode)) {
        load_directory(fullpath);
    }
}

int main(int argc, char* argv[]) {
    gtk_init(&argc, &argv);
    
    GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), "JNL 文件管理器");
    gtk_window_set_default_size(GTK_WINDOW(window), 600, 400);
    
    GtkWidget* vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_container_add(GTK_CONTAINER(window), vbox);
    
    liststore = gtk_list_store_new(1, G_TYPE_STRING);
    
    GtkWidget* treeview = gtk_tree_view_new_with_model(GTK_TREE_MODEL(liststore));
    GtkCellRenderer* renderer = gtk_cell_renderer_text_new();
    GtkTreeViewColumn* column = gtk_tree_view_column_new_with_attributes("文件名", renderer, "text", 0, NULL);
    gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);
    g_signal_connect(treeview, "row-activated", G_CALLBACK(on_file_activated), NULL);
    
    GtkWidget* scrolled = gtk_scrolled_window_new(NULL, NULL);
    gtk_container_add(GTK_CONTAINER(scrolled), treeview);
    gtk_box_pack_start(GTK_BOX(vbox), scrolled, TRUE, TRUE, 0);
    
    load_directory("/home/jnluser");
    
    gtk_widget_show_all(window);
    gtk_main();
    
    return 0;
}
