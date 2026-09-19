import QtQuick

Item {
    id: hf

    property var slots: []
    property string iconSet: "mono-light"
    property color textColor: "#ffffff"
    property color secondaryTextColor: "#ffffff"
    property real secondaryOpacity: 0.70
    property string fontFamily: ""
    property real baseFontSize: 11

    readonly property int _fontSize: Math.max(8, Math.round(baseFontSize * 0.90))
    readonly property real _slotWidth: hf.slots && hf.slots.length > 0 ? (hf.width / hf.slots.length) : (hf.width / 6)

    Row {
        anchors.fill: parent

        Repeater {
            model: hf.slots ? hf.slots.length : 0

            Item {
                width: hf._slotWidth
                height: hf.height

                readonly property var slot: hf.slots[index]

                Column {
                    anchors.centerIn: parent
                    spacing: Math.round(hf.height * 0.08)

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: slot ? slot.displayTime : "--"
                        color: hf.secondaryTextColor
                        opacity: hf.secondaryOpacity
                        font.family: hf.fontFamily
                        font.pixelSize: hf._fontSize
                        font.weight: Font.Normal
                        renderType: Text.NativeRendering
                    }

                    WeatherIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        iconName: slot ? slot.iconName : "sunny"
                        iconSet: hf.iconSet
                        iconSize: Math.round(hf.height * 0.38)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (slot ? slot.temp : "--") + "°"
                        color: hf.textColor
                        font.family: hf.fontFamily
                        font.pixelSize: hf._fontSize
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }
}
