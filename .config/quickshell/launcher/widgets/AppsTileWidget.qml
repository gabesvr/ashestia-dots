import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    anchors.fill: parent

    property alias cardItem: full
    property alias sharedBackdrop: glass.sharedBackdrop

    function setWallpaper(path) {
        glass.setWallpaper(path);
    }

    FontLoader {
        id: sfRegular
        source: Qt.resolvedUrl("fonts/sf_pro_display_regular.otf")
    }

    property real targetX: 50
    property real targetY: 591
    property real targetWidth: 240
    property real targetHeight: 68

    signal openLaunchpadRequested()

    readonly property bool isSmallSquare: targetWidth < 120
    readonly property bool isCompactShelf: targetWidth >= 120 && targetWidth < 220

    Item {
        id: full
        x: root.targetX
        y: root.targetY
        width: root.targetWidth
        height: root.targetHeight

        Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on y { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on width { NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }
        Behavior on height { NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }

        scale: tileMouse.pressed ? 0.94 : (tileMouse.containsMouse ? 1.02 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: Math.min(28, Math.min(full.height, full.width) * 0.45)
            roundness: 4.6
            widgetX: full.x
            widgetY: full.y
            screenWidth: root.width > 0 ? root.width : 1920
            screenHeight: root.height > 0 ? root.height : 1080
        }

        // ── 1. COMPACT SHELF MODE (Layout 2: width 180px, clean icon + "Apps", NO overflow) ──
        Item {
            anchors.fill: parent
            visible: root.isCompactShelf
            anchors.margins: 12

            Row {
                anchors.centerIn: parent
                spacing: 10

                Rectangle {
                    width: 32; height: 32
                    radius: 16
                    color: Qt.rgba(1, 1, 1, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.20)
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        width: 16; height: 16
                        source: "file:///home/gabriel/.config/quickshell/assets/icons/apps.svg"
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.90
                    }
                }

                Text {
                    text: "Apps"
                    color: "#ffffff"
                    font.family: sfRegular.name
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ── 2. FULL WIDE RECTANGLE MODE (Layout 1, 3, 4, 5: width >= 220px) ──
        Item {
            anchors.fill: parent
            visible: !root.isSmallSquare && !root.isCompactShelf
            anchors.margins: 14

            Row {
                anchors.fill: parent
                spacing: 12

                Rectangle {
                    width: 36; height: 36
                    radius: 18
                    color: Qt.rgba(1, 1, 1, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.20)
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        width: 18; height: 18
                        source: "file:///home/gabriel/.config/quickshell/assets/icons/apps.svg"
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.90
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "Apps"
                        color: "#ffffff"
                        font.family: sfRegular.name
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }

                    Text {
                        text: "Launchpad"
                        color: "#ffffff"
                        opacity: 0.65
                        font.family: sfRegular.name
                        font.pixelSize: 10
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 22; height: 22
                    radius: 6
                    color: Qt.rgba(1, 1, 1, 0.14)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "⌘"
                        color: "#ffffff"
                        opacity: 0.90
                        font.pixelSize: 12
                    }
                }
            }
        }

        // ── 3. COMPACT SQUARE BADGE MODE (NO TEXT) ──
        Item {
            anchors.fill: parent
            visible: root.isSmallSquare

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(38, Math.min(parent.width, parent.height) * 0.60)
                height: width
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.14)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.20)

                Image {
                    anchors.centerIn: parent
                    width: parent.width * 0.52
                    height: width
                    source: "file:///home/gabriel/.config/quickshell/assets/icons/apps.svg"
                    fillMode: Image.PreserveAspectFit
                    opacity: 0.90
                }
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: (mouse) => {
                glass.mouseU = mouse.x / Math.max(1, full.width);
                glass.mouseV = mouse.y / Math.max(1, full.height);
                glass.mouseFade = 1;
            }
            onEntered: {
                glass.mouseFade = 1;
            }
            onExited: {
                glass.mouseFade = 0;
                glass.mouseU = -1;
                glass.mouseV = -1;
            }
            onClicked: root.openLaunchpadRequested()
        }
    }
}
