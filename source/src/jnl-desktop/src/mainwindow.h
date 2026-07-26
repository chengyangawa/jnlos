#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QWidget>
#include <QVBoxLayout>
#include "taskbar.h"
#include "desktopicons.h"

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

private slots:
    void onStartMenuToggled(bool visible);

private:
    TaskBar *m_taskbar;
    DesktopIcons *m_desktopIcons;
    QWidget *m_centralWidget;
    QVBoxLayout *m_layout;
};

#endif
