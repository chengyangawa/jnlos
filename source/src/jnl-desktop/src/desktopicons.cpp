#include "desktopicons.h"
#include "styles.h"
#include "systemsettings.h"
#include <QProcess>
#include <QMenu>
#include <QAction>
#include <QMessageBox>

DesktopIcons::DesktopIcons(QWidget *parent)
    : QWidget(parent)
{
    setStyleSheet(JNLStyles::desktopIconStyle());

    m_gridLayout = new QGridLayout(this);
    m_gridLayout->setContentsMargins(24, 24, 24, 24);
    m_gridLayout->setSpacing(JNLStyles::IconSpacing);
    m_gridLayout->setAlignment(Qt::AlignTop | Qt::AlignLeft);

    struct IconEntry {
        QString label;
        QString exec;
        bool isSettings;
    };

    QList<IconEntry> icons = {
        {"JNL Player", "jnlp", false},
        {"安装 JNL OS", "pkexec /usr/local/bin/install-jnl-os.sh", false},
        {"系统设置", "", true}
    };

    for (int i = 0; i < icons.size(); ++i) {
        QPushButton *btn = new QPushButton(icons[i].label, this);
        btn->setFixedSize(JNLStyles::IconSize + 30, JNLStyles::IconSize + 50);
        btn->setStyleSheet(JNLStyles::appButtonStyle());
        if (icons[i].isSettings) {
            connect(btn, &QPushButton::clicked, [this]() {
                SystemSettings dlg(nullptr, "__VERSION_FULL__");
                dlg.exec();
            });
        } else {
            connect(btn, &QPushButton::clicked, [this, exec=icons[i].exec]() {
                QProcess::startDetached(exec);
            });
        }
        m_gridLayout->addWidget(btn, i, 0);
    }
}

DesktopIcons::~DesktopIcons()
{
}

void DesktopIcons::contextMenuEvent(QContextMenuEvent *event)
{
    QMenu menu(this);
    menu.setStyleSheet(R"(
        QMenu {
            background-color: #f3f3f3;
            border: 1px solid #d1d1d1;
            border-radius: 8px;
            padding: 4px;
        }
        QMenu::item {
            padding: 6px 24px;
            color: #202020;
            font-size: 13px;
            border-radius: 4px;
        }
        QMenu::item:selected {
            background-color: #e5f3ff;
        }
        QMenu::separator {
            height: 1px;
            background-color: #d1d1d1;
            margin: 4px 8px;
        }
    )");

    QAction *refresh = menu.addAction("刷新");
    menu.addSeparator();
    QAction *settings = menu.addAction("个性化设置");
    QAction *sysinfo = menu.addAction("系统信息");
    menu.addSeparator();
    QAction *openTerm = menu.addAction("在终端中打开");

    QAction *selected = menu.exec(event->globalPos());
    if (selected == refresh) {
        // 刷新桌面（重新加载图标）
    } else if (selected == settings) {
        SystemSettings dlg(nullptr, "__VERSION_FULL__");
        dlg.exec();
    } else if (selected == sysinfo) {
        QProcess::startDetached("/usr/local/bin/jnl-system-info");
    } else if (selected == openTerm) {
        QProcess::startDetached("konsole");
    }
}
