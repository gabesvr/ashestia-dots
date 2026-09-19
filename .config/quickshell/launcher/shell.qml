import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

import "./widgets"

// Daemon QuickShell — Control Center + Mini Dynamic Island (iPhone 17 / Mac Notch) via FIFO
ShellRoot {
    id: shellRoot

    ControlCenter {
        id: controlCenter
        isIslandActive: dynamicIsland.shown && !dynamicIsland.isClosing
        onRequestIslandGlide: dynamicIsland.glideToControlCenter()
        onMorphToIslandRequested: dynamicIsland.morphFromControlCenter()
        onToggleMiniIslandRequested: dynamicIsland.toggleIsland()
        onMiniIslandDismissRequested: dynamicIsland.hideIsland()
        onWallpaperChanged: (path) => {
            desktopClock.setWallpaper(path)
            dynamicIsland.setWallpaper(path)
            desktopCalendar.setWallpaper(path)
            desktopWeather.setWallpaper(path)
            desktopMusic.setWallpaper(path)
        }
        onOpenLaunchpadRequested: {
            console.log("[SHELL.QML] onOpenLaunchpadRequested received!")
            launchpad.toggleLaunchpad()
        }
        onLayoutChangeRequested: (arg) => {
            shellRoot.handleLayoutCommand(arg)
        }
    }

    FontLoader {
        id: sfRegular
        source: Qt.resolvedUrl("widgets/fonts/sf_pro_display_regular.otf")
    }

    // ── 5 Creative Desktop Layouts (Smooth iOS Spring Animation) ──
    property int currentLayout: 1

    readonly property var layouts: [
        // ── Layout 1: Sonoma Flanks ──────────────────────────────
        // Left column (x=50..290, width=240): Clock + Calendar (20px gap)
        // Right column (x=1530..1870, width=340): Weather + Music (20px gap)
        // Completely flush edges ("rentes") on both sides!
        {
            id: 1,
            name: "Sonoma Flanks",
            desc: "Equilíbrio Lateral",
            clock:    { x: 50,   y: 50 },
            calendar: { x: 50,   y: 210, width: 240 },
            weather:  { x: 1530, y: 50,  width: 340 },
            music:    { x: 1530, y: 410 }
        },
        // ── Layout 2: Executive Shelf ────────────────────────────
        // Top row centered (total w=1130, left margin=395, 20px gaps)
        {
            id: 2,
            name: "Executive Shelf",
            desc: "Prateleira Superior",
            clock:    { x: 395,  y: 50 },
            calendar: { x: 655,  y: 50,  width: 240 },
            weather:  { x: 915,  y: 50,  width: 250 },
            music:    { x: 1185, y: 50 }
        },
        // ── Layout 3: Smart Sidebar ──────────────────────────────
        // 2×2 sidebar grid on the right, completely flush ("rentes")!
        // Left col (x=1270..1510, w=240): Clock (50..190) + Calendar (210..405)
        // Right col (x=1530..1870, w=340): Weather (50..390) + Music (410..570)
        // 20px gap between columns, 20px gap between rows, zero overlap!
        {
            id: 3,
            name: "Smart Sidebar",
            desc: "Painel Direito",
            clock:    { x: 1270, y: 50 },
            calendar: { x: 1270, y: 210, width: 240 },
            weather:  { x: 1530, y: 50,  width: 340 },
            music:    { x: 1530, y: 410 }
        },
        // ── Layout 4: Four Corners ───────────────────────────────
        // TL: Clock (50..290) | TR: Weather (1530..1870, w=340)
        // BL: Calendar (50..290, w=240) | BR: Music (1530..1870, w=340)
        {
            id: 4,
            name: "Four Corners",
            desc: "Quatro Cantos HUD",
            clock:    { x: 50,   y: 50 },
            weather:  { x: 1530, y: 50,  width: 340 },
            calendar: { x: 50,   y: 835, width: 240 },
            music:    { x: 1530, y: 870 }
        },
        // ── Layout 5: Creative Studio ────────────────────────────
        // Left column: Clock (50..190) → Calendar (210..405) → Weather (425..765)
        // All width 240, flush-left at x=50, 20px gaps! Music at (1530, 50)
        {
            id: 5,
            name: "Creative Studio",
            desc: "Trilho Esquerdo + Palco",
            clock:    { x: 50,   y: 50 },
            calendar: { x: 50,   y: 210, width: 240 },
            weather:  { x: 50,   y: 425, width: 240 },
            music:    { x: 1530, y: 50 }
        }
    ]

    function applyLayout(idx) {
        if (idx < 1 || idx > layouts.length) idx = 1;
        currentLayout = idx;
        const l = layouts[idx - 1];

        desktopClock.targetX = l.clock.x;
        desktopClock.targetY = l.clock.y;

        desktopCalendar.targetX = l.calendar.x;
        desktopCalendar.targetY = l.calendar.y;
        desktopCalendar.targetWidth = (l.calendar && l.calendar.width) ? l.calendar.width : 240;

        desktopWeather.targetX = l.weather.x;
        desktopWeather.targetY = l.weather.y;
        desktopWeather.targetWidth = (l.weather && l.weather.width) ? l.weather.width : 250;

        desktopMusic.targetX = l.music.x;
        desktopMusic.targetY = l.music.y;

        saveLayoutState(idx);
        showLayoutToast(l.name, l.desc, idx);
    }

    function nextLayout() {
        var next = currentLayout + 1;
        if (next > layouts.length) next = 1;
        applyLayout(next);
    }

    function prevLayout() {
        var prev = currentLayout - 1;
        if (prev < 1) prev = layouts.length;
        applyLayout(prev);
    }

    function handleLayoutCommand(arg) {
        if (arg === "next") nextLayout();
        else if (arg === "prev") prevLayout();
        else {
            var n = parseInt(arg);
            if (!isNaN(n) && n >= 1 && n <= layouts.length) {
                applyLayout(n);
            }
        }
    }

    // Persistence for active layout
    Process {
        id: layoutLoader
        command: ["cat", "/home/gabriel/.config/quickshell/layout_state.json"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const data = JSON.parse(line.trim());
                    if (data.layout) {
                        shellRoot.applyLayout(data.layout);
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: layoutSaver
        running: false
    }

    function saveLayoutState(idx) {
        const json = "{\"layout\":" + idx + "}";
        layoutSaver.command = ["sh", "-c", "echo '" + json + "' > /home/gabriel/.config/quickshell/layout_state.json"];
        layoutSaver.running = true;
    }

    // ── Floating Liquid Glass Layout Toast OSD ─────────────────
    PanelWindow {
        id: layoutToastWindow
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusiveZone: -1
        color: "transparent"
        visible: toastOpacity > 0.001

        mask: Region {
            item: toastCard
        }

        property real toastOpacity: 0.0
        property string toastTitle: ""
        property string toastDesc: ""
        property int toastIndex: 1

        Behavior on toastOpacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        Timer {
            id: toastHideTimer
            interval: 1800
            onTriggered: layoutToastWindow.toastOpacity = 0.0
        }

        Item {
            id: toastCard
            anchors.top: parent.top
            anchors.topMargin: 48
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 46
            opacity: layoutToastWindow.toastOpacity
            scale: layoutToastWindow.toastOpacity > 0 ? 1.0 : 0.85
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

            // Liquid Glass capsule background
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(0.08, 0.10, 0.14, 0.75)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.25)
            }

            Row {
                anchors.centerIn: parent
                spacing: 12

                Rectangle {
                    width: 26; height: 26
                    radius: 13
                    color: Qt.rgba(1, 1, 1, 0.18)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: String(layoutToastWindow.toastIndex)
                        color: "#ffffff"
                        font.family: sfRegular.name
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: layoutToastWindow.toastTitle
                        color: "#ffffff"
                        font.family: sfRegular.name
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: layoutToastWindow.toastDesc
                        color: "#ffffff"
                        opacity: 0.70
                        font.family: sfRegular.name
                        font.pixelSize: 10
                        font.weight: Font.Normal
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }

    function showLayoutToast(title, desc, idx) {
        layoutToastWindow.toastTitle = title;
        layoutToastWindow.toastDesc = desc;
        layoutToastWindow.toastIndex = idx;
        layoutToastWindow.toastOpacity = 1.0;
        toastHideTimer.restart();
    }

    DynamicIsland {
        id: dynamicIsland
        glassBgColor: controlCenter.glassBgColor
        glassHoverColor: controlCenter.glassHoverColor
        accentColor: controlCenter.accentColor
        mediaStat: controlCenter.mediaStat
        mediaTitle: controlCenter.mediaTitle
        mediaArtist: controlCenter.mediaArtist
        onMorphToControlCenterRequested: {
            controlCenter.morphFromIsland()
        }
        onExpandRequested: {
            dynamicIsland.glideToControlCenter()
        }
    }

    function broadcastWallpaper(path) {
        if (!path || !path.startsWith("/")) return;
        desktopClock.setWallpaper(path);
        desktopCalendar.setWallpaper(path);
        desktopWeather.setWallpaper(path);
        desktopMusic.setWallpaper(path);
        dynamicIsland.setWallpaper(path);
    }

    // Single centralized inotify wallpaper watcher (saves 4 duplicate processes)
    Process {
        id: wpTailWatcher
        command: ["tail", "-F", "-n", "1", "/home/gabriel/.config/hypr/current_wallpaper"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                shellRoot.broadcastWallpaper(line.trim());
            }
        }
    }

    // Single initial wallpaper loader at startup
    Process {
        id: wpInitLoader
        command: ["cat", "/home/gabriel/.config/hypr/current_wallpaper"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                shellRoot.broadcastWallpaper(line.trim());
            }
        }
    }

    ClockWidget {
        id: desktopClock
    }

    CalendarWidget {
        id: desktopCalendar
    }

    WeatherWidget {
        id: desktopWeather
    }

    MusicWidget {
        id: desktopMusic
        trackTitle: controlCenter.mediaTitle
        trackArtist: controlCenter.mediaArtist
        trackArtUrl: controlCenter.mediaArt
        playerStatus: controlCenter.mediaStat
        playbackPos: controlCenter.mediaPos
        playbackLen: controlCenter.mediaLen
    }

    Launchpad {
        id: launchpad
    }
}
