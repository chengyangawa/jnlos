#include "windowmanager.h"
#include <QApplication>
#include <QMouseEvent>

WindowManager::WindowManager(QObject *parent)
    : QObject(parent)
{
}

WindowManager::~WindowManager()
{
}

void WindowManager::registerDesktop(DesktopWindow *desktop)
{
    m_desktops.append(desktop);
}

void WindowManager::raiseDesktop()
{
    for (auto desktop : m_desktops) {
        desktop->raise();
    }
}

DesktopWindow::DesktopWindow(QWidget *parent)
    : QWidget(parent)
{
    setAttribute(Qt::WA_StaticContents);
    setAttribute(Qt::WA_NoSystemBackground, false);
    setWindowFlags(Qt::FramelessWindowHint);
    setWindowState(Qt::WindowFullScreen);
}

DesktopWindow::~DesktopWindow()
{
}

void DesktopWindow::mousePressEvent(QMouseEvent *event)
{
    QWidget::mousePressEvent(event);
}
