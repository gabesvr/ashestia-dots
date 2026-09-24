import Quickshell
import Quickshell.Wayland
import QtQuick

// Tile "GPU": alterna entre só NVIDIA (jogos, HDMI) e só AMD (NVIDIA desligada, bateria) via `gpu-mode`.
// A troca exige reiniciar: o clique abre o aviso com contagem (Cancelar / Reiniciar) no shell.qml.
// Verde = AMD em uso; laranja = contagem para reiniciar.
Item {
    id: root
    anchors.fill: parent

    property alias cardItem: full
    property alias sharedBackdrop: glass.sharedBackdrop

    function setWallpaper(path) {
        glass.setWallpaper(path);
    }

    property real targetX: 1706
    property real targetY: 688
    property real targetWidth: 76
    property real targetHeight: 76
    property string variant: "classic"   // visual escolhido pelo layout ("classic" = o de sempre)
    // variant "hidden": some com fade (o layout não usa este widget)
    opacity: variant === "hidden" ? 0 : 1
    visible: opacity > 0.01
    Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 260 } }

    property bool amdMode: false
    property int countdown: 0
    readonly property bool isPending: countdown > 0
    readonly property color accent: isPending ? "#ff9500" : "#34c759"
    readonly property bool lit: amdMode || isPending
    signal toggleRequested()

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
            tint: root.lit ? root.accent : "#ffffff"
            tintAlpha: root.lit ? 0.22 : (tileMouse.containsMouse ? 0.18 : 0.10)
            widgetX: full.x
            widgetY: full.y
            screenWidth: root.width > 0 ? root.width : 1920
            screenHeight: root.height > 0 ? root.height : 1080

            Behavior on tintAlpha { enabled: !GlassTheme.gaming; NumberAnimation { duration: 180 } }
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(38, Math.min(parent.width, parent.height) * 0.60)
            height: width
            radius: width / 2
            color: root.lit ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45) : Qt.rgba(1, 1, 1, 0.16)
            border.width: 1
            border.color: root.lit ? root.accent : Qt.rgba(1, 1, 1, 0.30)
            Behavior on color { enabled: !GlassTheme.gaming; ColorAnimation { duration: 180 } }
            Behavior on border.color { enabled: !GlassTheme.gaming; ColorAnimation { duration: 180 } }

            Image {
                visible: !root.isPending
                anchors.centerIn: parent
                width: parent.width * 0.56
                height: width
                source: root.amdMode ? "file:///home/gabriel/.config/quickshell/assets/icons/leaf.svg" : "file:///home/gabriel/.config/quickshell/assets/icons/gpu.svg"
                sourceSize.width: 48
                sourceSize.height: 48
                fillMode: Image.PreserveAspectFit
            }

            Text {
                visible: root.isPending
                anchors.centerIn: parent
                text: root.countdown
                font.pixelSize: 16
                font.weight: Font.Black
                color: "#ffffff"
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
