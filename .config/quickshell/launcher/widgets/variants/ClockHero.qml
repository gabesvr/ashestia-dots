import QtQuick
import Quickshell
import ".."

// Hero Clock: dígitos gigantes e finos direto no wallpaper, com a data espaçada embaixo.
Item {
    id: v
    property Item host
    anchors.fill: parent

    SystemClock { id: clk; precision: SystemClock.Minutes }
    readonly property var loc: Qt.locale("pt_BR")

    Item {
        id: content
        anchors.fill: parent
        Text {
            id: digits
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            text: Qt.formatTime(clk.date, "HH:mm")
            font.family: "SF Pro Display"; font.weight: Font.Thin
            font.pixelSize: Math.round(v.height * 0.74)
            renderType: Text.CurveRendering   // texto gigante: sem artefatos do distance field
            font.letterSpacing: -v.height * 0.02
            color: "#ffffff"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: digits.bottom
            anchors.topMargin: -v.height * 0.04
            text: (v.loc.dayName(clk.date.getDay(), Locale.LongFormat) + " · " + clk.date.getDate() + " de " + v.loc.monthName(clk.date.getMonth(), Locale.LongFormat)).toUpperCase()
            font.family: "SF Pro Display"; font.weight: Font.Light
            font.pixelSize: Math.max(12, Math.round(v.height * 0.07))
            font.letterSpacing: v.height * 0.025
            color: "#ffffff"
            opacity: 0.88
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.35)
        }
    }
}
