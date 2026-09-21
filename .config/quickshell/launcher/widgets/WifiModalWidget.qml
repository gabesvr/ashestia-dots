import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PanelWindow {
    id: modalWindow

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: modalWindow.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1
    color: "transparent"
    visible: modalWindow.shown || card.opacity > 0.01

    Item {
        id: fullRegionItem
        anchors.fill: parent
    }

    mask: Region {
        item: modalWindow.shown ? fullRegionItem : card
    }

    property bool shown: false
    property var networks: []
    property bool isScanning: false
    property string selectedSsid: ""
    property string enteredPassword: ""
    property string statusMsg: ""

    function toggle() {
        if (shown) hide();
        else show();
    }

    function show() {
        shown = true;
        refresh();
    }

    function hide() {
        shown = false;
        selectedSsid = "";
        enteredPassword = "";
        statusMsg = "";
    }

    function setWallpaper(path) {
        glass.setWallpaper(path);
    }

    FontLoader {
        id: sfRegular
        source: Qt.resolvedUrl("fonts/sf_pro_display_regular.otf")
    }

    // ── Wi-Fi Lister Process ──
    Process {
        id: wifiLister
        command: ["/home/gabriel/.config/quickshell/scripts/wifi_tool.sh", "list"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const data = JSON.parse(line.trim());
                    modalWindow.networks = data.networks || [];
                    modalWindow.isScanning = false;
                } catch(e) {
                    modalWindow.isScanning = false;
                }
            }
        }
    }

    // ── Wi-Fi Action Process ──
    Process {
        id: wifiAction
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const res = JSON.parse(line.trim());
                    if (res.output) modalWindow.statusMsg = res.output;
                } catch(e) {}
                refresh();
            }
        }
    }

    function refresh() {
        modalWindow.isScanning = true;
        wifiLister.running = true;
    }

    function connectNetwork(ssid, pwd) {
        modalWindow.statusMsg = "Connecting to " + ssid + "...";
        if (pwd && pwd.length > 0) {
            wifiAction.command = ["/home/gabriel/.config/quickshell/scripts/wifi_tool.sh", "connect", ssid, pwd];
        } else {
            wifiAction.command = ["/home/gabriel/.config/quickshell/scripts/wifi_tool.sh", "connect", ssid];
        }
        wifiAction.running = true;
    }

    function disconnectNetwork() {
        modalWindow.statusMsg = "Disconnecting...";
        wifiAction.command = ["/home/gabriel/.config/quickshell/scripts/wifi_tool.sh", "disconnect"];
        wifiAction.running = true;
    }

    // Click outside to dismiss with dimming scrim
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: modalWindow.shown ? 0.35 : 0.0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

        MouseArea {
            anchors.fill: parent
            enabled: modalWindow.shown
            onClicked: modalWindow.hide()
        }
    }

    Item {
        id: card
        width: 360
        height: 420
        anchors.centerIn: parent

        opacity: modalWindow.shown ? 1.0 : 0.0
        scale: modalWindow.shown ? 1.0 : 0.90
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

        // Liquid Glass Background
        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: 36
            roundness: 7.5
            refractThickness: 40
            refractIOR: 1.7
            refractScale: 70
            tint: "#0a101f"
            tintAlpha: 0.70
            chromaStrength: 0.35
            specStrength: 0.85
            blurRadius: 7
            widgetX: (modalWindow.width - width) / 2
            widgetY: (modalWindow.height - height) / 2
            screenWidth: modalWindow.width > 0 ? modalWindow.width : 1920
            screenHeight: modalWindow.height > 0 ? modalWindow.height : 1080
        }

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // Header
            Row {
                width: parent.width
                height: 28

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18
                    source: "file:///home/gabriel/.config/quickshell/assets/icons/wifi.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Item { width: 8; height: 1 }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Wi-Fi Networks"
                    color: "#ffffff"
                    font.family: sfRegular.name
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }

                Item { Layout.fillWidth: true; width: card.width - 230 }

                // Refresh Button
                Rectangle {
                    width: 26; height: 26
                    radius: 13
                    color: Qt.rgba(1, 1, 1, 0.12)
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        width: 12; height: 12
                        source: "file:///home/gabriel/.config/quickshell/assets/icons/refresh.svg"
                        fillMode: Image.PreserveAspectFit
                        rotation: modalWindow.isScanning ? 360 : 0
                        Behavior on rotation { NumberAnimation { duration: 800; loops: Animation.Infinite } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modalWindow.refresh()
                    }
                }

                Item { width: 6; height: 1 }

                // Close Button
                Rectangle {
                    width: 26; height: 26
                    radius: 13
                    color: Qt.rgba(1, 1, 1, 0.12)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#ffffff"
                        opacity: 0.8
                        font.pixelSize: 11
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modalWindow.hide()
                    }
                }
            }

            // Status message (if any)
            Text {
                visible: modalWindow.statusMsg !== ""
                text: modalWindow.statusMsg
                color: "#38bdf8"
                font.family: sfRegular.name
                font.pixelSize: 10
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                width: parent.width
            }

            // Networks List
            ListView {
                width: parent.width
                height: 310
                clip: true
                spacing: 8
                model: modalWindow.networks

                delegate: Rectangle {
                    width: parent.width
                    height: (modalWindow.selectedSsid === modelData.ssid) ? 105 : 44
                    radius: 14
                    color: modelData.in_use ? Qt.rgba(0.20, 0.50, 1.0, 0.28) : Qt.rgba(1, 1, 1, 0.08)
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Row {
                            width: parent.width
                            height: 24

                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 15; height: 15
                                source: "file:///home/gabriel/.config/quickshell/assets/icons/wifi.svg"
                                fillMode: Image.PreserveAspectFit
                            }

                            Item { width: 8; height: 1 }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Text {
                                    text: modelData.ssid || "Hidden Network"
                                    color: "#ffffff"
                                    font.family: sfRegular.name
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    text: modelData.in_use ? "Connected" : (modelData.signal + "% • " + (modelData.security || "Open"))
                                    color: modelData.in_use ? "#34d399" : Qt.rgba(1, 1, 1, 0.6)
                                    font.family: sfRegular.name
                                    font.pixelSize: 9
                                }
                            }

                            Item { Layout.fillWidth: true; width: parent.width - 200 }

                            // Lock icon if secured
                            Image {
                                visible: modelData.is_locked
                                anchors.verticalCenter: parent.verticalCenter
                                width: 12; height: 12
                                source: "file:///home/gabriel/.config/quickshell/assets/icons/lock.svg"
                                fillMode: Image.PreserveAspectFit
                                opacity: 0.6
                            }
                        }

                        // Expanded Connection Box
                        Item {
                            visible: modalWindow.selectedSsid === modelData.ssid
                            width: parent.width
                            height: 50

                            Row {
                                anchors.fill: parent
                                spacing: 8

                                Rectangle {
                                    visible: modelData.is_locked && !modelData.in_use
                                    width: parent.width - 90
                                    height: 32
                                    radius: 8
                                    color: Qt.rgba(0, 0, 0, 0.35)
                                    anchors.verticalCenter: parent.verticalCenter

                                    TextInput {
                                        id: pwdInput
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        echoMode: TextInput.Password
                                        color: "#ffffff"
                                        font.family: sfRegular.name
                                        font.pixelSize: 11
                                        clip: true
                                        onTextChanged: modalWindow.enteredPassword = text
                                        onAccepted: modalWindow.connectNetwork(modelData.ssid, text)

                                        Text {
                                            visible: !pwdInput.text
                                            text: "Password..."
                                            color: Qt.rgba(1, 1, 1, 0.4)
                                            font.pixelSize: 11
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                Rectangle {
                                    width: (modelData.is_locked && !modelData.in_use) ? 80 : parent.width
                                    height: 32
                                    radius: 8
                                    color: modelData.in_use ? Qt.rgba(0.9, 0.2, 0.2, 0.4) : Qt.rgba(0.2, 0.6, 1.0, 0.4)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.in_use ? "Disconnect" : "Connect"
                                        color: "#ffffff"
                                        font.family: sfRegular.name
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData.in_use) {
                                                modalWindow.disconnectNetwork();
                                            } else {
                                                modalWindow.connectNetwork(modelData.ssid, modalWindow.enteredPassword);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: modalWindow.selectedSsid !== modelData.ssid
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            modalWindow.selectedSsid = modelData.ssid;
                            modalWindow.enteredPassword = "";
                        }
                    }
                }
            }
        }
    }
}
