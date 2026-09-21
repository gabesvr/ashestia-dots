import Quickshell
import QtQuick

// Botão-chave (switch) estilo macOS: liga/desliga o tema sólido cinza-escuro dos widgets
Item {
    id: root
    anchors.fill: parent

    property alias cardItem: full
    property alias sharedBackdrop: glass.sharedBackdrop

    function setWallpaper(path) {
        glass.setWallpaper(path);
    }

    property real targetX: 1530
    property real targetY: 688
    property real targetWidth: 76
    property real targetHeight: 76

    readonly property bool isSolid: GlassTheme.solid

    signal toggleRequested()

    Item {
        id: full
        x: root.targetX
        y: root.targetY
        width: root.targetWidth
        height: root.targetHeight

        onXChanged: GlassTheme.originX = x + width / 2
        onYChanged: GlassTheme.originY = y + height / 2
        onWidthChanged: GlassTheme.originX = x + width / 2
        onHeightChanged: GlassTheme.originY = y + height / 2

        Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on y { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on width { NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }
        Behavior on height { NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }

        scale: tileMouse.pressed ? 0.94 : (tileMouse.containsMouse ? 1.04 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: Math.min(24, Math.min(full.height, full.width) * 0.45)
            roundness: 4.6
            widgetX: full.x
            widgetY: full.y
            screenWidth: root.width > 0 ? root.width : 1920
            screenHeight: root.height > 0 ? root.height : 1080
        }

        // ── A chave ──────────────────────────────────────────────
        Item {
            id: sw
            anchors.centerIn: parent
            width: Math.min(54, parent.width - 18)
            height: 32

            // Trilho
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: root.isSolid ? "#d6d8df" : Qt.rgba(1, 1, 1, 0.26)
                border.width: 1
                border.color: root.isSolid ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.34)
                Behavior on color { ColorAnimation { duration: 360 } }
                Behavior on border.color { ColorAnimation { duration: 360 } }
            }

            // Botão deslizante (estica ao pressionar, como no iOS/macOS)
            Rectangle {
                id: knob
                readonly property real baseW: 26
                width: tileMouse.pressed ? baseW + 7 : baseW
                height: 26
                radius: height / 2
                y: 3
                x: root.isSolid ? sw.width - width - 3 : 3
                color: root.isSolid ? "#2b2d33" : "#ffffff"

                Behavior on x { NumberAnimation { duration: 480; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }
                Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                Behavior on color { ColorAnimation { duration: 360 } }

                // Sol (desligado) e lua (ligado) trocam com giro + fade
                Item {
                    anchors.centerIn: parent
                    width: 16; height: 16
                    rotation: root.isSolid ? 0 : -90
                    Behavior on rotation { NumberAnimation { duration: 480; easing.type: Easing.OutBack; easing.overshoot: 1.0 } }

                    Image {
                        anchors.fill: parent
                        source: "file:///home/gabriel/.config/quickshell/assets/icons/sun-color.svg"
                        sourceSize.width: 48; sourceSize.height: 48
                        opacity: root.isSolid ? 0 : 1
                        scale: root.isSolid ? 0.4 : 1
                        Behavior on opacity { NumberAnimation { duration: 260 } }
                        Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.OutBack } }
                    }
                    Image {
                        anchors.fill: parent
                        source: "file:///home/gabriel/.config/quickshell/assets/icons/moon-light.svg"
                        sourceSize.width: 48; sourceSize.height: 48
                        opacity: root.isSolid ? 1 : 0
                        scale: root.isSolid ? 1 : 0.4
                        Behavior on opacity { NumberAnimation { duration: 260 } }
                        Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.OutBack } }
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
            onEntered: glass.mouseFade = 1
            onExited: {
                glass.mouseFade = 0;
                glass.mouseU = -1;
                glass.mouseV = -1;
            }
            onClicked: {
                GlassTheme.originX = full.x + full.width / 2;
                GlassTheme.originY = full.y + full.height / 2;
                GlassTheme.toggle();
            }
        }
    }
}
