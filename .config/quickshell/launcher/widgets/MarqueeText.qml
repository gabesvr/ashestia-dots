import QtQuick

Item {
    id: marquee

    property string text: ""
    property real fontSize: 13
    property int fontWeight: Font.DemiBold
    property color textColor: "#ffffff"
    property string fontFamily: ""
    property real textOpacity: 1.0
    property int scrollSpeed: 40
    property int initialPause: 4000
    property int endPause: 2500
    property int maxLoops: 3
    property bool scrollEnabled: true
    property int horizontalAlignment: Text.AlignLeft

    clip: true

    Text {
        id: label
        text: marquee.text
        textFormat: Text.PlainText
        font.pixelSize: marquee.fontSize
        font.weight: marquee.fontWeight
        font.family: marquee.fontFamily
        color: marquee.textColor
        opacity: marquee.textOpacity
        renderType: Text.NativeRendering
        elide: needsScrolling ? Text.ElideNone : Text.ElideRight
        width: needsScrolling ? implicitWidth : parent.width
        horizontalAlignment: needsScrolling ? Text.AlignLeft : marquee.horizontalAlignment

        property bool needsScrolling: marquee.scrollEnabled && implicitWidth > marquee.width

        x: 0

        SequentialAnimation on x {
            id: scrollAnim
            running: label.needsScrolling
            loops: marquee.maxLoops

            PauseAnimation { duration: marquee.initialPause }

            NumberAnimation {
                from: 0
                to: -(label.implicitWidth - marquee.width)
                duration: label.needsScrolling ? Math.max(1, Math.round((label.implicitWidth - marquee.width) * marquee.scrollSpeed)) : 0
                easing.type: Easing.Linear
            }

            PauseAnimation { duration: marquee.endPause }

            NumberAnimation {
                from: -(label.implicitWidth - marquee.width)
                to: 0
                duration: label.needsScrolling ? Math.max(1, Math.round((label.implicitWidth - marquee.width) * marquee.scrollSpeed)) : 0
                easing.type: Easing.Linear
            }

            PauseAnimation { duration: marquee.endPause }
        }

        Connections {
            target: marquee
            function onTextChanged() {
                scrollAnim.stop();
                label.x = 0;
                if (label.needsScrolling) scrollAnim.restart();
            }
            function onWidthChanged() {
                scrollAnim.stop();
                label.x = 0;
                if (label.needsScrolling) scrollAnim.restart();
            }
        }
    }
}
