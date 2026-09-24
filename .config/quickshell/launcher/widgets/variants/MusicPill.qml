import QtQuick
import ".."
import "../../services"

// Hero: player em pílula — capa redonda girando, título/artista, controles e progresso na borda de baixo.
Item {
    id: v
    property Item host
    anchors.fill: parent

    VGlass { anchors.fill: parent; host: v.host; radius: height / 2 }

    AlbumArt {
        id: art
        x: v.height * 0.14; y: x
        width: v.height - 2 * x; height: width
        radius: width / 2
        artUrl: MusicService.artUrl
    }
    Column {
        anchors.left: art.right
        anchors.leftMargin: 12
        anchors.right: ctl.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        Text { width: parent.width; text: MusicService.title; elide: Text.ElideRight; font.family: "SF Pro Rounded"; font.pixelSize: v.height * 0.24; font.weight: Font.Bold; color: "#ffffff" }
        Text { width: parent.width; text: MusicService.artist; elide: Text.ElideRight; font.family: "SF Pro Rounded"; font.pixelSize: v.height * 0.19; color: Qt.rgba(1, 1, 1, 0.65) }
    }
    Row {
        id: ctl
        anchors.right: parent.right
        anchors.rightMargin: v.height * 0.2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        VButton { icon: "prev"; size: v.height * 0.56; onClicked: MusicService.previous() }
        VButton { icon: MusicService.isPlaying ? "pause" : "play"; size: v.height * 0.56; onClicked: MusicService.togglePlay() }
        VButton { icon: "next"; size: v.height * 0.56; onClicked: MusicService.next() }
    }
    Rectangle {
        x: v.height * 0.5; y: v.height - 3
        width: (v.width - v.height) * (MusicService.length > 0 ? Math.min(1, MusicService.position / MusicService.length) : 0)
        height: 2; radius: 1
        color: "#ffffff"; opacity: 0.8
    }
}
