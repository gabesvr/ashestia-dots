import QtQuick
import QtQuick.Effects

Item {
    id: btn

    property string iconSource: ""
    property color iconColor: "#ffffff"
    property real iconSize: 22
    property bool activeHover: hoverArea.containsMouse

    signal clicked()

    implicitWidth: iconSize * 1.6
    implicitHeight: iconSize * 1.6

    Item {
        id: iconItem
        anchors.centerIn: parent
        width: btn.iconSize
        height: btn.iconSize
        scale: btn.activeHover && !hoverArea.pressed ? 1.08 : 1.0
        Behavior on scale { enabled: !GlassTheme.gaming; NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        layer.enabled: true
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: btn.iconColor
        }

        Image {
            anchors.fill: parent
            source: btn.iconSource
            sourceSize: Qt.size(btn.iconSize * 3, btn.iconSize * 3)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }

        SequentialAnimation {
            id: bounceAnim
            NumberAnimation {
                target: iconItem; property: "scale"
                to: 0.72; duration: 90
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: iconItem; property: "scale"
                to: 1.0; duration: 250
                easing.type: Easing.OutBack
                easing.overshoot: 2.2
            }
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            bounceAnim.restart();
            btn.clicked();
        }
    }
}
