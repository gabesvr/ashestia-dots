import QtQuick
import Quickshell
import "../services"

// Ilha do layout Island: pílula escura no topo com hora, música, clima e bateria.
// Passar o mouse expande e mostra os controles do player e o progresso.
Item {
    id: root
    anchors.fill: parent

    property alias cardItem: full
    property alias sharedBackdrop: glass.sharedBackdrop
    function setWallpaper(path) { glass.setWallpaper(path); }

    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 560
    property real targetHeight: 52
    property bool shown: false
    // Aberta enquanto o mouse estiver em qualquer parte da ilha. HoverHandler é passivo: continua valendo
    // em cima dos botões (uma MouseArea de hover perdia o hover para os botões e a ilha fechava).
    // Pequena espera ao sair, para não fechar num tremor do mouse na borda.
    property bool open: false
    Timer { id: closeDelay; interval: 350; onTriggered: root.open = false }

    SystemClock { id: clk; precision: SystemClock.Minutes }
    readonly property var wd: WeatherService.data

    Item {
        id: full
        x: root.targetX - (root.open ? 30 : 0)
        y: root.targetY + (root.shown ? 0 : -80)
        width: root.targetWidth + (root.open ? 60 : 0)
        height: root.open ? root.targetHeight + 64 : root.targetHeight
        opacity: root.shown ? 1 : 0
        visible: opacity > 0.01
        Behavior on x { enabled: !GlassTheme.gaming; NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
        Behavior on y { enabled: !GlassTheme.gaming; NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on width { enabled: !GlassTheme.gaming; NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
        Behavior on height { enabled: !GlassTheme.gaming; NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
        Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 300 } }

        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: root.targetHeight / 2
            roundness: 4.6
            tint: "#0b0c10"
            tintAlpha: 0.72
            lumaCap: 0.45
            widgetX: full.x
            widgetY: full.y
            screenWidth: root.width > 0 ? root.width : 1920
            screenHeight: root.height > 0 ? root.height : 1200
        }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) { closeDelay.stop(); root.open = true; }
                else closeDelay.restart();
            }
        }

        // linha principal
        Item {
            id: bar
            width: parent.width
            height: root.targetHeight
            Text {
                id: time
                anchors.left: parent.left; anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatTime(clk.date, "HH:mm")
                font.family: "SF Pro Rounded"; font.pixelSize: 17; font.weight: Font.Bold
                color: "#ffffff"
            }
            AlbumArt {
                id: art
                anchors.left: time.right; anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 30; height: 30; radius: 15
                artUrl: MusicService.artUrl
                RotationAnimator on rotation { from: 0; to: 360; duration: 10000; loops: Animation.Infinite; running: MusicService.isPlaying && !GlassTheme.gaming }
            }
            Text {
                anchors.left: art.right; anchors.leftMargin: 10
                anchors.right: right.left; anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: MusicService.title + "  ·  " + MusicService.artist
                elide: Text.ElideRight
                font.family: "SF Pro Rounded"; font.pixelSize: 13
                color: Qt.rgba(1, 1, 1, 0.82)
            }
            Row {
                id: right
                anchors.right: parent.right; anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Text { text: root.wd.currentTemp + "°"; font.family: "SF Pro Rounded"; font.pixelSize: 14; font.weight: Font.DemiBold; color: "#ffffff" }
                Rectangle { width: 1; height: 16; color: Qt.rgba(1, 1, 1, 0.25); anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: (BatteryService.charging ? "⚡" : "") + BatteryService.percent + "%"
                    font.family: "SF Pro Rounded"; font.pixelSize: 14; font.weight: Font.DemiBold
                    color: BatteryService.charging ? "#34c759" : (BatteryService.percent < 20 ? "#ff9500" : "#ffffff")
                }
            }
        }

        // parte expandida: controles + progresso
        Item {
            anchors.top: bar.bottom
            width: parent.width
            height: 60
            opacity: root.open ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 200 } }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                spacing: 18
                IslandButton { icon: "prev"; onClicked: MusicService.previous() }
                IslandButton { icon: MusicService.isPlaying ? "pause" : "play"; onClicked: MusicService.togglePlay() }
                IslandButton { icon: "next"; onClicked: MusicService.next() }
            }
            Rectangle {
                x: 24; y: 44
                width: parent.width - 48; height: 3; radius: 1.5
                color: Qt.rgba(1, 1, 1, 0.16)
                Rectangle { height: parent.height; radius: 1.5; color: "#ffffff"; width: parent.width * (MusicService.length > 0 ? Math.min(1, MusicService.position / MusicService.length) : 0) }
            }
        }
    }

    component IslandButton: Item {
        id: ib
        property string icon: "play"
        signal clicked()
        width: 34; height: 34
        scale: ibm.pressed ? 0.88 : 1
        Rectangle { anchors.fill: parent; radius: 17; color: ibm.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : "transparent" }
        Image { anchors.centerIn: parent; width: 17; height: 17; source: "file:///home/gabriel/.config/quickshell/assets/icons/" + ib.icon + ".svg"; sourceSize.width: 48; sourceSize.height: 48 }
        MouseArea { id: ibm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ib.clicked() }
    }
}
