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

    property real targetX: 1708
    property real targetY: 586
    property real targetWidth: 76
    property real targetHeight: 76

    property bool isBtOn: true
    property string btDevice: ""
    property bool isExpanded: false

    signal toggleRequested()

    property var deviceList: []
    property bool isScanning: false
    property string statusMessage: ""

    function scanDevices() {
        if (isScanning) return;
        isScanning = true;
        statusMessage = "Scanning...";
        scanProc.running = false;
        scanProc.running = true;
    }

    function toggleDevice(mac, isConnected) {
        statusMessage = (isConnected ? "Disconnecting..." : "Connecting...");
        actionProc.command = ["/home/gabriel/.config/quickshell/scripts/bt_tool.sh", isConnected ? "disconnect" : "connect", mac];
        actionProc.running = false;
        actionProc.running = true;
    }

    Process {
        id: scanProc
        command: ["/home/gabriel/.config/quickshell/scripts/bt_tool.sh", "list"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const data = JSON.parse(line.trim());
                    if (data.devices) {
                        root.deviceList = data.devices;
                        root.statusMessage = "";
                    }
                } catch(e) {}
                root.isScanning = false;
            }
        }
        onExited: (code) => { root.isScanning = false; }
    }

    Process {
        id: actionProc
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                root.statusMessage = "";
                root.scanDevices();
            }
        }
    }

    onIsExpandedChanged: {
        if (isExpanded) {
            scanDevices();
        } else {
            statusMessage = "";
        }
    }

    Item {
        id: full
        x: root.targetX
        y: root.targetY
        width: root.isExpanded ? 340 : root.targetWidth
        height: root.isExpanded ? 290 : root.targetHeight

        Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on y { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on width { NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }
        Behavior on height { NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }

        scale: (tileMouse.pressed && !root.isExpanded) ? 0.92 : ((tileMouse.containsMouse && !root.isExpanded) ? 1.04 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: root.isExpanded ? 28 : Math.min(24, Math.min(full.height, full.width) * 0.45)
            roundness: 4.6
            tint: root.isExpanded ? "#0a1024" : "#ffffff"
            tintAlpha: root.isExpanded ? 0.30 : 0.15
            lumaCap: root.isExpanded ? 0.50 : 0.80
            Behavior on tint { ColorAnimation { duration: 320 } }
            Behavior on tintAlpha { NumberAnimation { duration: 320 } }
            Behavior on lumaCap { NumberAnimation { duration: 320 } }
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
                color: root.isBtOn ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                border.color: root.isBtOn ? Qt.rgba(1, 1, 1, 0.40) : Qt.rgba(1, 1, 1, 0.14)

                Image {
                    anchors.centerIn: parent
                    width: parent.width * 0.52
                    height: width
                    source: "file:///home/gabriel/.config/quickshell/assets/icons/bluetooth.svg"
                    fillMode: Image.PreserveAspectFit
                    opacity: root.isBtOn ? 1.0 : 0.60
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
                    visible: root.isBtOn
                }
            }
        }

        // ══════════════════════════════════════════════════════════════
        // 2. EXPANDED MODE: BLUETOOTH DEVICE BROWSER
        // ══════════════════════════════════════════════════════════════
        Item {
            id: expPanel
            anchors.fill: parent
            anchors.margins: 16
            visible: root.isExpanded || opacity > 0.01
            opacity: root.isExpanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 240 } }
            clip: true

            PanelHeader {
                id: expHeader
                width: parent.width
                iconSource: "file:///home/gabriel/.config/quickshell/assets/icons/bluetooth.svg"
                title: "Bluetooth"
                subtitle: root.statusMessage !== "" ? root.statusMessage
                        : (!root.isBtOn ? "Off"
                        : (root.isScanning ? "Scanning…"
                        : (root.btDevice !== "" ? root.btDevice : "Not connected")))
                showSwitch: true
                switchOn: root.isBtOn
                busy: root.isScanning
                onSwitchToggled: root.toggleRequested()
                onRefreshClicked: root.scanDevices()
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
                id: devListView
                anchors.top: expDivider.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true
                spacing: 5
                boundsBehavior: Flickable.StopAtBounds
                model: root.deviceList

                delegate: Rectangle {
                    width: devListView.width
                    height: 46
                    radius: 13
                    color: modelData.connected ? Qt.rgba(1, 1, 1, 0.20) : (devRowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
                    border.width: 1
                    border.color: modelData.connected ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Rectangle {
                        id: devBadge
                        width: 28; height: 28
                        radius: 14
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: modelData.connected ? "#0a84ff" : Qt.rgba(1, 1, 1, 0.16)

                        Image {
                            anchors.centerIn: parent
                            width: 14; height: 14
                            source: "file:///home/gabriel/.config/quickshell/assets/icons/bluetooth.svg"
                            sourceSize.width: 32; sourceSize.height: 32
                            fillMode: Image.PreserveAspectFit
                            opacity: modelData.connected ? 1.0 : 0.85
                        }
                    }

                    Column {
                        anchors.left: devBadge.right
                        anchors.leftMargin: 10
                        anchors.right: actionPill.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: modelData.name || modelData.mac
                            color: "#ffffff"
                            font.family: sfRegular.name
                            font.pixelSize: 13
                            font.weight: modelData.connected ? Font.Bold : Font.Medium
                            elide: Text.ElideRight
                            style: Text.Raised
                            styleColor: Qt.rgba(0, 0, 0, 0.32)
                        }
                        Text {
                            text: modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "Available")
                            color: modelData.connected ? "#34d399" : Qt.rgba(1, 1, 1, 0.72)
                            font.family: sfRegular.name
                            font.pixelSize: 10
                        }
                    }

                    Rectangle {
                        id: actionPill
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: pillText.implicitWidth + 20
                        height: 24
                        radius: 12
                        color: modelData.connected ? Qt.rgba(1, 0.27, 0.23, 0.55) : Qt.rgba(1, 1, 1, 0.20)

                        Text {
                            id: pillText
                            anchors.centerIn: parent
                            text: modelData.connected ? "Disconnect" : "Connect"
                            color: "#ffffff"
                            font.family: sfRegular.name
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }

                    MouseArea {
                        id: devRowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleDevice(modelData.mac, modelData.connected)
                    }
                }
            }

            Text {
                anchors.centerIn: devListView
                visible: root.deviceList.length === 0
                text: !root.isBtOn ? "Bluetooth is off" : (root.isScanning ? "Looking for devices…" : "No devices found")
                color: Qt.rgba(1, 1, 1, 0.70)
                font.family: sfRegular.name
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
