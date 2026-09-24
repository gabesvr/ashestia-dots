import QtQuick
import Quickshell
import ".."

// Editorial: capa de revista — dia da semana espaçado, número do dia gigante em serifa, mês e hora.
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
            id: wd
            x: v.height * 0.02
            y: 0
            text: v.loc.dayName(clk.date.getDay(), Locale.LongFormat).toUpperCase()
            font.family: "SF Pro Display"; font.weight: Font.Light
            font.pixelSize: Math.round(v.height * 0.06)
            font.letterSpacing: v.height * 0.03
            color: "#ffffff"
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.35)
        }
        Text {
            id: day
            anchors.top: wd.bottom
            anchors.topMargin: -v.height * 0.06
            text: clk.date.getDate()
            font.family: "Noto Serif Display"
            font.weight: Font.Black
            font.pixelSize: Math.round(v.height * 0.72)
            renderType: Text.CurveRendering   // texto gigante: sem artefatos do distance field
            color: "#ffffff"
        }
        Row {
            anchors.top: day.bottom
            anchors.topMargin: -v.height * 0.07
            x: v.height * 0.02
            spacing: v.height * 0.03
            Text {
                text: v.loc.monthName(clk.date.getMonth(), Locale.LongFormat)
                font.family: "Noto Serif Display"
                font.italic: true
                font.pixelSize: Math.round(v.height * 0.075)
                color: "#ffffff"
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.35)
        }
            Rectangle { width: v.height * 0.06; height: 1.5; color: "#ffffff"; opacity: 0.7; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: Qt.formatTime(clk.date, "HH:mm")
                font.family: "SF Pro Display"; font.weight: Font.Light
                font.pixelSize: Math.round(v.height * 0.07)
                font.letterSpacing: 2
                color: "#ffffff"
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.35)
        }
        }
    }
}
