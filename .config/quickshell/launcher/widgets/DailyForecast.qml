import QtQuick

Item {
    id: df

    property var days: []
    property real overallLow: 0
    property real overallHigh: 100
    property string iconSet: "mono-light"
    property color textColor: "#ffffff"
    property color secondaryColor: "#ffffff"
    property real secondaryOpacity: 0.70
    property color rangeBarBg: Qt.rgba(1, 1, 1, 0.12)
    property color rangeBarFill: Qt.rgba(1, 1, 1, 0.50)
    property string fontFamily: ""
    property real fontSize: 11
    property var iconNameForCode: null

    Column {
        id: contentColumn
        anchors.fill: parent
        spacing: Math.round(df.height * 0.03)

        Repeater {
            model: df.days ? df.days.length : 0

            Item {
                width: df.width
                height: (contentColumn.height - (df.days.length - 1) * contentColumn.spacing) / Math.max(1, df.days.length)

                readonly property var entry: df.days[index]
                readonly property real range: Math.max(1, df.overallHigh - df.overallLow)

                // Day of week
                Text {
                    id: dayLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.14
                    text: entry ? entry.day : "--"
                    color: df.textColor
                    font.family: df.fontFamily
                    font.pixelSize: df.fontSize
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                }

                // Weather Icon
                WeatherIcon {
                    id: dayIcon
                    anchors.left: dayLabel.right
                    anchors.leftMargin: parent.width * 0.02
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: entry && df.iconNameForCode ? df.iconNameForCode(entry.weatherCode, false) : "sunny"
                    iconSet: df.iconSet
                    iconSize: Math.min(parent.height * 0.85, df.fontSize * 1.8)
                }

                // Low temp
                Text {
                    id: lowLabel
                    anchors.left: dayIcon.right
                    anchors.leftMargin: parent.width * 0.03
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.09
                    text: entry ? entry.low + "°" : "--"
                    color: df.secondaryColor
                    opacity: df.secondaryOpacity
                    font.family: df.fontFamily
                    font.pixelSize: df.fontSize
                    horizontalAlignment: Text.AlignRight
                    renderType: Text.NativeRendering
                }

                // Range capsule bar
                Item {
                    id: barContainer
                    anchors.left: lowLabel.right
                    anchors.leftMargin: parent.width * 0.03
                    anchors.right: highLabel.left
                    anchors.rightMargin: parent.width * 0.03
                    anchors.verticalCenter: parent.verticalCenter
                    height: Math.max(4, Math.round(df.fontSize * 0.35))

                    // Track background
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: df.rangeBarBg
                    }

                    // Temperature pill fill
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        radius: height / 2
                        color: df.rangeBarFill
                        x: {
                            if (!entry || range <= 0) return 0
                            return (parseFloat(entry.low) - df.overallLow) / range * parent.width
                        }
                        width: {
                            if (!entry || range <= 0) return parent.width
                            return Math.max(height, (parseFloat(entry.high) - parseFloat(entry.low)) / range * parent.width)
                        }
                    }
                }

                // High temp
                Text {
                    id: highLabel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.09
                    text: entry ? entry.high + "°" : "--"
                    color: df.textColor
                    font.family: df.fontFamily
                    font.pixelSize: df.fontSize
                    horizontalAlignment: Text.AlignLeft
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
