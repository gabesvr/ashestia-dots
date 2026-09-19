import QtQuick
import QtQuick.Effects

Item {
    id: art

    property string artUrl: ""
    property real radius: 14
    property color fallbackColor: "#1c1c1e"

    // Background placeholder
    Rectangle {
        anchors.fill: parent
        color: art.fallbackColor
        radius: art.radius
        opacity: 0.35
    }

    // Cover image
    Image {
        id: coverImage
        anchors.fill: parent
        source: art.artUrl && art.artUrl.length > 0 ? art.artUrl : "/home/gabriel/.config/quickshell/assets/icons/music_widget/no_album.png"
        sourceSize.width: 256
        sourceSize.height: 256
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        visible: false
        layer.enabled: true
    }

    // Rounded mask
    Item {
        id: roundMask
        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: art.radius
            color: "white"
        }
    }

    // Masked artwork
    MultiEffect {
        anchors.fill: parent
        source: coverImage
        maskEnabled: true
        maskSource: roundMask
        visible: true
    }

    // Subtle inner border highlight
    Rectangle {
        anchors.fill: parent
        radius: art.radius
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.15)
        border.width: 1
    }
}
