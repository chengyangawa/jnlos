import QtQuick 2.15
import QtQuick.Window 2.15

Rectangle {
    id: root
    color: "#000000"
    anchors.fill: parent

    Column {
        id: centerBox
        anchors.centerIn: parent
        spacing: 20

        Image {
            id: logo
            source: "/usr/share/icons/jnl-os/OS.svg"
            anchors.horizontalCenter: parent.horizontalCenter
            width: 200
            height: 200
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 400
            sourceSize.height: 400
        }

        Text {
            id: sysName
            text: "Java Net Lava OS"
            color: "#ffffff"
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 36
            font.bold: true
        }

        Text {
            id: versionText
            text: "1.0.29"
            color: "#999999"
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 18
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 8
            anchors.topMargin: 40

            Rectangle {
                id: progressBg
                width: parent.width
                height: parent.height
                color: "#2a2a2a"
                radius: 4
            }

            Rectangle {
                id: progressFill
                width: 0
                height: parent.height
                color: "#ec1c24"
                radius: 4
            }
        }
    }

    Timer {
        id: progressTimer
        interval: 150
        running: true
        repeat: true
        property real progress: 0

        onTriggered: {
            progress += 0.8
            if (progress > 95) progress = 95
            progressFill.width = (progress / 100) * 300
        }
    }
}
