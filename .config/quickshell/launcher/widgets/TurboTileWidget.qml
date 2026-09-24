import Quickshell
import Quickshell.Wayland
import QtQuick

// Tile de energia: chave de 3 posições (ocupa 2 casas da grade — ver placeTiles no shell.qml).
//   0 Silencioso (folha, verde) · 1 Equilibrado (medidor, branco) · 2 Desempenho (chama, laranja)
// Clique direto no segmento; aplica via `power-mode` (nenhum modo faz overclock). O estado real
// vem do controls_status (platform_profile), então a chave acompanha a troca automática do carregador.
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
    property real targetWidth: 164
    property real targetHeight: 76
    property string variant: "classic"   // visual escolhido pelo layout ("classic" = o de sempre)
    // variant "hidden": some com fade (o layout não usa este widget)
    opacity: variant === "hidden" ? 0 : 1
    visible: opacity > 0.01
    Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 260 } }

    property int powerMode: 1
    signal modeRequested(int mode)

    readonly property var accents: ["#34c759", "#ffffff", "#ff9500"]
    readonly property var icons: ["leaf.svg", "gauge.svg", "flame.svg"]

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

        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: (root.variant === "circle" ? Math.min(full.height, full.width) / 2 : Math.min(24, Math.min(full.height, full.width) * 0.45))
            roundness: (root.variant === "circle" && root.isExpanded !== true) ? 2.0 : 4.6   // "circle": tile redondo (Orbit/Hero/Island)
            tint: root.powerMode === 1 ? "#ffffff" : root.accents[root.powerMode]
            tintAlpha: root.powerMode === 1 ? (tileMouse.containsMouse ? 0.18 : 0.10) : 0.22
            widgetX: full.x
            widgetY: full.y
            screenWidth: root.width > 0 ? root.width : 1920
            screenHeight: root.height > 0 ? root.height : 1080

            Behavior on tintAlpha { enabled: !GlassTheme.gaming; NumberAnimation { duration: 180 } }
        }

        // ── Chave ──
        Item {
            id: sw
            anchors.centerIn: parent
            width: full.width - Math.round(full.height * 0.24)
            height: Math.min(42, Math.round(full.height * 0.55))

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.18)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.30)
            }

            Rectangle {
                id: knob
                readonly property real segW: sw.width / 3
                width: segW - 6 + (tileMouse.pressed ? 5 : 0)
                height: sw.height - 6
                y: 3
                x: 3 + root.powerMode * segW - (tileMouse.pressed ? 2.5 : 0)
                radius: height / 2
                color: root.accents[root.powerMode]

                Behavior on x { enabled: !GlassTheme.gaming; NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                Behavior on width { enabled: !GlassTheme.gaming; NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                Behavior on color { enabled: !GlassTheme.gaming; ColorAnimation { duration: 300 } }
            }

            Row {
                anchors.fill: parent
                Repeater {
                    model: 3
                    Item {
                        required property int index
                        width: sw.width / 3
                        height: sw.height

                        Image {
                            anchors.centerIn: parent
                            width: Math.min(18, sw.height * 0.46)
                            height: width
                            // no Equilibrado a bolinha é branca: medidor escuro por cima dela
                            source: "file:///home/gabriel/.config/quickshell/assets/icons/" + (index === 1 && root.powerMode === 1 ? "gauge-dark.svg" : root.icons[index])
                            sourceSize.width: 48
                            sourceSize.height: 48
                            fillMode: Image.PreserveAspectFit
                            opacity: root.powerMode === index ? 1.0 : 0.55
                            Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 200 } }
                        }
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
            onClicked: (mouse) => {
                const p = mapToItem(sw, mouse.x, mouse.y);
                const m = Math.max(0, Math.min(2, Math.floor(p.x / (sw.width / 3))));
                if (m !== root.powerMode) root.modeRequested(m);
            }
        }
    }
}
