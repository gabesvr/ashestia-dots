import QtQuick

Item {
    id: iconItem

    property string iconName: "sunny"
    property string iconSet: "mono-light"
    property real iconSize: 36

    implicitWidth: iconSize
    implicitHeight: iconSize
    width: iconSize
    height: iconSize

    Image {
        anchors.fill: parent
        source: "/home/gabriel/.config/quickshell/assets/weather/" + iconItem.iconSet + "/" + iconItem.iconName + ".png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }
}
