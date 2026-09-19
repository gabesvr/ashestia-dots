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

    property var devices: []
    property bool isScanning: false
    property bool isBtEnabled: controlCenter.isBtOn
    property string statusMessage: ""
    property string searchQuery: ""

    Connections {
        target: controlCenter
        function onIsBtOnChanged() {
            root.isBtEnabled = controlCenter.isBtOn
        }
    }

    readonly property var myDevices: {
        return devices.filter(d => {
            const matchesQuery = !searchQuery || searchQuery.trim() === "" ||
                (d.name && d.name.toLowerCase().includes(searchQuery.toLowerCase().trim())) ||
                (d.mac && d.mac.toLowerCase().includes(searchQuery.toLowerCase().trim()));
            return matchesQuery && (d.paired || d.connected);
        });
    }

    readonly property var otherDevices: {
        return devices.filter(d => {
            const matchesQuery = !searchQuery || searchQuery.trim() === "" ||
                (d.name && d.name.toLowerCase().includes(searchQuery.toLowerCase().trim())) ||
                (d.mac && d.mac.toLowerCase().includes(searchQuery.toLowerCase().trim()));
            return matchesQuery && !d.paired && !d.connected;
        });
    }

    readonly property var filteredDevices: {
        return devices.filter(d => {
            if (!searchQuery || searchQuery.trim() === "") return true;
            const q = searchQuery.toLowerCase().trim();
            return (d.name && d.name.toLowerCase().includes(q)) || (d.mac && d.mac.toLowerCase().includes(q));
        });
    }

    // ── Processo de Listagem ──────────────────────────────────
    Process {
        id: btLister
        command: ["/home/gabriel/.config/quickshell/scripts/bt_tool.py", "list"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const data = JSON.parse(line.trim())
                    const isEnabled = (data.enabled !== undefined ? data.enabled : data.powered)
                    if (isEnabled !== undefined) {
                        root.isBtEnabled = isEnabled
                        root.controlCenter.isBtOn = isEnabled
                    }
                    if (data.devices) {
                        root.devices = data.devices
                    }
                    root.isScanning = false
                } catch (e) {
                    root.isScanning = false
                }
            }
        }
    }

    // ── Processo de Operações (Connect, Disconnect, Pair, Remove, Toggle) ──
    Process {
        id: btAction
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const res = JSON.parse(line.trim())
                    if (res.output) {
                        root.statusMessage = res.output
                    }
                    if (res.devices) {
                        root.devices = res.devices
                    }
                    const isEnabled = (res.enabled !== undefined ? res.enabled : res.powered)
                    if (isEnabled !== undefined) {
                        root.isBtEnabled = isEnabled
                        root.controlCenter.isBtOn = isEnabled
                    }
                } catch (e) {}
                root.isScanning = false
                refresh()
            }
        }
    }

    function refresh() {
        btLister.running = true
    }

    function scan() {
        if (!root.isBtEnabled) {
            root.toggleBt()
        }
        root.isScanning = true
        btAction.command = ["/home/gabriel/.config/quickshell/scripts/bt_tool.py", "scan", "5"]
        btAction.running = true
    }

    function toggleBt() {
        const nextState = !root.isBtEnabled
        root.isBtEnabled = nextState
        root.controlCenter.isBtOn = nextState
        btAction.command = ["/home/gabriel/.config/quickshell/scripts/bt_tool.py", "toggle", nextState ? "on" : "off"]
        btAction.running = true
    }

    function connect(mac) {
        root.statusMessage = "Conectando..."
        btAction.command = ["/home/gabriel/.config/quickshell/scripts/bt_tool.py", "connect", mac]
        btAction.running = true
    }

    function disconnect(mac) {
        root.statusMessage = "Desconectando..."
        btAction.command = ["/home/gabriel/.config/quickshell/scripts/bt_tool.py", "disconnect", mac]
        btAction.running = true
    }

    function pair(mac) {
        root.statusMessage = "Pareando..."
        btAction.command = ["/home/gabriel/.config/quickshell/scripts/bt_tool.py", "pair", mac]
        btAction.running = true
    }

    function remove(mac) {
        root.statusMessage = "Removendo dispositivo..."
        btAction.command = ["/home/gabriel/.config/quickshell/scripts/bt_tool.py", "remove", mac]
        btAction.running = true
    }

    function isAudioDevice(name) {
        if (!name) return false;
        const n = name.toLowerCase();
        return n.includes("head") || n.includes("buds") || n.includes("ear") ||
               n.includes("airpod") || n.includes("speaker") || n.includes("sound") ||
               n.includes("wh-") || n.includes("wf-") || n.includes("jbl") || n.includes("audio");
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
                    text: "Bluetooth"
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
                        onClicked: root.scan()
                    }
                }

                // Master Toggle Switch Estilo iOS (Verde / Desativado)
                Rectangle {
                    width: 48
                    height: 28
                    radius: 14
                    color: root.isBtEnabled ? "#34c759" : Qt.rgba(255, 255, 255, 0.20)
                    scale: switchMouse.pressed ? 0.94 : 1.0

                    Behavior on color { ColorAnimation { duration: 160 } }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.isBtEnabled ? 21 : 3

                        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: switchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleBt()
                    }
                }
            }
        }

        // ── 2. BARRA DE BUSCA APPLE (Com Lupa e Clear) ───────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 14
            visible: root.isBtEnabled
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
                    placeholderText: "Buscar dispositivos..."
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

        // ── 3. MENSAGEM DE STATUS (Notificação de Conexão/Pareamento) ─
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

        // ── 4. CORPO (Desativado OU Lista de Dispositivos Apple) ──
        // A) Bluetooth Desativado
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            radius: 20
            color: root.controlCenter.glassBgColor
            visible: !root.isBtEnabled
            border.width: 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12

                SvgIcon {
                    Layout.alignment: Qt.AlignHCenter
                    name: "bluetooth"
                    size: 32
                    color: Qt.rgba(255, 255, 255, 0.40)
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "O Bluetooth está desativado"
                    color: Qt.rgba(255, 255, 255, 0.80)
                    font.family: "Inter, sans-serif"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 130
                    height: 32
                    radius: 14
                    color: enableMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.32) : Qt.rgba(255, 255, 255, 0.22)
                    scale: enableMouse.pressed ? 0.94 : (enableMouse.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 110 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Ativar Bluetooth"
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
                        onClicked: root.toggleBt()
                    }
                }
            }
        }

        // B) Lista de Dispositivos Apple Style
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.isBtEnabled

            // Scroll container
            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(320, devCol.implicitHeight)
                contentHeight: devCol.implicitHeight
                clip: true

                ColumnLayout {
                    id: devCol
                    width: parent.width
                    spacing: 8

                    // Estado vazio de busca
                    Text {
                        visible: root.filteredDevices.length === 0
                        text: root.isScanning ? "Buscando dispositivos próximos..." : (root.searchQuery ? "Nenhum dispositivo com \"" + root.searchQuery + "\"" : "Nenhum dispositivo encontrado.\nClique em atualizar para escanear.")
                        color: Qt.rgba(255, 255, 255, 0.60)
                        font.family: "Inter, sans-serif"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                        Layout.topMargin: 20
                        Layout.bottomMargin: 20
                        renderType: Text.NativeRendering
                    }

                    // ── SEÇÃO 1: MEUS DISPOSITIVOS ───────────────
                    Text {
                        visible: root.myDevices.length > 0
                        text: "MEUS DISPOSITIVOS"
                        color: Qt.rgba(255, 255, 255, 0.55)
                        font.family: "Inter, sans-serif"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                        Layout.leftMargin: 6
                        Layout.topMargin: 4
                    }

                    Repeater {
                        model: root.myDevices

                        delegate: Rectangle {
                            id: myDevCard
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: 16
                            color: modelData.connected ? Qt.rgba(255, 255, 255, 0.14) : (myCardM.containsMouse ? root.controlCenter.glassHoverColor : root.controlCenter.glassBgColor)
                            border.width: 0
                            scale: myCardM.pressed ? 0.98 : (myCardM.containsMouse ? 1.01 : 1.0)

                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on scale { NumberAnimation { duration: 110 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 10

                                // Ícone do Dispositivo (Fone se áudio, Bluetooth caso contrário)
                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: modelData.connected ? Qt.rgba(255, 255, 255, 0.22) : Qt.rgba(255, 255, 255, 0.12)

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        name: root.isAudioDevice(modelData.name) ? "speaker-high" : "bluetooth"
                                        size: 16
                                        color: modelData.connected ? "#34c759" : "#ffffff"
                                    }
                                }

                                // Nome e Status
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name || modelData.mac
                                        color: "#ffffff"
                                        font.family: "Inter, sans-serif"
                                        font.pixelSize: 13
                                        font.weight: modelData.connected ? Font.Bold : Font.DemiBold
                                        renderType: Text.NativeRendering
                                        elide: Text.ElideRight
                                    }

                                    RowLayout {
                                        spacing: 4
                                        Rectangle {
                                            width: 6
                                            height: 6
                                            radius: 3
                                            color: modelData.connected ? "#34c759" : Qt.rgba(255, 255, 255, 0.45)
                                        }
                                        Text {
                                            text: modelData.connected ? "Conectado" : "Não conectado"
                                            color: modelData.connected ? "#34c759" : Qt.rgba(255, 255, 255, 0.60)
                                            font.family: "Inter, sans-serif"
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                            renderType: Text.NativeRendering
                                        }
                                    }
                                }

                                // Botão Conectar / Desconectar
                                Rectangle {
                                    width: modelData.connected ? 84 : 74
                                    height: 28
                                    radius: 14
                                    color: actionM.containsMouse ? Qt.rgba(255, 255, 255, 0.32) : Qt.rgba(255, 255, 255, 0.22)
                                    scale: actionM.pressed ? 0.92 : (actionM.containsMouse ? 1.05 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 110 } }
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.connected ? "Desconectar" : "Conectar"
                                        color: "#ffffff"
                                        font.family: "Inter, sans-serif"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        renderType: Text.NativeRendering
                                    }

                                    MouseArea {
                                        id: actionM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData.connected) {
                                                root.disconnect(modelData.mac)
                                            } else {
                                                root.connect(modelData.mac)
                                            }
                                        }
                                    }
                                }

                                // Botão Esquecer (Lixeira Glass)
                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: rmM.containsMouse ? Qt.rgba(255, 59/255, 48/255, 0.35) : Qt.rgba(255, 255, 255, 0.12)
                                    scale: rmM.pressed ? 0.90 : 1.0

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        name: "trash"
                                        size: 13
                                        color: rmM.containsMouse ? "#ff453a" : Qt.rgba(255, 255, 255, 0.65)
                                    }

                                    MouseArea {
                                        id: rmM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.remove(modelData.mac)
                                    }
                                }
                            }

                            MouseArea {
                                id: myCardM
                                anchors.fill: parent
                                hoverEnabled: true
                                z: -1
                            }
                        }
                    }

                    // ── SEÇÃO 2: OUTROS DISPOSITIVOS ──────────────
                    Text {
                        visible: root.otherDevices.length > 0
                        text: root.isScanning ? "OUTROS DISPOSITIVOS (Buscando...)" : "OUTROS DISPOSITIVOS"
                        color: Qt.rgba(255, 255, 255, 0.55)
                        font.family: "Inter, sans-serif"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                        Layout.leftMargin: 6
                        Layout.topMargin: 8
                    }

                    Repeater {
                        model: root.otherDevices

                        delegate: Rectangle {
                            id: otherDevCard
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            radius: 16
                            color: otherCardM.containsMouse ? root.controlCenter.glassHoverColor : root.controlCenter.glassBgColor
                            border.width: 0
                            scale: otherCardM.pressed ? 0.98 : (otherCardM.containsMouse ? 1.01 : 1.0)

                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on scale { NumberAnimation { duration: 110 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 10

                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: Qt.rgba(255, 255, 255, 0.12)

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        name: root.isAudioDevice(modelData.name) ? "speaker-high" : "bluetooth"
                                        size: 16
                                        color: Qt.rgba(255, 255, 255, 0.85)
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name || modelData.mac
                                        color: "#ffffff"
                                        font.family: "Inter, sans-serif"
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        renderType: Text.NativeRendering
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: "Disponível para parear"
                                        color: Qt.rgba(255, 255, 255, 0.50)
                                        font.family: "Inter, sans-serif"
                                        font.pixelSize: 10
                                        renderType: Text.NativeRendering
                                    }
                                }

                                // Botão Parear
                                Rectangle {
                                    width: 68
                                    height: 28
                                    radius: 14
                                    color: pairM.containsMouse ? Qt.rgba(255, 255, 255, 0.32) : Qt.rgba(255, 255, 255, 0.22)
                                    scale: pairM.pressed ? 0.92 : (pairM.containsMouse ? 1.05 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 110 } }
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Parear"
                                        color: "#ffffff"
                                        font.family: "Inter, sans-serif"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        renderType: Text.NativeRendering
                                    }

                                    MouseArea {
                                        id: pairM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.pair(modelData.mac)
                                    }
                                }
                            }

                            MouseArea {
                                id: otherCardM
                                anchors.fill: parent
                                hoverEnabled: true
                                z: -1
                            }
                        }
                    }
                }
            }
        }
    }
}
