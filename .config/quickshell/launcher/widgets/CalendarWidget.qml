import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: calendarWindow

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1
    color: "transparent"

    // Only capture mouse pointer inside the widget card
    mask: Region {
        item: full
    }

    // Font loading
    FontLoader {
        id: sfRegular
        source: Qt.resolvedUrl("fonts/sf_pro_display_regular.otf")
    }

    // Animated Target Position (Driven by Layout Manager)
    property real targetX: 50
    property real targetY: 220
    property real targetWidth: 240

    function setWallpaper(path) {
        glass.setWallpaper(path);
    }

    // Date state
    property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth() // 0..11
    property int firstDow: 0 // 0 = Sunday first, 1 = Monday first

    readonly property var monthNamesEn: ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]
    readonly property var monthNamesPt: ["JANEIRO", "FEVEREIRO", "MARÇO", "ABRIL", "MAIO", "JUNHO", "JULHO", "AGOSTO", "SETEMBRO", "OUTUBRO", "NOVEMBRO", "DEZEMBRO"]
    property bool usePortugueseMonth: false

    readonly property string displayMonthName: {
        const list = usePortugueseMonth ? monthNamesPt : monthNamesEn;
        return list[viewMonth] || "";
    }

    readonly property var weekdayShortSun: ["S", "M", "T", "W", "T", "F", "S"]
    readonly property var weekdayShortMon: ["M", "T", "W", "T", "F", "S", "S"]
    readonly property var weekdayShort: firstDow === 1 ? weekdayShortMon : weekdayShortSun

    function isWeekendCol(col) {
        return firstDow === 1 ? (col === 5 || col === 6) : (col === 0 || col === 6);
    }

    // Days calculation
    property var monthDays: []
    function rebuildMonthDays() {
        const firstOfMonth = new Date(viewYear, viewMonth, 1);
        let offset = firstOfMonth.getDay() - firstDow;
        if (offset < 0) offset += 7;
        const lastDay = new Date(viewYear, viewMonth + 1, 0).getDate();
        const out = new Array(42);
        for (let i = 0; i < 42; i++) {
            const day = i - offset + 1;
            out[i] = (day < 1 || day > lastDay) ? 0 : day;
        }
        monthDays = out;
    }

    onViewYearChanged: rebuildMonthDays()
    onViewMonthChanged: rebuildMonthDays()
    onFirstDowChanged: rebuildMonthDays()

    Component.onCompleted: {
        rebuildMonthDays();
        scheduleNextMidnight();
    }

    Timer {
        id: midnightTimer
        repeat: false
        onTriggered: {
            calendarWindow.today = new Date();
            calendarWindow.scheduleNextMidnight();
            calendarWindow.rebuildMonthDays();
        }
    }

    function scheduleNextMidnight() {
        const now = new Date();
        const next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 5);
        midnightTimer.interval = Math.max(1000, next.getTime() - now.getTime());
        midnightTimer.start();
    }

    function nextMonth() {
        if (viewMonth === 11) {
            viewYear++;
            viewMonth = 0;
        } else {
            viewMonth++;
        }
    }

    function prevMonth() {
        if (viewMonth === 0) {
            viewYear--;
            viewMonth = 11;
        } else {
            viewMonth--;
        }
    }

    function resetToToday() {
        today = new Date();
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
    }

    // The Calendar Card
    Item {
        id: full
        x: calendarWindow.targetX
        y: calendarWindow.targetY
        width: calendarWindow.targetWidth
        height: 195

        Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutQuint } }
        Behavior on y { NumberAnimation { duration: 700; easing.type: Easing.OutQuint } }
        Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.OutQuint } }

        // Liquid Glass Background
        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: 40
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
            screenWidth: calendarWindow.width > 0 ? calendarWindow.width : 1920
            screenHeight: calendarWindow.height > 0 ? calendarWindow.height : 1080
        }

        readonly property real labelSize: Math.max(10, Math.round(full.height * 0.065))

        // Content Area
        Column {
            anchors.fill: parent
            anchors.margins: Math.round(full.height * 0.10)
            anchors.topMargin: Math.round(full.height * 0.12)
            spacing: Math.round(full.height * 0.035)

            // Month Header with navigation arrows
            Item {
                width: parent.width
                height: Math.round(full.labelSize * 1.5)

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(parent.width / 7 / 2 - full.labelSize * 0.4)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        id: monthText
                        text: calendarWindow.displayMonthName
                        color: "#ffffff"
                        font.family: sfRegular.name
                        font.pixelSize: full.labelSize
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                        renderType: Text.NativeRendering
                    }

                    // Small indicator when not on current month
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4; height: 4
                        radius: 2
                        color: "#ffffff"
                        opacity: 0.6
                        visible: calendarWindow.viewMonth !== calendarWindow.today.getMonth() || calendarWindow.viewYear !== calendarWindow.today.getFullYear()
                    }
                }

                // Month Switchers on hover
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    opacity: clickArea.containsMouse ? 0.75 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Text {
                        text: "‹"
                        color: "#ffffff"
                        font.pixelSize: full.labelSize * 1.3
                        font.bold: true
                        renderType: Text.NativeRendering
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calendarWindow.prevMonth()
                        }
                    }

                    Text {
                        text: "›"
                        color: "#ffffff"
                        font.pixelSize: full.labelSize * 1.3
                        font.bold: true
                        renderType: Text.NativeRendering
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calendarWindow.nextMonth()
                        }
                    }
                }
            }

            // Weekday Initials Row: S M T W T F S
            Item {
                width: parent.width
                height: full.labelSize * 1.3

                Row {
                    anchors.fill: parent
                    Repeater {
                        model: 7
                        delegate: Item {
                            width: parent.width / 7
                            height: parent.height

                            Text {
                                anchors.centerIn: parent
                                text: calendarWindow.weekdayShort[index]
                                color: "#ffffff"
                                opacity: calendarWindow.isWeekendCol(index) ? 0.45 : 0.85
                                font.family: sfRegular.name
                                font.pixelSize: full.labelSize
                                font.weight: Font.Medium
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }
            }

            // 6x7 Calendar Day Grid
            Item {
                id: gridWrap
                width: parent.width
                height: full.height * 0.58

                readonly property real cellW: width / 7
                readonly property real cellH: height / 6
                readonly property real badgeDiameter: Math.min(cellW, cellH) * 1.15

                Grid {
                    id: dayGrid
                    anchors.fill: parent
                    rows: 6
                    columns: 7

                    Repeater {
                        model: 42
                        delegate: Item {
                            width: gridWrap.cellW
                            height: gridWrap.cellH

                            readonly property int day: calendarWindow.monthDays[index] || 0
                            readonly property bool empty: day === 0
                            readonly property bool isCurrent: !empty && day === calendarWindow.today.getDate()
                                && calendarWindow.viewMonth === calendarWindow.today.getMonth()
                                && calendarWindow.viewYear === calendarWindow.today.getFullYear()
                            readonly property bool isWeekend: calendarWindow.isWeekendCol(index % 7)

                            // Normal day number
                            Text {
                                anchors.centerIn: parent
                                visible: !empty && !isCurrent
                                text: day
                                color: "#ffffff"
                                opacity: isWeekend ? 0.45 : 1.0
                                font.family: sfRegular.name
                                font.pixelSize: full.labelSize
                                font.weight: Font.Medium
                                renderType: Text.NativeRendering
                            }

                            // Today badge with white circular cutout
                            TodayBadge {
                                anchors.centerIn: parent
                                width: gridWrap.badgeDiameter
                                height: gridWrap.badgeDiameter
                                visible: isCurrent
                                dayNumber: day
                                diameter: gridWrap.badgeDiameter
                                fontPixelSize: full.labelSize * 1.05
                                fontFamily: sfRegular.name
                                badgeColor: "#ffffff"
                                punchOutText: true
                            }
                        }
                    }
                }
            }
        }

        // Smooth Click & Specular Interaction (Dragging disabled - driven by Layouts)
        MouseArea {
            id: clickArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor

            onPositionChanged: (mouse) => {
                glass.mouseU = mouse.x / Math.max(1, full.width);
                glass.mouseV = mouse.y / Math.max(1, full.height);
                glass.mouseFade = 1;
            }

            onClicked: (mouse) => {
                // Click on header resets to today or toggles PT/EN month name
                if (mouse.y < full.height * 0.25) {
                    if (calendarWindow.viewMonth !== calendarWindow.today.getMonth() || calendarWindow.viewYear !== calendarWindow.today.getFullYear()) {
                        calendarWindow.resetToToday();
                    } else {
                        calendarWindow.usePortugueseMonth = !calendarWindow.usePortugueseMonth;
                    }
                }
            }

            onWheel: (wheel) => {
                if (wheel.angleDelta.y < 0) {
                    calendarWindow.nextMonth();
                } else if (wheel.angleDelta.y > 0) {
                    calendarWindow.prevMonth();
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
