#ifndef SYSTEMSETTINGS_H
#define SYSTEMSETTINGS_H

#include <QWidget>
#include <QDialog>
#include <QLabel>
#include <QPushButton>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QTreeWidget>
#include <QStackedWidget>
#include <QProcess>
#include <QSysInfo>
#include <QFile>
#include <QTextStream>
#include <QIcon>
#include <QPixmap>
#include <QPainter>

class AboutPage : public QWidget
{
    Q_OBJECT
public:
    explicit AboutPage(QWidget *parent = nullptr);
    void setVersion(const QString &version);

private:
    QLabel *m_logoLabel;
    QLabel *m_nameLabel;
    QLabel *m_versionLabel;
    QLabel *m_osLabel;
    QLabel *m_kernelLabel;
    QLabel *m_cpuLabel;
    QLabel *m_memoryLabel;
    QLabel *m_diskLabel;
};

class SystemSettings : public QDialog
{
    Q_OBJECT

public:
    SystemSettings(QWidget *parent = nullptr, const QString &version = "__VERSION_FULL__");
    ~SystemSettings();

private slots:
    void onCategoryChanged();
    void switchTheme(const QString &themeName);

private:
    void setupUI();
    void applyStyles();

    QHBoxLayout *m_mainLayout;
    QTreeWidget *m_categoryList;
    QStackedWidget *m_contentStack;
    AboutPage *m_aboutPage;
    QWidget *m_themePage;
    QWidget *m_networkPage;
    QWidget *m_displayPage;
    QString m_currentVersion;
};

#endif
