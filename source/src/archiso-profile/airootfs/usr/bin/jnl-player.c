#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>

#define ICON_PATH "/usr/share/icons/jnl-os/jnl-player.svg"
#define MUSIC_DIR_NAME "Music"

typedef struct {
    char* path;
    char* name;
} TrackInfo;

static GList* track_list = NULL;
static GtkWidget* playlist_view;
static GtkWidget* status_label;
static GPid mpv_pid = 0;

static char* get_music_dir(void) {
    const char* home = getenv("HOME");
    if (!home) home = "/home/jnluser";
    char* dir = g_strdup_printf("%s/%s", home, MUSIC_DIR_NAME);
    mkdir(dir, 0755);
    return dir;
}

static int is_music_file(const char* name) {
    const char* exts[] = {".mp3", ".flac", ".ogg", ".wav", ".m4a", ".aac", ".wma", ".opus", NULL};
    for (int i = 0; exts[i]; i++) {
        if (g_str_has_suffix(name, exts[i])) return 1;
    }
    return 0;
}

static void scan_music_dir(const char* dir) {
    if (track_list) {
        g_list_free_full(track_list, g_free);
        track_list = NULL;
    }
    DIR* d = opendir(dir);
    if (!d) return;
    struct dirent* ent;
    while ((ent = readdir(d)) != NULL) {
        if (ent->d_name[0] == '.') continue;
        if (!is_music_file(ent->d_name)) continue;
        TrackInfo* t = g_new0(TrackInfo, 1);
        t->path = g_strdup_printf("%s/%s", dir, ent->d_name);
        t->name = g_strdup(ent->d_name);
        track_list = g_list_append(track_list, t);
    }
    closedir(d);
}

static void refresh_playlist(void) {
    GtkListStore* store = GTK_LIST_STORE(gtk_tree_view_get_model(GTK_TREE_VIEW(playlist_view)));
    gtk_list_store_clear(store);
    char* mdir = get_music_dir();
    scan_music_dir(mdir);
    g_free(mdir);
    GList* l = track_list;
    while (l) {
        TrackInfo* t = l->data;
        GtkTreeIter iter;
        gtk_list_store_append(store, &iter);
        gtk_list_store_set(store, &iter, 0, t->name, -1);
        l = l->next;
    }
    gchar* text = g_strdup_printf("共 %d 首音乐", g_list_length(track_list));
    gtk_label_set_text(GTK_LABEL(status_label), text);
    g_free(text);
}

static void play_track(const char* path) {
    if (mpv_pid > 0) {
        kill(mpv_pid, SIGTERM);
        g_spawn_close_pid(mpv_pid);
        mpv_pid = 0;
    }
    gchar* argv[] = {"mpv", "--no-video", "--force-window=immediate", (gchar*)path, NULL};
    GError* err = NULL;
    if (!g_spawn_async(NULL, argv, NULL, G_SPAWN_SEARCH_PATH | G_SPAWN_DO_NOT_REAP_CHILD,
                       NULL, NULL, &mpv_pid, &err)) {
        gchar* msg = g_strdup_printf("播放失败：%s", err->message);
        gtk_label_set_text(GTK_LABEL(status_label), msg);
        g_free(msg);
        g_error_free(err);
    } else {
        gchar* msg = g_strdup_printf("正在播放：%s", path);
        gtk_label_set_text(GTK_LABEL(status_label), msg);
        g_free(msg);
    }
}

static void on_play_clicked(GtkWidget* widget, gpointer data) {
    GtkTreeSelection* sel = gtk_tree_view_get_selection(GTK_TREE_VIEW(playlist_view));
    GtkTreeModel* model;
    GtkTreeIter iter;
    if (gtk_tree_selection_get_selected(sel, &model, &iter)) {
        gint idx = 0;
        GtkTreePath* path = gtk_tree_model_get_path(model, &iter);
        if (path) {
            idx = gtk_tree_path_get_indices(path)[0];
            gtk_tree_path_free(path);
        }
        TrackInfo* t = g_list_nth_data(track_list, idx);
        if (t) play_track(t->path);
    }
}

static void on_row_activated(GtkTreeView* view, GtkTreePath* path, GtkTreeViewColumn* col, gpointer data) {
    gint idx = gtk_tree_path_get_indices(path)[0];
    TrackInfo* t = g_list_nth_data(track_list, idx);
    if (t) play_track(t->path);
}

static void on_stop_clicked(GtkWidget* widget, gpointer data) {
    if (mpv_pid > 0) {
        kill(mpv_pid, SIGTERM);
        g_spawn_close_pid(mpv_pid);
        mpv_pid = 0;
        gtk_label_set_text(GTK_LABEL(status_label), "已停止");
    }
}

static void on_open_folder_clicked(GtkWidget* widget, gpointer data) {
    char* mdir = get_music_dir();
    gchar* argv[] = {"xdg-open", mdir, NULL};
    GError* err = NULL;
    g_spawn_async(NULL, argv, NULL, G_SPAWN_SEARCH_PATH, NULL, NULL, NULL, &err);
    if (err) g_error_free(err);
    g_free(mdir);
}

static void on_about_clicked(GtkWidget* widget, gpointer data) {
    GtkWidget* dialog = gtk_message_dialog_new(NULL, GTK_DIALOG_MODAL,
        GTK_MESSAGE_INFO, GTK_BUTTONS_OK,
        "JNL Player 音乐播放器\n\n版本 2.0\n\nJava Net Lava OS 内置音乐播放器\n\n© 2026 FEPT");
    gtk_window_set_title(GTK_WINDOW(dialog), "关于 JNL Player");
    gtk_dialog_run(GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog);
}

int main(int argc, char* argv[]) {
    gtk_init(&argc, &argv);

    GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), "JNL Player");
    gtk_window_set_default_size(GTK_WINDOW(window), 600, 450);
    gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
    if (g_file_test(ICON_PATH, G_FILE_TEST_EXISTS)) {
        gtk_window_set_icon_from_file(GTK_WINDOW(window), ICON_PATH, NULL);
    }
    g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);

    GtkWidget* vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    gtk_container_set_border_width(GTK_CONTAINER(vbox), 12);
    gtk_container_add(GTK_CONTAINER(window), vbox);

    GtkWidget* header = gtk_label_new(NULL);
    gtk_label_set_markup(GTK_LABEL(header), "<span size='x-large' weight='bold'>JNL 音乐播放器</span>");
    gtk_box_pack_start(GTK_BOX(vbox), header, FALSE, FALSE, 4);

    GtkWidget* btn_bar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
    gtk_box_pack_start(GTK_BOX(vbox), btn_bar, FALSE, FALSE, 4);

    GtkWidget* btn_play = gtk_button_new_with_label("▶ 播放");
    g_signal_connect(btn_play, "clicked", G_CALLBACK(on_play_clicked), NULL);
    gtk_box_pack_start(GTK_BOX(btn_bar), btn_play, FALSE, FALSE, 0);

    GtkWidget* btn_stop = gtk_button_new_with_label("■ 停止");
    g_signal_connect(btn_stop, "clicked", G_CALLBACK(on_stop_clicked), NULL);
    gtk_box_pack_start(GTK_BOX(btn_bar), btn_stop, FALSE, FALSE, 0);

    GtkWidget* btn_refresh = gtk_button_new_with_label("↻ 刷新列表");
    g_signal_connect_swapped(btn_refresh, "clicked", G_CALLBACK(refresh_playlist), NULL);
    gtk_box_pack_start(GTK_BOX(btn_bar), btn_refresh, FALSE, FALSE, 0);

    GtkWidget* btn_folder = gtk_button_new_with_label("📂 音乐文件夹");
    g_signal_connect(btn_folder, "clicked", G_CALLBACK(on_open_folder_clicked), NULL);
    gtk_box_pack_start(GTK_BOX(btn_bar), btn_folder, FALSE, FALSE, 0);

    GtkWidget* btn_about = gtk_button_new_with_label("ℹ 关于");
    g_signal_connect(btn_about, "clicked", G_CALLBACK(on_about_clicked), NULL);
    gtk_box_pack_end(GTK_BOX(btn_bar), btn_about, FALSE, FALSE, 0);

    GtkWidget* scroll = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll),
        GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
    gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 4);

    GtkListStore* store = gtk_list_store_new(1, G_TYPE_STRING);
    playlist_view = gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
    g_object_unref(store);
    GtkCellRenderer* renderer = gtk_cell_renderer_text_new();
    GtkTreeViewColumn* col = gtk_tree_view_column_new_with_attributes("播放列表", renderer, "text", 0, NULL);
    gtk_tree_view_append_column(GTK_TREE_VIEW(playlist_view), col);
    gtk_tree_view_set_headers_visible(GTK_TREE_VIEW(playlist_view), TRUE);
    g_signal_connect(playlist_view, "row-activated", G_CALLBACK(on_row_activated), NULL);
    gtk_container_add(GTK_CONTAINER(scroll), playlist_view);

    status_label = gtk_label_new("准备就绪");
    gtk_label_set_xalign(GTK_LABEL(status_label), 0);
    gtk_box_pack_start(GTK_BOX(vbox), status_label, FALSE, FALSE, 0);

    refresh_playlist();

    gtk_widget_show_all(window);
    gtk_main();

    if (track_list) {
        g_list_free_full(track_list, g_free);
    }
    if (mpv_pid > 0) {
        kill(mpv_pid, SIGTERM);
        g_spawn_close_pid(mpv_pid);
    }

    return 0;
}
