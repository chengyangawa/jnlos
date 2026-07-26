QT       += core gui widgets svg

TARGET = jnl-desktop
TEMPLATE = app

DEFINES += QT_DEPRECATED_WARNINGS

SOURCES += \
    main.cpp \
    src/mainwindow.cpp \
    src/taskbar.cpp \
    src/startmenu.cpp \
    src/desktopicons.cpp \
    src/systray.cpp \
    src/styles.cpp \
    src/systemsettings.cpp \
    src/windowmanager.cpp

HEADERS += \
    src/mainwindow.h \
    src/taskbar.h \
    src/startmenu.h \
    src/desktopicons.h \
    src/systray.h \
    src/styles.h \
    src/systemsettings.h \
    src/windowmanager.h

RESOURCES += \
    resources/jnl-desktop.qrc

DISTFILES += \
    resources/icons/jnl-logo.svg \
    resources/icons/jnl-player.svg \
    resources/icons/jnl-browser.svg \
    resources/icons/jnl-settings.svg \
    resources/icons/jnl-terminal.svg \
    resources/icons/jnl-files.svg

unix {
    target.path = /usr/local/bin
    INSTALLS += target
}
