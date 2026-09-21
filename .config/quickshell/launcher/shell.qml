import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

import "./widgets"

// Daemon QuickShell — Liquid Glass Modular Desktop Widgets
ShellRoot {
    id: shellRoot

    FontLoader {
        id: sfRegular
        source: Qt.resolvedUrl("widgets/fonts/sf_pro_display_regular.otf")
    }

    // ── System States (Single Source of Truth) ────────────────
    property real systemVolume: 0.5
    property bool systemVolumeMuted: false
    property int systemBrightness: 80
    property bool systemWifiOn: true
    property string systemWifiSsid: "Wi-Fi"
    property bool systemBtOn: false
    property bool systemTurbo: false
    property bool systemDnd: false
    property bool systemXwayland: false

    Process { id: cmdRunner; running: false }
    function exec(cmd) {
        cmdRunner.command = ["sh", "-c", cmd];
        cmdRunner.running = false;
        cmdRunner.running = true;
    }

    Process { id: volProc; running: false }
    function setVolume(pct) {
        systemVolume = pct;
        systemVolumeMuted = (pct === 0);
        volProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(pct * 100) + "%"];
        volProc.running = false;
        volProc.running = true;
    }

    function toggleMute() {
        systemVolumeMuted = !systemVolumeMuted;
        volProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"];
        volProc.running = false;
        volProc.running = true;
    }

    Process { id: brProc; running: false }
    function setBrightness(pct) {
        systemBrightness = pct;
        brProc.command = ["brightnessctl", "set", pct + "%"];
        brProc.running = false;
        brProc.running = true;
    }

    function toggleWifi() {
        systemWifiOn = !systemWifiOn;
        exec("nmcli radio wifi " + (systemWifiOn ? "on" : "off"));
    }

    function toggleBt() {
        systemBtOn = !systemBtOn;
        exec("rfkill toggle bluetooth");
    }

    Process {
        id: turboProc
        running: false
        onExited: statusPoller.running = true
    }
    function toggleTurbo() {
        systemTurbo = !systemTurbo;
        turboProc.command = ["sh", "-c", systemTurbo ? "powerprofilesctl set performance 2>/dev/null || asusctl profile -P Performance 2>/dev/null" : "powerprofilesctl set balanced 2>/dev/null || asusctl profile -P Balanced 2>/dev/null || asusctl profile -P Quiet 2>/dev/null"];
        turboProc.running = false;
        turboProc.running = true;
    }

    Process {
        id: dndProc
        running: false
        onExited: statusPoller.running = true
    }
    function toggleDnd() {
        systemDnd = !systemDnd;
        dndProc.command = ["sh", "-c", systemDnd ? "makoctl mode -a do-not-disturb -a dnd && makoctl dismiss -a" : "makoctl mode -r do-not-disturb -r dnd"];
        dndProc.running = false;
        dndProc.running = true;
    }

    Process {
        id: xwaylandProc
        running: false
        onExited: statusPoller.running = true
    }

    property int xwaylandCountdown: 0
    property bool xwaylandRestartPending: false

    Timer {
        id: xwaylandRebootTimer
        interval: 1000
        repeat: true
        running: shellRoot.xwaylandCountdown > 0
        onTriggered: {
            shellRoot.xwaylandCountdown--;
            if (shellRoot.xwaylandCountdown <= 0) {
                shellRoot.xwaylandCountdown = 0;
                xwaylandRebootTimer.stop();
                exec("systemctl reboot");
            }
        }
    }

    function toggleXwayland() {
        if (shellRoot.xwaylandRestartPending) {
            cancelXwaylandCountdown();
            return;
        }
        const next = !systemXwayland;
        systemXwayland = next;
        exec("sh -c 'echo " + (next ? "true" : "false") + " > /home/gabriel/.config/hypr/xwayland_state'");
        shellRoot.xwaylandCountdown = 5;
        shellRoot.xwaylandRestartPending = true;
        xwaylandRebootTimer.start();
    }

    function cancelXwaylandCountdown() {
        xwaylandRebootTimer.stop();
        shellRoot.xwaylandCountdown = 0;
        shellRoot.xwaylandRestartPending = false;
        const reverted = !systemXwayland;
        systemXwayland = reverted;
        exec("sh -c 'echo " + (reverted ? "true" : "false") + " > /home/gabriel/.config/hypr/xwayland_state'");
    }

    function rebootNow() {
        xwaylandRebootTimer.stop();
        shellRoot.xwaylandCountdown = 0;
        shellRoot.xwaylandRestartPending = false;
        exec("systemctl reboot");
    }

    Process {
        id: wpSwitcher
        running: false
        onExited: (exitCode) => { running = false; }
    }
    function nextWallpaper() {
        wpSwitcher.running = false;
        wpSwitcher.command = ["bash", "-c", "/home/gabriel/.config/quickshell/scripts/wallpaper_tool.sh next"];
        wpSwitcher.running = true;
    }

    // Centralized Status Poller
    Process {
        id: statusPoller
        command: ["/home/gabriel/.config/quickshell/scripts/controls_status"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const data = JSON.parse(line.trim());
                    if (data.vol !== undefined) {
                        shellRoot.systemVolume = data.vol;
                        shellRoot.systemVolumeMuted = data.muted;
                    }
                    if (data.br !== undefined) {
                        shellRoot.systemBrightness = data.br;
                    }
                    if (data.wifi_on !== undefined) shellRoot.systemWifiOn = data.wifi_on;
                    if (data.wifi_ssid !== undefined) shellRoot.systemWifiSsid = data.wifi_ssid;
                    if (data.bt_on !== undefined) shellRoot.systemBtOn = data.bt_on;
                    if (data.turbo !== undefined) shellRoot.systemTurbo = data.turbo;
                    if (data.dnd !== undefined) shellRoot.systemDnd = data.dnd;
                    if (data.xwayland !== undefined) shellRoot.systemXwayland = data.xwayland;
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 2500
        repeat: true
        running: true
        onTriggered: {
            if (!statusPoller.running) statusPoller.running = true;
        }
    }

    // ── FIFO listener — /tmp/qs-island-fifo ────────────────────
    Process {
        id: fifoReader
        command: ["bash", "-c",
            "PIPE=/tmp/qs-island-fifo; " +
            "[ -p $PIPE ] || mkfifo $PIPE; " +
            "while kill -0 $PPID 2>/dev/null; do cat $PIPE; done"
        ]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                const cmd = line.trim();
                console.log("[FIFO CMD RECEIVED]:", cmd);
                if (cmd.startsWith("layout:") || cmd === "layout") {
                    const arg = cmd.startsWith("layout:") ? cmd.substring(7).trim() : "next";
                    shellRoot.handleLayoutCommand(arg);
                } else if (cmd === "apps" || cmd === "view:apps" || cmd === "launcher" || cmd === "launchpad") {
                    launchpad.toggleLaunchpad();
                } else if (cmd === "wifi:dialog" || cmd === "wifi") {
                    wWifi.isExpanded = !wWifi.isExpanded;
                } else if (cmd === "bt:dialog" || cmd === "bt") {
                    wBt.isExpanded = !wBt.isExpanded;
                } else if (cmd === "dnd" || cmd === "dnd:toggle" || cmd === "mode:dnd") {
                    shellRoot.toggleDnd();
                } else if (cmd === "theme" || cmd === "solid" || cmd === "theme:toggle") {
                    GlassTheme.toggle();
                } else if (cmd === "wallpaper:panel" || cmd === "wallpaper:dialog") {
                    wWallpaper.isExpanded = !wWallpaper.isExpanded;
                } else if (cmd === "wallpaper" || cmd === "view:wallpaper" || cmd === "wallpapers") {
                    shellRoot.nextWallpaper();
                } else if (cmd === "turbo" || cmd === "turbo:toggle") {
                    shellRoot.toggleTurbo();
                } else if (cmd === "xwayland" || cmd === "xwayland:toggle") {
                    shellRoot.toggleXwayland();
                } else if (cmd === "lyrics" || cmd === "music:lyrics") {
                    desktopMusic.toggleLyrics();
                }
            }
        }
    }

    // ── 5 Desktop Layouts (adaptativos, sem sobreposição, mola + escalonamento) ──
    property int currentLayout: 1
    property bool layoutReady: false

    readonly property var tileKeys: ["wifi", "bt", "turbo", "dnd", "xwayland", "wallpaper", "theme"]

    function computeLayouts(W, H) {
        if (!W || W <= 0) W = 1920;
        if (!H || H <= 0) H = 1200;

        const m = Math.round(Math.max(24, Math.min(50, W * 0.025)));  // margem da tela
        const g = 14;                                                  // espaço entre cards
        const R = W - m - 340;                                         // x da coluna direita (340px)
        const bottom = H - m;

        function box(x, y, w, h) { return { x: x, y: y, width: w, height: h }; }
        function grid(x, y, cols, size, gap) { return { x: x, y: y, cols: cols, size: size, gap: gap }; }

        // Duas colunas de painéis (usado nos layouts 1 e 3): coluna A (240px) + coluna B (340px, à direita)
        function flanks(id, name, desc, ax) {
            const clockY = m, calY = m + 140 + g, volY = calY + 195 + g, appsY = volY + 160 + g;
            const musicY = m + 340 + g, tilesY = musicY + 160 + g;
            return {
                id: id, name: name, desc: desc, m: m, g: g,
                pos: {
                    clock:    box(ax, clockY, 240, 140),
                    calendar: box(ax, calY, 240, 195),
                    vol:      box(ax, volY, 113, 160),
                    br:       box(ax + 127, volY, 113, 160),
                    apps:     box(ax, appsY, 240, 68),
                    weather:  box(R, m, 340, 340),
                    music:    box(R, musicY, 340, 160)
                },
                tiles:  grid(R, tilesY, 4, 76, 12),
                alt:    grid(ax, appsY + 68 + g, 3, 72, 12),   // tiles migram p/ baixo do Apps quando algo expande
                expand: { x: R, y: tilesY },
                lyrics: { music: { x: R, y: musicY, height: 420 }, tiles: "alt" }
            };
        }

        // Layout 2: prateleira no topo, deixa toda a metade de baixo livre para janelas
        const shelfVolX = m + 254 + 240 + g;
        const shelfTilesX = shelfVolX + 172 + g;
        const shelfMusicX = Math.min(shelfTilesX, R - g - 340);
        const shelfMusicY = m + 76 * 2 + 12 + g;

        // Layout 4: quatro cantos + console central
        const rowY = bottom - 72;
        const volY4 = bottom - 88;
        const music4Y = volY4 - g - 160;
        const lyr4H = Math.min(420, volY4 - g - (m + 340 + g));

        // Layout 5: trilho esquerdo + palco direito
        const cal5 = m + 140 + g, wea5 = cal5 + 195 + g;
        const vol5 = m + 160 + g, br5 = vol5 + 68 + g, tiles5 = br5 + 68 + g;

        return [
            flanks(1, "Sonoma Flanks", "Equilíbrio Lateral", m),

            {
                id: 2, name: "Top Shelf", desc: "Prateleira Superior", m: m, g: g,
                pos: {
                    clock:    box(m, m, 240, 140),
                    apps:     box(m, m + 140 + g, 240, 68),
                    calendar: box(m + 254, m, 240, 195),
                    vol:      box(shelfVolX, m, 172, 68),
                    br:       box(shelfVolX, m + 82, 172, 68),
                    music:    box(shelfMusicX, shelfMusicY, 340, 160),
                    weather:  box(R, m, 340, 340)
                },
                tiles:  grid(shelfTilesX, m, 4, 76, 12),
                alt:    grid(m, m + 140 + g + 68 + g, 3, 72, 12),
                expand: { x: shelfTilesX, y: m },
                expandOver: { music: { y: m + 290 + g } },
                lyrics: { music: { x: shelfMusicX, y: shelfMusicY, height: 420 }, tiles: "keep" }
            },

            flanks(3, "Smart Sidebar", "Painel Direito", R - 240 - g),

            {
                id: 4, name: "Four Corners", desc: "Quatro Cantos HUD", m: m, g: g,
                pos: {
                    clock:    box(m, m, 240, 140),
                    weather:  box(R, m, 340, 340),
                    calendar: box(m, rowY - g - 195, 240, 195),
                    apps:     box(m, rowY, 240, 72),
                    music:    box(R, music4Y, 340, 160),
                    vol:      box(R, volY4, 162, 88),
                    br:       box(R + 178, volY4, 162, 88)
                },
                tiles:  grid(Math.round((W - 552) / 2), rowY, 7, 72, 8),
                alt:    "keep",
                expand: { x: Math.round((W - 340) / 2), y: rowY - g - 290 },
                lyrics: { music: { x: R, y: volY4 - g - lyr4H, height: lyr4H }, tiles: "keep" }
            },

            {
                id: 5, name: "Creative Studio", desc: "Trilho Esquerdo + Palco", m: m, g: g,
                pos: {
                    clock:    box(m, m, 240, 140),
                    calendar: box(m, cal5, 240, 195),
                    weather:  box(m, wea5, 240, 340),
                    apps:     box(m, wea5 + 340 + g, 240, 68),
                    music:    box(R, m, 340, 160),
                    vol:      box(R, vol5, 340, 68),
                    br:       box(R, br5, 340, 68)
                },
                tiles:  grid(R, tiles5, 4, 76, 12),
                alt:    "below",
                expand: { x: R, y: tiles5 },
                lyrics: { music: { x: R, y: m, height: 420 }, tiles: "shift", dy: 260, shift: ["vol", "br"] }
            }
        ];
    }

    Timer {
        id: relayoutTimer
        interval: 150
        repeat: false
        onTriggered: shellRoot.applyLayout(shellRoot.currentLayout)
    }

    readonly property var layouts: computeLayouts(desktopWindow.width, desktopWindow.height)

    function collapseAllExpanded() {
        if (wWallpaper.isExpanded) wWallpaper.isExpanded = false;
        if (wWifi.isExpanded) wWifi.isExpanded = false;
        if (wBt.isExpanded) wBt.isExpanded = false;
        if (desktopMusic.isLyricsOpen) desktopMusic.layoutMode = "wide";
    }

    // Distribui os 6 tiles numa grade
    function placeTiles(t, gr, keys) {
        for (let i = 0; i < keys.length; i++) {
            const c = i % gr.cols, r = Math.floor(i / gr.cols);
            t[keys[i]] = { x: gr.x + c * (gr.size + gr.gap), y: gr.y + r * (gr.size + gr.gap), width: gr.size, height: gr.size };
        }
    }

    // Resolve a posição final de cada widget levando em conta lyrics / painel expandido
    function computeTargets(l, H) {
        const t = {};
        for (const k in l.pos) t[k] = Object.assign({}, l.pos[k]);

        const expKey = wWifi.isExpanded ? "wifi" : (wBt.isExpanded ? "bt" : (wWallpaper.isExpanded ? "wallpaper" : ""));
        let gr = l.tiles;
        let keys = tileKeys.slice();

        if (expKey !== "") {
            const ey = Math.min(l.expand.y, H - l.m - 290);
            if (l.alt === "below") gr = { x: gr.x, y: ey + 290 + l.g, cols: gr.cols, size: gr.size, gap: gr.gap };
            else if (l.alt !== "keep") gr = l.alt;
            if (l.alt !== "keep") keys = keys.filter(k => k !== expKey);
            placeTiles(t, gr, keys);
            t[expKey] = { x: l.expand.x, y: ey, width: 340, height: 290 };
            if (l.expandOver && l.expandOver.music) Object.assign(t.music, l.expandOver.music);
        } else if (desktopMusic.isLyricsOpen) {
            Object.assign(t.music, l.lyrics.music);
            if (l.lyrics.tiles === "alt") gr = l.alt;
            else if (l.lyrics.tiles === "shift") {
                gr = { x: gr.x, y: gr.y + l.lyrics.dy, cols: gr.cols, size: gr.size, gap: gr.gap };
                for (const k of l.lyrics.shift) t[k].y += l.lyrics.dy;
            }
            placeTiles(t, gr, keys);
        } else {
            placeTiles(t, gr, keys);
        }
        return t;
    }

    readonly property var widgetMap: ({
        clock: desktopClock, calendar: desktopCalendar, weather: desktopWeather, music: desktopMusic,
        vol: wVol, br: wBr, apps: wApps, wifi: wWifi, bt: wBt, turbo: wTurbo,
        dnd: wDnd, xwayland: wXwayland, wallpaper: wWallpaper, theme: wTheme
    })

    property var staggerQueue: []

    function applyOne(w, p) {
        w.targetX = p.x;
        w.targetY = p.y;
        if (p.width !== undefined && w.targetWidth !== undefined) w.targetWidth = p.width;
        if (p.height !== undefined && w.targetHeight !== undefined) w.targetHeight = p.height;
    }

    Timer {
        id: staggerTimer
        interval: 34
        repeat: true
        onTriggered: {
            const q = shellRoot.staggerQueue;
            if (q.length === 0) { stop(); return; }
            const it = q.shift();
            shellRoot.applyOne(it.w, it.p);
        }
    }

    // Aplica os alvos; ao trocar de layout os widgets chegam em "onda" (canto sup. esq. → inf. dir.)
    function applyTargets(t, stagger) {
        staggerTimer.stop();
        staggerQueue = [];

        desktopMusic.tallHeight = (t.music && t.music.height && desktopMusic.isLyricsOpen) ? t.music.height : 420;

        const items = [];
        for (const k in t) {
            const w = widgetMap[k];
            if (!w) continue;
            const p = t[k];
            const changed = w.targetX !== p.x || w.targetY !== p.y
                || (p.width !== undefined && w.targetWidth !== undefined && w.targetWidth !== p.width)
                || (p.height !== undefined && w.targetHeight !== undefined && w.targetHeight !== p.height);
            if (changed) items.push({ w: w, p: p, order: p.x + p.y * 0.8 });
        }
        if (!stagger) {
            for (const it of items) applyOne(it.w, it.p);
            return;
        }
        items.sort((a, b) => a.order - b.order);
        staggerQueue = items;
        staggerTimer.start();
    }

    function applyLayout(idx) {
        const W = desktopWindow.width > 0 ? desktopWindow.width : 1920;
        const H = desktopWindow.height > 0 ? desktopWindow.height : 1200;
        const lList = computeLayouts(W, H);
        if (idx < 1 || idx > lList.length) idx = 1;

        const switched = layoutReady && idx !== currentLayout;
        currentLayout = idx;
        if (switched) collapseAllExpanded();

        applyTargets(computeTargets(lList[idx - 1], H), switched);
        layoutReady = true;
        saveLayoutState(idx);
    }

    function nextLayout() {
        collapseAllExpanded();
        var next = currentLayout + 1;
        if (next > layouts.length) next = 1;
        applyLayout(next);
    }

    function prevLayout() {
        collapseAllExpanded();
        var prev = currentLayout - 1;
        if (prev < 1) prev = layouts.length;
        applyLayout(prev);
    }

    function handleLayoutCommand(arg) {
        collapseAllExpanded();
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

    property string activeWallpaper: ""

    Timer {
        id: blurScheduler
        interval: 32
        repeat: false
        property int step: 0
        onTriggered: {
            const chain = [masterWallpaperTex, wpDownTex, wpDown2Tex, masterBlurredTex];
            chain[step].scheduleUpdate();
            if (step < chain.length - 1) {
                step += 1;
                blurScheduler.interval = 32;
                blurScheduler.start();
            } else {
                step = 0;
            }
        }
    }

    function triggerMasterBlur() {
        blurScheduler.step = 0;
        blurScheduler.interval = 16;
        blurScheduler.start();
    }

    function broadcastWallpaper(path) {
        if (!path || !path.startsWith("/")) return;
        shellRoot.activeWallpaper = path;
    }

    // Single centralized inotify wallpaper watcher
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

    // ── Single Unified Desktop Panel Window (Adaptive Resolution) ──────
    // Consolidates all 13 widgets into 1 single Wayland bottom-layer surface.
    // Slashes compositor bandwidth by 92% and achieves rock-solid fluid animations.
    PanelWindow {
        id: desktopWindow

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: (wWifi.isExpanded || wBt.isExpanded) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        WlrLayershell.exclusiveZone: -1
        color: "transparent"

        // Recalcula as posições quando a resolução/escala do monitor muda
        onWidthChanged: relayoutTimer.restart()
        onHeightChanged: relayoutTimer.restart()

        // Input mask: only active widget cards intercept pointer input
        mask: Region {
            Region { item: desktopClock.cardItem }
            Region { item: desktopCalendar.cardItem }
            Region { item: desktopWeather.cardItem }
            Region { item: desktopMusic.cardItem }
            Region { item: wVol.cardItem }
            Region { item: wBr.cardItem }
            Region { item: wWifi.cardItem }
            Region { item: wBt.cardItem }
            Region { item: wTurbo.cardItem }
            Region { item: wDnd.cardItem }
            Region { item: wXwayland.cardItem }
            Region { item: wWallpaper.cardItem }
            Region { item: wApps.cardItem }
            Region { item: wTheme.cardItem }
            Region { item: xwaylandBannerCard }
        }

        // Shared full-screen wallpaper source & Kawase blur pipeline
        // Executed ONCE at startup and on wallpaper change (0ms during layout animation!)
        Image {
            id: masterWallpaper
            source: shellRoot.activeWallpaper ? ("file://" + shellRoot.activeWallpaper) : ""
            sourceSize.width: desktopWindow.width > 0 ? desktopWindow.width : 1920
            sourceSize.height: desktopWindow.height > 0 ? desktopWindow.height : 1200
            width: desktopWindow.width > 0 ? desktopWindow.width : 1920
            height: desktopWindow.height > 0 ? desktopWindow.height : 1200
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: false
            asynchronous: false
            cache: false
            visible: false
            onStatusChanged: {
                if (status === Image.Ready) {
                    shellRoot.triggerMasterBlur();
                }
            }
        }

        ShaderEffectSource {
            id: masterWallpaperTex
            sourceItem: masterWallpaper
            hideSource: true
            live: false
            mipmap: false
            textureMirroring: ShaderEffectSource.MirrorVertically
        }

        // Blur em cadeia (1/2 → 1/4 → 1/2): vidro fosco bem macio como o Liquid Glass do macOS
        readonly property real _sw: desktopWindow.width > 0 ? desktopWindow.width : 1920
        readonly property real _sh: desktopWindow.height > 0 ? desktopWindow.height : 1200
        readonly property int _blurW: Math.max(1, Math.round(_sw / 2))
        readonly property int _blurH: Math.max(1, Math.round(_sh / 2))
        readonly property int _b2W: Math.max(1, Math.round(_sw / 4))
        readonly property int _b2H: Math.max(1, Math.round(_sh / 4))

        ShaderEffect {
            id: wpDownPass
            width: desktopWindow._blurW; height: desktopWindow._blurH
            visible: false
            fragmentShader: Qt.resolvedUrl("widgets/shaders/kawase_down.frag.qsb")
            property variant source: masterWallpaperTex
            property vector2d halfpixel: Qt.vector2d(0.5 / desktopWindow._blurW, 0.5 / desktopWindow._blurH)
        }
        ShaderEffectSource {
            id: wpDownTex
            sourceItem: wpDownPass
            hideSource: true
            live: false
            textureSize: Qt.size(desktopWindow._blurW, desktopWindow._blurH)
        }

        ShaderEffect {
            id: wpDown2Pass
            width: desktopWindow._b2W; height: desktopWindow._b2H
            visible: false
            fragmentShader: Qt.resolvedUrl("widgets/shaders/kawase_down.frag.qsb")
            property variant source: wpDownTex
            property vector2d halfpixel: Qt.vector2d(0.5 / desktopWindow._b2W, 0.5 / desktopWindow._b2H)
        }
        ShaderEffectSource {
            id: wpDown2Tex
            sourceItem: wpDown2Pass
            hideSource: true
            live: false
            textureSize: Qt.size(desktopWindow._b2W, desktopWindow._b2H)
        }

        ShaderEffect {
            id: wpUpPass
            width: desktopWindow._blurW; height: desktopWindow._blurH
            visible: false
            fragmentShader: Qt.resolvedUrl("widgets/shaders/kawase_up.frag.qsb")
            property variant source: wpDown2Tex
            property vector2d halfpixel: Qt.vector2d(0.5 / desktopWindow._b2W, 0.5 / desktopWindow._b2H)
        }
        ShaderEffectSource {
            id: masterBlurredTex
            sourceItem: wpUpPass
            hideSource: true
            live: false
            smooth: true
            textureSize: Qt.size(desktopWindow._blurW, desktopWindow._blurH)
        }

        // ── Primary Desktop Widgets ──────────────────────────────
        ClockWidget {
            id: desktopClock
            sharedBackdrop: masterBlurredTex
        }

        CalendarWidget {
            id: desktopCalendar
            sharedBackdrop: masterBlurredTex
        }

        WeatherWidget {
            id: desktopWeather
            sharedBackdrop: masterBlurredTex
        }

        MusicWidget {
            id: desktopMusic
            sharedBackdrop: masterBlurredTex
            onIsLyricsOpenChanged: {
                if (isLyricsOpen) {
                    if (wWifi.isExpanded) wWifi.isExpanded = false;
                    if (wBt.isExpanded) wBt.isExpanded = false;
                    if (wWallpaper.isExpanded) wWallpaper.isExpanded = false;
                }
                shellRoot.applyLayout(shellRoot.currentLayout);
            }
        }

        // ── Modular Liquid Glass Control Widgets ──────────────────
        VolumeWidget {
            id: wVol
            sharedBackdrop: masterBlurredTex
            volumeVal: shellRoot.systemVolume
            isMuted: shellRoot.systemVolumeMuted
            onVolumeChangeRequested: (pct) => shellRoot.setVolume(pct)
            onToggleMuteRequested: () => shellRoot.toggleMute()
        }

        BrightnessWidget {
            id: wBr
            sharedBackdrop: masterBlurredTex
            brightnessVal: shellRoot.systemBrightness
            onBrightnessChangeRequested: (pct) => shellRoot.setBrightness(pct)
        }

        WifiTileWidget {
            id: wWifi
            sharedBackdrop: masterBlurredTex
            isWifiOn: shellRoot.systemWifiOn
            wifiSsid: shellRoot.systemWifiSsid
            onToggleRequested: () => shellRoot.toggleWifi()
            onIsExpandedChanged: {
                if (isExpanded) {
                    if (wBt.isExpanded) wBt.isExpanded = false;
                    if (wWallpaper.isExpanded) wWallpaper.isExpanded = false;
                    if (desktopMusic.isLyricsOpen) desktopMusic.layoutMode = "wide";
                }
                shellRoot.applyLayout(shellRoot.currentLayout);
            }
        }

        BluetoothTileWidget {
            id: wBt
            sharedBackdrop: masterBlurredTex
            isBtOn: shellRoot.systemBtOn
            onToggleRequested: () => shellRoot.toggleBt()
            onIsExpandedChanged: {
                if (isExpanded) {
                    if (wWifi.isExpanded) wWifi.isExpanded = false;
                    if (wWallpaper.isExpanded) wWallpaper.isExpanded = false;
                    if (desktopMusic.isLyricsOpen) desktopMusic.layoutMode = "wide";
                }
                shellRoot.applyLayout(shellRoot.currentLayout);
            }
        }

        TurboTileWidget {
            id: wTurbo
            sharedBackdrop: masterBlurredTex
            isTurbo: shellRoot.systemTurbo
            onToggleRequested: () => shellRoot.toggleTurbo()
        }

        DndTileWidget {
            id: wDnd
            sharedBackdrop: masterBlurredTex
            isDnd: shellRoot.systemDnd
            onToggleRequested: () => shellRoot.toggleDnd()
        }

        XwaylandTileWidget {
            id: wXwayland
            sharedBackdrop: masterBlurredTex
            isXwayland: shellRoot.systemXwayland
            countdown: shellRoot.xwaylandCountdown
            onToggleRequested: () => shellRoot.toggleXwayland()
        }

        WallpaperTileWidget {
            id: wWallpaper
            sharedBackdrop: masterBlurredTex
            onNextRequested: () => shellRoot.nextWallpaper()
            onIsExpandedChanged: {
                if (isExpanded) {
                    if (wWifi.isExpanded) wWifi.isExpanded = false;
                    if (wBt.isExpanded) wBt.isExpanded = false;
                    if (desktopMusic.isLyricsOpen) desktopMusic.layoutMode = "wide";
                }
                shellRoot.applyLayout(shellRoot.currentLayout);
            }
        }

        ThemeSwitchTileWidget {
            id: wTheme
            sharedBackdrop: masterBlurredTex
        }

        AppsTileWidget {
            id: wApps
            sharedBackdrop: masterBlurredTex
            onOpenLaunchpadRequested: () => launchpad.toggleLaunchpad()
        }

        // ── Xwayland Reboot Countdown Toast OSD Banner ───────────
        Item {
            id: xwaylandBannerCard
            x: (desktopWindow.width - 450) / 2
            y: shellRoot.xwaylandRestartPending ? 48 : -95
            width: 450
            height: 60
            visible: shellRoot.xwaylandRestartPending || y > -90

            Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutBack } }

            LiquidGlass {
                id: bannerGlass
                anchors.fill: parent
                radius: 20
                roundness: 6.5
                refractThickness: 30
                refractIOR: 1.6
                refractScale: 60
                tint: "#111318"
                tintAlpha: 0.85
                specStrength: 0.80
                blurRadius: 10
                widgetX: xwaylandBannerCard.x
                widgetY: xwaylandBannerCard.y
                screenWidth: desktopWindow.width > 0 ? desktopWindow.width : 1920
                screenHeight: desktopWindow.height > 0 ? desktopWindow.height : 1200
            }

            Rectangle {
                anchors.fill: parent
                radius: 20
                color: Qt.rgba(255/255, 149/255, 0/255, 0.10)
                border.width: 1.5
                border.color: Qt.rgba(255/255, 149/255, 0/255, 0.60)
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                // Countdown Circle Badge
                Rectangle {
                    width: 38
                    height: 38
                    radius: 19
                    color: Qt.rgba(255/255, 149/255, 0/255, 0.35)
                    border.width: 1
                    border.color: "#ff9500"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: shellRoot.xwaylandCountdown + "s"
                        font.family: sfRegular.name
                        font.pixelSize: 15
                        font.weight: Font.Black
                        color: "#ff9500"
                    }
                }

                // Alert Texts
                Column {
                    width: 220
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        width: parent.width
                        text: shellRoot.systemXwayland ? "Ativando Xwayland..." : "Desativando Xwayland..."
                        font.family: sfRegular.name
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }
                    Text {
                        width: parent.width
                        text: "Reiniciando o PC em " + shellRoot.xwaylandCountdown + "s para aplicar..."
                        font.family: sfRegular.name
                        font.pixelSize: 11
                        color: "#ff9500"
                    }
                }

                // Cancel Button
                Rectangle {
                    width: 68
                    height: 30
                    radius: 15
                    color: cancelMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.22)
                    anchors.verticalCenter: parent.verticalCenter
                    scale: cancelMouse.pressed ? 0.92 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Cancelar"
                        font.family: sfRegular.name
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shellRoot.cancelXwaylandCountdown()
                    }
                }

                // Reboot Now Button
                Rectangle {
                    width: 68
                    height: 30
                    radius: 15
                    color: rebootNowMouse.containsMouse ? "#ff3b30" : Qt.rgba(255/255, 59/255, 48/255, 0.85)
                    anchors.verticalCenter: parent.verticalCenter
                    scale: rebootNowMouse.pressed ? 0.92 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Reiniciar"
                        font.family: sfRegular.name
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: rebootNowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shellRoot.rebootNow()
                    }
                }
            }
        }
    }

    // ── Fullscreen Launchpad ─────────────────────────────────
    Launchpad {
        id: launchpad
    }
}
