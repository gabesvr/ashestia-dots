import QtQuick

// Botão circular translúcido com ícone SVG (kind: "icon") ou "X" desenhado (kind: "close")
Item {
    id: btn
    property string kind: "icon"
    property url iconSource: ""
    property bool spinning: false
    property real size: 28
    signal clicked()

    width: size
    height: size

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: width / 2
        color: mouse.pressed ? Qt.rgba(1, 1, 1, 0.30) : (mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.13))
        Behavior on color { enabled: !GlassTheme.gaming; ColorAnimation { duration: 120 } }
    }

    Image {
        id: ico
        visible: btn.kind === "icon"
        anchors.centerIn: parent
        width: btn.size * 0.5
        height: width
        source: btn.iconSource
        sourceSize.width: 48
        sourceSize.height: 48
        fillMode: Image.PreserveAspectFit
        opacity: btn.spinning ? 0.6 : 0.95

        RotationAnimation on rotation {
            running: btn.spinning
            from: 0; to: 360
            duration: 900
            loops: Animation.Infinite
        }
        onVisibleChanged: if (!btn.spinning) rotation = 0
    }

    Item {
        visible: btn.kind === "close"
        anchors.centerIn: parent
        width: btn.size * 0.36
        height: width
        Rectangle { anchors.centerIn: parent; width: parent.width * 1.35; height: 1.8; radius: 1; rotation: 45;  color: "#ffffff"; opacity: 0.92 }
        Rectangle { anchors.centerIn: parent; width: parent.width * 1.35; height: 1.8; radius: 1; rotation: -45; color: "#ffffff"; opacity: 0.92 }
    }

    scale: mouse.pressed ? 0.9 : 1.0
    Behavior on scale { enabled: !GlassTheme.gaming; NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
