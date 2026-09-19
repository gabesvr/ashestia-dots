import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: clockWindow

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1
    color: "transparent"

    // Only intercept pointer input inside the clock card itself
    mask: Region {
        item: full
    }

    // Load original KDE widget fonts
    FontLoader {
        id: barlowMedium
        source: Qt.resolvedUrl("fonts/barlow_medium.ttf")
    }
    FontLoader {
        id: barlowSemiBold
        source: Qt.resolvedUrl("fonts/barlow_semibold.ttf")
    }
    FontLoader {
        id: sfProRounded
        source: Qt.resolvedUrl("fonts/sf_pro_rounded.otf")
    }

    // Saved position persistence
    property real cardX: 45
    property real cardY: 45

    Process {
        id: posLoader
        command: ["cat", "/home/gabriel/.config/quickshell/clock_pos.json"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const data = JSON.parse(line.trim());
                    if (data.x !== undefined && data.y !== undefined) {
                        full.x = data.x;
                        full.y = data.y;
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: posSaver
        running: false
    }

    function savePosition(newX, newY) {
        const json = "{\"x\":" + Math.round(newX) + ",\"y\":" + Math.round(newY) + "}";
        posSaver.command = ["sh", "-c", "echo '" + json + "' > /home/gabriel/.config/quickshell/clock_pos.json"];
        posSaver.running = true;
    }

    function setWallpaper(path) {
        glass.setWallpaper(path);
    }

    // Time & City state
    property string cityCode: "LOCAL"
    property real tzOffsetHours: 1.0
    property bool useLocalTime: true
    property date currentTime: new Date()

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            clockWindow.currentTime = new Date();
            ticks.secondHandAngle = clockWindow.currentTime.getSeconds() * 6;
        }
    }

    readonly property var displayDate: {
        if (clockWindow.useLocalTime) return clockWindow.currentTime;
        const utcMs = clockWindow.currentTime.getTime() + (clockWindow.currentTime.getTimezoneOffset() * 60000);
        return new Date(utcMs + (clockWindow.tzOffsetHours * 3600000));
    }

    readonly property int hour12: ((displayDate.getHours() + 11) % 12) + 1
    readonly property int minute: displayDate.getMinutes()

    readonly property string subLabel: {
        if (clockWindow.useLocalTime) {
            const days = ["DOM", "SEG", "TER", "QUA", "QUI", "SEX", "SÁB"];
            const day = days[displayDate.getDay()];
            return day + ", " + displayDate.getDate();
        }
        const localOffset = -clockWindow.currentTime.getTimezoneOffset() / 60.0;
        const diff = clockWindow.tzOffsetHours - localOffset;
        const formattedDiff = (diff % 1 === 0) ? String(diff) : diff.toFixed(1);
        return (diff >= 0 ? "+" : "") + formattedDiff + "HRS";
    }

    function cycleCity() {
        clockWindow.currentTime = new Date();
        if (clockWindow.cityCode === "LOCAL") {
            clockWindow.cityCode = "TYO";
            clockWindow.tzOffsetHours = 9.0;
            clockWindow.useLocalTime = false;
        } else if (clockWindow.cityCode === "TYO") {
            clockWindow.cityCode = "NYC";
            clockWindow.tzOffsetHours = -4.0;
            clockWindow.useLocalTime = false;
        } else if (clockWindow.cityCode === "NYC") {
            clockWindow.cityCode = "LON";
            clockWindow.tzOffsetHours = 1.0;
            clockWindow.useLocalTime = false;
        } else {
            clockWindow.cityCode = "LOCAL";
            clockWindow.useLocalTime = true;
        }
    }

    // The movable Clock Card
    Item {
        id: full
        x: clockWindow.cardX
        y: clockWindow.cardY
        width: 240
        height: 140

        // Liquid Glass Frosted Background
        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: 100
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
            screenWidth: clockWindow.width > 0 ? clockWindow.width : 1536
            screenHeight: clockWindow.height > 0 ? clockWindow.height : 960
        }

        // 60-Tick Animated Perimeter Ring
        TickRing {
            id: ticks
            anchors.fill: parent
            cornerRadius: glass.radius
            roundness: glass.roundness
            outerInset: 0.05
            tickLength: 0.026
            cornerOuterExtension: 0.012
            tickWidthPx: 2.2
            baseOpacity: 0.18
            tickColor: "#ffffff"
        }

        // Barlow Medium Digital Time Display with custom colon dots
        DigitalTime {
            anchors.centerIn: parent
            fontFamily: barlowMedium.name
            fontPixelSize: Math.min(full.width, full.height) * 0.60
            availableWidth: Math.max(40, full.width - 2 * Math.min(full.width, full.height) * 0.15)
            hour12: clockWindow.hour12
            minute: clockWindow.minute
            digitOpacity: 0.55
            textColor: "#ffffff"
        }

        // Top City Code and Bottom Offset Labels
        readonly property real _annoFont: Math.max(8, Math.min(full.width, full.height) * 0.085)
        readonly property real _annoMargin: Math.min(full.width, full.height) * 0.13
        readonly property real _annoOpacity: 0.55 * 0.55

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: full._annoMargin
            text: clockWindow.cityCode
            font.family: sfProRounded.name
            font.pixelSize: full._annoFont
            font.weight: Font.Medium
            color: "#ffffff"
            opacity: full._annoOpacity
            renderType: Text.NativeRendering
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: full._annoMargin
            text: clockWindow.subLabel
            font.family: sfProRounded.name
            font.pixelSize: full._annoFont
            font.weight: Font.Medium
            color: "#ffffff"
            opacity: full._annoOpacity
            renderType: Text.NativeRendering
        }

        // 144Hz Smooth Native Dragging & Click Interaction
        MouseArea {
            id: dragArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: dragArea.drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor

            drag.target: full
            drag.axis: Drag.XAndYAxis
            drag.threshold: 8
            drag.minimumX: 10
            drag.minimumY: 10
            drag.maximumX: clockWindow.width > 0 ? (clockWindow.width - full.width - 10) : 1500
            drag.maximumY: clockWindow.height > 0 ? (clockWindow.height - full.height - 10) : 900

            property real pressX: 0
            property real pressY: 0
            property bool isDrag: false

            onPositionChanged: (mouse) => {
                glass.mouseU = mouse.x / Math.max(1, full.width);
                glass.mouseV = mouse.y / Math.max(1, full.height);
                glass.mouseFade = 1;

                if (pressed) {
                    if (drag.active || Math.hypot(mouse.x - pressX, mouse.y - pressY) > 8) {
                        isDrag = true;
                    }
                }
            }

            onPressed: (mouse) => {
                pressX = mouse.x;
                pressY = mouse.y;
                isDrag = false;
            }

            onReleased: (mouse) => {
                if (!isDrag && !drag.active) {
                    clockWindow.cycleCity();
                } else {
                    clockWindow.savePosition(full.x, full.y);
                }
            }

            onEntered: {
                glass.mouseFade = 1;
            }

            onExited: {
                glass.mouseFade = 0;
                glass.mouseU = -1;
                glass.mouseV = -1;
            }
        }
    }
}
