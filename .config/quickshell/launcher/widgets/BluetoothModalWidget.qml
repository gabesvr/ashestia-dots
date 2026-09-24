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
    property var devices: []
    property bool isScanning: false
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
        statusMsg = "";
    }

    function setWallpaper(path) {
        glass.setWallpaper(path);
    }


    // ── Bluetooth Lister Process ──
    Process {
        id: btLister
        command: [GlassTheme.home + "/.config/quickshell/scripts/bt_tool.sh", "list"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const data = JSON.parse(line.trim());
                    modalWindow.devices = data.devices || [];
                    modalWindow.isScanning = false;
                } catch(e) {
                    modalWindow.isScanning = false;
                }
            }
        }
    }

    // ── Bluetooth Action Process ──
    Process {
        id: btAction
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
        btLister.running = true;
    }

    function connectDevice(mac) {
        modalWindow.statusMsg = "Connecting to " + mac + "...";
        btAction.command = [GlassTheme.home + "/.config/quickshell/scripts/bt_tool.sh", "connect", mac];
        btAction.running = true;
    }

    function disconnectDevice(mac) {
        modalWindow.statusMsg = "Disconnecting " + mac + "...";
        btAction.command = [GlassTheme.home + "/.config/quickshell/scripts/bt_tool.sh", "disconnect", mac];
        btAction.running = true;
    }

    // Click outside to dismiss with dimming scrim
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: modalWindow.shown ? 0.35 : 0.0
        Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

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
        Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on scale { enabled: !GlassTheme.gaming; NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

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
                    source: "file://" + GlassTheme.home + "/.config/quickshell/assets/icons/bluetooth.svg"
                    fillMode: Image.PreserveAspectFit
                }

                Item { width: 8; height: 1 }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Bluetooth Devices"
                    color: "#ffffff"
                    font.family: "SF Pro Display"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }

                Item { Layout.fillWidth: true; width: card.width - 245 }

                // Refresh Button
                Rectangle {
                    width: 26; height: 26
                    radius: 13
                    color: Qt.rgba(1, 1, 1, 0.12)
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        width: 12; height: 12
                        source: "file://" + GlassTheme.home + "/.config/quickshell/assets/icons/refresh.svg"
                        fillMode: Image.PreserveAspectFit
                        rotation: modalWindow.isScanning ? 360 : 0
                        Behavior on rotation { enabled: !GlassTheme.gaming; NumberAnimation { duration: 800; loops: Animation.Infinite } }
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
                font.family: "SF Pro Display"
                font.pixelSize: 10
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                width: parent.width
            }

            // Devices List
            ListView {
                width: parent.width
                height: 310
                clip: true
                spacing: 8
                model: modalWindow.devices

                delegate: Rectangle {
                    width: parent.width
                    height: 52
                    radius: 14
                    color: modelData.connected ? Qt.rgba(0.20, 0.50, 1.0, 0.28) : Qt.rgba(1, 1, 1, 0.08)

                    Row {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16
                            source: "file://" + GlassTheme.home + "/.config/quickshell/assets/icons/bluetooth.svg"
                            fillMode: Image.PreserveAspectFit
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            width: parent.width - 120

                            Text {
                                text: modelData.name || modelData.mac
                                color: "#ffffff"
                                font.family: "SF Pro Display"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "Ready to pair")
                                color: modelData.connected ? "#34d399" : Qt.rgba(1, 1, 1, 0.55)
                                font.family: "SF Pro Display"
                                font.pixelSize: 9
                            }
                        }

                        Rectangle {
                            width: 70
                            height: 28
                            radius: 8
                            color: modelData.connected ? Qt.rgba(0.9, 0.2, 0.2, 0.4) : Qt.rgba(0.2, 0.6, 1.0, 0.4)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: modelData.connected ? "Disconnect" : "Connect"
                                color: "#ffffff"
                                font.family: "SF Pro Display"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.connected) {
                                        modalWindow.disconnectDevice(modelData.mac);
                                    } else {
                                        modalWindow.connectDevice(modelData.mac);
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
