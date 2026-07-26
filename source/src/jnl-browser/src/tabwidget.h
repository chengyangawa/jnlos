#ifndef TABWIDGET_H
#define TABWIDGET_H

#include <QWidget>
#include <QTabWidget>
#include <QWebEngineView>
#include <QUrl>
#include <QVBoxLayout>

class TabWidget : public QWidget
{
    Q_OBJECT

public:
    explicit TabWidget(QWidget *parent = nullptr);
    ~TabWidget();

    QWebEngineView *currentWebView() const;
    QWebEngineView *addNewTab(const QUrl &url = QUrl());
    void closeTab(int index);

signals:
    void titleChanged(const QString &title);
    void urlChanged(const QUrl &url);
    void loadStarted();
    void loadFinished(bool ok);

private slots:
    void onCurrentChanged(int index);
    void onTabTitleChanged(const QString &title);
    void onTabUrlChanged(const QUrl &url);

private:
    QTabWidget *m_tabBar;
    QVBoxLayout *m_mainLayout;
    QList<QWebEngineView*> m_webViews;
};

#endif
