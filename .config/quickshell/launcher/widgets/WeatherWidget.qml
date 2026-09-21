import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: weatherWindow
    anchors.fill: parent

    property alias cardItem: full
    property alias sharedBackdrop: glass.sharedBackdrop

    FontLoader {
        id: sfRegular
        source: Qt.resolvedUrl("fonts/sf_pro_display_regular.otf")
    }
    FontLoader {
        id: sfLight
        source: Qt.resolvedUrl("fonts/SF-Pro-Display-Light.otf")
    }

    // Animated Target Position (Driven by Layout Manager)
    property real targetX: 1620
    property real targetY: 55
    property real targetWidth: 250

    function setWallpaper(path) {
        glass.setWallpaper(path);
    }

    // Preset cities to cycle through on click
    property var cityList: ["Porto", "Lausanne"]
    property int cityIndex: 0

    WeatherData {
        id: weatherData
        location: weatherWindow.cityList[weatherWindow.cityIndex]
    }

    function cycleCity() {
        cityIndex = (cityIndex + 1) % cityList.length;
        weatherData.setLocation(cityList[cityIndex]);
    }

    // The Weather Card
    Item {
        id: full
        x: weatherWindow.targetX
        y: weatherWindow.targetY
        width: weatherWindow.targetWidth
        height: 340

        Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on y { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on width { NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }

        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: 44
            roundness: 4.6
            widgetX: full.x
            widgetY: full.y
            screenWidth: weatherWindow.width > 0 ? weatherWindow.width : 1920
            screenHeight: weatherWindow.height > 0 ? weatherWindow.height : 1080
        }

        readonly property int baseFontSize: full.height > 0 ? Math.max(10, Math.round(full.height * 0.038)) : 12

        Column {
            anchors.fill: parent
            anchors.margins: Math.round(full.height * 0.055)
            anchors.leftMargin: Math.round(full.width * 0.07)
            anchors.rightMargin: Math.round(full.width * 0.07)
            spacing: Math.round(full.height * 0.018)

            // Top Section: City & Large Temp (Left) / Icon, Condition & H/L (Right)
            Item {
                width: parent.width
                height: full.height * 0.28

                // Left: City & Big Temperature
                Column {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    spacing: 0

                    Row {
                        spacing: 4
                        Text {
                            text: weatherData.cityName || weatherData.location
                            color: "#ffffff"
                            font.family: sfRegular.name
                            font.pixelSize: Math.round(full.baseFontSize * 1.18)
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                        }

                        // Small location pin icon
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(full.baseFontSize * 0.9)
                            height: width
                            source: "/home/gabriel/.config/quickshell/assets/icons/location.png"
                            opacity: 0.75
                            smooth: true
                        }
                    }

                    Text {
                        text: (weatherData.currentTemp !== "--" ? weatherData.currentTemp : "22") + "°"
                        color: "#ffffff"
                        font.family: sfLight.name
                        font.pixelSize: Math.round(full.baseFontSize * 3.8)
                        font.weight: Font.Thin
                        renderType: Text.NativeRendering
                    }
                }

                // Right: Weather Icon, Condition, High/Low
                Column {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 2

                    WeatherIcon {
                        anchors.right: parent.right
                        iconName: weatherData.iconNameForCode(weatherData.weatherCode, weatherData.isNight)
                        iconSet: "mono-light"
                        iconSize: Math.round(full.baseFontSize * 3.2)
                    }

                    Text {
                        anchors.right: parent.right
                        text: weatherData.condition || "Overcast"
                        color: "#ffffff"
                        font.family: sfRegular.name
                        font.pixelSize: full.baseFontSize
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }

                    Text {
                        anchors.right: parent.right
                        text: "H:" + (weatherData.highTemp !== "--" ? weatherData.highTemp : "32") + "°  L:" + (weatherData.lowTemp !== "--" ? weatherData.lowTemp : "20") + "°"
                        color: "#ffffff"
                        opacity: 0.70
                        font.family: sfRegular.name
                        font.pixelSize: full.baseFontSize
                        font.weight: Font.Normal
                        renderType: Text.NativeRendering
                    }
                }
            }

            // Divider 1
            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.15)
            }

            // Middle Section: Hourly Forecast (6 slots)
            HourlyForecast {
                width: parent.width
                height: full.height * 0.20
                slots: weatherData.hourlySlots.length > 0 ? weatherData.hourlySlots : [
                    { displayTime: "12 PM", iconName: "cloudy", temp: "31" },
                    { displayTime: "1 PM",  iconName: "cloudy", temp: "32" },
                    { displayTime: "2 PM",  iconName: "cloudy", temp: "32" },
                    { displayTime: "3 PM",  iconName: "cloudy", temp: "32" },
                    { displayTime: "4 PM",  iconName: "cloudy", temp: "31" },
                    { displayTime: "5 PM",  iconName: "cloudy", temp: "30" }
                ]
                iconSet: "mono-light"
                fontFamily: sfRegular.name
                baseFontSize: full.baseFontSize
            }

            // Divider 2
            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.15)
            }

            // Bottom Section: 5-day Daily Forecast with temp bars
            DailyForecast {
                width: parent.width
                height: full.height * 0.35
                days: weatherData.dailyForecast.length > 0 ? weatherData.dailyForecast : [
                    { day: "Mon", weatherCode: 61, high: "26", low: "19" },
                    { day: "Tue", weatherCode: 3,  high: "24", low: "16" },
                    { day: "Wed", weatherCode: 61, high: "27", low: "19" },
                    { day: "Thu", weatherCode: 61, high: "31", low: "22" },
                    { day: "Fri", weatherCode: 61, high: "24", low: "19" }
                ]
                overallLow: weatherData.dailyForecast.length > 0 ? weatherData.overallLow : 16
                overallHigh: weatherData.dailyForecast.length > 0 ? weatherData.overallHigh : 31
                iconSet: "mono-light"
                fontFamily: sfRegular.name
                fontSize: full.baseFontSize
                iconNameForCode: function(code, night) { return weatherData.iconNameForCode(code, night) }
            }
        }

        // Smooth Click & Specular Interaction (Dragging disabled - driven by Layouts)
        MouseArea {
            id: clickArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onPositionChanged: (mouse) => {
                glass.mouseU = mouse.x / Math.max(1, full.width);
                glass.mouseV = mouse.y / Math.max(1, full.height);
                glass.mouseFade = 1;
            }

            onClicked: (mouse) => {
                // Click on top region cycles city, click elsewhere refreshes
                if (mouse.y < full.height * 0.3) {
                    weatherWindow.cycleCity();
                } else {
                    weatherData.forceRefresh();
                }
            }

            onEntered: {
                glass.mouseFade = 1;
            }

            onExited: {
                glass.mouseFade = 0;
                glass.mouseU = -1;
                glass.mouseV = -1;
            }
        }
    }
}
