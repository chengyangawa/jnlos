#ifndef WINDOWMANAGER_H
#define WINDOWMANAGER_H

#include <QObject>
#include <QWidget>
#include <QList>

class QScreen;
class DesktopWindow;

class WindowManager : public QObject
{
    Q_OBJECT

public:
    explicit WindowManager(QObject *parent = nullptr);
    ~WindowManager();

    void registerDesktop(DesktopWindow *desktop);
    void raiseDesktop();

private:
    QList<DesktopWindow*> m_desktops;
};

class DesktopWindow : public QWidget
{
    Q_OBJECT

public:
    explicit DesktopWindow(QWidget *parent = nullptr);
    ~DesktopWindow();

protected:
    void mousePressEvent(QMouseEvent *event) override;
};

#endif
