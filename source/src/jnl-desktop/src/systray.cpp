#include "systray.h"
#include "styles.h"
#include <QProcess>

SysTray::SysTray(QWidget *parent)
    : QWidget(parent)
{
    setStyleSheet(JNLStyles::systrayStyle());

    m_layout = new QHBoxLayout(this);
    m_layout->setContentsMargins(0, 0, 0, 0);
    m_layout->setSpacing(4);

    m_volumeButton = new QPushButton("🔊", this);
    m_volumeButton->setFixedSize(28, 28);
    connect(m_volumeButton, &QPushButton::clicked, this, &SysTray::onVolumeClicked);
    m_layout->addWidget(m_volumeButton);

    m_networkButton = new QPushButton("📶", this);
    m_networkButton->setFixedSize(28, 28);
    connect(m_networkButton, &QPushButton::clicked, this, &SysTray::onNetworkClicked);
    m_layout->addWidget(m_networkButton);
}

SysTray::~SysTray()
{
}

void SysTray::onVolumeClicked()
{
    QProcess::startDetached("pavucontrol");
}

void SysTray::onNetworkClicked()
{
    QProcess::startDetached("nm-connection-editor");
}
