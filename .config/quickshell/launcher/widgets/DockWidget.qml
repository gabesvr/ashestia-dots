import QtQuick

// Fundo de vidro do dock do layout Hero (os tiles ficam por cima). Composto: só aparece nos layouts que o posicionam.
Item {
    id: root
    anchors.fill: parent
    z: -1   // atrás dos tiles

    property alias cardItem: full
    property alias sharedBackdrop: glass.sharedBackdrop
    function setWallpaper(path) { glass.setWallpaper(path); }

    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 600
    property real targetHeight: 88
    property bool shown: false

    Item {
        id: full
        x: root.targetX
        y: root.targetY + (root.shown ? 0 : 40)
        width: root.targetWidth
        height: root.targetHeight
        opacity: root.shown ? 1 : 0
        visible: opacity > 0.01
        Behavior on x { enabled: !GlassTheme.gaming; NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on y { enabled: !GlassTheme.gaming; NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on width { enabled: !GlassTheme.gaming; NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }
        Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 300 } }

        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: height / 2
            roundness: 4.6
            tintAlpha: 0.16
            widgetX: full.x
            widgetY: full.y
            screenWidth: root.width > 0 ? root.width : 1920
            screenHeight: root.height > 0 ? root.height : 1200
        }
    }
}
