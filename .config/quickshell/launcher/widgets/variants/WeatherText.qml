import QtQuick
import ".."
import "../../services"

// Editorial: temperatura fina gigante alinhada à direita, sem card.
Item {
    id: v
    property Item host
    anchors.fill: parent
    readonly property var wd: WeatherService.data


    Column {
        id: content
        anchors.right: parent.right
        anchors.top: parent.top
        Text {
            anchors.right: parent.right
            text: v.wd.currentTemp + "°"
            font.family: "SF Pro Display"; font.weight: Font.Thin
            font.pixelSize: v.height * 0.62
            renderType: Text.CurveRendering   // texto gigante: sem artefatos do distance field
            color: "#ffffff"
        }
        Text {
            anchors.right: parent.right
            text: v.wd.condition
            font.family: "Noto Serif Display"
            font.italic: true
            font.pixelSize: v.height * 0.13
            color: "#ffffff"
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.35)
        }
        Text {
            anchors.right: parent.right
            text: (v.wd.cityName || v.wd.location).toUpperCase() + "  ·  MÁX " + v.wd.highTemp + "°  MÍN " + v.wd.lowTemp + "°"
            font.family: "SF Pro Display"; font.weight: Font.Light
            font.pixelSize: v.height * 0.065
            font.letterSpacing: 2
            color: Qt.rgba(1, 1, 1, 0.85)
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.35)
        }
    }
}
