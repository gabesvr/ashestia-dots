import QtQuick
import ".."
import "../../services"

// Bento: card alto com a capa grande em cima, título, progresso e controles.
Item {
    id: v
    property Item host
    anchors.fill: parent
    function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60); }
    readonly property real pad: Math.round(v.width * 0.08)

    VGlass { anchors.fill: parent; host: v.host; radius: 32 }

    AlbumArt {
        id: art
        x: v.pad; y: v.pad
        width: v.width - 2 * v.pad
        height: Math.min(width, v.height - 2 * v.pad - 120)
        radius: 20
        artUrl: MusicService.artUrl
    }
    Column {
        anchors.top: art.bottom
        anchors.topMargin: 12
        x: v.pad
        width: v.width - 2 * v.pad
        spacing: 4
        Text { width: parent.width; text: MusicService.title; elide: Text.ElideRight; font.family: "SF Pro Rounded"; font.pixelSize: 17; font.weight: Font.Bold; color: "#ffffff" }
        Text { width: parent.width; text: MusicService.artist; elide: Text.ElideRight; font.family: "SF Pro Rounded"; font.pixelSize: 13; color: Qt.rgba(1, 1, 1, 0.65) }
        Item { width: 1; height: 4 }
        Rectangle {
            width: parent.width; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.18)
            Rectangle { height: parent.height; radius: 2; color: "#ffffff"; width: parent.width * (MusicService.length > 0 ? Math.min(1, MusicService.position / MusicService.length) : 0) }
        }
        Item {
            width: parent.width; height: 14
            Text { text: v.fmt(MusicService.position); font.family: "SF Pro Rounded"; font.pixelSize: 10; color: Qt.rgba(1, 1, 1, 0.55) }
            Text { anchors.right: parent.right; text: v.fmt(MusicService.length); font.family: "SF Pro Rounded"; font.pixelSize: 10; color: Qt.rgba(1, 1, 1, 0.55) }
        }
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: v.pad * 0.6
        spacing: 14
        VButton { icon: "prev"; size: 38; onClicked: MusicService.previous() }
        VButton { icon: MusicService.isPlaying ? "pause" : "play"; size: 46; onClicked: MusicService.togglePlay() }
        VButton { icon: "next"; size: 38; onClicked: MusicService.next() }
    }
}
