#include "tabwidget.h"
#include <QPushButton>
#include <QIcon>

TabWidget::TabWidget(QWidget *parent)
    : QWidget(parent)
{
    m_mainLayout = new QVBoxLayout(this);
    m_mainLayout->setContentsMargins(0, 0, 0, 0);
    m_mainLayout->setSpacing(0);

    m_tabBar = new QTabWidget(this);
    m_tabBar->setTabsClosable(true);
    m_tabBar->setMovable(true);
    m_tabBar->setDocumentMode(true);
    m_tabBar->setStyleSheet(R"(
        QTabBar {
            background-color: #2a2a2a;
            border: none;
        }
        QTabBar::tab {
            background-color: #1e1e1e;
            color: #aaa;
            padding: 8px 16px;
            border: none;
            min-width: 120px;
            max-width: 200px;
        }
        QTabBar::tab:selected {
            background-color: #1e1e1e;
            color: white;
            border-bottom: 2px solid #0078d4;
        }
        QTabBar::tab:hover:!selected {
            background-color: #2a2a2a;
            color: white;
        }
        QTabBar::close-button {
            image: url(data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIxMiIgdmlld0JveD0iMCAwIDEyIDEyIj48Y2lyY2xlIGN4PSI2IiBjeT0iNiIgcj0iNiIgZmlsbD0iIzU1NSIvPjwvc3ZnPg==);
        }
        QTabWidget::pane {
            border: none;
            background-color: white;
        }
    )");
    
    m_mainLayout->addWidget(m_tabBar);
    
    connect(m_tabBar, &QTabWidget::currentChanged, this, &TabWidget::onCurrentChanged);
    connect(m_tabBar, &QTabWidget::tabCloseRequested, this, &TabWidget::closeTab);
}

TabWidget::~TabWidget()
{
}

QWebEngineView *TabWidget::currentWebView() const
{
    int idx = m_tabBar->currentIndex();
    if (idx >= 0 && idx < m_webViews.size()) {
        return m_webViews[idx];
    }
    return nullptr;
}

QWebEngineView *TabWidget::addNewTab(const QUrl &url)
{
    QWebEngineView *view = new QWebEngineView(this);
    view->setUrl(url);
    
    int index = m_tabBar->addTab(view, "加载中...");
    m_webViews.append(view);
    m_tabBar->setCurrentIndex(index);
    
    connect(view, &QWebEngineView::titleChanged, this, &TabWidget::onTabTitleChanged);
    connect(view, &QWebEngineView::urlChanged, this, &TabWidget::onTabUrlChanged);
    connect(view, &QWebEngineView::loadStarted, this, &TabWidget::loadStarted);
    connect(view, &QWebEngineView::loadFinished, this, &TabWidget::loadFinished);
    
    return view;
}

void TabWidget::closeTab(int index)
{
    if (index < 0 || index >= m_webViews.size()) return;
    
    QWebEngineView *view = m_webViews.takeAt(index);
    m_tabBar->removeTab(index);
    view->deleteLater();
    
    if (m_webViews.isEmpty()) {
        addNewTab();
    }
}

void TabWidget::onCurrentChanged(int index)
{
    if (index < 0 || index >= m_webViews.size()) return;
    
    QWebEngineView *view = m_webViews[index];
    emit titleChanged(view->title());
    emit urlChanged(view->url());
}

void TabWidget::onTabTitleChanged(const QString &title)
{
    QWebEngineView *view = qobject_cast<QWebEngineView*>(sender());
    if (!view) return;
    
    int idx = m_webViews.indexOf(view);
    if (idx >= 0) {
        QString displayTitle = title.length() > 20 ? title.left(20) + "..." : title;
        m_tabBar->setTabText(idx, displayTitle);
    }
    
    if (view == currentWebView()) {
        emit titleChanged(title);
    }
}

void TabWidget::onTabUrlChanged(const QUrl &url)
{
    QWebEngineView *view = qobject_cast<QWebEngineView*>(sender());
    if (!view) return;
    
    if (view == currentWebView()) {
        emit urlChanged(url);
    }
}
