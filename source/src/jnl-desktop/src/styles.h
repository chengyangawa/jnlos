#ifndef STYLES_H
#define STYLES_H

#include <QColor>
#include <QString>

namespace JNLStyles {

const QColor AccentColor = QColor(0, 120, 212);
const QColor AccentHover = QColor(0, 140, 230);
const QColor TaskbarBg = QColor(32, 32, 32);
const QColor TaskbarHover = QColor(50, 50, 50);
const QColor TaskbarActive = QColor(60, 60, 60);
const QColor StartMenuBg = QColor(38, 38, 38);
const QColor StartMenuBorder = QColor(60, 60, 60);
const QColor TextColor = QColor(240, 240, 240);
const QColor TextDim = QColor(160, 160, 160);
const QColor IconBg = QColor(45, 45, 45);
const QColor IconHover = QColor(60, 60, 60);
const int TaskbarHeight = 48;
const int StartMenuWidth = 640;
const int StartMenuHeight = 700;
const int IconSize = 48;
const int IconSpacing = 12;
const int Radius = 8;
const int TaskbarRadius = 12;

QString taskbarStyle();
QString startMenuStyle();
QString appButtonStyle();
QString desktopIconStyle();
QString systrayStyle();

}

#endif
