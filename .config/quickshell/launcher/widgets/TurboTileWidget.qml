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

    property real targetX: 1530
    property real targetY: 688
    property real targetWidth: 76
    property real targetHeight: 76

    property bool isTurbo: false

    signal toggleRequested()

    readonly property bool isSmallSquare: targetWidth < 120

    Item {
        id: full
        x: root.targetX
        y: root.targetY
        width: root.targetWidth
        height: root.targetHeight

        Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        scale: tileMouse.pressed ? 0.92 : (tileMouse.containsMouse ? 1.04 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: Math.min(24, Math.min(full.height, full.width) * 0.45)
            roundness: 7.5
            refractThickness: 35
            refractIOR: 1.7
            refractScale: 65
            tint: "#ffffff"
            tintAlpha: 0.10
            chromaStrength: 0.30
            specStrength: 0.70
            blurRadius: 6
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
                color: root.isTurbo ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                border.color: root.isTurbo ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.15)

                Behavior on color { ColorAnimation { duration: 180 } }
                Behavior on border.color { ColorAnimation { duration: 180 } }

                Image {
                    anchors.centerIn: parent
                    width: parent.width * 0.52
                    height: width
                    source: "file:///home/gabriel/.config/quickshell/assets/icons/flame.svg"
                    fillMode: Image.PreserveAspectFit
                    opacity: root.isTurbo ? 1.0 : 0.70
                    Behavior on opacity { NumberAnimation { duration: 180 } }
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
                    color: root.isTurbo ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    border.color: root.isTurbo ? Qt.rgba(1, 1, 1, 0.40) : Qt.rgba(1, 1, 1, 0.14)
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        width: 17; height: 17
                        source: "file:///home/gabriel/.config/quickshell/assets/icons/flame.svg"
                        fillMode: Image.PreserveAspectFit
                        opacity: root.isTurbo ? 1.0 : 0.75
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "Turbo Mode"
                        color: "#ffffff"
                        font.family: sfRegular.name
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }

                    Text {
                        text: root.isTurbo ? "Active" : "Balanced"
                        color: "#ffffff"
                        opacity: 0.70
                        font.family: sfRegular.name
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
