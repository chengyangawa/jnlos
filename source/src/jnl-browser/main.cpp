#include <QApplication>
#include <QCoreApplication>
#include "src/mainwindow.h"

int main(int argc, char *argv[])
{
    QApplication a(argc, argv);
    QCoreApplication::setApplicationName("JNL Browser");
    QCoreApplication::setOrganizationName("Java Net Lava");

    MainWindow w;
    w.show();

    return a.exec();
}
