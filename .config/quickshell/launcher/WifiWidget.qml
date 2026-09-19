import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var controlCenter

    implicitHeight: mainLayout.implicitHeight
    implicitWidth: 350

    property var networks: []
    property bool isScanning: false
    property bool isWifiEnabled: controlCenter.isWifiOn
    property string statusMessage: ""
    property string selectedSsid: ""
    property string searchQuery: ""

    readonly property var filteredNetworks: {
        if (!searchQuery || searchQuery.trim() === "") return networks;
        const q = searchQuery.toLowerCase().trim();
        return networks.filter(n => (n.ssid && n.ssid.toLowerCase().includes(q)));
    }

    // ── Processo de Listagem ──────────────────────────────────
    Process {
        id: wifiLister
        command: ["/home/gabriel/.config/quickshell/scripts/wifi_tool.py", "list"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const data = JSON.parse(line.trim())
                    root.isWifiEnabled = data.enabled
                    root.networks = data.networks || []
                    root.isScanning = false
                } catch (e) {
                    root.isScanning = false
                }
            }
        }
    }

    // ── Processo de Operações (Connect, Disconnect, Forget, Toggle) ──
    Process {
        id: wifiAction
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const res = JSON.parse(line.trim())
                    if (res.output) {
                        root.statusMessage = res.output
                    }
                } catch (e) {}
                refresh()
                controlCenter.refreshStatus()
            }
        }
    }

    function refresh() {
        root.isScanning = true
        wifiLister.running = true
    }

    function toggleWifi() {
        wifiAction.command = ["/home/gabriel/.config/quickshell/scripts/wifi_tool.py", "toggle"]
        wifiAction.running = true
    }

    function connect(ssid, password) {
        root.statusMessage = "Conectando a " + ssid + "..."
        if (password) {
            wifiAction.command = ["/home/gabriel/.config/quickshell/scripts/wifi_tool.py", "connect", ssid, password]
        } else {
            wifiAction.command = ["/home/gabriel/.config/quickshell/scripts/wifi_tool.py", "connect", ssid]
        }
        wifiAction.running = true
    }

    function disconnect() {
        root.statusMessage = "Desconectando..."
        wifiAction.command = ["/home/gabriel/.config/quickshell/scripts/wifi_tool.py", "disconnect"]
        wifiAction.running = true
    }

    function forget(ssid) {
        root.statusMessage = "Esquecendo rede " + ssid + "..."
        wifiAction.command = ["/home/gabriel/.config/quickshell/scripts/wifi_tool.py", "forget", ssid]
        wifiAction.running = true
    }

    Component.onCompleted: {
        refresh()
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: 10

        // ── 1. HEADER APPLE (Voltar, Título, Scan, iOS Toggle) ───
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: 20
            color: root.controlCenter.glassBgColor
            border.width: 0

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 12
                spacing: 8

                // Botão Voltar (Círculo de Vidro)
                Rectangle {
                    width: 34
                    height: 34
                    radius: 17
                    color: backMouse.containsMouse ? root.controlCenter.glassHoverColor : Qt.rgba(255, 255, 255, 0.14)
                    scale: backMouse.pressed ? 0.92 : (backMouse.containsMouse ? 1.05 : 1.0)

                    Behavior on color { ColorAnimation { duration: 130 } }
                    Behavior on scale { NumberAnimation { duration: 110 } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "chevron-left"
                        size: 16
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.controlCenter.currentView = "main"
                    }
                }

                // Título
                Text {
                    Layout.fillWidth: true
                    text: "Wi-Fi"
                    color: "#ffffff"
                    font.family: "Inter, sans-serif"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    renderType: Text.NativeRendering
                }

                // Botão Scan / Atualizar
                Rectangle {
                    width: 34
                    height: 34
                    radius: 17
                    color: scanMouse.containsMouse ? root.controlCenter.glassHoverColor : Qt.rgba(255, 255, 255, 0.14)
                    scale: scanMouse.pressed ? 0.92 : (scanMouse.containsMouse ? 1.05 : 1.0)

                    Behavior on color { ColorAnimation { duration: 130 } }
                    Behavior on scale { NumberAnimation { duration: 110 } }

                    SvgIcon {
                        id: scanIcon
                        anchors.centerIn: parent
                        name: "refresh"
                        size: 15
                        color: "#ffffff"

                        RotationAnimation on rotation {
                            running: root.isScanning
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 750
                        }
                    }

                    MouseArea {
                        id: scanMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refresh()
                    }
                }

                // Master Toggle Switch Estilo iOS (Verde / Desativado)
                Rectangle {
                    width: 48
                    height: 28
                    radius: 14
                    color: root.isWifiEnabled ? "#34c759" : Qt.rgba(255, 255, 255, 0.20)
                    scale: switchMouse.pressed ? 0.94 : 1.0

                    Behavior on color { ColorAnimation { duration: 160 } }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.isWifiEnabled ? 21 : 3

                        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: switchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleWifi()
                    }
                }
            }
        }

        // ── 2. BARRA DE BUSCA APPLE (Com Lupa e Clear) ───────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 14
            visible: root.isWifiEnabled
            color: root.controlCenter.glassBgColor
            border.width: 0

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 8

                SvgIcon {
                    name: "search"
                    size: 15
                    color: searchInput.activeFocus ? "#ffffff" : Qt.rgba(255, 255, 255, 0.60)
                }

                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    placeholderText: "Buscar redes..."
                    placeholderTextColor: Qt.rgba(255, 255, 255, 0.45)
                    color: "#ffffff"
                    font.family: "Inter, sans-serif"
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                    background: null
                    onTextChanged: root.searchQuery = text
                }

                Rectangle {
                    visible: searchInput.text.length > 0
                    width: 20
                    height: 20
                    radius: 10
                    color: Qt.rgba(255, 255, 255, 0.22)

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#ffffff"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = ""
                            root.searchQuery = ""
                        }
                    }
                }
            }
        }

        // ── 3. MENSAGEM DE STATUS (Notificação de Conexão) ───────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 12
            color: root.controlCenter.glassBgColor
            visible: root.statusMessage.length > 0
            border.width: 0

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: root.statusMessage
                    color: "#ffffff"
                    font.family: "Inter, sans-serif"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                    elide: Text.ElideRight
                }

                Text {
                    text: "✕"
                    color: Qt.rgba(255, 255, 255, 0.60)
                    font.pixelSize: 11
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.statusMessage = ""
                    }
                }
            }
        }

        // ── 4. CORPO (Desativado OU Lista de Redes Apple) ────────
        // A) Wi-Fi Desativado
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            radius: 20
            color: root.controlCenter.glassBgColor
            visible: !root.isWifiEnabled
            border.width: 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12

                SvgIcon {
                    Layout.alignment: Qt.AlignHCenter
                    name: "wifi"
                    size: 32
                    color: Qt.rgba(255, 255, 255, 0.40)
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "O Wi-Fi está desativado"
                    color: Qt.rgba(255, 255, 255, 0.80)
                    font.family: "Inter, sans-serif"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 120
                    height: 32
                    radius: 14
                    color: enableMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.32) : Qt.rgba(255, 255, 255, 0.22)
                    scale: enableMouse.pressed ? 0.94 : (enableMouse.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Ativar Wi-Fi"
                        color: "#ffffff"
                        font.family: "Inter, sans-serif"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: enableMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleWifi()
                    }
                }
            }
        }

        // B) Lista de Redes Apple Style
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.isWifiEnabled

            Text {
                text: "REDES DISPONÍVEIS (" + root.filteredNetworks.length + ")"
                color: Qt.rgba(255, 255, 255, 0.55)
                font.family: "Inter, sans-serif"
                font.pixelSize: 10
                font.weight: Font.Bold
                renderType: Text.NativeRendering
                Layout.leftMargin: 6
            }

            // Scroll container
            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(320, netCol.implicitHeight)
                contentHeight: netCol.implicitHeight
                clip: true

                ColumnLayout {
                    id: netCol
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: root.filteredNetworks

                        delegate: Rectangle {
                            id: netCard
                            Layout.fillWidth: true
                            Layout.preferredHeight: isExpanded ? 116 : 52
                            radius: 16
                            color: modelData.in_use ? Qt.rgba(255, 255, 255, 0.14) : (cardMouse.containsMouse ? root.controlCenter.glassHoverColor : root.controlCenter.glassBgColor)
                            border.width: 0
                            scale: cardMouse.pressed && !isExpanded ? 0.98 : (cardMouse.containsMouse && !isExpanded ? 1.01 : 1.0)

                            Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on scale { NumberAnimation { duration: 110 } }

                            readonly property bool isExpanded: root.selectedSsid === modelData.ssid

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                // Linha Principal
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: modelData.in_use ? Qt.rgba(255, 255, 255, 0.22) : Qt.rgba(255, 255, 255, 0.12)

                                        SvgIcon {
                                            anchors.centerIn: parent
                                            name: "wifi"
                                            size: 16
                                            color: modelData.in_use ? "#34c759" : "#ffffff"
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.ssid
                                            color: "#ffffff"
                                            font.family: "Inter, sans-serif"
                                            font.pixelSize: 13
                                            font.weight: modelData.in_use ? Font.Bold : Font.DemiBold
                                            renderType: Text.NativeRendering
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: (modelData.in_use ? "Conectado • " : "") + modelData.signal + "% sinal" + (modelData.security ? " • " + modelData.security : "")
                                            color: modelData.in_use ? "#34c759" : Qt.rgba(255, 255, 255, 0.60)
                                            font.family: "Inter, sans-serif"
                                            font.pixelSize: 10
                                            renderType: Text.NativeRendering
                                        }
                                    }

                                    SvgIcon {
                                        visible: modelData.is_locked && !modelData.in_use
                                        name: "lock"
                                        size: 14
                                        color: Qt.rgba(255, 255, 255, 0.60)
                                    }

                                    // Ícone de Conectado (Checkmark)
                                    SvgIcon {
                                        visible: modelData.in_use
                                        name: "check"
                                        size: 16
                                        color: "#34c759"
                                    }

                                    // Botão de Esquecer / Desconectar
                                    Rectangle {
                                        visible: modelData.in_use
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: discMouse.containsMouse ? Qt.rgba(255, 59, 48, 0.40) : Qt.rgba(255, 59, 48, 0.22)
                                        scale: discMouse.pressed ? 0.90 : 1.0

                                        SvgIcon {
                                            anchors.centerIn: parent
                                            name: "trash"
                                            size: 13
                                            color: "#ff3b30"
                                        }

                                        MouseArea {
                                            id: discMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.forget(modelData.ssid)
                                        }
                                    }

                                    Text {
                                        visible: !modelData.in_use && !netCard.isExpanded
                                        text: "›"
                                        font.family: "Inter, sans-serif"
                                        font.pixelSize: 16
                                        font.weight: Font.DemiBold
                                        renderType: Text.NativeRendering
                                        color: Qt.rgba(255, 255, 255, 0.40)
                                    }
                                }

                                // Campo de Senha Expansível Apple Style
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: netCard.isExpanded && !modelData.in_use
                                    spacing: 8

                                    TextField {
                                        id: passInput
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 34
                                        placeholderText: "Senha do Wi-Fi..."
                                        placeholderTextColor: Qt.rgba(255, 255, 255, 0.45)
                                        color: "#ffffff"
                                        echoMode: TextInput.Password
                                        font.family: "Inter, sans-serif"
                                        font.pixelSize: 12
                                        renderType: Text.NativeRendering
                                        background: Rectangle {
                                            radius: 10
                                            color: Qt.rgba(0, 0, 0, 0.35)
                                            border.width: 0
                                        }
                                        onAccepted: {
                                            root.connect(modelData.ssid, passInput.text)
                                            root.selectedSsid = ""
                                        }
                                    }

                                    Rectangle {
                                        width: 76
                                        height: 34
                                        radius: 10
                                        color: connMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.32) : Qt.rgba(255, 255, 255, 0.22)
                                        scale: connMouse.pressed ? 0.92 : (connMouse.containsMouse ? 1.05 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 110 } }
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Conectar"
                                            color: "#ffffff"
                                            font.family: "Inter, sans-serif"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            renderType: Text.NativeRendering
                                        }

                                        MouseArea {
                                            id: connMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.connect(modelData.ssid, passInput.text)
                                                root.selectedSsid = ""
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 34
                                        height: 34
                                        radius: 10
                                        color: cancelMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.26) : Qt.rgba(255, 255, 255, 0.16)
                                        scale: cancelMouse.pressed ? 0.92 : 1.0

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            color: "#ffffff"
                                            font.pixelSize: 12
                                        }

                                        MouseArea {
                                            id: cancelMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.selectedSsid = ""
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !netCard.isExpanded && !modelData.in_use
                                onClicked: {
                                    if (modelData.is_locked) {
                                        root.selectedSsid = modelData.ssid
                                    } else {
                                        root.connect(modelData.ssid, "")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
