#ifndef SYSTRAY_H
#define SYSTRAY_H

#include <QWidget>
#include <QHBoxLayout>
#include <QPushButton>
#include <QLabel>

class SysTray : public QWidget
{
    Q_OBJECT

public:
    SysTray(QWidget *parent = nullptr);
    ~SysTray();

private slots:
    void onVolumeClicked();
    void onNetworkClicked();

private:
    QHBoxLayout *m_layout;
    QPushButton *m_volumeButton;
    QPushButton *m_networkButton;
    QLabel *m_statusLabel;
};

#endif
