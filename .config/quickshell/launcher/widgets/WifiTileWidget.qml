import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

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

    property bool isWifiOn: true
    property string wifiSsid: ""
    property bool isExpanded: false

    signal toggleRequested()

    property var networkList: []
    property bool isScanning: false
    property string selectedSsid: ""
    property string passwordInput: ""
    property string statusMessage: ""
    property string connectingSsid: ""   // trava cliques durante a conexão (um 2º connect derruba a rede)

    // rescan = true: lista em cache na hora + varredura nova (o NM quase não varre sozinho com sinal bom)
    function scanNetworks(rescan) {
        if (isScanning) return;
        isScanning = true;
        scanProc.command = ["/home/gabriel/.config/quickshell/scripts/wifi_tool.sh", "list"].concat(rescan ? ["rescan"] : []);
        scanProc.running = false;
        scanProc.running = true;
    }

    function connectTo(ssid, password) {
        if (connectingSsid !== "") return;
        connectingSsid = ssid;
        statusMessage = "Connecting to " + ssid + "...";
        connectProc.command = ["/home/gabriel/.config/quickshell/scripts/wifi_tool.sh", "connect", ssid];
        if (password) connectProc.command.push(password);
        connectProc.running = false;
        connectProc.running = true;
    }

    Process {
        id: scanProc
        command: ["/home/gabriel/.config/quickshell/scripts/wifi_tool.sh", "list"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const data = JSON.parse(line.trim());
                    if (data.networks) root.networkList = data.networks;
                } catch(e) {}
            }
        }
        onExited: (code) => { root.isScanning = false; }
    }

    Process {
        id: connectProc
        running: false
        onExited: root.connectingSsid = ""   // garante a trava solta mesmo se o script não imprimir nada
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const data = JSON.parse(line.trim());
                    if (data.success) {
                        root.statusMessage = "";
                        root.selectedSsid = "";
                        root.passwordInput = "";
                    } else {
                        root.statusMessage = "Failed: " + (data.output || "Error");
                        root.selectedSsid = root.connectingSsid;   // senha salva errada/ausente: abre o campo de senha
                    }
                } catch(e) {}
                root.connectingSsid = "";
                root.scanNetworks(false);
            }
        }
    }

    // Painel aberto: varre de novo a cada 15 s (redes que aparecem/somem)
    Timer {
        interval: 15000
        repeat: true
        running: root.isExpanded && root.isWifiOn
        onTriggered: root.scanNetworks(true)
    }

    onIsExpandedChanged: {
        if (isExpanded) {
            scanNetworks(true);
        } else {
            selectedSsid = "";
            passwordInput = "";
            statusMessage = "";
        }
    }

    Item {
        id: full
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
            tintAlpha: root.isExpanded ? 0.30 : 0.15
            lumaCap: root.isExpanded ? 0.50 : 0.80
            Behavior on tint { enabled: !GlassTheme.gaming; ColorAnimation { duration: 320 } }
            Behavior on tintAlpha { enabled: !GlassTheme.gaming; NumberAnimation { duration: 320 } }
            Behavior on lumaCap { enabled: !GlassTheme.gaming; NumberAnimation { duration: 320 } }
            widgetX: full.x
            widgetY: full.y
            screenWidth: root.width > 0 ? root.width : 1920
            screenHeight: root.height > 0 ? root.height : 1080
        }

        // ══════════════════════════════════════════════════════════════
        // 1. COLLAPSED MODE: PURE ICON-ONLY SYMBOL (NO TEXT)
        // ══════════════════════════════════════════════════════════════
        Item {
            anchors.fill: parent
            visible: !root.isExpanded

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(38, Math.min(parent.width, parent.height) * 0.60)
                height: width
                radius: width / 2
                color: root.isWifiOn ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                border.color: root.isWifiOn ? Qt.rgba(1, 1, 1, 0.40) : Qt.rgba(1, 1, 1, 0.14)

                Image {
                    anchors.centerIn: parent
                    width: parent.width * 0.52
                    height: width
                    source: "file:///home/gabriel/.config/quickshell/assets/icons/wifi.svg"
                    fillMode: Image.PreserveAspectFit
                    opacity: root.isWifiOn ? 1.0 : 0.60
                }

                // Active indicator dot
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: 1
                    anchors.topMargin: 1
                    width: 6; height: 6
                    radius: 3
                    color: "#34d399"
                    visible: root.isWifiOn
                }
            }
        }

        // ══════════════════════════════════════════════════════════════
        // 2. EXPANDED MODE: WI-FI NETWORK BROWSER
        // ══════════════════════════════════════════════════════════════
        Item {
            id: expPanel
            anchors.fill: parent
            anchors.margins: 16
            visible: root.isExpanded || opacity > 0.01
            opacity: root.isExpanded ? 1 : 0
            Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 240 } }
            clip: true

            PanelHeader {
                id: expHeader
                width: parent.width
                iconSource: "file:///home/gabriel/.config/quickshell/assets/icons/wifi.svg"
                title: "Wi-Fi"
                subtitle: root.statusMessage !== "" ? root.statusMessage
                        : (!root.isWifiOn ? "Off"
                        : (root.isScanning ? "Scanning…"
                        : (root.wifiSsid !== "" ? root.wifiSsid : "Not connected")))
                showSwitch: true
                switchOn: root.isWifiOn
                busy: root.isScanning
                onSwitchToggled: root.toggleRequested()
                onRefreshClicked: root.scanNetworks(true)
                onCloseClicked: root.isExpanded = false
            }

            Rectangle {
                id: expDivider
                anchors.top: expHeader.bottom
                anchors.topMargin: 8
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.14)
            }

            ListView {
                id: netListView
                anchors.top: expDivider.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true
                spacing: 5
                boundsBehavior: Flickable.StopAtBounds
                model: root.networkList

                delegate: Rectangle {
                    id: netRow
                    readonly property bool selected: root.selectedSsid === modelData.ssid
                    readonly property int sigLevel: modelData.signal > 75 ? 4 : (modelData.signal > 50 ? 3 : (modelData.signal > 25 ? 2 : 1))

                    width: netListView.width
                    height: selected ? 84 : 40
                    radius: 13
                    color: modelData.in_use ? Qt.rgba(1, 1, 1, 0.20) : (rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
                    border.width: 1
                    border.color: modelData.in_use ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.06)
                    clip: true

                    Behavior on height { enabled: !GlassTheme.gaming; NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.6 } }
                    Behavior on color { enabled: !GlassTheme.gaming; ColorAnimation { duration: 120 } }

                    MouseArea {
                        id: rowMouse
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 40
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.in_use || root.connectingSsid !== "") return;
                            if (modelData.is_locked && !modelData.saved) {
                                root.selectedSsid = netRow.selected ? "" : modelData.ssid;
                            } else {
                                root.connectTo(modelData.ssid, null);
                            }
                        }
                    }

                    SignalBars {
                        id: sigBars
                        level: netRow.sigLevel
                        activeColor: modelData.in_use ? "#34d399" : "#ffffff"
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        y: (40 - height) / 2
                    }

                    Text {
                        anchors.left: sigBars.right
                        anchors.leftMargin: 12
                        anchors.right: trailing.left
                        anchors.rightMargin: 8
                        y: (40 - height) / 2
                        text: modelData.ssid
                        color: "#ffffff"
                        font.family: "SF Pro Display"
                        font.pixelSize: 13
                        font.weight: modelData.in_use ? Font.Bold : Font.Medium
                        elide: Text.ElideRight
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.32)
                    }

                    Row {
                        id: trailing
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        y: (40 - height) / 2
                        spacing: 6

                        Image {
                            visible: modelData.in_use
                            width: 14; height: 14
                            source: "file:///home/gabriel/.config/quickshell/assets/icons/check.svg"
                            sourceSize.width: 32; sourceSize.height: 32
                            fillMode: Image.PreserveAspectFit
                            anchors.verticalCenter: parent.verticalCenter
                            layer.enabled: true
                        }
                        Image {
                            visible: !modelData.in_use && modelData.is_locked
                            width: 12; height: 12
                            source: "file:///home/gabriel/.config/quickshell/assets/icons/lock.svg"
                            sourceSize.width: 32; sourceSize.height: 32
                            fillMode: Image.PreserveAspectFit
                            opacity: 0.75
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Campo de senha (redes protegidas)
                    Row {
                        visible: netRow.selected && !modelData.in_use
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        y: 44
                        height: 30
                        spacing: 8

                        Rectangle {
                            width: parent.width - 64
                            height: 30
                            radius: 10
                            color: Qt.rgba(0, 0, 0, 0.34)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, pwdField.activeFocus ? 0.45 : 0.18)

                            TextInput {
                                id: pwdField
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: "#ffffff"
                                font.family: "SF Pro Display"
                                font.pixelSize: 12
                                echoMode: TextInput.Password
                                selectByMouse: true
                                onTextChanged: root.passwordInput = text
                                onAccepted: root.connectTo(modelData.ssid, text)

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: pwdField.text === ""
                                    text: "Password"
                                    color: Qt.rgba(1, 1, 1, 0.45)
                                    font: pwdField.font
                                }
                            }
                        }

                        Rectangle {
                            width: 56; height: 30
                            radius: 15
                            color: joinMouse.pressed ? "#0a6ed1" : "#0a84ff"

                            Text {
                                anchors.centerIn: parent
                                text: "Join"
                                color: "#ffffff"
                                font.family: "SF Pro Display"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }
                            MouseArea {
                                id: joinMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.connectTo(modelData.ssid, pwdField.text)
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: netListView
                visible: root.networkList.length === 0
                text: !root.isWifiOn ? "Wi-Fi is off" : (root.isScanning ? "Looking for networks…" : "No networks found")
                color: Qt.rgba(1, 1, 1, 0.70)
                font.family: "SF Pro Display"
                font.pixelSize: 12
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
            onClicked: {
                root.isExpanded = true;
            }
            onDoubleClicked: {
                root.toggleRequested();
            }
        }
    }
}
