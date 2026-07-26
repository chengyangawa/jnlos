QT       += core gui widgets webenginecore webenginewidgets network

TARGET = jnl-browser
TEMPLATE = app

DEFINES += QT_DEPRECATED_WARNINGS

SOURCES += \
    main.cpp \
    src/mainwindow.cpp \
    src/tabwidget.cpp \
    src/qqmusicdownloader.cpp

HEADERS += \
    src/mainwindow.h \
    src/tabwidget.h \
    src/qqmusicdownloader.h

RESOURCES += \
    resources/jnl-browser.qrc

DISTFILES += \
    resources/icons/jnl-browser.svg

unix {
    target.path = /usr/local/bin
    INSTALLS += target
}
