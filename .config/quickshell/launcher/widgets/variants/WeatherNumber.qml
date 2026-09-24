import QtQuick
import ".."
import "../../services"

// Bento: card quadrado com a temperatura enorme.
Item {
    id: v
    property Item host
    anchors.fill: parent
    readonly property var wd: WeatherService.data


    VGlass { anchors.fill: parent; host: v.host; radius: 32; tint: "#0a84ff"; tintAlpha: 0.16 }

    Text {
        x: v.width * 0.1; y: v.height * 0.09
        text: (v.wd.cityName || v.wd.location)
        font.family: "SF Pro Rounded"
        font.pixelSize: v.height * 0.085
        font.weight: Font.DemiBold
        color: "#ffffff"
    }
    WeatherIcon {
        x: v.width * 0.9 - width; y: v.height * 0.07
        iconName: v.wd.iconNameForCode(v.wd.weatherCode, v.wd.isNight)
        iconSize: v.height * 0.2
    }
    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: v.height * 0.02
        text: v.wd.currentTemp + "°"
        font.family: "SF Pro Display"; font.weight: Font.Light
        font.pixelSize: v.height * 0.42
        color: "#ffffff"
    }
    Text {
        x: v.width * 0.1; y: v.height * 0.8
        width: v.width * 0.8
        text: v.wd.condition + "   ↑" + v.wd.highTemp + "° ↓" + v.wd.lowTemp + "°"
        elide: Text.ElideRight
        font.family: "SF Pro Rounded"
        font.pixelSize: v.height * 0.07
        color: Qt.rgba(1, 1, 1, 0.75)
    }
}
