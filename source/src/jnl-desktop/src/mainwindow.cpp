#include "mainwindow.h"
#include "styles.h"
#include <QApplication>
#include <QScreen>

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
{
    setWindowTitle("Java Net Lava OS Desktop");
    setWindowFlags(Qt::Window | Qt::FramelessWindowHint);

    QScreen *screen = QApplication::primaryScreen();
    QRect screenRect = screen->geometry();
    setGeometry(screenRect);

    m_centralWidget = new QWidget(this);
    m_layout = new QVBoxLayout(m_centralWidget);
    m_layout->setContentsMargins(0, 0, 0, 0);
    m_layout->setSpacing(0);
    setCentralWidget(m_centralWidget);

    m_desktopIcons = new DesktopIcons(this);
    m_layout->addWidget(m_desktopIcons, 1);

    m_taskbar = new TaskBar(this);
    m_layout->addWidget(m_taskbar);

    connect(m_taskbar, &TaskBar::startMenuToggled, this, &MainWindow::onStartMenuToggled);

    setStyleSheet(JNLStyles::taskbarStyle());
    
    showFullScreen();
}

MainWindow::~MainWindow()
{
}

void MainWindow::onStartMenuToggled(bool visible)
{
    Q_UNUSED(visible);
}
