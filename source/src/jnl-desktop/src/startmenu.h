#ifndef STARTMENU_H
#define STARTMENU_H

#include <QWidget>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QPushButton>
#include <QLineEdit>
#include <QGridLayout>

class StartMenu : public QWidget
{
    Q_OBJECT

public:
    StartMenu(QWidget *parent = nullptr);
    ~StartMenu();

private slots:
    void launchApp(const QString &app);

private:
    QVBoxLayout *m_mainLayout;
    QLineEdit *m_searchBox;
    QGridLayout *m_appGrid;
    QPushButton *m_powerButton;
};

#endif
