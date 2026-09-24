import QtQuick
import "."

// Botão redondo com ícone (controles das variantes do player).
Item {
    id: b
    property string icon: "play"
    property real size: 32
    property bool filled: false
    property color fillColor: "#ffffff"
    signal clicked()
    width: size; height: size
    scale: ma.pressed ? 0.88 : (ma.containsMouse ? 1.08 : 1.0)
    Behavior on scale { enabled: !GlassTheme.gaming; NumberAnimation { duration: 120 } }
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: b.filled ? b.fillColor : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : "transparent")
    }
    Image {
        anchors.centerIn: parent
        width: b.size * 0.5; height: width
        source: "file://" + GlassTheme.home + "/.config/quickshell/assets/icons/" + b.icon + ".svg"
        sourceSize.width: 48; sourceSize.height: 48
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
}
