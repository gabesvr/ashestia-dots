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

    FontLoader {
        id: sfProRounded
        source: Qt.resolvedUrl("fonts/sf_pro_rounded.otf")
    }
    FontLoader {
        id: sfRegular
        source: Qt.resolvedUrl("fonts/sf_pro_display_regular.otf")
    }

    property real targetX: 1530
    property real targetY: 586
    property real targetWidth: 76
    property real targetHeight: 76

    property bool isWifiOn: true
    property string wifiSsid: ""
    property bool isExpanded: false

    signal toggleRequested()

    property var networkList: []
    property bool isScanning: false
    property string selectedSsid: ""
    property string passwordInput: ""
    property string statusMessage: ""

    function scanNetworks() {
        if (isScanning) return;
        isScanning = true;
        statusMessage = "Scanning...";
        scanProc.running = false;
        scanProc.running = true;
    }

    function connectTo(ssid, password) {
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
                    if (data.networks) {
                        root.networkList = data.networks;
                        root.statusMessage = "";
                    }
                } catch(e) {}
                root.isScanning = false;
            }
        }
        onExited: (code) => { root.isScanning = false; }
    }

    Process {
        id: connectProc
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const data = JSON.parse(line.trim());
                    if (data.success) {
                        root.statusMessage = "Connected!";
                        root.selectedSsid = "";
                        root.passwordInput = "";
                        root.scanNetworks();
                    } else {
                        root.statusMessage = "Failed: " + (data.output || "Error");
                    }
                } catch(e) {}
            }
        }
    }

    onIsExpandedChanged: {
        if (isExpanded) {
            scanNetworks();
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

        Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        scale: (tileMouse.pressed && !root.isExpanded) ? 0.92 : ((tileMouse.containsMouse && !root.isExpanded) ? 1.04 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: root.isExpanded ? 28 : Math.min(24, Math.min(full.height, full.width) * 0.45)
            roundness: 7.5
            refractThickness: 35
            refractIOR: 1.7
            refractScale: 65
            tint: "#ffffff"
            tintAlpha: 0.10
            chromaStrength: 0.30
            specStrength: 0.70
            blurRadius: 6
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
        // 2. EXPANDED MODE: INTERACTIVE WI-FI NETWORK BROWSER
        // ══════════════════════════════════════════════════════════════
        Item {
            anchors.fill: parent
            visible: root.isExpanded
            anchors.margins: 14
            clip: true

            // Header Row
            Row {
                id: expHeader
                width: parent.width
                height: 28
                spacing: 10

                Rectangle {
                    width: 28; height: 28
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.20)
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        width: 14; height: 14
                        source: "file:///home/gabriel/.config/quickshell/assets/icons/wifi.svg"
                        fillMode: Image.PreserveAspectFit
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Wi-Fi"
                    color: "#ffffff"
                    font.family: sfProRounded.name
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }

                Item { Layout.fillWidth: true; width: full.width - 230 }

                // Wi-Fi On/Off Pill Switch
                Rectangle {
                    width: 38; height: 20
                    radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.isWifiOn ? Qt.rgba(0.2, 0.8, 0.4, 0.55) : Qt.rgba(1, 1, 1, 0.16)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.20)

                    Rectangle {
                        width: 16; height: 16
                        radius: 8
                        x: root.isWifiOn ? 20 : 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#ffffff"
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleRequested()
                    }
                }

                // Refresh Button
                Rectangle {
                    width: 22; height: 22
                    radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.14)

                    Text {
                        anchors.centerIn: parent
                        text: "↻"
                        color: "#ffffff"
                        font.pixelSize: 13
                        opacity: root.isScanning ? 0.4 : 0.9
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.scanNetworks()
                    }
                }

                // Close / Collapse Button
                Rectangle {
                    width: 22; height: 22
                    radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.14)

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#ffffff"
                        font.pixelSize: 10
                        opacity: 0.85
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.isExpanded = false
                    }
                }
            }

            // Status message (if any)
            Text {
                id: statusLabel
                anchors.top: expHeader.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                text: root.statusMessage
                color: Qt.rgba(1, 1, 1, 0.65)
                font.family: sfRegular.name
                font.pixelSize: 10
                visible: root.statusMessage !== ""
            }

            // Network List
            ListView {
                id: netListView
                anchors.top: statusLabel.visible ? statusLabel.bottom : expHeader.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true
                spacing: 4
                model: root.networkList

                delegate: Rectangle {
                    width: netListView.width
                    height: (root.selectedSsid === modelData.ssid) ? 68 : 34
                    radius: 10
                    color: modelData.in_use ? Qt.rgba(1, 1, 1, 0.18) : (rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
                    border.width: modelData.in_use ? 1 : 0
                    border.color: Qt.rgba(1, 1, 1, 0.25)

                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        Row {
                            width: parent.width
                            height: 22
                            spacing: 8

                            Text {
                                text: modelData.signal > 70 ? "●●●" : (modelData.signal > 40 ? "●●○" : "●○○")
                                color: modelData.in_use ? "#34d399" : Qt.rgba(1, 1, 1, 0.70)
                                font.pixelSize: 9
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.ssid
                                color: "#ffffff"
                                font.family: sfRegular.name
                                font.pixelSize: 12
                                font.weight: modelData.in_use ? Font.Bold : Font.Normal
                                elide: Text.ElideRight
                                width: parent.width - 110
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: modelData.in_use ? "Connected" : (modelData.is_locked ? "🔒" : "")
                                color: modelData.in_use ? "#34d399" : Qt.rgba(1, 1, 1, 0.55)
                                font.family: sfRegular.name
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Inline Password Row if selected
                        Row {
                            width: parent.width
                            height: 24
                            spacing: 6
                            visible: root.selectedSsid === modelData.ssid && !modelData.in_use

                            Rectangle {
                                width: parent.width - 60
                                height: 24
                                radius: 6
                                color: Qt.rgba(0, 0, 0, 0.35)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.20)

                                TextInput {
                                    id: pwdField
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    color: "#ffffff"
                                    font.pixelSize: 11
                                    echoMode: TextInput.Password
                                    onTextChanged: root.passwordInput = text
                                    onAccepted: root.connectTo(modelData.ssid, text)
                                }
                            }

                            Rectangle {
                                width: 50; height: 24
                                radius: 6
                                color: Qt.rgba(1, 1, 1, 0.25)

                                Text {
                                    anchors.centerIn: parent
                                    text: "Join"
                                    color: "#ffffff"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.connectTo(modelData.ssid, pwdField.text)
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.in_use) return;
                            if (modelData.is_locked) {
                                root.selectedSsid = (root.selectedSsid === modelData.ssid) ? "" : modelData.ssid;
                            } else {
                                root.connectTo(modelData.ssid, null);
                            }
                        }
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
            onClicked: {
                root.isExpanded = true;
            }
            onDoubleClicked: {
                root.toggleRequested();
            }
        }
    }
}
