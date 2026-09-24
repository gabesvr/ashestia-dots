import QtQuick
import Quickshell
import ".."

// Bento: card largo com a hora grande, dia da semana e anel dos segundos.
Item {
    id: v
    property Item host
    anchors.fill: parent

    SystemClock { id: clk; precision: SystemClock.Seconds }
    readonly property var loc: Qt.locale("pt_BR")

    VGlass { anchors.fill: parent; host: v.host; radius: 32 }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: v.height * 0.14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            text: v.loc.dayName(clk.date.getDay(), Locale.LongFormat)
            font.family: "SF Pro Rounded"
            font.pixelSize: Math.round(v.height * 0.11)
            font.weight: Font.DemiBold
            color: "#ff9f0a"
        }
        Text {
            text: Qt.formatTime(clk.date, "HH:mm")
            font.family: "SF Pro Display"; font.weight: Font.Light
            font.pixelSize: Math.round(v.height * 0.46)
            color: "#ffffff"
        }
        Text {
            text: clk.date.getDate() + " de " + v.loc.monthName(clk.date.getMonth(), Locale.LongFormat)
            font.family: "SF Pro Rounded"
            font.pixelSize: Math.round(v.height * 0.09)
            color: Qt.rgba(1, 1, 1, 0.65)
        }
    }

    // anel dos segundos
    Canvas {
        id: ring
        width: v.height * 0.46
        height: width
        anchors.right: parent.right
        anchors.rightMargin: v.height * 0.16
        anchors.verticalCenter: parent.verticalCenter
        property int sec: clk.date.getSeconds()
        onSecChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const c = width / 2;
            for (let i = 0; i < 60; i++) {
                const a = i / 60 * 2 * Math.PI - Math.PI / 2;
                const r1 = c - 2, r2 = c - (i % 5 === 0 ? 12 : 7);
                ctx.strokeStyle = i <= sec ? "#ffffff" : Qt.rgba(1, 1, 1, 0.18);
                ctx.lineWidth = i % 5 === 0 ? 2.4 : 1.4;
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.moveTo(c + r1 * Math.cos(a), c + r1 * Math.sin(a));
                ctx.lineTo(c + r2 * Math.cos(a), c + r2 * Math.sin(a));
                ctx.stroke();
            }
        }
        Text {
            anchors.centerIn: parent
            text: (clk.date.getSeconds() < 10 ? "0" : "") + clk.date.getSeconds()
            font.family: "SF Pro Rounded"
            font.pixelSize: parent.width * 0.26
            font.weight: Font.DemiBold
            color: "#ffffff"
        }
    }
}
