import QtQuick

// Switch estilo iOS
Item {
    id: sw
    property bool on: false
    signal toggled()

    width: 44
    height: 26

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.on ? "#34c759" : Qt.rgba(1, 1, 1, 0.22)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, sw.on ? 0.0 : 0.18)
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    Rectangle {
        id: knob
        width: 22; height: 22
        radius: 11
        y: 2
        x: sw.on ? sw.width - width - 2 : 2
        color: "#ffffff"
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
