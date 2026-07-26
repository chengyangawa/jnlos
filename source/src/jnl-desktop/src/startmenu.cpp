#include "startmenu.h"
#include "systemsettings.h"
#include "styles.h"
#include <QProcess>
#include <QIcon>
#include <QApplication>

StartMenu::StartMenu(QWidget *parent)
    : QWidget(parent)
{
    setFixedSize(JNLStyles::StartMenuWidth, JNLStyles::StartMenuHeight);
    setStyleSheet(JNLStyles::startMenuStyle());
    setWindowFlags(Qt::Popup | Qt::FramelessWindowHint);

    m_mainLayout = new QVBoxLayout(this);
    m_mainLayout->setContentsMargins(16, 16, 16, 16);
    m_mainLayout->setSpacing(16);

    m_searchBox = new QLineEdit(this);
    m_searchBox->setPlaceholderText("搜索应用...");
    m_mainLayout->addWidget(m_searchBox);

    m_appGrid = new QGridLayout();
    m_appGrid->setSpacing(JNLStyles::IconSpacing);

    struct AppEntry {
        QString name;
        QString exec;
        bool isInternal;
    };
    
    QList<AppEntry> apps = {
        {"JNL Player", "jnlp", false},
        {"JNL Browser", "jnl-browser", false},
        {"文件管理器", "dolphin", false},
        {"终端", "konsole", false},
        {"Firefox", "firefox", false},
        {"系统设置", "", true},
        {"主题切换", "/usr/local/bin/switch-theme-gui.sh", false},
        {"安装 JNL OS", "pkexec /usr/local/bin/install-jnl-os.sh", false}
    };

    int row = 0, col = 0;
    for (const auto &app : apps) {
        QPushButton *btn = new QPushButton(app.name, this);
        btn->setFixedSize(150, 100);
        btn->setStyleSheet(JNLStyles::appButtonStyle());
        
        if (app.isInternal && app.name == "系统设置") {
            connect(btn, &QPushButton::clicked, [this]() {
                SystemSettings dlg(nullptr, "__VERSION_FULL__");
                dlg.exec();
                hide();
            });
        } else {
            QString exec = app.exec;
            connect(btn, &QPushButton::clicked, [this, exec]() {
                launchApp(exec);
            });
        }
        
        m_appGrid->addWidget(btn, row, col);
        col++;
        if (col >= 3) {
            col = 0;
            row++;
        }
    }

    m_mainLayout->addLayout(m_appGrid);
    m_mainLayout->addStretch();

    QHBoxLayout *bottomLayout = new QHBoxLayout();
    
    QPushButton *rebootBtn = new QPushButton("重启", this);
    rebootBtn->setFixedSize(80, 32);
    rebootBtn->setStyleSheet(QString(R"(
        QPushButton {
            background-color: #3a3a3a;
            color: white;
            border: none;
            border-radius: 6px;
            font-size: 13px;
        }
        QPushButton:hover {
            background-color: #4a4a4a;
        }
    )"));
    connect(rebootBtn, &QPushButton::clicked, []() {
        QProcess::startDetached("systemctl", {"reboot"});
    });
    bottomLayout->addWidget(rebootBtn);
    
    QPushButton *logoutBtn = new QPushButton("注销", this);
    logoutBtn->setFixedSize(80, 32);
    logoutBtn->setStyleSheet(QString(R"(
        QPushButton {
            background-color: #3a3a3a;
            color: white;
            border: none;
            border-radius: 6px;
            font-size: 13px;
        }
        QPushButton:hover {
            background-color: #4a4a4a;
        }
    )"));
    connect(logoutBtn, &QPushButton::clicked, []() {
        QProcess::startDetached("systemctl", {"logout"});
    });
    bottomLayout->addWidget(logoutBtn);
    
    bottomLayout->addStretch();
    
    m_powerButton = new QPushButton("关机", this);
    m_powerButton->setFixedSize(80, 32);
    m_powerButton->setStyleSheet(QString(R"(
        QPushButton {
            background-color: #dc2626;
            color: white;
            border: none;
            border-radius: 6px;
            font-size: 13px;
        }
        QPushButton:hover {
            background-color: #ef4444;
        }
    )"));
    connect(m_powerButton, &QPushButton::clicked, []() {
        QProcess::startDetached("systemctl", {"poweroff"});
    });
    bottomLayout->addWidget(m_powerButton);

    m_mainLayout->addLayout(bottomLayout);
}

StartMenu::~StartMenu()
{
}

void StartMenu::launchApp(const QString &app)
{
    QProcess::startDetached(app);
    hide();
}
