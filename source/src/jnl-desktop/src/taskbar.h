#ifndef TASKBAR_H
#define TASKBAR_H

#include <QWidget>
#include <QHBoxLayout>
#include <QPushButton>
#include <QLabel>
#include "startmenu.h"
#include "systray.h"

class TaskBar : public QWidget
{
    Q_OBJECT

public:
    TaskBar(QWidget *parent = nullptr);
    ~TaskBar();

signals:
    void startMenuToggled(bool visible);

private slots:
    void toggleStartMenu();

private:
    QHBoxLayout *m_layout;
    QPushButton *m_startButton;
    QPushButton *m_taskButton;
    QLabel *m_clockLabel;
    StartMenu *m_startMenu;
    SysTray *m_systray;
    bool m_startMenuVisible;
};

#endif
