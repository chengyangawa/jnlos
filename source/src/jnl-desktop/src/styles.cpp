#include "styles.h"

namespace JNLStyles {

QString taskbarStyle() {
    return QString(R"(
        QWidget {
            background-color: %1;
            color: %2;
        }
        QPushButton {
            background-color: transparent;
            border: none;
            color: %2;
            padding: 8px 12px;
            border-radius: %3px;
            font-size: 14px;
        }
        QPushButton:hover {
            background-color: %4;
        }
        QPushButton:pressed {
            background-color: %5;
        }
    )").arg(TaskbarBg.name())
     .arg(TextColor.name())
     .arg(TaskbarRadius)
     .arg(TaskbarHover.name())
     .arg(TaskbarActive.name());
}

QString startMenuStyle() {
    return QString(R"(
        QWidget {
            background-color: %1;
            color: %2;
            border: 1px solid %3;
            border-radius: %4px;
        }
        QPushButton {
            background-color: transparent;
            border: none;
            color: %2;
            padding: 12px 16px;
            text-align: left;
            font-size: 14px;
        }
        QPushButton:hover {
            background-color: %5;
            border-radius: %4px;
        }
        QLabel {
            color: %6;
            font-size: 12px;
        }
        QLineEdit {
            background-color: %5;
            border: 1px solid %3;
            border-radius: %4px;
            padding: 8px 12px;
            color: %2;
            font-size: 14px;
        }
        QLineEdit:focus {
            border-color: %7;
            outline: none;
        }
    )").arg(StartMenuBg.name())
     .arg(TextColor.name())
     .arg(StartMenuBorder.name())
     .arg(Radius)
     .arg(IconHover.name())
     .arg(TextDim.name())
     .arg(AccentColor.name());
}

QString appButtonStyle() {
    return QString(R"(
        QPushButton {
            background-color: %1;
            border: none;
            border-radius: %2px;
            padding: 8px;
            color: %3;
        }
        QPushButton:hover {
            background-color: %4;
        }
    )").arg(IconBg.name())
     .arg(Radius)
     .arg(TextColor.name())
     .arg(IconHover.name());
}

QString desktopIconStyle() {
    return QString(R"(
        QWidget {
            background-color: transparent;
        }
        QPushButton {
            background-color: transparent;
            border: none;
            border-radius: %1px;
            padding: 8px;
        }
        QPushButton:hover {
            background-color: rgba(255, 255, 255, 0.1);
        }
        QLabel {
            color: %2;
            font-size: 12px;
            text-align: center;
        }
    )").arg(Radius)
     .arg(TextColor.name());
}

QString systrayStyle() {
    return QString(R"(
        QWidget {
            background-color: transparent;
            color: %1;
        }
        QPushButton {
            background-color: transparent;
            border: none;
            padding: 4px 8px;
            border-radius: %2px;
        }
        QPushButton:hover {
            background-color: %3;
        }
    )").arg(TextColor.name())
     .arg(Radius)
     .arg(TaskbarHover.name());
}

}
