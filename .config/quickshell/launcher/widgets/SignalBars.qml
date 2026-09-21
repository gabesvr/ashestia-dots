import QtQuick

// Barrinhas de intensidade de sinal (0-4)
Row {
    id: bars
    property int level: 0
    property color activeColor: "#ffffff"
    spacing: 2
    height: 14

    Repeater {
        model: 4
        Rectangle {
            width: 3
            height: 4 + index * 3
            radius: 1.5
            anchors.bottom: parent.bottom
            color: index < bars.level ? bars.activeColor : Qt.rgba(1, 1, 1, 0.26)
        }
    }
}
