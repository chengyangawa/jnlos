#include "taskbar.h"
#include "styles.h"
#include <QTimer>
#include <QTime>
#include <QDate>

TaskBar::TaskBar(QWidget *parent)
    : QWidget(parent), m_startMenuVisible(false)
{
    setFixedHeight(JNLStyles::TaskbarHeight);
    setStyleSheet(JNLStyles::taskbarStyle());

    m_layout = new QHBoxLayout(this);
    m_layout->setContentsMargins(8, 0, 8, 0);
    m_layout->setSpacing(8);

    m_startButton = new QPushButton(this);
    m_startButton->setFixedSize(40, 40);
    m_startButton->setStyleSheet(QString(R"(
        QPushButton {
            background-color: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 %1, stop:1 %3);
            border-radius: %2px;
            border: none;
            padding: 0;
        }
        QPushButton:hover {
            background-color: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 %3, stop:1 %4);
        }
        QPushButton::after {
            content: "";
            display: block;
            width: 100%;
            height: 100%;
            border-radius: %2px;
            border: 1px solid rgba(255,255,255,0.3);
        }
    )").arg("#0078d4")
     .arg(JNLStyles::TaskbarRadius)
     .arg("#00a8e8")
     .arg("#00c8ff"));
    
    QLabel *iconLabel = new QLabel("J", m_startButton);
    iconLabel->setStyleSheet("color: white; font-weight: bold; font-size: 20px;");
    iconLabel->setAlignment(Qt::AlignCenter);
    QVBoxLayout *btnLayout = new QVBoxLayout(m_startButton);
    btnLayout->addWidget(iconLabel);
    connect(m_startButton, &QPushButton::clicked, this, &TaskBar::toggleStartMenu);
    m_layout->addWidget(m_startButton);

    m_layout->addStretch();

    m_clockLabel = new QLabel(this);
    m_clockLabel->setStyleSheet("color: white; font-size: 12px;");
    m_layout->addWidget(m_clockLabel);

    QTimer *timer = new QTimer(this);
    connect(timer, &QTimer::timeout, [this]() {
        QTime time = QTime::currentTime();
        QDate date = QDate::currentDate();
        m_clockLabel->setText(QString("%1 %2").arg(date.toString("yyyy-MM-dd")).arg(time.toString("HH:mm")));
    });
    timer->start(1000);

    m_systray = new SysTray(this);
    m_layout->addWidget(m_systray);

    m_startMenu = new StartMenu(this);
    m_startMenu->hide();
}

TaskBar::~TaskBar()
{
}

void TaskBar::toggleStartMenu()
{
    m_startMenuVisible = !m_startMenuVisible;
    if (m_startMenuVisible) {
        QPoint pos = mapToGlobal(QPoint(m_startButton->geometry().left(), JNLStyles::TaskbarHeight));
        m_startMenu->move(pos);
        m_startMenu->show();
    } else {
        m_startMenu->hide();
    }
    emit startMenuToggled(m_startMenuVisible);
}
