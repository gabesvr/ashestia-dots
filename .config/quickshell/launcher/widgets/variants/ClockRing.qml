import QtQuick
import Quickshell
import ".."

// Orbit: relógio redondo de vidro com os segundos correndo na borda.
Item {
    id: v
    property Item host
    anchors.fill: parent

    SystemClock { id: clk; precision: SystemClock.Seconds }
    readonly property var loc: Qt.locale("pt_BR")
    readonly property real d: Math.min(width, height)

    VGlass {
        width: v.d; height: v.d
        anchors.centerIn: parent
        host: v.host
        offsetX: (v.width - v.d) / 2
        offsetY: (v.height - v.d) / 2
        radius: v.d / 2
        roundness: 2.0
    }

    Canvas {
        id: ring
        width: v.d; height: v.d
        anchors.centerIn: parent
        property int sec: clk.date.getSeconds()
        onSecChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const c = width / 2, r = c - 14;
            ctx.lineWidth = 5;
            ctx.lineCap = "round";
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.14);
            ctx.beginPath(); ctx.arc(c, c, r, 0, 2 * Math.PI); ctx.stroke();
            ctx.strokeStyle = "#ffffff";
            ctx.beginPath(); ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + (sec + 1) / 60 * 2 * Math.PI); ctx.stroke();
            // ponto na ponta
            const a = -Math.PI / 2 + (sec + 1) / 60 * 2 * Math.PI;
            ctx.fillStyle = "#ff9f0a";
            ctx.beginPath(); ctx.arc(c + r * Math.cos(a), c + r * Math.sin(a), 6, 0, 2 * Math.PI); ctx.fill();
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clk.date, "HH:mm")
            font.family: "SF Pro Display"; font.weight: Font.Thin
            font.pixelSize: Math.round(v.d * 0.27)
            color: "#ffffff"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: v.loc.dayName(clk.date.getDay(), Locale.ShortFormat).toUpperCase() + " " + clk.date.getDate()
            font.family: "SF Pro Rounded"
            font.pixelSize: Math.round(v.d * 0.055)
            font.letterSpacing: 3
            font.weight: Font.DemiBold
            color: Qt.rgba(1, 1, 1, 0.7)
        }
    }
}
