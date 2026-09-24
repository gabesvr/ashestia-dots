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


    property real targetX: 1618
    property real targetY: 688
    property real targetWidth: 76
    property real targetHeight: 76
    property string variant: "classic"   // visual escolhido pelo layout ("classic" = o de sempre)
    // variant "hidden": some com fade (o layout não usa este widget)
    opacity: variant === "hidden" ? 0 : 1
    visible: opacity > 0.01
    Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 260 } }

    property bool isDnd: false

    signal toggleRequested()

    readonly property bool isSmallSquare: targetWidth < 120

    Item {
        id: full
        x: root.targetX
        y: root.targetY
        width: root.targetWidth
        height: root.targetHeight

        Behavior on x { enabled: !GlassTheme.gaming; NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on y { enabled: !GlassTheme.gaming; NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on width { enabled: !GlassTheme.gaming; NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }
        Behavior on height { enabled: !GlassTheme.gaming; NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }

        scale: tileMouse.pressed ? 0.92 : (tileMouse.containsMouse ? 1.04 : 1.0)
        Behavior on scale { enabled: !GlassTheme.gaming; NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: (root.variant === "circle" ? Math.min(full.height, full.width) / 2 : Math.min(24, Math.min(full.height, full.width) * 0.45))
            roundness: (root.variant === "circle" && root.isExpanded !== true) ? 2.0 : 4.6   // "circle": tile redondo (Orbit/Hero/Island)
            widgetX: full.x
            widgetY: full.y
            screenWidth: root.width > 0 ? root.width : 1920
            screenHeight: root.height > 0 ? root.height : 1080
        }

        // ── 1. COMPACT ICON-ONLY BADGE MODE (NO TEXT, PURE SYMBOL) ──
        Item {
            anchors.fill: parent
            visible: root.isSmallSquare

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(38, Math.min(parent.width, parent.height) * 0.60)
                height: width
                radius: width / 2
                color: root.isDnd ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                border.color: root.isDnd ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.15)

                Behavior on color { enabled: !GlassTheme.gaming; ColorAnimation { duration: 180 } }
                Behavior on border.color { enabled: !GlassTheme.gaming; ColorAnimation { duration: 180 } }

                Image {
                    anchors.centerIn: parent
                    width: parent.width * 0.52
                    height: width
                    source: "file:///home/gabriel/.config/quickshell/assets/icons/bell.svg"
                    fillMode: Image.PreserveAspectFit
                    opacity: root.isDnd ? 1.0 : 0.70
                    Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 180 } }
                }
            }
        }

        // ── 2. WIDE RECTANGLE MODE ──
        Item {
            anchors.fill: parent
            visible: !root.isSmallSquare
            anchors.margins: 12

            Row {
                anchors.fill: parent
                spacing: 10

                Rectangle {
                    width: 34; height: 34
                    radius: 17
                    color: root.isDnd ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    border.color: root.isDnd ? Qt.rgba(1, 1, 1, 0.40) : Qt.rgba(1, 1, 1, 0.14)
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        width: 17; height: 17
                        source: "file:///home/gabriel/.config/quickshell/assets/icons/bell.svg"
                        fillMode: Image.PreserveAspectFit
                        opacity: root.isDnd ? 1.0 : 0.75
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "Do Not Disturb"
                        color: "#ffffff"
                        font.family: "SF Pro Display"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }

                    Text {
                        text: root.isDnd ? "Silence Active" : "Normal Mode"
                        color: "#ffffff"
                        opacity: 0.70
                        font.family: "SF Pro Display"
                        font.pixelSize: 9
                    }
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
            onClicked: root.toggleRequested()
        }
    }
}
