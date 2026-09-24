import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root
    anchors.fill: parent

    property alias cardItem: full
    property alias sharedBackdrop: glass.sharedBackdrop

    function setWallpaper(path) {
        glass.setWallpaper(path);
    }


    property real targetX: 176
    property real targetY: 417
    property real targetWidth: 114
    property real targetHeight: 160
    property string variant: "classic"   // visual escolhido pelo layout ("classic" = o de sempre)
    // variant "hidden": some com fade (o layout não usa este widget)
    opacity: variant === "hidden" ? 0 : 1
    visible: opacity > 0.01
    Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 260 } }

    property int brightnessVal: 80

    signal brightnessChangeRequested(int pct)

    readonly property bool isVertical: targetHeight > (targetWidth * 1.15)
    readonly property bool isSmallSquare: targetWidth < 120 && targetHeight < 120

    Item {
        id: full
        x: root.targetX
        y: root.targetY
        width: root.targetWidth
        height: root.targetHeight

        Behavior on x { enabled: !GlassTheme.gaming; NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on y { enabled: !GlassTheme.gaming; NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on width { enabled: !GlassTheme.gaming; NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }
        Behavior on height { enabled: !GlassTheme.gaming; NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }

        scale: cardMouse.pressed ? 0.96 : (cardMouse.containsMouse ? 1.02 : 1.0)
        Behavior on scale { enabled: !GlassTheme.gaming; NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: Math.min(28, Math.min(full.height, full.width) * 0.40)
            roundness: 4.6
            widgetX: full.x
            widgetY: full.y
            screenWidth: root.width > 0 ? root.width : 1920
            screenHeight: root.height > 0 ? root.height : 1080
        }

        // ── 1. VERTICAL APPLE macOS CAPSULE SLIDER MODE ──
        Item {
            anchors.fill: parent
            visible: root.isVertical

            // Top: Percentage
            Text {
                id: vPctLabel
                anchors.top: parent.top
                anchors.topMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.brightnessVal + "%"
                color: "#ffffff"
                font.family: "SF Pro Rounded"
                font.pixelSize: 13
                font.weight: Font.Bold
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.30)
            }

            // Apple macOS Center Capsule Slider Bar
            Item {
                id: vCapsuleTrack
                width: 52
                anchors.top: vPctLabel.bottom
                anchors.topMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter

                // Dark groove background capsule
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(0, 0, 0, 0.28)
                }

                // Precision Bottom Clipper
                Item {
                    id: vClipper
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.height * Math.min(1.0, Math.max(0.0, root.brightnessVal / 100.0))
                    clip: true
                    visible: height > 0

                    Behavior on height {
                        enabled: !GlassTheme.gaming && !cardMouse.isDragging
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }

                    // Full capsule white fill anchored to the bottom of the track
                    // Because it has identical width, height, and corner radius as the capsule track,
                    // its bottom curve matches the track with mathematical precision — zero leakage!
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: vCapsuleTrack.width
                        height: vCapsuleTrack.height
                        radius: width / 2
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.88)
                    }
                }

                // Outer border ring on top (crisp vector border)
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.14)
                }

                // Apple Bottom Icon (Sun) with dynamic contrast inversion
                Image {
                    id: vIconLight
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 22; height: 22
                    source: "file:///home/gabriel/.config/quickshell/assets/icons/brightness.svg"
                    fillMode: Image.PreserveAspectFit
                    opacity: (root.brightnessVal < 26) ? 0.95 : 0.0
                    Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 150 } }
                }

                Image {
                    id: vIconDark
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 22; height: 22
                    source: "file:///home/gabriel/.config/quickshell/assets/icons/brightness.svg"
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 1.0
                        colorizationColor: "#18181b"
                    }
                    opacity: (root.brightnessVal >= 26) ? 0.88 : 0.0
                    Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 150 } }
                }
            }
        }

        // ── 2. WIDE HORIZONTAL RECTANGLE MODE ──
        Item {
            anchors.fill: parent
            visible: !root.isVertical && !root.isSmallSquare
            anchors.margins: 12

            Column {
                anchors.fill: parent
                spacing: 8

                Row {
                    width: parent.width
                    height: 16

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 15; height: 15
                        source: "file:///home/gabriel/.config/quickshell/assets/icons/brightness.svg"
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.85
                    }

                    Item { width: 6; height: 1 }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "DISPLAY"
                        color: "#ffffff"
                        opacity: 0.60
                        font.family: "SF Pro Display"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                    }

                    Item { Layout.fillWidth: true; width: full.width - 130 }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.brightnessVal + "%"
                        color: "#ffffff"
                        opacity: 0.90
                        font.family: "SF Pro Rounded"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                }

                // Apple Horizontal Capsule Track
                Rectangle {
                    width: parent.width
                    height: 22
                    radius: 11
                    color: Qt.rgba(0, 0, 0, 0.26)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    clip: true

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(0, parent.width * Math.min(1.0, Math.max(0.02, root.brightnessVal / 100.0)))
                        radius: 11
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.88)

                        Behavior on width {
                            enabled: !GlassTheme.gaming && !cardMouse.isDragging
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }

        // ── 3. COMPACT SQUARE BADGE MODE ──
        Item {
            anchors.fill: parent
            visible: root.isSmallSquare

            Column {
                anchors.centerIn: parent
                spacing: 5

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 32; height: 32
                    radius: 16
                    color: Qt.rgba(1, 1, 1, 0.14)

                    Image {
                        anchors.centerIn: parent
                        width: 16; height: 16
                        source: "file:///home/gabriel/.config/quickshell/assets/icons/brightness.svg"
                        fillMode: Image.PreserveAspectFit
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.brightnessVal + "%"
                    color: "#ffffff"
                    font.family: "SF Pro Rounded"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
            }
        }

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            property bool isDragging: false

            onPressed: (mouse) => {
                isDragging = true;
                updateFromMouse(mouse.x, mouse.y);
            }
            onPositionChanged: (mouse) => {
                glass.mouseU = mouse.x / Math.max(1, full.width);
                glass.mouseV = mouse.y / Math.max(1, full.height);
                glass.mouseFade = 1;
                if (isDragging) updateFromMouse(mouse.x, mouse.y);
            }
            onEntered: {
                glass.mouseFade = 1;
            }
            onExited: {
                glass.mouseFade = 0;
                glass.mouseU = -1;
                glass.mouseV = -1;
            }
            onReleased: {
                isDragging = false;
            }

            function updateFromMouse(posX, posY) {
                let pct = 0;
                if (root.isVertical) {
                    let trackTop = 38;
                    let trackHeight = Math.max(1, full.height - 52);
                    let relativeY = posY - trackTop;
                    pct = Math.round(Math.max(1, Math.min(100, (1.0 - (relativeY / trackHeight)) * 100)));
                } else {
                    pct = Math.round(Math.max(1, Math.min(100, (posX / full.width) * 100)));
                }
                root.brightnessChangeRequested(pct);
            }
        }
    }
}
