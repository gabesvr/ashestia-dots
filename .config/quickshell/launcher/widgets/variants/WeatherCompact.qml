import QtQuick
import ".."
import "../../services"

// Orbit: card pequeno — ícone, temperatura e condição.
Item {
    id: v
    property Item host
    anchors.fill: parent
    readonly property var wd: WeatherService.data


    VGlass { anchors.fill: parent; host: v.host; radius: Math.min(28, height * 0.3) }

    Row {
        anchors.centerIn: parent
        spacing: v.height * 0.14
        WeatherIcon {
            anchors.verticalCenter: parent.verticalCenter
            iconName: v.wd.iconNameForCode(v.wd.weatherCode, v.wd.isNight)
            iconSize: v.height * 0.46
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: v.wd.currentTemp + "°"
                font.family: "SF Pro Display"; font.weight: Font.Light
                font.pixelSize: v.height * 0.4
                color: "#ffffff"
            }
            Text {
                text: v.wd.condition
                font.family: "SF Pro Rounded"
                font.pixelSize: v.height * 0.13
                color: Qt.rgba(1, 1, 1, 0.72)
            }
        }
    }
}
