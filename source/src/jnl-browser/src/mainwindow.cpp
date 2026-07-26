#include "mainwindow.h"
#include <QApplication>
#include <QStyle>
#include <QUrl>
#include <QShortcut>
#include <QKeySequence>
#include <QTimer>

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
{
    setWindowTitle("JNL Browser");
    resize(1280, 800);

    setupUI();
    createToolBar();
    setupConnections();
    
    m_tabWidget->addNewTab(QUrl("https://www.baidu.com"));
    setStyleSheet(R"(
        QMainWindow {
            background-color: #1e1e1e;
        }
        QToolBar {
            background-color: #2a2a2a;
            border: none;
            spacing: 4px;
            padding: 4px;
        }
        QLineEdit {
            background-color: #3a3a3a;
            border: 1px solid #4a4a4a;
            border-radius: 16px;
            padding: 6px 16px;
            color: white;
            font-size: 14px;
            selection-background-color: #0078d4;
        }
        QLineEdit:focus {
            border-color: #0078d4;
        }
        QToolButton {
            background-color: transparent;
            border: none;
            color: white;
            padding: 6px;
            border-radius: 4px;
        }
        QToolButton:hover {
            background-color: #3a3a3a;
        }
        QProgressBar {
            background-color: transparent;
            border: none;
            text-align: center;
            color: white;
            height: 3px;
        }
        QProgressBar::chunk {
            background-color: #0078d4;
        }
    )");
}

MainWindow::~MainWindow()
{
}

void MainWindow::setupUI()
{
    m_tabWidget = new TabWidget(this);
    setCentralWidget(m_tabWidget);
    
    m_musicDownloader = new QQMusicDownloader(this);
}

void MainWindow::createToolBar()
{
    m_toolBar = addToolBar("Navigation");
    m_toolBar->setMovable(false);
    m_toolBar->setIconSize(QSize(20, 20));
    m_toolBar->setFixedHeight(48);

    m_backAction = m_toolBar->addAction("←");
    m_forwardAction = m_toolBar->addAction("→");
    m_reloadAction = m_toolBar->addAction("⟳");
    m_homeAction = m_toolBar->addAction("⌂");
    
    m_urlBar = new QLineEdit(this);
    m_urlBar->setPlaceholderText("搜索或输入网址...");
    m_toolBar->addWidget(m_urlBar);

    m_newTabAction = m_toolBar->addAction("+");
    m_downloadAction = m_toolBar->addAction("🎵");
    
    m_progressBar = new QProgressBar(this);
    m_progressBar->setMaximumHeight(3);
    m_progressBar->setTextVisible(false);
    
    QWidget *spacer = new QWidget(this);
    spacer->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Preferred);
    m_toolBar->addWidget(spacer);
    
    m_statusLabel = new QLabel("就绪", this);
    m_statusLabel->setStyleSheet("color: #888; padding: 0 8px;");
    m_toolBar->addWidget(m_statusLabel);
}

void MainWindow::setupConnections()
{
    connect(m_urlBar, &QLineEdit::returnPressed, this, &MainWindow::navigateToUrl);
    connect(m_newTabAction, &QAction::triggered, this, &MainWindow::newTab);
    connect(m_downloadAction, &QAction::triggered, this, &MainWindow::onDownloadClicked);
    connect(m_backAction, &QAction::triggered, [this](){
        if (m_tabWidget->currentWebView()) m_tabWidget->currentWebView()->back();
    });
    connect(m_forwardAction, &QAction::triggered, [this](){
        if (m_tabWidget->currentWebView()) m_tabWidget->currentWebView()->forward();
    });
    connect(m_reloadAction, &QAction::triggered, [this](){
        if (m_tabWidget->currentWebView()) m_tabWidget->currentWebView()->reload();
    });
    connect(m_homeAction, &QAction::triggered, [this](){
        m_tabWidget->addNewTab(QUrl("https://www.baidu.com"));
    });
    
    connect(m_tabWidget, &TabWidget::titleChanged, this, &MainWindow::onTitleChanged);
    connect(m_tabWidget, &TabWidget::urlChanged, this, &MainWindow::onUrlChanged);
    connect(m_tabWidget, &TabWidget::loadStarted, this, &MainWindow::onLoadStarted);
    connect(m_tabWidget, &TabWidget::loadFinished, this, &MainWindow::onLoadFinished);
}

void MainWindow::navigateToUrl()
{
    QString text = m_urlBar->text().trimmed();
    if (text.isEmpty()) return;
    
    QUrl url;
    if (text.startsWith("http://") || text.startsWith("https://")) {
        url = QUrl(text);
    } else if (text.contains('.') && !text.contains(' ')) {
        url = QUrl("https://" + text);
    } else {
        url = QUrl("https://www.baidu.com/s?wd=" + text);
    }
    
    navigateTo(url);
}

void MainWindow::newTab()
{
    m_tabWidget->addNewTab(QUrl("https://www.baidu.com"));
}

void MainWindow::closeTab(int index)
{
    Q_UNUSED(index);
}

void MainWindow::onDownloadClicked()
{
    m_musicDownloader->show();
}

void MainWindow::onTitleChanged(const QString &title)
{
    setWindowTitle(QString("JNL Browser - %1").arg(title));
}

void MainWindow::onUrlChanged(const QUrl &url)
{
    m_urlBar->setText(url.toString());
}

void MainWindow::onLoadStarted()
{
    m_progressBar->setValue(50);
}

void MainWindow::onLoadFinished(bool ok)
{
    m_progressBar->setValue(ok ? 100 : 0);
    QTimer::singleShot(500, [this]() { m_progressBar->setValue(0); });
}

void MainWindow::navigateTo(const QUrl &url)
{
    if (m_tabWidget->currentWebView()) {
        m_tabWidget->currentWebView()->setUrl(url);
    }
}
