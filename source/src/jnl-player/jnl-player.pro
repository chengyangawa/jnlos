QT       += core gui multimedia multimediawidgets

greaterThan(QT_MAJOR_VERSION, 4): QT += widgets

TARGET = jnl-player
TEMPLATE = app

SOURCES += main.cpp

RESOURCES += jnl-player.qrc

INCLUDEPATH += .

CONFIG += c++17

LIBS += -lQt6Multimedia -lQt6MultimediaWidgets