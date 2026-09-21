import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    anchors.fill: parent

    property alias cardItem: full
    property alias sharedBackdrop: glass.sharedBackdrop

    function setWallpaper(path) {
        glass.setWallpaper(path);
    }

    FontLoader {
        id: sfRegular
        source: Qt.resolvedUrl("fonts/sf_pro_display_regular.otf")
    }
    FontLoader {
        id: sfProRounded
        source: Qt.resolvedUrl("fonts/sf_pro_rounded.otf")
    }

    property real targetX: 1794
    property real targetY: 688
    property real targetWidth: 76
    property real targetHeight: 76

    property bool isExpanded: false
    property var wallpaperList: []
    property string activeWallpaperPath: ""
    property bool isLoading: false

    signal nextRequested()
    signal wallpaperSelected(string path)

    readonly property bool isSmallSquare: targetWidth < 120

    // ── Wallpaper List Loader ─────────────────────────────────
    function loadWallpapers() {
        if (isLoading) return;
        isLoading = true;
        wpListProc.running = false;
        wpListProc.running = true;
    }

    Process {
        id: wpListProc
        command: ["/home/gabriel/.config/quickshell/scripts/wallpaper_tool.sh", "list"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const data = JSON.parse(line.trim());
                    if (data.wallpapers) {
                        root.wallpaperList = data.wallpapers;
                    }
                    if (data.active) {
                        root.activeWallpaperPath = data.active;
                    }
                } catch(e) {}
                root.isLoading = false;
            }
        }
        onExited: (code) => { root.isLoading = false; }
    }

    // ── Wallpaper Set Process ────────────────────────────────
    Process {
        id: wpSetProc
        running: false
    }

    function selectWallpaper(path) {
        root.activeWallpaperPath = path;
        wpSetProc.running = false;
        wpSetProc.command = ["/home/gabriel/.config/quickshell/scripts/wallpaper_tool.sh", "set", path];
        wpSetProc.running = true;
        root.wallpaperSelected(path);
    }

    onIsExpandedChanged: {
        if (isExpanded) {
            loadWallpapers();
        }
    }

    Component.onCompleted: {
        loadWallpapers();
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
            screenHeight: root.height > 0 ? root.height : 1200
        }

        // ══════════════════════════════════════════════════════════════
        // 1. COLLAPSED MODE: PURE ICON-ONLY SYMBOL
        // ══════════════════════════════════════════════════════════════
        Item {
            anchors.fill: parent
            visible: !root.isExpanded && root.isSmallSquare

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(38, Math.min(parent.width, parent.height) * 0.60)
                height: width
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.14)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.20)

                Image {
                    anchors.centerIn: parent
                    width: parent.width * 0.52
                    height: width
                    source: "file:///home/gabriel/.config/quickshell/assets/icons/wallpaper.svg"
                    fillMode: Image.PreserveAspectFit
                    opacity: 0.85
                }
            }
        }

        // ── 2. WIDE RECTANGLE MODE (collapsed) ──
        Item {
            anchors.fill: parent
            visible: !root.isExpanded && !root.isSmallSquare
            anchors.margins: 12

            Row {
                anchors.fill: parent
                spacing: 10

                Rectangle {
                    width: 34; height: 34
                    radius: 17
                    color: Qt.rgba(1, 1, 1, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.20)
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        width: 17; height: 17
                        source: "file:///home/gabriel/.config/quickshell/assets/icons/wallpaper.svg"
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.85
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "Wallpaper"
                        color: "#ffffff"
                        font.family: sfRegular.name
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }

                    Text {
                        text: "Click to browse"
                        color: "#ffffff"
                        opacity: 0.70
                        font.family: sfRegular.name
                        font.pixelSize: 9
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════
        // 3. EXPANDED MODE: WALLPAPER GALLERY PICKER
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
                id: wpHeader
                width: parent.width
                iconSource: "file:///home/gabriel/.config/quickshell/assets/icons/wallpaper.svg"
                accent: "#af52de"
                title: "Wallpapers"
                subtitle: root.isLoading ? "Loading…" : (root.wallpaperList.length + " images")
                showSwitch: false
                busy: root.isLoading
                onRefreshClicked: root.loadWallpapers()
                onCloseClicked: root.isExpanded = false
            }

            Rectangle {
                id: wpDivider
                anchors.top: wpHeader.bottom
                anchors.topMargin: 8
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.14)
            }

            GridView {
                id: wpGrid
                anchors.top: wpDivider.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                cellWidth: Math.floor(wpGrid.width / 3)
                cellHeight: Math.round(cellWidth * 0.66)

                model: root.wallpaperList

                delegate: Item {
                    width: wpGrid.cellWidth
                    height: wpGrid.cellHeight

                    Rectangle {
                        id: thumbCard
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 12
                        clip: true
                        color: Qt.rgba(1, 1, 1, 0.10)
                        border.width: modelData.active ? 2 : 0
                        border.color: "#ffffff"
                        scale: thumbMouse.pressed ? 0.95 : (thumbMouse.containsMouse ? 1.03 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

                        Image {
                            anchors.fill: parent
                            anchors.margins: modelData.active ? 2 : 0
                            source: modelData.path ? ("file://" + modelData.path) : ""
                            sourceSize.width: 200
                            sourceSize.height: 130
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                            cache: true
                        }

                        // Selo de ativo
                        Rectangle {
                            visible: modelData.active
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 5
                            width: 18; height: 18
                            radius: 9
                            color: "#34c759"
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.6)

                            Image {
                                anchors.centerIn: parent
                                width: 10; height: 10
                                source: "file:///home/gabriel/.config/quickshell/assets/icons/check.svg"
                                sourceSize.width: 32; sourceSize.height: 32
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        MouseArea {
                            id: thumbMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!modelData.active) {
                                    root.selectWallpaper(modelData.path);
                                    let updated = [];
                                    for (let i = 0; i < root.wallpaperList.length; i++) {
                                        let item = root.wallpaperList[i];
                                        updated.push({
                                            name: item.name,
                                            filename: item.filename,
                                            path: item.path,
                                            active: (item.path === modelData.path)
                                        });
                                    }
                                    root.wallpaperList = updated;
                                }
                            }
                        }
                    }
                }
            }
        }

        // Collapsed click area
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
        }
    }
}
