import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: clockWindow
    anchors.fill: parent

    property alias cardItem: full
    property alias sharedBackdrop: glass.sharedBackdrop

    // Load original KDE widget fonts
    FontLoader {
        id: barlowMedium
        source: Qt.resolvedUrl("fonts/barlow_medium.ttf")
    }
    FontLoader {
        id: barlowSemiBold
        source: Qt.resolvedUrl("fonts/barlow_semibold.ttf")
    }

    // Animated Target Position (Driven by Layout Manager)
    property real targetX: 50
    property real targetY: 55
    property real targetWidth: 240     // usados pelas variantes (o card clássico tem tamanho fixo)
    property real targetHeight: 140
    property string variant: "classic"   // visual escolhido pelo layout ("classic" = o de sempre)
    // variant "hidden": some com fade (o layout não usa este widget)
    opacity: variant === "hidden" ? 0 : 1
    visible: opacity > 0.01
    Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 260 } }

    function setWallpaper(path) {
        glass.setWallpaper(path);
    }

    // Time & City state
    property string cityCode: "PORTO"
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

    property bool is24Hour: true
    readonly property int hour24: displayDate.getHours()
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
        if (clockWindow.cityCode === "PORTO") {
            clockWindow.cityCode = "LAUSANNE";
            clockWindow.tzOffsetHours = 2.0;
            clockWindow.useLocalTime = false;
        } else {
            clockWindow.cityCode = "PORTO";
            clockWindow.tzOffsetHours = 1.0;
            clockWindow.useLocalTime = true;
        }
    }

    // The Clock Card
    Item {
        id: full
        opacity: vhost.active || clockWindow.variant === "hidden" ? 0 : 1   // clássico some quando uma variante assume ou quando o layout esconde o widget (senão pisca no fade-out)
        visible: opacity > 0.01
        Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 200 } }
        x: clockWindow.targetX
        y: clockWindow.targetY
        width: 240
        height: 140

        Behavior on x { enabled: !GlassTheme.gaming; NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on y { enabled: !GlassTheme.gaming; NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }

        // Liquid Glass Frosted Background
        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: 100
            roundness: 4.6
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
            hour: clockWindow.is24Hour ? clockWindow.hour24 : clockWindow.hour12
            minute: clockWindow.minute
            useLeadingZero: clockWindow.is24Hour
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
            font.family: "SF Pro Rounded"
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
            font.family: "SF Pro Rounded"
            font.pixelSize: full._annoFont
            font.weight: Font.Medium
            color: "#ffffff"
            opacity: full._annoOpacity
            renderType: Text.NativeRendering
        }

        // Smooth Click & Specular Interaction (Dragging disabled - driven by Layouts)
        MouseArea {
            id: clickArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onPositionChanged: (mouse) => {
                glass.mouseU = mouse.x / Math.max(1, full.width);
                glass.mouseV = mouse.y / Math.max(1, full.height);
                glass.mouseFade = 1;
            }

            onClicked: {
                clockWindow.cycleCity();
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

    // Visuais alternativos escolhidos pelo layout (widgets/variants/)
    VariantHost {
        id: vhost
        variant: clockWindow.variant
        sources: ({ hero: Qt.resolvedUrl("variants/ClockHero.qml"), bento: Qt.resolvedUrl("variants/ClockBento.qml"), ring: Qt.resolvedUrl("variants/ClockRing.qml"), editorial: Qt.resolvedUrl("variants/ClockEditorial.qml") })
        targetX: clockWindow.targetX
        targetY: clockWindow.targetY
        targetWidth: clockWindow.targetWidth
        targetHeight: clockWindow.targetHeight
        sharedBackdrop: clockWindow.sharedBackdrop
        screenW: clockWindow.width > 0 ? clockWindow.width : 1920
        screenH: clockWindow.height > 0 ? clockWindow.height : 1200
    }
}
