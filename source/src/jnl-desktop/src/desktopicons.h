#ifndef DESKTOPICONS_H
#define DESKTOPICONS_H

#include <QWidget>
#include <QGridLayout>
#include <QPushButton>
#include <QLabel>
#include <QContextMenuEvent>

class DesktopIcons : public QWidget
{
    Q_OBJECT

public:
    DesktopIcons(QWidget *parent = nullptr);
    ~DesktopIcons();

protected:
    void contextMenuEvent(QContextMenuEvent *event) override;

private:
    QGridLayout *m_gridLayout;
};

#endif
