import QtQuick

Item {
    id: slider

    property real position: 0 // in seconds
    property real length: 0   // in seconds
    property color fillColor: "#ffffff"
    property color trackColor: "#ffffff"
    property real trackOpacity: 0.20
    property color timeLabelColor: "#ffffff"
    property real timeLabelOpacity: 0.55
    property string fontFamily: ""
    property real fontSize: 10
    property bool showTimeLabels: true

    signal seek(real positionSec)

    function formatTime(seconds) {
        if (!seconds || seconds <= 0 || isNaN(seconds)) return "0:00";
        var totalSec = Math.floor(seconds);
        var m = Math.floor(totalSec / 60);
        var s = totalSec % 60;
        return m + ":" + (s < 10 ? "0" + s : s);
    }

    implicitHeight: showTimeLabels ? (barArea.height + timeRow.height + 2) : barArea.height

    property bool _active: barMouse.containsMouse || barMouse.pressed

    Item {
        id: barArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 14

        // Track background line
        Rectangle {
            id: track
            anchors.centerIn: parent
            width: parent.width
            height: slider._active ? 6 : 3
            radius: height / 2
            color: slider.trackColor
            opacity: slider.trackOpacity

            Behavior on height { enabled: !GlassTheme.gaming;
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }

        // Fill bar line
        Rectangle {
            id: fill
            anchors.verticalCenter: track.verticalCenter
            anchors.left: track.left
            width: slider.length > 0 ? (track.width * Math.min(1, Math.max(0, slider.position / slider.length))) : 0
            height: track.height
            radius: height / 2
            color: slider.fillColor
            opacity: 0.85

            Behavior on width {
                enabled: !GlassTheme.gaming && !barMouse.pressed
                NumberAnimation { duration: 180 }
            }
        }

        // Click / Drag Mouse Area
        MouseArea {
            id: barMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onPressed: function(mouse) { _seekTo(mouse.x) }
            onPositionChanged: function(mouse) {
                if (pressed) _seekTo(mouse.x)
            }

            function _seekTo(mx) {
                var ratio = Math.max(0, Math.min(1, mx / width));
                slider.seek(ratio * slider.length);
            }
        }
    }

    // Time elapsed on left, duration on right
    Item {
        id: timeRow
        visible: slider.showTimeLabels
        anchors.top: barArea.bottom
        anchors.topMargin: 2
        anchors.left: parent.left
        anchors.right: parent.right
        height: currentLabel.height

        Text {
            id: currentLabel
            anchors.left: parent.left
            text: slider.formatTime(slider.position)
            color: slider.timeLabelColor
            opacity: slider.timeLabelOpacity
            font.family: slider.fontFamily
            font.pixelSize: slider.fontSize
            font.weight: Font.Normal
            renderType: Text.NativeRendering
        }

        Text {
            id: totalLabel
            anchors.right: parent.right
            text: slider.formatTime(slider.length)
            color: slider.timeLabelColor
            opacity: slider.timeLabelOpacity
            font.family: slider.fontFamily
            font.pixelSize: slider.fontSize
            font.weight: Font.Normal
            renderType: Text.NativeRendering
        }
    }
}
