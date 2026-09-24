import Quickshell
import Quickshell.Wayland
import QtQuick

// Tile "Claude": um clique abre o terminal flutuante (foot-float, o mesmo do SUPER+T) já rodando o claude.
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

    readonly property var launchCommand: ["systemd-run", "--user", "--scope", "--quiet", "--collect", "foot", "--app-id=foot-float", "-e", GlassTheme.home + "/.local/bin/claude"]

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
            tint: "#ffffff"
            tintAlpha: tileMouse.containsMouse ? 0.18 : 0.10
            widgetX: full.x
            widgetY: full.y
            screenWidth: root.width > 0 ? root.width : 1920
            screenHeight: root.height > 0 ? root.height : 1080

            Behavior on tintAlpha { enabled: !GlassTheme.gaming; NumberAnimation { duration: 180 } }
        }

        Image {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.56
            height: width * 10 / 17
            source: "file://" + GlassTheme.home + "/.config/quickshell/assets/icons/claude-crab.svg"
            sourceSize.width: 136
            sourceSize.height: 80
            fillMode: Image.PreserveAspectFit
            smooth: false
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
            onClicked: Quickshell.execDetached(root.launchCommand)
        }
    }
}
