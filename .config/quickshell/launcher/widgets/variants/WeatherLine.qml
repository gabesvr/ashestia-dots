import QtQuick
import ".."
import "../../services"

// Hero: clima numa pílula de uma linha só.
Item {
    id: v
    property Item host
    anchors.fill: parent
    readonly property var wd: WeatherService.data


    VGlass { anchors.fill: parent; host: v.host; radius: height / 2 }

    Row {
        anchors.centerIn: parent
        spacing: 10
        WeatherIcon {
            anchors.verticalCenter: parent.verticalCenter
            iconName: v.wd.iconNameForCode(v.wd.weatherCode, v.wd.isNight)
            iconSize: v.height * 0.5
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: v.wd.currentTemp + "°"
            font.family: "SF Pro Rounded"
            font.pixelSize: v.height * 0.42
            font.weight: Font.Bold
            color: "#ffffff"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: v.wd.condition + "  ·  " + (v.wd.cityName || v.wd.location) + "  ·  ↑" + v.wd.highTemp + "° ↓" + v.wd.lowTemp + "°"
            font.family: "SF Pro Rounded"
            font.pixelSize: v.height * 0.28
            color: Qt.rgba(1, 1, 1, 0.8)
        }
    }
}
