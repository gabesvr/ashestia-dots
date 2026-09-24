import QtQuick
import ".."
import "../../services"

// Bento: card da bateria com o número grande e o anel.
Item {
    id: v
    property Item host
    anchors.fill: parent
    readonly property color col: BatteryService.charging ? "#34c759" : (BatteryService.percent < 10 ? "#ff3b30" : (BatteryService.percent < 20 ? "#ff9500" : "#ffffff"))

    VGlass { anchors.fill: parent; host: v.host; radius: 32; tint: v.col; tintAlpha: BatteryService.charging ? 0.14 : 0.08 }

    Canvas {
        id: ring
        width: Math.min(v.width, v.height) * 0.62; height: width
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -v.height * 0.04
        property real val: BatteryService.percent / 100
        property color c: v.col
        onValChanged: requestPaint()
        onCChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d"); ctx.reset();
            const lw = width * 0.08, r = width / 2 - lw / 2;
            ctx.lineWidth = lw; ctx.lineCap = "round";
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.14);
            ctx.beginPath(); ctx.arc(width / 2, height / 2, r, 0, 2 * Math.PI); ctx.stroke();
            ctx.strokeStyle = c;
            ctx.beginPath(); ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * val); ctx.stroke();
        }
        Text {
            anchors.centerIn: parent
            text: BatteryService.percent + "%"
            font.family: "SF Pro Display"; font.weight: Font.Light
            font.pixelSize: parent.width * 0.3
            color: "#ffffff"
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: v.height * 0.07
        text: BatteryService.charging ? "⚡ Carregando" : (BatteryService.status === "Discharging" ? "Na bateria" : "Na tomada")
        font.family: "SF Pro Rounded"
        font.pixelSize: v.height * 0.075
        font.weight: Font.DemiBold
        color: v.col
    }
}
