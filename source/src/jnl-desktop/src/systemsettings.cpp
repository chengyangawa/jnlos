#include "systemsettings.h"
#include "styles.h"
#include <QHeaderView>
#include <QFileInfo>
#include <QDir>
#include <QListWidget>
#include <QListWidgetItem>
#include <QMessageBox>
#include <QStandardPaths>
#include <QFont>

AboutPage::AboutPage(QWidget *parent)
    : QWidget(parent)
{
    QVBoxLayout *mainLayout = new QVBoxLayout(this);
    mainLayout->setContentsMargins(40, 40, 40, 40);
    mainLayout->setSpacing(16);
    mainLayout->setAlignment(Qt::AlignCenter);

    m_logoLabel = new QLabel(this);
    QPixmap logo(128, 128);
    logo.fill(Qt::transparent);
    QPainter painter(&logo);
    painter.setRenderHint(QPainter::Antialiasing);
    
    QLinearGradient grad(0, 0, 128, 128);
    grad.setColorAt(0, QColor(0, 120, 212));
    grad.setColorAt(1, QColor(0, 200, 255));
    painter.setBrush(grad);
    painter.setPen(Qt::NoPen);
    painter.drawRoundedRect(0, 0, 128, 128, 24, 24);
    
    QFont logoFont;
    logoFont.setPointSize(64);
    logoFont.setBold(true);
    painter.setFont(logoFont);
    painter.setPen(QColor(255, 255, 255));
    painter.drawText(logo.rect(), Qt::AlignCenter, "J");
    
    m_logoLabel->setPixmap(logo);
    m_logoLabel->setAlignment(Qt::AlignCenter);
    mainLayout->addWidget(m_logoLabel);

    m_nameLabel = new QLabel("Java Net Lava OS", this);
    QFont nameFont;
    nameFont.setPointSize(28);
    nameFont.setBold(true);
    m_nameLabel->setFont(nameFont);
    m_nameLabel->setStyleSheet("color: white;");
    m_nameLabel->setAlignment(Qt::AlignCenter);
    mainLayout->addWidget(m_nameLabel);

    m_versionLabel = new QLabel("__VERSION_FULL__", this);
    m_versionLabel->setStyleSheet("color: #00a8e8; font-size: 16px;");
    m_versionLabel->setAlignment(Qt::AlignCenter);
    mainLayout->addWidget(m_versionLabel);

    mainLayout->addSpacing(20);

    QWidget *infoCard = new QWidget(this);
    infoCard->setStyleSheet("background-color: #2a2a2a; border-radius: 8px; padding: 16px;");
    QVBoxLayout *infoLayout = new QVBoxLayout(infoCard);
    infoLayout->setSpacing(8);

    auto addInfo = [&](const QString &label, QLabel **valueLabel) {
        QHBoxLayout *row = new QHBoxLayout();
        QLabel *lbl = new QLabel(label, infoCard);
        lbl->setStyleSheet("color: #888; font-size: 13px;");
        *valueLabel = new QLabel(infoCard);
        (*valueLabel)->setStyleSheet("color: white; font-size: 13px;");
        row->addWidget(lbl);
        row->addStretch();
        row->addWidget(*valueLabel);
        infoLayout->addLayout(row);
    };

    addInfo("操作系统", &m_osLabel);
    m_osLabel->setText("Java Net Lava OS __VERSION_FULL__");

    addInfo("内核版本", &m_kernelLabel);
    m_kernelLabel->setText(QSysInfo::kernelVersion());

    addInfo("CPU", &m_cpuLabel);
    m_cpuLabel->setText(QSysInfo::currentCpuArchitecture());

    addInfo("内存", &m_memoryLabel);
    QProcess *mem = new QProcess(this);
    mem->start("sh", {"-c", "free -h | awk 'NR==2{print $2}'"});
    mem->waitForFinished();
    QString memStr = QString::fromUtf8(mem->readAllStandardOutput()).trimmed();
    if (memStr.isEmpty()) memStr = "未知";
    m_memoryLabel->setText(memStr);

    addInfo("存储", &m_diskLabel);
    QProcess *disk = new QProcess(this);
    disk->start("sh", {"-c", "df -h / | awk 'NR==2{print $2}'"});
    disk->waitForFinished();
    QString diskStr = QString::fromUtf8(disk->readAllStandardOutput()).trimmed();
    if (diskStr.isEmpty()) diskStr = "未知";
    m_diskLabel->setText(diskStr);

    mainLayout->addWidget(infoCard);
    mainLayout->addStretch();
}

void AboutPage::setVersion(const QString &version)
{
    m_versionLabel->setText(version);
    m_osLabel->setText(QString("Java Net Lava OS %1").arg(version));
}

SystemSettings::SystemSettings(QWidget *parent, const QString &version)
    : QDialog(parent), m_currentVersion(version)
{
    setWindowTitle("系统设置 - Java Net Lava OS");
    resize(900, 600);
    setStyleSheet("background-color: #1a1a1a; color: white;");

    setupUI();
    applyStyles();
}

SystemSettings::~SystemSettings()
{
}

void SystemSettings::setupUI()
{
    m_mainLayout = new QHBoxLayout(this);
    m_mainLayout->setContentsMargins(0, 0, 0, 0);
    m_mainLayout->setSpacing(0);

    m_categoryList = new QTreeWidget(this);
    m_categoryList->setHeaderHidden(true);
    m_categoryList->setFixedWidth(220);
    m_categoryList->setIndentation(0);
    m_categoryList->setStyleSheet(R"(
        QTreeWidget {
            background-color: #1a1a1a;
            border: none;
            color: white;
            font-size: 14px;
            outline: none;
        }
        QTreeWidget::item {
            padding: 12px 16px;
            border: none;
        }
        QTreeWidget::item:selected {
            background-color: #0078d4;
            color: white;
        }
        QTreeWidget::item:hover:!selected {
            background-color: #2a2a2a;
        }
    )");

    QTreeWidgetItem *aboutItem = new QTreeWidgetItem(m_categoryList, QStringList() << "ℹ️  关于本机");
    QTreeWidgetItem *themeItem = new QTreeWidgetItem(m_categoryList, QStringList() << "🎨  主题");
    QTreeWidgetItem *displayItem = new QTreeWidgetItem(m_categoryList, QStringList() << "🖥️  显示");
    QTreeWidgetItem *networkItem = new QTreeWidgetItem(m_categoryList, QStringList() << "📡  网络");

    m_contentStack = new QStackedWidget(this);
    m_contentStack->setStyleSheet("background-color: #1a1a1a;");

    m_aboutPage = new AboutPage(this);
    m_aboutPage->setVersion(m_currentVersion);
    m_contentStack->addWidget(m_aboutPage);

    m_themePage = new QWidget(this);
    QVBoxLayout *themeLayout = new QVBoxLayout(m_themePage);
    themeLayout->setContentsMargins(40, 40, 40, 40);
    QLabel *themeTitle = new QLabel("选择主题", m_themePage);
    QFont titleFont;
    titleFont.setPointSize(20);
    titleFont.setBold(true);
    themeTitle->setFont(titleFont);
    themeTitle->setStyleSheet("color: white;");
    themeLayout->addWidget(themeTitle);
    themeLayout->addSpacing(20);

    QListWidget *themeList = new QListWidget(m_themePage);
    themeList->setStyleSheet(R"(
        QListWidget {
            background-color: #2a2a2a;
            border: 1px solid #3a3a3a;
            border-radius: 8px;
            color: white;
            font-size: 14px;
            outline: none;
        }
        QListWidget::item {
            padding: 12px 16px;
            border-bottom: 1px solid #3a3a3a;
        }
        QListWidget::item:selected {
            background-color: #0078d4;
        }
        QListWidget::item:hover:!selected {
            background-color: #3a3a3a;
        }
    )");

    QDir themesDir("/usr/share/themes");
    if (themesDir.exists()) {
        QStringList themes = themesDir.entryList(QStringList() << "JNL-*", QDir::Dirs);
        for (const QString &theme : themes) {
            QListWidgetItem *item = new QListWidgetItem(theme, themeList);
            item->setData(Qt::UserRole, theme);
        }
    }

    connect(themeList, &QListWidget::itemClicked, [this](QListWidgetItem *item) {
        switchTheme(item->data(Qt::UserRole).toString());
    });

    themeLayout->addWidget(themeList);
    themeLayout->addStretch();
    m_contentStack->addWidget(m_themePage);

    m_displayPage = new QWidget(this);
    QVBoxLayout *displayLayout = new QVBoxLayout(m_displayPage);
    displayLayout->setContentsMargins(40, 40, 40, 40);
    QLabel *displayTitle = new QLabel("显示设置", m_displayPage);
    displayTitle->setFont(titleFont);
    displayTitle->setStyleSheet("color: white;");
    displayLayout->addWidget(displayTitle);
    displayLayout->addSpacing(20);
    QLabel *displayInfo = new QLabel("分辨率：自动检测\n缩放：100%\n方向：横向", m_displayPage);
    displayInfo->setStyleSheet("color: #ccc; font-size: 14px; line-height: 1.8;");
    displayLayout->addWidget(displayInfo);
    displayLayout->addStretch();
    m_contentStack->addWidget(m_displayPage);

    m_networkPage = new QWidget(this);
    QVBoxLayout *networkLayout = new QVBoxLayout(m_networkPage);
    networkLayout->setContentsMargins(40, 40, 40, 40);
    QLabel *networkTitle = new QLabel("网络设置", m_networkPage);
    networkTitle->setFont(titleFont);
    networkTitle->setStyleSheet("color: white;");
    networkLayout->addWidget(networkTitle);
    networkLayout->addSpacing(20);
    
    QProcess *ip = new QProcess(this);
    ip->start("sh", {"-c", "ip addr show | grep 'inet ' | awk '{print $2}' | head -3"});
    ip->waitForFinished();
    QString ipStr = QString::fromUtf8(ip->readAllStandardOutput()).trimmed();
    if (ipStr.isEmpty()) ipStr = "未连接";
    
    QLabel *networkInfo = new QLabel(QString("IP 地址：\n%1").arg(ipStr), m_networkPage);
    networkInfo->setStyleSheet("color: #ccc; font-size: 14px; line-height: 1.8;");
    networkLayout->addWidget(networkInfo);
    networkLayout->addStretch();
    m_contentStack->addWidget(m_networkPage);

    m_mainLayout->addWidget(m_categoryList);
    m_mainLayout->addWidget(m_contentStack, 1);

    connect(m_categoryList, &QTreeWidget::itemSelectionChanged,
            this, &SystemSettings::onCategoryChanged);

    m_categoryList->setCurrentItem(aboutItem);
    m_contentStack->setCurrentIndex(0);
}

void SystemSettings::applyStyles()
{
}

void SystemSettings::onCategoryChanged()
{
    int idx = m_categoryList->currentIndex().row();
    m_contentStack->setCurrentIndex(idx);
}

void SystemSettings::switchTheme(const QString &themeName)
{
    QProcess::startDetached("sh", {"-c", QString("gsettings set org.gnome.desktop.interface gtk-theme '%1' && gsettings set org.gnome.desktop.wm.preferences theme '%1'").arg(themeName)});
    QMessageBox::information(this, "主题切换", QString("已切换到 %1").arg(themeName));
}
