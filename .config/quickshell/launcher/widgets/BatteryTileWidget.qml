import Quickshell
import Quickshell.Io
import QtQuick
import "../services"

// Tile "Bateria": anel com a porcentagem (verde carregando, laranja < 20%, vermelho < 10%).
// Clique abre o painel (como Wi-Fi/Bluetooth): tempo restante, watts, saúde, ciclos,
// limite de carga em 80% (asusctl) e o modo de energia atual. Dados: BatteryService.
Item {
    id: root
    anchors.fill: parent

    property alias cardItem: full
    property alias sharedBackdrop: glass.sharedBackdrop

    function setWallpaper(path) {
        glass.setWallpaper(path);
    }


    property real targetX: 1530
    property real targetY: 586
    property real targetWidth: 76
    property real targetHeight: 76
    property string variant: "classic"   // visual escolhido pelo layout ("classic" = o de sempre)
    // variant "hidden": some com fade (o layout não usa este widget)
    opacity: variant === "hidden" ? 0 : 1
    visible: opacity > 0.01
    Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 260 } }
    property bool isExpanded: false

    // ── Dados (BatteryService: um poller só) ──
    readonly property int percent: BatteryService.percent
    readonly property string status: BatteryService.status
    readonly property bool onAc: BatteryService.onAc
    readonly property real watts: BatteryService.watts
    readonly property int minutes: BatteryService.minutes
    readonly property int health: BatteryService.health
    readonly property int cycles: BatteryService.cycles
    readonly property int chargeLimit: BatteryService.chargeLimit
    readonly property string powerMode: BatteryService.powerMode

    readonly property bool charging: BatteryService.charging
    readonly property color ringColor: charging ? "#34c759"
                                     : (percent < 10 ? "#ff3b30" : (percent < 20 ? "#ff9500" : "#ffffff"))

    function fmtTime(m) {
        if (m < 0) return "";
        const h = Math.floor(m / 60), mm = m % 60;
        return h > 0 ? (h + " h " + (mm < 10 ? "0" : "") + mm + " min") : (mm + " min");
    }
    readonly property string statusText: {
        if (status === "Charging") return minutes >= 0 ? ("Carregando · cheia em " + fmtTime(minutes)) : "Carregando";
        if (status === "Discharging") return minutes >= 0 ? (fmtTime(minutes) + " restantes") : "Na bateria";
        if (status === "Full") return "Carregada";
        if (onAc) return chargeLimit < 100 ? ("Na tomada · parada em " + chargeLimit + "%") : "Na tomada";
        return "Bateria";
    }

    onIsExpandedChanged: BatteryService.fast = isExpanded

    Item {
        id: full
        opacity: vhost.active || root.variant === "hidden" ? 0 : 1   // clássico some quando uma variante assume ou quando o layout esconde o widget (senão pisca no fade-out)
        visible: opacity > 0.01
        Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 200 } }
        x: root.targetX
        y: root.targetY
        width: root.isExpanded ? 340 : root.targetWidth
        height: root.isExpanded ? 290 : root.targetHeight

        Behavior on x { enabled: !GlassTheme.gaming; NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on y { enabled: !GlassTheme.gaming; NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on width { enabled: !GlassTheme.gaming; NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }
        Behavior on height { enabled: !GlassTheme.gaming; NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }

        scale: (tileMouse.pressed && !root.isExpanded) ? 0.92 : ((tileMouse.containsMouse && !root.isExpanded) ? 1.04 : 1.0)
        Behavior on scale { enabled: !GlassTheme.gaming; NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: root.isExpanded ? 28 : (root.variant === "circle" ? Math.min(full.height, full.width) / 2 : Math.min(24, Math.min(full.height, full.width) * 0.45))
            roundness: (root.variant === "circle" && root.isExpanded !== true) ? 2.0 : 4.6   // "circle": tile redondo (Orbit/Hero/Island)
            tint: root.isExpanded ? "#0a1024" : "#ffffff"
            tintAlpha: root.isExpanded ? 0.30 : (tileMouse.containsMouse ? 0.18 : 0.10)
            lumaCap: root.isExpanded ? 0.50 : 0.80
            Behavior on tint { enabled: !GlassTheme.gaming; ColorAnimation { duration: 320 } }
            Behavior on tintAlpha { enabled: !GlassTheme.gaming; NumberAnimation { duration: 320 } }
            Behavior on lumaCap { enabled: !GlassTheme.gaming; NumberAnimation { duration: 320 } }
            widgetX: full.x
            widgetY: full.y
            screenWidth: root.width > 0 ? root.width : 1920
            screenHeight: root.height > 0 ? root.height : 1080
        }

        // ══ 1. TILE: anel + porcentagem ══
        Item {
            anchors.fill: parent
            visible: !root.isExpanded

            Canvas {
                id: ring
                anchors.centerIn: parent
                width: Math.min(46, Math.min(parent.width, parent.height) * 0.68)
                height: width
                property real value: root.percent / 100
                property color col: root.ringColor
                Behavior on value { enabled: !GlassTheme.gaming; NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                onValueChanged: requestPaint()
                onColChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const lw = Math.max(3, width * 0.09), r = width / 2 - lw / 2;
                    ctx.lineWidth = lw;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.16);
                    ctx.beginPath(); ctx.arc(width / 2, height / 2, r, 0, 2 * Math.PI); ctx.stroke();
                    if (value > 0) {
                        ctx.strokeStyle = col;
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * value);
                        ctx.stroke();
                    }
                }
            }

            Text {
                anchors.centerIn: ring
                anchors.verticalCenterOffset: root.charging ? 3 : 0
                text: root.percent
                color: "#ffffff"
                font.family: "SF Pro Rounded"
                font.pixelSize: Math.round(ring.width * 0.30)
                font.weight: Font.Bold
            }

            Image {
                visible: root.charging
                anchors.horizontalCenter: ring.horizontalCenter
                y: ring.y + ring.height * 0.18
                width: Math.round(ring.width * 0.22)
                height: width
                source: "file://" + GlassTheme.home + "/.config/quickshell/assets/icons/bolt-small.svg"
                sourceSize.width: 32
                sourceSize.height: 32
                fillMode: Image.PreserveAspectFit
            }
        }

        // ══ 2. PAINEL ══
        Item {
            id: expPanel
            anchors.fill: parent
            anchors.margins: 16
            visible: root.isExpanded || opacity > 0.01
            opacity: root.isExpanded ? 1 : 0
            Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 240 } }
            clip: true

            PanelHeader {
                id: hdr
                width: parent.width
                iconSource: "file://" + GlassTheme.home + "/.config/quickshell/assets/icons/bolt-small.svg"
                accent: root.charging ? "#34c759" : "#0a84ff"
                title: "Bateria"
                subtitle: root.statusText
                showRefresh: false
                onCloseClicked: root.isExpanded = false
            }

            // Porcentagem grande + barra
            Item {
                id: bigRow
                anchors.top: hdr.bottom
                anchors.topMargin: 14
                width: parent.width
                height: 44

                Text {
                    id: bigPct
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.percent + "%"
                    color: "#ffffff"
                    font.family: "SF Pro Rounded"
                    font.pixelSize: 34
                    font.weight: Font.Bold
                }

                Rectangle {
                    id: bar
                    anchors.left: bigPct.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 14
                    radius: 7
                    color: Qt.rgba(1, 1, 1, 0.14)

                    Rectangle {
                        width: Math.max(height, parent.width * root.percent / 100)
                        height: parent.height
                        radius: 7
                        color: root.ringColor
                        Behavior on width { enabled: !GlassTheme.gaming; NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    }
                    // marca do limite de carga
                    Rectangle {
                        visible: root.chargeLimit < 100
                        x: parent.width * root.chargeLimit / 100 - 1
                        y: -3
                        width: 2
                        height: parent.height + 6
                        radius: 1
                        color: "#ffffff"
                        opacity: 0.8
                    }
                }
            }

            // Linhas de informação
            Column {
                id: info
                anchors.top: bigRow.bottom
                anchors.topMargin: 12
                width: parent.width
                spacing: 5

                Repeater {
                    model: [
                        [root.charging ? "Entrada" : "Consumo", root.watts.toFixed(1) + " W"],
                        ["Saúde", root.health + "%" + (root.cycles > 0 ? "  ·  " + root.cycles + " ciclos" : "")],
                        ["Modo de energia", ({ silent: "Silencioso", balanced: "Equilibrado", performance: "Desempenho" })[root.powerMode] || "—"]
                    ]
                    Rectangle {
                        required property var modelData
                        width: info.width
                        height: 30
                        radius: 11
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData[0]
                            color: Qt.rgba(1, 1, 1, 0.70)
                            font.family: "SF Pro Display"
                            font.pixelSize: 12
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData[1]
                            color: "#ffffff"
                            font.family: "SF Pro Display"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }
                }

                // Limite de carga
                Rectangle {
                    width: info.width
                    height: 36
                    radius: 11
                    color: Qt.rgba(1, 1, 1, 0.08)

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: "Limitar carga a 80%"
                            color: "#ffffff"
                            font.family: "SF Pro Display"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: "Conserva a bateria na tomada"
                            color: Qt.rgba(1, 1, 1, 0.55)
                            font.family: "SF Pro Display"
                            font.pixelSize: 9
                        }
                    }
                    PillSwitch {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        on: root.chargeLimit < 100
                        onToggled: BatteryService.setLimit(BatteryService.chargeLimit < 100 ? 100 : 80)
                    }
                }
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !root.isExpanded
            onPositionChanged: (mouse) => {
                glass.mouseU = mouse.x / Math.max(1, full.width);
                glass.mouseV = mouse.y / Math.max(1, full.height);
                glass.mouseFade = 1;
            }
            onEntered: {
                glass.mouseFade = 1;
            }
            onExited: {
                glass.mouseFade = 0;
                glass.mouseU = -1;
                glass.mouseV = -1;
            }
            onClicked: root.isExpanded = true
        }
    }

    // Visuais alternativos escolhidos pelo layout (widgets/variants/)
    VariantHost {
        id: vhost
        variant: root.variant
        sources: ({ big: Qt.resolvedUrl("variants/BatteryBig.qml") })
        targetX: root.targetX
        targetY: root.targetY
        targetWidth: root.targetWidth
        targetHeight: root.targetHeight
        sharedBackdrop: root.sharedBackdrop
        screenW: root.width > 0 ? root.width : 1920
        screenH: root.height > 0 ? root.height : 1200
    }
}
