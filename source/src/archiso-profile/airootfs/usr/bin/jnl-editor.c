#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/stat.h>
#include <unistd.h>

#define ICON_PATH "/usr/share/icons/jnl-os/jnl-editor.svg"

static GtkWidget* text_view;
static GtkWidget* window;
static char* current_file = NULL;
static gboolean modified = FALSE;

static void set_title(void) {
    if (current_file) {
        char* base = g_path_get_basename(current_file);
        gchar* title = g_strdup_printf("%s%s - JNL Editor", modified ? "*" : "", base);
        gtk_window_set_title(GTK_WINDOW(window), title);
        g_free(title);
        g_free(base);
    } else {
        gtk_window_set_title(GTK_WINDOW(window),
            modified ? "未命名* - JNL Editor" : "未命名 - JNL Editor");
    }
}

static void on_text_changed(GtkTextBuffer* buf, gpointer data) {
    modified = TRUE;
    set_title();
}

static void new_file(GtkWidget* widget, gpointer data) {
    GtkTextBuffer* buf = gtk_text_view_get_buffer(GTK_TEXT_VIEW(text_view));
    gtk_text_buffer_set_text(buf, "", -1);
    g_free(current_file);
    current_file = NULL;
    modified = FALSE;
    set_title();
}

static gboolean save_file(const char* path) {
    GtkTextBuffer* buf = gtk_text_view_get_buffer(GTK_TEXT_VIEW(text_view));
    GtkTextIter start, end;
    gtk_text_buffer_get_bounds(buf, &start, &end);
    gchar* text = gtk_text_buffer_get_text(buf, &start, &end, FALSE);
    FILE* f = fopen(path, "w");
    if (!f) {
        g_free(text);
        return FALSE;
    }
    fwrite(text, 1, strlen(text), f);
    fclose(f);
    g_free(text);
    modified = FALSE;
    g_free(current_file);
    current_file = g_strdup(path);
    set_title();
    return TRUE;
}

static void save_as(GtkWidget* widget, gpointer data);

static void save_file_cb(GtkWidget* widget, gpointer data) {
    if (current_file) {
        save_file(current_file);
    } else {
        save_as(widget, data);
    }
}

static void save_as(GtkWidget* widget, gpointer data) {
    GtkWidget* dialog = gtk_file_chooser_dialog_new("另存为",
        GTK_WINDOW(window), GTK_FILE_CHOOSER_ACTION_SAVE,
        "取消", GTK_RESPONSE_CANCEL,
        "保存", GTK_RESPONSE_ACCEPT, NULL);
    gtk_file_chooser_set_do_overwrite_confirmation(GTK_FILE_CHOOSER(dialog), TRUE);
    if (current_file) {
        gtk_file_chooser_set_filename(GTK_FILE_CHOOSER(dialog), current_file);
    } else {
        gtk_file_chooser_set_current_name(GTK_FILE_CHOOSER(dialog), "note.jnl");
    }
    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        char* filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
        save_file(filename);
        g_free(filename);
    }
    gtk_widget_destroy(dialog);
}

static void open_file_cb(GtkWidget* widget, gpointer data) {
    GtkWidget* dialog = gtk_file_chooser_dialog_new("打开文件",
        GTK_WINDOW(window), GTK_FILE_CHOOSER_ACTION_OPEN,
        "取消", GTK_RESPONSE_CANCEL,
        "打开", GTK_RESPONSE_ACCEPT, NULL);
    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        char* filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
        gchar* content = NULL;
        gsize length = 0;
        GError* err = NULL;
        if (g_file_get_contents(filename, &content, &length, &err)) {
            GtkTextBuffer* buf = gtk_text_view_get_buffer(GTK_TEXT_VIEW(text_view));
            gtk_text_buffer_set_text(buf, content, length);
            g_free(content);
            g_free(current_file);
            current_file = g_strdup(filename);
            modified = FALSE;
            set_title();
        } else {
            g_error_free(err);
        }
        g_free(filename);
    }
    gtk_widget_destroy(dialog);
}

static void insert_timestamp(GtkWidget* widget, gpointer data) {
    GtkTextBuffer* buf = gtk_text_view_get_buffer(GTK_TEXT_VIEW(text_view));
    GtkTextIter iter;
    gtk_text_buffer_get_iter_at_mark(buf, &iter, gtk_text_buffer_get_insert(buf));
    time_t now = time(NULL);
    struct tm* tm = localtime(&now);
    char ts[64];
    strftime(ts, sizeof(ts), "--- %Y-%m-%d %H:%M:%S ---\n", tm);
    gtk_text_buffer_insert(buf, &iter, ts, -1);
}

static void about_dialog(GtkWidget* widget, gpointer data) {
    GtkWidget* d = gtk_message_dialog_new(GTK_WINDOW(window),
        GTK_DIALOG_DESTROY_WITH_PARENT, GTK_MESSAGE_INFO, GTK_BUTTONS_OK,
        "JNL Editor\n\n版本 2.0\n\nJava Net Lava OS 笔记编辑器\n支持 .jnl 格式\n\n© 2026 FEPT");
    gtk_window_set_title(GTK_WINDOW(d), "关于 JNL Editor");
    gtk_dialog_run(GTK_DIALOG(d));
    gtk_widget_destroy(d);
}

static gboolean on_delete_event(GtkWidget* w, GdkEvent* e, gpointer d) {
    if (modified) {
        GtkWidget* dialog = gtk_message_dialog_new(GTK_WINDOW(window),
            GTK_DIALOG_MODAL, GTK_MESSAGE_QUESTION, GTK_BUTTONS_NONE,
            "文件已修改，是否保存？");
        gtk_dialog_add_buttons(GTK_DIALOG(dialog),
            "保存", GTK_RESPONSE_YES,
            "不保存", GTK_RESPONSE_NO,
            "取消", GTK_RESPONSE_CANCEL, NULL);
        gint r = gtk_dialog_run(GTK_DIALOG(dialog));
        gtk_widget_destroy(dialog);
        if (r == GTK_RESPONSE_YES) {
            if (current_file) {
                save_file(current_file);
                return FALSE;
            }
        } else if (r == GTK_RESPONSE_NO) {
            return FALSE;
        } else {
            return TRUE;
        }
    }
    return FALSE;
}

int main(int argc, char* argv[]) {
    gtk_init(&argc, &argv);

    window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_default_size(GTK_WINDOW(window), 700, 500);
    gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
    if (g_file_test(ICON_PATH, G_FILE_TEST_EXISTS)) {
        gtk_window_set_icon_from_file(GTK_WINDOW(window), ICON_PATH, NULL);
    }
    set_title();
    g_signal_connect(window, "delete-event", G_CALLBACK(on_delete_event), NULL);
    g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);

    GtkWidget* vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_container_add(GTK_CONTAINER(window), vbox);

    // Toolbar
    GtkWidget* toolbar = gtk_toolbar_new();
    gtk_box_pack_start(GTK_BOX(vbox), toolbar, FALSE, FALSE, 0);

    GtkToolItem* new_btn = gtk_tool_button_new(NULL, "新建");
    gtk_tool_button_set_icon_name(GTK_TOOL_BUTTON(new_btn), "document-new");
    g_signal_connect(new_btn, "clicked", G_CALLBACK(new_file), NULL);
    gtk_toolbar_insert(GTK_TOOLBAR(toolbar), new_btn, -1);

    GtkToolItem* open_btn = gtk_tool_button_new(NULL, "打开");
    gtk_tool_button_set_icon_name(GTK_TOOL_BUTTON(open_btn), "document-open");
    g_signal_connect(open_btn, "clicked", G_CALLBACK(open_file_cb), NULL);
    gtk_toolbar_insert(GTK_TOOLBAR(toolbar), open_btn, -1);

    GtkToolItem* save_btn = gtk_tool_button_new(NULL, "保存");
    gtk_tool_button_set_icon_name(GTK_TOOL_BUTTON(save_btn), "document-save");
    g_signal_connect(save_btn, "clicked", G_CALLBACK(save_file_cb), NULL);
    gtk_toolbar_insert(GTK_TOOLBAR(toolbar), save_btn, -1);

    GtkToolItem* sep = gtk_separator_tool_item_new();
    gtk_toolbar_insert(GTK_TOOLBAR(toolbar), sep, -1);

    GtkToolItem* ts_btn = gtk_tool_button_new(NULL, "时间戳");
    gtk_tool_button_set_icon_name(GTK_TOOL_BUTTON(ts_btn), "insert-text");
    g_signal_connect(ts_btn, "clicked", G_CALLBACK(insert_timestamp), NULL);
    gtk_toolbar_insert(GTK_TOOLBAR(toolbar), ts_btn, -1);

    GtkToolItem* sep2 = gtk_separator_tool_item_new();
    gtk_toolbar_insert(GTK_TOOLBAR(toolbar), sep2, -1);

    GtkToolItem* about_btn = gtk_tool_button_new(NULL, "关于");
    gtk_tool_button_set_icon_name(GTK_TOOL_BUTTON(about_btn), "help-about");
    g_signal_connect(about_btn, "clicked", G_CALLBACK(about_dialog), NULL);
    gtk_toolbar_insert(GTK_TOOLBAR(toolbar), about_btn, -1);

    // Text area
    GtkWidget* scroll = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll),
        GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
    gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 0);

    text_view = gtk_text_view_new();
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(text_view), GTK_WRAP_WORD);
    gtk_text_view_set_left_margin(GTK_TEXT_VIEW(text_view), 8);
    gtk_text_view_set_right_margin(GTK_TEXT_VIEW(text_view), 8);

    GtkTextBuffer* buf = gtk_text_view_get_buffer(GTK_TEXT_VIEW(text_view));
    g_signal_connect(buf, "changed", G_CALLBACK(on_text_changed), NULL);
    gtk_container_add(GTK_CONTAINER(scroll), text_view);

    // Load file if passed as argument
    if (argc > 1) {
        gchar* content = NULL;
        gsize length = 0;
        GError* err = NULL;
        if (g_file_get_contents(argv[1], &content, &length, &err)) {
            gtk_text_buffer_set_text(buf, content, length);
            g_free(content);
            current_file = g_strdup(argv[1]);
            modified = FALSE;
            set_title();
        } else {
            g_error_free(err);
        }
    }

    gtk_widget_show_all(window);
    gtk_main();

    g_free(current_file);
    return 0;
}
