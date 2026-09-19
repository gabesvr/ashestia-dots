import QtQuick

// Filled active-date circle with punch-out digit effect
Item {
    id: root

    property int dayNumber: 1
    property real diameter: 24
    property real circleXOffset: 0
    property real circleYOffset: 0
    property real fontPixelSize: 11
    property color badgeColor: "#ffffff"
    property color textColor: "#1c1c1e"
    property string fontFamily: ""
    property bool punchOutText: true
    property rect contentRect: Qt.rect(0, 0, width, height)

    onDayNumberChanged: canvas.requestPaint()
    onBadgeColorChanged: canvas.requestPaint()
    onTextColorChanged: canvas.requestPaint()
    onFontFamilyChanged: canvas.requestPaint()
    onDiameterChanged: canvas.requestPaint()
    onCircleXOffsetChanged: canvas.requestPaint()
    onCircleYOffsetChanged: canvas.requestPaint()
    onFontPixelSizeChanged: canvas.requestPaint()
    onPunchOutTextChanged: canvas.requestPaint()
    onContentRectChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        renderTarget: Canvas.Image

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.imageSmoothingEnabled = true;
            ctx.imageSmoothingQuality = "high";

            const textCx = root.contentRect.x + root.contentRect.width / 2;
            const textCy = root.contentRect.y + root.contentRect.height / 2;
            const circleCx = textCx + root.circleXOffset;
            const circleCy = textCy + root.circleYOffset;
            const r = root.diameter / 2;

            // 1. Draw white circle badge
            ctx.fillStyle = root.badgeColor;
            ctx.beginPath();
            ctx.arc(circleCx, circleCy, r, 0, Math.PI * 2);
            ctx.closePath();
            ctx.fill();

            const px = Math.round(root.fontPixelSize);
            ctx.font = "600 " + px + "px \"" + root.fontFamily + "\"";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";

            if (root.punchOutText) {
                // destination-out cuts out the digit so wallpaper shines through
                ctx.globalCompositeOperation = "destination-out";
                ctx.fillStyle = "#ffffff";
            } else {
                ctx.globalCompositeOperation = "source-over";
                ctx.fillStyle = root.textColor;
            }

            const text = String(root.dayNumber);
            ctx.fillText(text, textCx, circleCy);
            ctx.globalCompositeOperation = "source-over";
        }
    }
}
