import QtQuick
import ".."
import "../../services"

// Editorial: capa do álbum como pôster (com sombra) e os créditos alinhados à direita, ao lado.
Item {
    id: v
    property Item host
    anchors.fill: parent

    Item {
        id: poster
        width: v.height; height: v.height
        anchors.right: parent.right
        AlbumArt { anchors.fill: parent; radius: 6; artUrl: MusicService.artUrl }
        Rectangle { anchors.fill: parent; radius: 6; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.22) }
    }
    Column {
        anchors.right: poster.left
        anchors.rightMargin: v.height * 0.1
        anchors.bottom: parent.bottom
        width: v.width - v.height - v.height * 0.1
        spacing: 4
        Text {
            anchors.right: parent.right
            text: "TOCANDO AGORA"
            font.family: "SF Pro Display"; font.weight: Font.Light; font.pixelSize: 11; font.letterSpacing: 4
            color: Qt.rgba(1, 1, 1, 0.75)
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.35)
        }
        Text {
            width: parent.width; horizontalAlignment: Text.AlignRight
            text: MusicService.title
            wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
            font.family: "Noto Serif Display"; font.weight: Font.Bold; font.pixelSize: v.height * 0.13
            color: "#ffffff"
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.35)
        }
        Text {
            width: parent.width; horizontalAlignment: Text.AlignRight
            text: MusicService.artist
            elide: Text.ElideRight
            font.family: "Noto Serif Display"; font.italic: true; font.pixelSize: v.height * 0.075
            color: "#ffffff"
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.35)
        }
        Row {
            anchors.right: parent.right
            spacing: 2
            VButton { icon: "prev"; size: 32; onClicked: MusicService.previous() }
            VButton { icon: MusicService.isPlaying ? "pause" : "play"; size: 32; onClicked: MusicService.togglePlay() }
            VButton { icon: "next"; size: 32; onClicked: MusicService.next() }
        }
    }
}
