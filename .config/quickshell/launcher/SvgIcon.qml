import QtQuick
import QtQuick.Effects

Item {
    id: root

    property string name: ""
    property int size: 16
    property color color: "#ffffff"

    width: size
    height: size

    readonly property bool isWhite: {
        const s = String(root.color).toLowerCase()
        return s === "#ffffff" || s === "#ffffffff" || s === "white"
    }

    Image {
        id: img
        anchors.fill: parent
        source: root.name ? ("file:///home/gabriel/.config/quickshell/assets/icons/" + root.name + ".svg") : ""
        sourceSize: Qt.size(root.size * 4, root.size * 4)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true

        layer.enabled: !root.isWhite
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: root.color
        }
    }
}
