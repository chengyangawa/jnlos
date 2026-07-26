#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QTabWidget>
#include <QLineEdit>
#include <QToolBar>
#include <QAction>
#include <QProgressBar>
#include <QLabel>
#include "tabwidget.h"
#include "qqmusicdownloader.h"

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

private slots:
    void navigateToUrl();
    void newTab();
    void closeTab(int index);
    void onDownloadClicked();
    void onTitleChanged(const QString &title);
    void onUrlChanged(const QUrl &url);
    void onLoadStarted();
    void onLoadFinished(bool ok);

private:
    void setupUI();
    void createToolBar();
    void setupConnections();
    void navigateTo(const QUrl &url);

    QToolBar *m_toolBar;
    QAction *m_backAction;
    QAction *m_forwardAction;
    QAction *m_reloadAction;
    QAction *m_homeAction;
    QAction *m_newTabAction;
    QAction *m_downloadAction;
    QLineEdit *m_urlBar;
    QProgressBar *m_progressBar;
    QLabel *m_statusLabel;
    TabWidget *m_tabWidget;
    QQMusicDownloader *m_musicDownloader;
};

#endif
