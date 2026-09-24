import QtQuick
import ".."
import "../../services"

// Orbit: vinil girando com a capa no selo central; título e controles embaixo, sem card.
Item {
    id: v
    property Item host
    anchors.fill: parent
    readonly property real d: Math.min(width, height - 70)

    Item {
        id: disc
        width: v.d; height: v.d
        anchors.horizontalCenter: parent.horizontalCenter
        RotationAnimator on rotation { from: 0; to: 360; duration: 6000; loops: Animation.Infinite; running: MusicService.isPlaying && !GlassTheme.gaming }
        Rectangle { anchors.fill: parent; radius: width / 2; color: "#0d0d10"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12) }
        Repeater {   // sulcos
            model: 7
            Rectangle {
                required property int index
                anchors.centerIn: parent
                width: v.d * (0.92 - index * 0.075); height: width; radius: width / 2
                color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.05 + (index % 2) * 0.03)
            }
        }
        Rectangle {   // reflexo
            anchors.fill: parent; radius: width / 2; opacity: 0.18
            gradient: Gradient { GradientStop { position: 0.0; color: "#ffffff" } GradientStop { position: 0.45; color: "transparent" } GradientStop { position: 1.0; color: "transparent" } }
        }
        AlbumArt { anchors.centerIn: parent; width: v.d * 0.38; height: width; radius: width / 2; artUrl: MusicService.artUrl }
        Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: "#0d0d10" }
    }
    Column {
        anchors.top: disc.bottom
        anchors.topMargin: 8
        width: parent.width
        spacing: 2
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: MusicService.title; elide: Text.ElideRight; font.family: "SF Pro Rounded"; font.pixelSize: 14; font.weight: Font.Bold; color: "#ffffff"; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.4) }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            VButton { icon: "prev"; size: 30; onClicked: MusicService.previous() }
            VButton { icon: MusicService.isPlaying ? "pause" : "play"; size: 30; onClicked: MusicService.togglePlay() }
            VButton { icon: "next"; size: 30; onClicked: MusicService.next() }
        }
    }
}
