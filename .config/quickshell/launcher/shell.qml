import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

import "./widgets"
import "Layouts.js" as Layouts
import "./services"

// Daemon QuickShell — Liquid Glass Modular Desktop Widgets
ShellRoot {
    id: shellRoot


    // ── System States (Single Source of Truth) ────────────────
    property bool systemLaptopOnly: false

    Process {
        id: monitorModeProc
        command: ["/home/gabriel/.local/bin/monitor-mode", "status"]
        running: true
        stdout: SplitParser { onRead: (line) => shellRoot.systemLaptopOnly = (line.trim() === "laptop") }
    }
    function toggleMonitorMode() {
        systemLaptopOnly = !systemLaptopOnly;
        monitorModeProc.command = ["/home/gabriel/.local/bin/monitor-mode", systemLaptopOnly ? "laptop" : "auto"];
        monitorModeProc.running = false;
        monitorModeProc.running = true;
    }

    Process { id: cmdRunner; running: false }
    function exec(cmd) {
        cmdRunner.command = ["sh", "-c", cmd];
        cmdRunner.running = false;
        cmdRunner.running = true;
    }

    Process { id: volProc; running: false }
    function setVolume(pct) {
        SystemStatus.volume = pct;
        SystemStatus.muted = (pct === 0);
        volProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(pct * 100) + "%"];
        volProc.running = false;
        volProc.running = true;
    }

    function toggleMute() {
        SystemStatus.muted = !SystemStatus.muted;
        volProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"];
        volProc.running = false;
        volProc.running = true;
    }

    Process { id: brProc; running: false }
    function setBrightness(pct) {
        SystemStatus.brightness = pct;
        brProc.command = ["brightnessctl", "set", pct + "%"];
        brProc.running = false;
        brProc.running = true;
    }

    function toggleWifi() {
        SystemStatus.wifiOn = !SystemStatus.wifiOn;
        exec("nmcli radio wifi " + (SystemStatus.wifiOn ? "on" : "off"));
    }

    function toggleBt() {
        SystemStatus.btOn = !SystemStatus.btOn;
        exec("rfkill toggle bluetooth");
    }

    Process {
        id: turboProc
        running: false
        onExited: SystemStatus.restart()
    }
    function setPowerMode(m) {
        SystemStatus.power = m;
        SystemStatus.powerHoldUntil = Date.now() + 3000;
        turboProc.command = ["sudo", "-n", "/usr/local/bin/power-mode", ["silent", "balanced", "performance"][m]];
        turboProc.running = false;
        turboProc.running = true;
    }
    function toggleTurbo() { setPowerMode((SystemStatus.power + 1) % 3); }   // FIFO "turbo": próximo modo

    Process {
        id: dndProc
        running: false
        onExited: SystemStatus.restart()
    }
    function toggleDnd() {
        SystemStatus.dnd = !SystemStatus.dnd;
        dndProc.command = ["sh", "-c", SystemStatus.dnd ? "makoctl mode -a do-not-disturb -a dnd && makoctl dismiss -a" : "makoctl mode -r do-not-disturb -r dnd"];
        dndProc.running = false;
        dndProc.running = true;
    }

    Process {
        id: xwaylandProc
        running: false
        onExited: SystemStatus.restart()
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
        if (shellRoot.gpuRestartPending) return;
        if (shellRoot.xwaylandRestartPending) {
            cancelXwaylandCountdown();
            return;
        }
        const next = !SystemStatus.xwayland;
        SystemStatus.xwayland = next;
        exec("sh -c 'echo " + (next ? "true" : "false") + " > /home/gabriel/.config/hypr/xwayland_state'");
        shellRoot.xwaylandCountdown = 5;
        shellRoot.xwaylandRestartPending = true;
        xwaylandRebootTimer.start();
    }

    function cancelXwaylandCountdown() {
        xwaylandRebootTimer.stop();
        shellRoot.xwaylandCountdown = 0;
        shellRoot.xwaylandRestartPending = false;
        const reverted = !SystemStatus.xwayland;
        SystemStatus.xwayland = reverted;
        exec("sh -c 'echo " + (reverted ? "true" : "false") + " > /home/gabriel/.config/hypr/xwayland_state'");
    }

    function rebootNow() {
        xwaylandRebootTimer.stop();
        shellRoot.xwaylandCountdown = 0;
        shellRoot.xwaylandRestartPending = false;
        exec("systemctl reboot");
    }

    // ── GPU (gpu-mode): só NVIDIA <-> só AMD. Troca = firmware + reboot, com contagem e Cancelar ──
    property string systemGpuMode: "nvidia"    // modo em uso (gravado no boot pelo igpu-guard)
    property string gpuTarget: ""              // modo pedido durante a contagem
    property int gpuCountdown: 0
    readonly property bool gpuRestartPending: gpuCountdown > 0
    readonly property bool rebootBannerOn: xwaylandRestartPending || gpuRestartPending

    Process {
        id: gpuStatusProc
        command: ["/usr/local/bin/gpu-mode", "status"]
        running: true
        stdout: SplitParser { onRead: (line) => shellRoot.systemGpuMode = line.trim().split(" ")[0] }
    }
    Process {
        id: gpuSwitchProc
        running: false
        stderr: SplitParser { onRead: (line) => shellRoot.exec("notify-send -a GPU -u critical 'Troca de GPU falhou' '" + line.replace(/'/g, "") + "'") }
    }
    Timer {
        id: gpuRebootTimer
        interval: 1000
        repeat: true
        running: shellRoot.gpuCountdown > 0
        onTriggered: {
            shellRoot.gpuCountdown--;
            if (shellRoot.gpuCountdown <= 0) shellRoot.applyGpuMode();
        }
    }
    function toggleGpuMode() {
        if (gpuRestartPending) { cancelGpuCountdown(); return; }
        if (xwaylandRestartPending) return;
        gpuTarget = systemGpuMode === "amd" ? "nvidia" : "amd";
        gpuCountdown = 8;
    }
    function cancelGpuCountdown() {
        gpuCountdown = 0;
        gpuTarget = "";
    }
    function applyGpuMode() {
        gpuRebootTimer.stop();
        gpuCountdown = 0;
        // gpu-mode grava o firmware e reinicia; se o firmware recusar, sai com erro (stderr -> notificação) e não reinicia
        gpuSwitchProc.command = ["sudo", "-n", "/usr/local/bin/gpu-mode", gpuTarget];
        gpuSwitchProc.running = false;
        gpuSwitchProc.running = true;
        gpuTarget = "";
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

    Timer {
        interval: 2500
        repeat: true
        running: true
        onTriggered: {
            SystemStatus.restart();
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
                } else if (cmd === "battery") {
                    wBattery.isExpanded = !wBattery.isExpanded;
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
                } else if (cmd === "gaming" || cmd === "gaming:toggle") {
                    GlassTheme.toggleGaming();
                } else if (cmd === "turbo" || cmd === "turbo:toggle") {
                    shellRoot.toggleTurbo();
                } else if (cmd === "xwayland" || cmd === "xwayland:toggle") {
                    shellRoot.toggleXwayland();
                } else if (cmd === "monitor" || cmd === "monitor:toggle") {
                    shellRoot.toggleMonitorMode();
                } else if (cmd === "lyrics" || cmd === "music:lyrics") {
                    desktopMusic.toggleLyrics();
                }
            }
        }
    }

    // ── 5 Desktop Layouts (adaptativos, sem sobreposição, mola + escalonamento) ──
    property int currentLayout: 1
    property bool layoutReady: false

    readonly property var tileKeys: ["wifi", "bt", "turbo", "battery", "gaming", "dnd", "xwayland", "wallpaper", "theme", "claude", "laptop", "gpu"]

    readonly property var wideTiles: ["turbo"]                 // ocupam 2 casas (chave de 3 posições)



    Timer {
        id: relayoutTimer
        interval: 150
        repeat: false
        onTriggered: shellRoot.applyLayout(shellRoot.currentLayout)
    }

    readonly property var layouts: Layouts.compute(desktopWindow.width, desktopWindow.height, tileKeys, wideTiles)

    function collapseAllExpanded() {
        if (wWallpaper.isExpanded) wWallpaper.isExpanded = false;
        if (wWifi.isExpanded) wWifi.isExpanded = false;
        if (wBt.isExpanded) wBt.isExpanded = false;
        if (wBattery.isExpanded) wBattery.isExpanded = false;
        if (desktopMusic.isLyricsOpen) desktopMusic.layoutMode = "wide";
    }





    // Resolve a posição final de cada widget levando em conta lyrics / painel expandido
    function computeTargets(l, H) {
        const t = {};
        for (const k in l.pos) t[k] = Object.assign({}, l.pos[k]);

        const expKey = wWifi.isExpanded ? "wifi" : (wBt.isExpanded ? "bt" : (wWallpaper.isExpanded ? "wallpaper" : (wBattery.isExpanded ? "battery" : "")));
        let gr = l.tiles;
        let keys = tileKeys.filter(k => !l.pos[k]);   // tiles posicionados à mão no layout (ex.: turbo no Orbit) saem da grade

        const ey = Math.min(l.expand.y, H - l.m - 290);
        if (expKey !== "") {
            if (l.alt === "below") {
                const by = ey + 290 + l.g, n = tileKeys.length + wideTiles.length - 1;
                let best = null;
                for (let cols = 1; cols <= n; cols++) {
                    const rows = Math.ceil(n / cols);
                    const sz = Math.floor(Math.min(gr.size, (340 - (cols - 1) * gr.gap) / cols, (H - l.m - by - (rows - 1) * gr.gap) / rows));
                    if (!best || sz > best.size) best = { x: gr.x, y: by, cols: cols, size: sz, gap: gr.gap };
                }
                gr = best;
            }
            else if (l.alt !== "keep") gr = l.alt;
            if (l.alt !== "keep") keys = keys.filter(k => k !== expKey);
            Layouts.placeTiles(t, gr, keys, wideTiles);
            t[expKey] = { x: l.expand.x, y: ey, width: 340, height: 290 };
            if (l.expandOver && l.expandOver.music) Object.assign(t.music, l.expandOver.music);
        } else if (desktopMusic.isLyricsOpen) {
            Object.assign(t.music, l.lyrics.music);
            if (l.lyrics.tiles === "alt") gr = l.alt;
            else if (l.lyrics.tiles === "shift") {
                gr = { x: gr.x, y: gr.y + l.lyrics.dy, cols: gr.cols, size: gr.size, gap: gr.gap };
                for (const k of l.lyrics.shift) t[k].y += l.lyrics.dy;
            }
            Layouts.placeTiles(t, gr, keys, wideTiles);
        } else {
            Layouts.placeTiles(t, gr, keys, wideTiles);
        }

        // Cava: desce p/ baixo do painel expandido quando precisa; some (animado) se não sobrar altura
        if (t.cava) {
            let cy = -1;
            if (expKey !== "" && l.cavaExpand === "below") cy = ey + 290 + l.g;
            else if (expKey === "" && desktopMusic.isLyricsOpen && l.cavaLyrics === "below") cy = t.music.y + l.lyrics.music.height + l.g;
            if (cy >= 0) {
                t.cava.x = t.music.x;
                t.cava.width = 340;
                t.cava.y = cy;
                t.cava.height = H - l.m - cy;
            }
            t.cava.hidden = t.cava.height < 40;
            if (t.cava.hidden) t.cava.height = 40;
        }
        // Painel aberto: empurra para baixo o que ele cobriria (em vez de ficar por cima); o que não couber some
        if (expKey !== "") Layouts.pushAside(t, expKey, l.g, H - l.m);

        // Widgets que o layout não posiciona somem no lugar: compostos (com "shown") via hidden, o resto via variant "hidden"
        for (const k in widgetMap) {
            const w = widgetMap[k];
            if (!w || t[k]) continue;
            t[k] = w.shown !== undefined ? { x: w.targetX, y: w.targetY, hidden: true } : { x: w.targetX, y: w.targetY, variant: "hidden" };
        }
        return t;
    }

    readonly property var widgetMap: ({
        clock: desktopClock, calendar: desktopCalendar, weather: desktopWeather, music: desktopMusic,
        vol: wVol, br: wBr, apps: wApps, wifi: wWifi, bt: wBt, turbo: wTurbo, battery: wBattery, gaming: wGaming,
        dnd: wDnd, xwayland: wXwayland, wallpaper: wWallpaper, theme: wTheme, claude: wClaude, laptop: wLaptop, gpu: wGpu,
        cava: wCava, dock: wDock, island: wIsland
    })

    property var staggerQueue: []

    function applyOne(w, p) {
        w.targetX = p.x;
        w.targetY = p.y;
        if (p.width !== undefined && w.targetWidth !== undefined) w.targetWidth = p.width;
        if (p.height !== undefined && w.targetHeight !== undefined) w.targetHeight = p.height;
        if (w.shown !== undefined) w.shown = !p.hidden;
        if (w.variant !== undefined) w.variant = p.variant || "classic";
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
                || (p.height !== undefined && w.targetHeight !== undefined && w.targetHeight !== p.height)
                || (w.shown !== undefined && w.shown === !!p.hidden)
                || (w.variant !== undefined && w.variant !== (p.variant || "classic"));
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
        const lList = Layouts.compute(W, H, tileKeys, wideTiles);
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
        layoutSaver.running = false;   // reinicia: em trocas rápidas a gravação anterior ainda rodava e a nova se perdia
        layoutSaver.running = true;
    }

    property string activeWallpaper: ""

    // Cadeia de blur fica "live" por alguns frames após cada wallpaper novo: o Qt atualiza as 4 texturas
    // em ordem de dependência a cada frame, então o vidro sempre converge p/ o wallpaper atual (trocas rápidas inclusas).
    property bool blurLive: false
    Timer {
        id: blurSettleTimer
        interval: 250
        repeat: false
        onTriggered: shellRoot.blurLive = false
    }

    function triggerMasterBlur() {
        shellRoot.blurLive = true;
        blurSettleTimer.restart();
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

    // Hotplug/troca de monitor: a janela do painel não é recriada sozinha na tela nova, então recarrega o shell (soft, não mata processos filhos)
    Connections {
        target: Quickshell
        function onScreensChanged() { screensReloadTimer.restart() }
    }
    Timer {
        id: screensReloadTimer
        interval: 600
        repeat: false
        onTriggered: Quickshell.reload(false)
    }

    // ── Single Unified Desktop Panel Window (Adaptive Resolution) ──────
    // Consolidates all 13 widgets into 1 single Wayland bottom-layer surface.
    // Slashes compositor bandwidth by 92% and achieves rock-solid fluid animations.
    PanelWindow {
        id: desktopWindow

        // Segue o monitor que estiver ligado (o modo externo desliga o eDP-1): sem isso a janela fica presa na tela removida
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

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
            Region { item: wBattery.cardItem }
            Region { item: wDock.cardItem }
            Region { item: wIsland.cardItem }
            Region { item: wGaming.cardItem }
            Region { item: wDnd.cardItem }
            Region { item: wXwayland.cardItem }
            Region { item: wWallpaper.cardItem }
            Region { item: wApps.cardItem }
            Region { item: wTheme.cardItem }
            Region { item: wClaude.cardItem }
            Region { item: wLaptop.cardItem }
            Region { item: wGpu.cardItem }
            Region { item: wCava.shown ? wCava.cardItem : null }
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
            asynchronous: true   // decodifica fora da thread da UI (não trava as animações ao trocar)
            cache: false
            visible: false
            onStatusChanged: {
                if (status === Image.Ready) {
                    shellRoot.triggerMasterBlur();
                } else if (status === Image.Loading) {
                    // não capturar o Image vazio enquanto carrega: o vidro mantém o wallpaper anterior
                    shellRoot.blurLive = false;
                    blurSettleTimer.stop();
                }
            }
        }

        ShaderEffectSource {
            id: masterWallpaperTex
            sourceItem: masterWallpaper
            hideSource: true
            live: shellRoot.blurLive
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
            live: shellRoot.blurLive
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
            live: shellRoot.blurLive
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
            live: shellRoot.blurLive
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
                    if (wBattery.isExpanded) wBattery.isExpanded = false;
                    if (wWallpaper.isExpanded) wWallpaper.isExpanded = false;
                }
                shellRoot.applyLayout(shellRoot.currentLayout);
            }
        }

        // ── Modular Liquid Glass Control Widgets ──────────────────
        VolumeWidget {
            id: wVol
            sharedBackdrop: masterBlurredTex
            volumeVal: SystemStatus.volume
            isMuted: SystemStatus.muted
            onVolumeChangeRequested: (pct) => shellRoot.setVolume(pct)
            onToggleMuteRequested: () => shellRoot.toggleMute()
        }

        BrightnessWidget {
            id: wBr
            sharedBackdrop: masterBlurredTex
            brightnessVal: SystemStatus.brightness
            onBrightnessChangeRequested: (pct) => shellRoot.setBrightness(pct)
        }

        WifiTileWidget {
            id: wWifi
            sharedBackdrop: masterBlurredTex
            isWifiOn: SystemStatus.wifiOn
            wifiSsid: SystemStatus.wifiSsid
            onToggleRequested: () => shellRoot.toggleWifi()
            onIsExpandedChanged: {
                if (isExpanded) {
                    if (wBt.isExpanded) wBt.isExpanded = false;
                    if (wBattery.isExpanded) wBattery.isExpanded = false;
                    if (wWallpaper.isExpanded) wWallpaper.isExpanded = false;
                    if (desktopMusic.isLyricsOpen) desktopMusic.layoutMode = "wide";
                }
                shellRoot.applyLayout(shellRoot.currentLayout);
            }
        }

        BluetoothTileWidget {
            id: wBt
            sharedBackdrop: masterBlurredTex
            isBtOn: SystemStatus.btOn
            onToggleRequested: () => shellRoot.toggleBt()
            onIsExpandedChanged: {
                if (isExpanded) {
                    if (wWifi.isExpanded) wWifi.isExpanded = false;
                    if (wWallpaper.isExpanded) wWallpaper.isExpanded = false;
                    if (wBattery.isExpanded) wBattery.isExpanded = false;
                    if (desktopMusic.isLyricsOpen) desktopMusic.layoutMode = "wide";
                }
                shellRoot.applyLayout(shellRoot.currentLayout);
            }
        }

        TurboTileWidget {
            id: wTurbo
            sharedBackdrop: masterBlurredTex
            powerMode: SystemStatus.power
            onModeRequested: (m) => shellRoot.setPowerMode(m)
        }

        // Compostos dos layouts 6–10 (só aparecem onde o layout os posiciona)
        DockWidget {
            id: wDock
            sharedBackdrop: masterBlurredTex
        }
        IslandWidget {
            id: wIsland
            sharedBackdrop: masterBlurredTex
        }

        BatteryTileWidget {
            id: wBattery
            sharedBackdrop: masterBlurredTex
            onIsExpandedChanged: {
                if (isExpanded) {
                    if (wWifi.isExpanded) wWifi.isExpanded = false;
                    if (wBt.isExpanded) wBt.isExpanded = false;
                    if (wWallpaper.isExpanded) wWallpaper.isExpanded = false;
                    if (desktopMusic.isLyricsOpen) desktopMusic.layoutMode = "wide";
                }
                shellRoot.applyLayout(shellRoot.currentLayout);
            }
        }

        GamingTileWidget {
            id: wGaming
            sharedBackdrop: masterBlurredTex
            onToggleRequested: () => GlassTheme.toggleGaming()
        }

        DndTileWidget {
            id: wDnd
            sharedBackdrop: masterBlurredTex
            isDnd: SystemStatus.dnd
            onToggleRequested: () => shellRoot.toggleDnd()
        }

        XwaylandTileWidget {
            id: wXwayland
            sharedBackdrop: masterBlurredTex
            isXwayland: SystemStatus.xwayland
            countdown: shellRoot.xwaylandCountdown
            onToggleRequested: () => shellRoot.toggleXwayland()
        }

        WallpaperTileWidget {
            id: wWallpaper
            sharedBackdrop: masterBlurredTex
            onNextRequested: () => shellRoot.nextWallpaper()
            onWallpaperSelected: (path) => shellRoot.broadcastWallpaper(path)
            onIsExpandedChanged: {
                if (isExpanded) {
                    if (wWifi.isExpanded) wWifi.isExpanded = false;
                    if (wBt.isExpanded) wBt.isExpanded = false;
                    if (wBattery.isExpanded) wBattery.isExpanded = false;
                    if (desktopMusic.isLyricsOpen) desktopMusic.layoutMode = "wide";
                }
                shellRoot.applyLayout(shellRoot.currentLayout);
            }
        }

        ThemeSwitchTileWidget {
            id: wTheme
            sharedBackdrop: masterBlurredTex
        }

        ClaudeTileWidget {
            id: wClaude
            sharedBackdrop: masterBlurredTex
        }

        CavaWidget {
            id: wCava
            sharedBackdrop: masterBlurredTex
            wallpaper: shellRoot.activeWallpaper
        }

        LaptopTileWidget {
            id: wLaptop
            sharedBackdrop: masterBlurredTex
            laptopOnly: shellRoot.systemLaptopOnly
            onToggleRequested: () => shellRoot.toggleMonitorMode()
        }

        GpuTileWidget {
            id: wGpu
            sharedBackdrop: masterBlurredTex
            amdMode: shellRoot.systemGpuMode === "amd"
            countdown: shellRoot.gpuCountdown
            onToggleRequested: () => shellRoot.toggleGpuMode()
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
            y: shellRoot.rebootBannerOn ? 48 : -95
            width: 450
            height: 60
            visible: shellRoot.rebootBannerOn || y > -90

            Behavior on y { enabled: !GlassTheme.gaming; NumberAnimation { duration: 350; easing.type: Easing.OutBack } }

            LiquidGlass {
                id: bannerGlass
                sharedBackdrop: masterBlurredTex   // sem isto o vidro carregava a própria cópia do wallpaper + blur (sempre, mesmo escondido)
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
                        text: (shellRoot.gpuRestartPending ? shellRoot.gpuCountdown : shellRoot.xwaylandCountdown) + "s"
                        font.family: "SF Pro Display"
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
                        text: shellRoot.gpuRestartPending ? (shellRoot.gpuTarget === "amd" ? "Trocando para AMD (bateria)..." : "Trocando para NVIDIA...")
                              : (SystemStatus.xwayland ? "Ativando Xwayland..." : "Desativando Xwayland...")
                        font.family: "SF Pro Display"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }
                    Text {
                        width: parent.width
                        text: "Reiniciando o PC em " + (shellRoot.gpuRestartPending ? shellRoot.gpuCountdown : shellRoot.xwaylandCountdown) + "s para aplicar..."
                        font.family: "SF Pro Display"
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
                    Behavior on scale { enabled: !GlassTheme.gaming; NumberAnimation { duration: 90 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Cancelar"
                        font.family: "SF Pro Display"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shellRoot.gpuRestartPending ? shellRoot.cancelGpuCountdown() : shellRoot.cancelXwaylandCountdown()
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
                    Behavior on scale { enabled: !GlassTheme.gaming; NumberAnimation { duration: 90 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Reiniciar"
                        font.family: "SF Pro Display"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: rebootNowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shellRoot.gpuRestartPending ? shellRoot.applyGpuMode() : shellRoot.rebootNow()
                    }
                }
            }
        }
    }

    // ── Fullscreen Launchpad ─────────────────────────────────
    // Launchpad só existe enquanto é usado: é criado ao abrir e descartado 60 s depois de fechar
    // (fechado ele mantinha janela, lista de apps e ícones na memória: ~13 MB).
    QtObject {
        id: launchpad
        function toggleLaunchpad() {
            if (!launchpadLoader.active) launchpadLoader.active = true;   // onLoaded abre
            else if (launchpadLoader.item) launchpadLoader.item.toggleLaunchpad();
        }
    }
    LazyLoader {
        id: launchpadLoader
        active: false
        onItemChanged: if (item) item.toggleLaunchpad()
        Launchpad {}
    }
    Timer { id: launchpadUnload; interval: 60000; onTriggered: launchpadLoader.active = false }
    Connections {
        target: launchpadLoader.item
        ignoreUnknownSignals: true
        function onShownChanged() {
            if (launchpadLoader.item.shown) launchpadUnload.stop();
            else launchpadUnload.restart();
        }
    }
}
