#include <QApplication>
#include <QScreen>
#include <QDebug>
#include "src/mainwindow.h"

int main(int argc, char *argv[])
{
    QApplication a(argc, argv);
    a.setApplicationName("JNL Desktop");
    a.setApplicationVersion("2.2");
    a.setOrganizationName("Java Net Lava");

    MainWindow w;
    w.show();

    return a.exec();
}
