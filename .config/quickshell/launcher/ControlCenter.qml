import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "./widgets"

// ============================================================
// CONTROL CENTER / DYNAMIC ISLAND — Canto Superior Direito
// 100% Vetorial (SVG puro, sem emojis), Animações de Entrada/Saída,
// Cores Brancas Nítidas de Alto Contraste, Micro-interações Fluidas,
// e Sub-widgets Completos para Wi-Fi e Bluetooth (com senha/esquecer)
// ============================================================

PanelWindow {
    id: root

    anchors.top: true
    anchors.bottom: false
    anchors.left: false
    anchors.right: true
    margins.top: 12
    margins.right: 16

    mask: Region {
        item: morphContainer
    }

    implicitWidth: 350
    implicitHeight: root.actualTargetHeight

    visible: root.shown || root.isClosing
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    color: "transparent"

    // ── Matugen Dynamic Colors (Material You Adaptativo) ──────
    property color accentColor: "#87d1ea"
    property color accentTextColor: "#003543"
    property color primaryContainerColor: "#004e5f"
    property color surfaceColor: "#0f1416"
    property color cardColor: "#1b2023"
    property color outlineColor: "#899296"
    property color glassBgColor: Qt.rgba(20/255, 24/255, 32/255, 0.25)
    property color glassHoverColor: Qt.rgba(36/255, 42/255, 54/255, 0.38)

    function applyColors(colors) {
        if (!colors) return;
        if (colors.primary) root.accentColor = colors.primary;
        if (colors.on_primary) root.accentTextColor = colors.on_primary;
        if (colors.primary_container) root.primaryContainerColor = colors.primary_container;
        if (colors.surface) root.surfaceColor = colors.surface;
        if (colors.surface_container) root.cardColor = colors.surface_container;
        if (colors.outline) root.outlineColor = colors.outline;
    }

    // ── Estado do Sistema & Morphing Líquido ──────────────────
    property bool shown: false
    property bool isClosing: false
    property bool isReady: false
    property string currentView: "main" // "main", "wifi", "bluetooth", "wallpaper", "apps"

    property bool isIslandActive: false
    property bool openedFromIsland: false

    // Geometria e estado do morphing líquido (gota -> pod vertical -> desdobramento horizontal à direita)
    property real morphX: 0
    property real morphY: 0
    property real morphWidth: 350
    property real morphHeight: 560
    property real morphRadius: 24
    property real contentOpacity: 1.0
    property real glassMorphOpacity: 0.0

    readonly property real actualTargetHeight: {
        let th = panel ? panel.targetHeight : 560;
        if (!th || isNaN(th) || th < 100) th = 560;
        return Math.min(th, 780);
    }

    signal toggleMiniIslandRequested()
    signal miniIslandDismissRequested()
    signal morphToIslandRequested()
    signal requestIslandGlide()
    signal wallpaperChanged(string path)
    signal openLaunchpadRequested()

    property real volumeVal: 0.4
    property bool isMuted: false
    property real brightnessVal: 1.0
    property bool isDraggingVol: false
    property bool isDraggingBr: false

    property int batteryVal: 100
    property string batteryStat: "Full"

    property string uptimeStr: "1:00"
    property string wifiSsid: "Wi-Fi"
    property bool isWifiOn: true

    property bool isBtOn: false
    property string btDevice: "Disabled"

    property string activePowerMode: "performance" // "silent", "performance", "turbo"
    property string powerProf: "Balanced"
    property bool _powerModeLock: false

    Timer {
        id: powerModeLockTimer
        interval: 2500
        repeat: false
        onTriggered: root._powerModeLock = false
    }

    Process {
        id: powerModeCmd
        running: false
    }

    function setPowerMode(mode) {
        root.activePowerMode = mode
        root._powerModeLock = true
        powerModeLockTimer.restart()
        powerModeCmd.command = ["sudo", "/usr/local/bin/tuf-power-mode.sh", mode]
        powerModeCmd.running = true
    }
    property bool isMicMuted: false
    property bool isDnd: false

    function toggleDnd() {
        const nextState = !root.isDnd
        root.isDnd = nextState
        if (nextState) {
            root.exec("makoctl mode -a do-not-disturb -a dnd && makoctl dismiss -a")
        } else {
            root.exec("makoctl mode -r do-not-disturb -r dnd")
        }
    }

    // ── Estado do Xwayland (Gaming Mode / Compatibilidade X11) ──
    property bool xwaylandEnabled: false
    property int xwaylandCountdown: 0
    property bool xwaylandRestartPending: false

    Timer {
        id: xwaylandRebootTimer
        interval: 1000
        repeat: true
        running: root.xwaylandCountdown > 0
        onTriggered: {
            root.xwaylandCountdown--
            if (root.xwaylandCountdown <= 0) {
                root.xwaylandCountdown = 0
                xwaylandRebootTimer.stop()
                root.exec("systemctl reboot")
            }
        }
    }

    function toggleXwayland() {
        if (root.xwaylandRestartPending) {
            cancelXwaylandCountdown()
            return
        }
        const nextState = !root.xwaylandEnabled
        root.xwaylandEnabled = nextState
        root.exec("sh -c 'echo " + (nextState ? "true" : "false") + " > /home/gabriel/.config/hypr/xwayland_state'")
        root.xwaylandCountdown = 5
        root.xwaylandRestartPending = true
        xwaylandRebootTimer.start()
    }

    function cancelXwaylandCountdown() {
        xwaylandRebootTimer.stop()
        root.xwaylandCountdown = 0
        root.xwaylandRestartPending = false
        const reverted = !root.xwaylandEnabled
        root.xwaylandEnabled = reverted
        root.exec("sh -c 'echo " + (reverted ? "true" : "false") + " > /home/gabriel/.config/hypr/xwayland_state'")
    }

    function rebootNow() {
        xwaylandRebootTimer.stop()
        root.exec("systemctl reboot")
    }

    // Media
    property string mediaTitle: "Blackbone"
    property string mediaArtist: "Unprocessed"
    property string mediaArt: ""
    property string _lastMediaArtUrl: ""          // cache: evita recarregar mesma URL
    property string _ytVideoId: ""                // cache: último YouTube video ID
    property real mediaPos: 66
    property real mediaLen: 272
    property string mediaStat: "Stopped"
    property string mediaPlayerName: "spotify"
    property var cavaBars: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

    function formatTime(sec) {
        if (!sec || isNaN(sec) || sec < 0) return "0:00";
        const s = Math.floor(sec);
        const m = Math.floor(s / 60);
        const remS = s % 60;
        return m + ":" + (remS < 10 ? "0" : "") + remS;
    }

    function seekMedia(pct) {
        if (root.mediaLen > 0) {
            const targetSec = Math.max(0, Math.min(root.mediaLen, pct * root.mediaLen));
            root.mediaPos = targetSec;
            root.exec("playerctl position " + Math.round(targetSec));
        }
    }

    Timer {
        interval: 1000
        running: root.shown && root.mediaStat === "Playing"
        repeat: true
        onTriggered: {
            if (root.mediaLen > 0 && root.mediaPos < root.mediaLen) {
                root.mediaPos += 1;
            }
        }
    }

    // GIF rotation: troca aleatoriamente a cada abertura do ControlCenter
    property var gifList: [
        "file:///home/gabriel/Pictures/icon-controlcenter/0d1ef6242e102852d7e98cc5fecbe52b.gif",
        "file:///home/gabriel/Pictures/icon-controlcenter/12e464b3f2db3d326e5397bcb052ce8d.gif",
        "file:///home/gabriel/Pictures/icon-controlcenter/2906855.gif"
    ]
    property string currentGif: gifList[Math.floor(Math.random() * gifList.length)]

    // ── Posicionamento Fixo (Canto Superior Direito) ───────────
    function getScreenWidth() {
        return (root.width > 400) ? root.width : (root.screen && root.screen.width > 400) ? root.screen.width : (Quickshell.screens && Quickshell.screens[0] ? Quickshell.screens[0].width : 1536);
    }
    function getScreenHeight() {
        return (root.height > 400) ? root.height : (root.screen && root.screen.height > 400) ? root.screen.height : (Quickshell.screens && Quickshell.screens[0] ? Quickshell.screens[0].height : 960);
    }

    function switchMonitor() {
        if (!Quickshell.screens || Quickshell.screens.length < 2) return;
        let nextIdx = 0;
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i] === root.screen) {
                nextIdx = (i + 1) % Quickshell.screens.length;
                break;
            }
        }
        root.screen = Quickshell.screens[nextIdx];
        panel.x = panel.targetX;
        panel.y = panel.targetY;
    }

    function updateScreen() {
        if (Hyprland.focusedMonitor) {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === Hyprland.focusedMonitor.name) {
                    root.screen = Quickshell.screens[i];
                    return;
                }
            }
        }
    }

    function showIsland() {
        if (root.shown && !root.isClosing) return

        // Se a Dynamic Island já está aberta, inicia o deslizamento da ilha até o Control Center
        if (root.isIslandActive) {
            root.requestIslandGlide()
            return
        }

        // Caso contrário, abre diretamente com o pingo escorrendo do topo
        showDirect()
    }

    function showDirect() {
        if (root.shown && !root.isClosing) return
        root.miniIslandDismissRequested()
        root.openedFromIsland = false
        root.isReady = false
        root.isClosing = false
        root.currentView = "main"

        stopAllAnims()

        // Estado inicial do desenho: "desce um botaozinho pequeno" (38x38 no topo da tela)
        root.morphX = 0
        root.morphY = -40
        root.morphWidth = 38
        root.morphHeight = 38
        root.morphRadius = 19
        root.contentOpacity = 0.0
        root.glassMorphOpacity = 1.0

        root.shown = true
        refreshStatus()
        directUnfoldAnim.restart()

        if (!colorCollector.running) colorCollector.running = true
        statusCollector.running = true
        if (!mediaFollower.running) mediaFollower.running = true
    }

    function morphFromIsland() {
        root.miniIslandDismissRequested()
        root.openedFromIsland = true
        root.isReady = false
        root.isClosing = false
        root.currentView = "main"

        stopAllAnims()

        // Estado inicial vindo da ilha: gota já no canto superior esquerdo do CC (x:0, y:0)
        root.morphX = 0
        root.morphY = 0
        root.morphWidth = 38
        root.morphHeight = 38
        root.morphRadius = 19
        root.contentOpacity = 0.0
        root.glassMorphOpacity = 1.0

        root.shown = true
        refreshStatus()
        islandUnfoldAnim.restart()

        if (!colorCollector.running) colorCollector.running = true
        statusCollector.running = true
        if (!mediaFollower.running) mediaFollower.running = true
    }

    function hideIsland() {
        if (!root.shown || root.isClosing) return
        root.isReady = false
        root.isClosing = true
        stopAllAnims()

        if (root.openedFromIsland) {
            islandFoldAnim.restart()
        } else {
            directFoldAnim.restart()
        }
    }

    function stopAllAnims() {
        directUnfoldAnim.stop()
        directFoldAnim.stop()
        islandUnfoldAnim.stop()
        islandFoldAnim.stop()
    }

    function openWifiWidget() {
        root.currentView = "wifi"
        wifiWidget.isWifiEnabled = root.isWifiOn
        wifiWidget.refresh()
    }

    function openBtWidget() {
        root.currentView = "bluetooth"
        btWidget.isBtEnabled = root.isBtOn
        btWidget.refresh()
    }

    function openWallpaperWidget() {
        root.currentView = "wallpaper"
        wallpaperWidget.refresh()
    }

    function openAppsWidget() {
        root.hideIsland()
        root.openLaunchpadRequested()
    }

    function openMusicWidget() {
        root.exec("playerctl play-pause")
    }

    function refreshStatus() {
        if (!statusCollector.running) statusCollector.running = true
    }

    // ── ANIMAÇÃO DIRETA DE ENTRADA: O PINGO DESCE DO TOPO, ESTICA E DESLIZA PARA A DIREITA ──
    SequentialAnimation {
        id: directUnfoldAnim

        // 1. "desce um botaozinho pequeno" (y: -40 -> 0)
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "morphY"
                from: -40
                to: 0
                duration: 200
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "morphWidth"
                from: 38
                to: 38
                duration: 200
            }
            NumberAnimation {
                target: root
                property: "morphHeight"
                from: 38
                to: 38
                duration: 200
            }
            NumberAnimation {
                target: root
                property: "glassMorphOpacity"
                from: 1.0
                to: 1.0
                duration: 200
            }
        }

        // Breve pausa para assentamento suave da gota
        PauseAnimation { duration: 30 }

        // 2. "aumenta" (estica verticalmente para baixo)
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "morphHeight"
                from: 38
                to: root.actualTargetHeight
                duration: 200
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "morphRadius"
                from: 19
                to: 22
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        // 3. "desliza para direita se auto completando" (expande horizontalmente, revela botões e dissolve o fundo da gota)
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "morphWidth"
                from: 38
                to: 350
                duration: 250
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "morphRadius"
                from: 22
                to: 24
                duration: 250
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "contentOpacity"
                from: 0.0
                to: 1.0
                duration: 220
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "glassMorphOpacity"
                from: 1.0
                to: 0.0
                duration: 200
                easing.type: Easing.OutQuad
            }
        }

        onFinished: {
            root.morphWidth = 350
            root.morphHeight = Qt.binding(() => root.actualTargetHeight)
            root.morphY = 0
            root.morphRadius = 24
            root.contentOpacity = 1.0
            root.glassMorphOpacity = 0.0
            root.isReady = true
        }
    }

    // ── ANIMAÇÃO DIRETA DE SAÍDA: RECOLHE PARA A ESQUERDA, ENCOLHE PARA PINGO E SOBE PARA O TOPO ──
    SequentialAnimation {
        id: directFoldAnim

        // 1. Conteúdo desvanece, gota ressurge e largura recolhe da direita para a esquerda (350 -> 38)
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "contentOpacity"
                to: 0.0
                duration: 80
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "glassMorphOpacity"
                to: 1.0
                duration: 80
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "morphWidth"
                to: 38
                duration: 200
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root
                property: "morphRadius"
                to: 20
                duration: 200
                easing.type: Easing.InCubic
            }
        }

        // 2. Altura encolhe de volta para a bolinha (38px)
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "morphHeight"
                to: 38
                duration: 160
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root
                property: "morphRadius"
                to: 19
                duration: 160
                easing.type: Easing.InCubic
            }
        }

        // 3. Pingo sobe de volta para dentro do bezel (y: 0 -> -40)
        NumberAnimation {
            target: root
            property: "morphY"
            from: 0
            to: -40
            duration: 160
            easing.type: Easing.InCubic
        }

        onFinished: {
            root.isClosing = false
            root.isReady = false
            root.shown = false
            root.currentView = "main"
            root.morphY = -40
            root.morphWidth = 38
            root.morphHeight = 38
            root.contentOpacity = 0.0
            root.glassMorphOpacity = 0.0
        }
    }

    // ── ANIMAÇÃO DE ENTRADA VINDA DA ILHA: GOTA JÁ ESTÁ NO CANTO, SÓ ESTICA E DESLIZA PARA A DIREITA ──
    SequentialAnimation {
        id: islandUnfoldAnim

        // Breve pausa para handoff perfeito
        PauseAnimation { duration: 20 }

        // 1. Estica verticalmente para baixo (gota visível)
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "morphHeight"
                from: 38
                to: root.actualTargetHeight
                duration: 200
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "morphRadius"
                from: 19
                to: 22
                duration: 200
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "glassMorphOpacity"
                from: 1.0
                to: 1.0
                duration: 200
            }
        }

        // 2. Desliza / expande para a direita: revela os botões e dissolve o fundo da gota para 0.0
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "morphWidth"
                from: 38
                to: 350
                duration: 250
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "morphRadius"
                from: 22
                to: 24
                duration: 250
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "contentOpacity"
                from: 0.0
                to: 1.0
                duration: 220
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "glassMorphOpacity"
                from: 1.0
                to: 0.0
                duration: 200
                easing.type: Easing.OutQuad
            }
        }

        onFinished: {
            root.morphWidth = 350
            root.morphHeight = Qt.binding(() => root.actualTargetHeight)
            root.morphY = 0
            root.morphRadius = 24
            root.contentOpacity = 1.0
            root.glassMorphOpacity = 0.0
            root.isReady = true
        }
    }

    // ── ANIMAÇÃO DE SAÍDA PARA A ILHA: RECOLHE PARA PINGO E ACIONA O RETORNO DA ILHA ──
    SequentialAnimation {
        id: islandFoldAnim

        // 1. Conteúdo desvanece, gota líquida ressurge e largura recolhe para a esquerda (350 -> 38)
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "contentOpacity"
                to: 0.0
                duration: 80
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "glassMorphOpacity"
                to: 1.0
                duration: 80
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "morphWidth"
                to: 38
                duration: 200
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: root
                property: "morphRadius"
                to: 20
                duration: 200
                easing.type: Easing.InOutCubic
            }
        }

        // 2. Altura encolhe de volta para a bolinha (38px)
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "morphHeight"
                to: 38
                duration: 160
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: root
                property: "morphRadius"
                to: 19
                duration: 160
                easing.type: Easing.InOutCubic
            }
        }

        onFinished: {
            root.isClosing = false
            root.isReady = false
            root.shown = false
            root.currentView = "main"
            root.contentOpacity = 0.0
            root.glassMorphOpacity = 0.0
            root.morphToIslandRequested()
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
                const cmd = line.trim()
                console.log("[FIFO CMD RECEIVED]:", cmd)
                if (cmd === "show") {
                    root.showIsland()
                } else if (cmd === "hide") {
                    root.hideIsland()
                } else if (cmd === "toggle") {
                    if (root.shown) root.hideIsland()
                    else root.showIsland()
                } else if (cmd === "mini" || cmd === "mini:toggle" || cmd === "notch" || cmd === "island") {
                    if (root.shown) {
                        root.openedFromIsland = true
                        root.hideIsland()
                    } else {
                        root.toggleMiniIslandRequested()
                    }
                } else if (cmd === "wifi" || cmd === "view:wifi") {
                    if (!root.shown) root.showIsland()
                    root.openWifiWidget()
                } else if (cmd === "bt" || cmd === "view:bluetooth") {
                    if (!root.shown) root.showIsland()
                    root.openBtWidget()
                } else if (cmd === "wallpaper" || cmd === "view:wallpaper" || cmd === "wallpapers") {
                    if (!root.shown) root.showIsland()
                    root.openWallpaperWidget()
                } else if (cmd === "apps" || cmd === "view:apps" || cmd === "launcher" || cmd === "launchpad") {
                    root.hideIsland()
                    root.openLaunchpadRequested()
                } else if (cmd === "music" || cmd === "view:music" || cmd === "player") {
                    if (!root.shown) root.showIsland()
                    root.openMusicWidget()
                } else if (cmd === "discord") {
                    root.exec("/home/gabriel/.local/bin/discord &")
                    root.hideIsland()
                } else if (cmd === "dnd" || cmd === "dnd:toggle" || cmd === "mode:dnd") {
                    root.toggleDnd()
                }
            }
        }
    }

    // ── Coletor de Cores Matugen (Execução Única no Início) ──
    Process {
        id: colorCollector
        command: ["/home/gabriel/.config/quickshell/scripts/wallpaper_tool.sh", "colors"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const data = JSON.parse(line.trim())
                    if (data.colors) root.applyColors(data.colors)
                } catch (e) {}
            }
        }
    }

    // ── Timer de Atualização (SÓ RODA QUANDO ABERTO) ───────────
    Timer {
        interval: 1200
        running: root.shown
        repeat: true
        onTriggered: {
            if (!statusCollector.running) statusCollector.running = true
            // mediaFollower é orientado a eventos (--follow), não precisa de polling
        }
    }

    Timer {
        id: btStatusTimer
        interval: 450
        repeat: false
        onTriggered: {
            root.refreshStatus()
            btWidget.refresh()
        }
    }

    Timer {
        id: wifiStatusTimer
        interval: 450
        repeat: false
        onTriggered: {
            root.refreshStatus()
            wifiWidget.refresh()
        }
    }

    // ── Coletor de Status do Sistema ──────────────────────────
    Process {
        id: statusCollector
        command: ["bash", "-c",
            "V=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); " +
            "B=$(cat /sys/class/backlight/nvidia_0/brightness 2>/dev/null || echo 100); " +
            "MB=$(cat /sys/class/backlight/nvidia_0/max_brightness 2>/dev/null || echo 100); " +
            "CAP=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 100); " +
            "STAT=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null || echo Full); " +
            "UP=$(awk '{h=int($1/3600); m=int(($1%3600)/60); printf \"%d:%02d\", h, m}' /proc/uptime); " +
            "WF=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2 | head -n 1); " +
            "WFR=$(nmcli radio wifi 2>/dev/null); " +
            "BT=$(bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo 1 || echo 0); " +
            "BTD=$(bluetoothctl devices Connected 2>/dev/null | head -n 1 | cut -d' ' -f3-); " +
            "PP=$(powerprofilesctl get 2>/dev/null || echo balanced); " +
            "TP=$(cat /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy 2>/dev/null || echo 0); " +
            "MIC=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q MUTED && echo 1 || echo 0); " +
            "XW=$(cat /home/gabriel/.config/hypr/xwayland_state 2>/dev/null || echo false); " +
            "DND=$(makoctl mode 2>/dev/null | grep -E -q 'do-not-disturb|dnd' && echo 1 || echo 0); " +
            "echo \"{\\\"vol\\\":\\\"$V\\\",\\\"br\\\":$B,\\\"mbr\\\":$MB,\\\"bat\\\":$CAP,\\\"bat_stat\\\":\\\"$STAT\\\",\\\"up\\\":\\\"$UP\\\",\\\"wifi\\\":\\\"$WF\\\",\\\"wfr\\\":\\\"$WFR\\\",\\\"bt\\\":$BT,\\\"btd\\\":\\\"$BTD\\\",\\\"prof\\\":\\\"$PP\\\",\\\"tuf\\\":\\\"$TP\\\",\\\"mic\\\":$MIC,\\\"xw\\\":\\\"$XW\\\",\\\"dnd\\\":$DND}\""
        ]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const data = JSON.parse(line.trim())
                    if (data.vol && !root.isDraggingVol && root.pendingVol < 0) {
                        const parts = data.vol.split(" ")
                        if (parts.length >= 2) {
                            root.volumeVal = Math.min(1.0, Math.max(0.0, parseFloat(parts[1])))
                        }
                        root.isMuted = data.vol.includes("MUTED")
                    }
                    if (data.mbr && data.mbr > 0 && !root.isDraggingBr && root.pendingBr < 0) {
                        root.brightnessVal = Math.min(1.0, Math.max(0.0, data.br / data.mbr))
                    }
                    root.batteryVal = parseInt(data.bat) || 100
                    root.batteryStat = data.bat_stat || "Full"
                    if (data.up) root.uptimeStr = data.up
                    
                    if (!wifiStatusTimer.running) {
                        root.isWifiOn = (data.wfr === "enabled")
                    }
                    if (data.wifi && data.wifi.length > 0) {
                        root.wifiSsid = data.wifi
                    } else if (root.isWifiOn) {
                        root.wifiSsid = "Disconnected"
                    } else {
                        root.wifiSsid = "Disabled"
                    }

                    if (!btStatusTimer.running) {
                        root.isBtOn = (data.bt === 1)
                    }
                    if (data.btd && data.btd.length > 0) {
                        root.btDevice = data.btd
                    } else if (root.isBtOn) {
                        root.btDevice = "None"
                    } else {
                        root.btDevice = "Disabled"
                    }
                    if (data.prof) {
                        root.powerProf = data.prof.charAt(0).toUpperCase() + data.prof.slice(1)
                    }
                    if (!root._powerModeLock && data.tuf !== undefined) {
                        if (data.tuf === "1" || data.tuf === 1) root.activePowerMode = "turbo"
                        else if (data.tuf === "2" || data.tuf === 2) root.activePowerMode = "silent"
                        else root.activePowerMode = "performance"
                    }
                    root.isMicMuted = (data.mic === 1)
                    if (data.dnd !== undefined) {
                        root.isDnd = (data.dnd === 1)
                    }
                    if (data.xw !== undefined && !root.xwaylandRestartPending) {
                        root.xwaylandEnabled = (data.xw === "true" || data.xw === 1 || data.xw === "1")
                    }
                } catch (e) {}
            }
        }
    }

    // ── Coletor de Mídia (playerctl --follow — orientado a eventos) ──
    // playerctl v2.4.1 não suporta json(), usa delimitador "│" para parsing
    Process {
        id: mediaFollower
        command: ["playerctl", "metadata", "--follow", "--format",
            "{{title}}│{{artist}}│{{mpris:artUrl}}│{{xesam:url}}│{{position}}│{{mpris:length}}│{{status}}│{{playerName}}"
        ]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const parts = line.trim().split("│")
                    if (parts.length < 8) return

                    const title   = parts[0] || ""
                    const artist  = parts[1] || ""
                    const artUrl  = parts[2] || ""
                    const url     = parts[3] || ""
                    const pos     = parseInt(parts[4]) || 0
                    const len     = parseInt(parts[5]) || 0
                    const stat    = parts[6] || "Stopped"
                    const player  = parts[7] || "player"

                    if (stat !== "Stopped") {
                        root.mediaTitle = title || "Unknown Title"
                        root.mediaArtist = artist || "Unknown Artist"

                        // ── Resolve artwork com cache e fallback ──
                        let art = artUrl
                        if (!art && url) {
                            let vid = ""
                            // Suporta: watch?v=, youtu.be/, /embed/, /shorts/, /v/
                            const rxWatch = url.match(/[?&]v=([a-zA-Z0-9_-]{11})/)
                            if (rxWatch) {
                                vid = rxWatch[1]
                            } else {
                                const rxShort = url.match(/youtu\.be\/([a-zA-Z0-9_-]{11})/)
                                if (rxShort) {
                                    vid = rxShort[1]
                                } else {
                                    const rxEmbed = url.match(/\/(?:embed|shorts|v)\/([a-zA-Z0-9_-]{11})/)
                                    if (rxEmbed) vid = rxEmbed[1]
                                }
                            }
                            if (vid) {
                                root._ytVideoId = vid
                                art = "https://img.youtube.com/vi/" + vid + "/maxresdefault.jpg"
                            }
                        }

                        // Cache: só atualiza mediaArt se a URL mudou
                        if (art !== root._lastMediaArtUrl) {
                            root._lastMediaArtUrl = art
                            root.mediaArt = art
                        }

                        root.mediaPos = pos / 1000000
                        root.mediaLen = len > 0 ? (len / 1000000) : 0
                        root.mediaStat = stat
                        root.mediaPlayerName = player
                    } else {
                        root.mediaStat = "Stopped"
                        root.mediaTitle = "Blackbone"
                        root.mediaArtist = "Unprocessed"
                        root.mediaPos = 66
                        root.mediaLen = 272
                    }
                } catch (e) {}
            }
        }
    }

    // ── CAVA Audio Visualizer Process ─────────────────────────
    Process {
        id: cavaProc
        command: ["cava", "-p", "/home/gabriel/.config/quickshell/cava.conf"]
        running: root.shown
        stdout: SplitParser {
            onRead: (line) => {
                const parts = line.trim().split(";")
                if (parts.length >= 20) {
                    const arr = []
                    for (let i = 0; i < 20; i++) {
                        arr.push(parseInt(parts[i]) || 0)
                    }
                    root.cavaBars = arr
                }
            }
        }
    }

    Process { id: actionCmd; running: false }
    function exec(cmd) {
        actionCmd.command = ["bash", "-c", cmd]
        actionCmd.running = true
    }

    // ── Controle Throttled de Volume (WirePlumber / wpctl) ──────
    property real pendingVol: -1
    Process {
        id: volSetter
        running: false
        onRunningChanged: {
            if (!running && root.pendingVol >= 0) {
                root.applyVolume()
            }
        }
    }
    function applyVolume(targetPct) {
        if (targetPct !== undefined) root.pendingVol = targetPct
        if (volSetter.running) return
        if (root.pendingVol >= 0) {
            const toSet = root.pendingVol
            root.pendingVol = -1
            const intPct = Math.round(toSet * 100)
            volSetter.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", intPct + "%"]
            volSetter.running = true
        }
    }

    // ── Controle Throttled de Brilho (brightnessctl) ────────────
    property real pendingBr: -1
    Process {
        id: brSetter
        running: false
        onRunningChanged: {
            if (!running && root.pendingBr >= 0) {
                root.applyBrightness()
            }
        }
    }
    function applyBrightness(targetPct) {
        if (targetPct !== undefined) root.pendingBr = targetPct
        if (brSetter.running) return
        if (root.pendingBr >= 0) {
            const toSet = root.pendingBr
            root.pendingBr = -1
            const intPct = Math.max(5, Math.round(toSet * 100))
            brSetter.command = ["brightnessctl", "set", intPct + "%"]
            brSetter.running = true
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.shown
        onActivated: {
            if (root.currentView !== "main") {
                root.currentView = "main"
            } else {
                root.hideIsland()
            }
        }
    }

    Shortcut {
        sequence: "M"
        enabled: root.shown
        onActivated: root.switchMonitor()
    }
    Shortcut {
        sequence: "W"
        enabled: root.shown && root.currentView === "main"
        onActivated: root.openWallpaperWidget()
    }
    Shortcut {
        sequence: "A"
        enabled: root.shown && root.currentView === "main"
        onActivated: root.openAppsWidget()
    }
    Shortcut {
        sequence: "P"
        enabled: root.shown && root.currentView === "main"
        onActivated: root.exec("playerctl play-pause")
    }

    // ── Painel Principal: Transparente (Widgets Flutuando Sem Container) ───
    Item {
        id: panel

        readonly property real targetHeight: root.currentView === "wifi" ? wifiWidget.implicitHeight :
                                             root.currentView === "bluetooth" ? btWidget.implicitHeight :
                                             root.currentView === "wallpaper" ? wallpaperWidget.implicitHeight :
                                             root.currentView === "apps" ? appsWidget.implicitHeight :
                                             mainCol.implicitHeight

        anchors.fill: parent

        transformOrigin: Item.Top
        clip: false
        z: 1

        // ── ENVELOPE / GOTA DE LIQUID GLASS MORPHING ──────────
        Item {
            id: morphContainer
            x: root.morphX
            y: root.morphY
            width: root.morphWidth
            height: root.morphHeight
            z: 1

            Behavior on height {
                enabled: root.isReady
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            Rectangle {
                id: morphGlass
                anchors.fill: parent
                radius: root.morphRadius
                color: root.glassBgColor
                border.width: 0
                antialiasing: true
                smooth: true
                opacity: root.glassMorphOpacity
                visible: opacity > 0.01
            }
        }

        // ── Container de Vistas (Clipper de Revelação Líquida) ────────
        Item {
            id: morphRevealClipper
            x: root.morphX
            y: root.morphY
            width: root.morphWidth
            height: root.morphHeight
            clip: true
            z: 2

            Behavior on height {
                enabled: root.isReady
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            Item {
                id: viewsContainer
                x: 0
                y: 0
                width: 350
                height: root.actualTargetHeight
                opacity: root.contentOpacity
                visible: opacity > 0.005

            // ========================================================
            // PÁGINA 0: VISTA PRINCIPAL (ISLAND / CONTROL CENTER)
            // ========================================================
            Item {
                id: mainView
                anchors.top: parent.top
                width: parent.width
                height: mainCol.implicitHeight
                transformOrigin: Item.Top
                scale: root.currentView === "main" ? 1.0 : 0.93
                opacity: root.currentView === "main" ? 1 : 0
                enabled: root.currentView === "main"
                visible: opacity > 0.005

                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

                ColumnLayout {
                    id: mainCol
                    anchors.fill: parent
                    spacing: 10

                    // ========================================================
                    // ── ROW 1: CONNECTIVITY POD (ESQ) + NOW PLAYING POD (DIR) ──
                    // ========================================================
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 140
                        spacing: 10

                        // ── 1. CONNECTIVITY CARD (Wi-Fi & Bluetooth Stack) ────
                        Rectangle {
                            Layout.preferredWidth: 170
                            Layout.fillHeight: true
                            radius: 20
                            color: root.glassBgColor
                            border.width: 0

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                // Linha Wi-Fi
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 14
                                    color: wifiRowM.containsMouse ? Qt.rgba(255, 255, 255, 0.10) : "transparent"
                                    border.width: 0
                                    scale: wifiRowM.pressed ? 0.96 : (wifiRowM.containsMouse ? 1.02 : 1.0)
                                    Behavior on color { ColorAnimation { duration: 140 } }
                                    Behavior on scale { NumberAnimation { duration: 110 } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        // Badge Circular Wi-Fi
                                        Rectangle {
                                            width: 36
                                            height: 36
                                            radius: 18
                                            color: root.isWifiOn ? "#0a84ff" : Qt.rgba(255, 255, 255, 0.10)
                                            scale: wifiBadgeM.pressed ? 0.90 : (wifiBadgeM.containsMouse ? 1.06 : 1.0)
                                            Behavior on color { ColorAnimation { duration: 160 } }
                                            Behavior on scale { NumberAnimation { duration: 100 } }

                                            SvgIcon {
                                                anchors.centerIn: parent
                                                name: "wifi"
                                                size: 17
                                                color: "#ffffff"
                                            }

                                            MouseArea {
                                                id: wifiBadgeM
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const nextState = root.isWifiOn ? "off" : "on"
                                                    root.isWifiOn = !root.isWifiOn
                                                    root.exec("nmcli radio wifi " + nextState)
                                                    wifiWidget.isWifiEnabled = root.isWifiOn
                                                    wifiStatusTimer.restart()
                                                }
                                            }
                                        }

                                        // Textos
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                text: "Wi-Fi"
                                                font.family: "Inter, sans-serif"
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                renderType: Text.NativeRendering
                                                color: "#ffffff"
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: root.isWifiOn ? root.wifiSsid : "Desativado"
                                                font.family: "Inter, sans-serif"
                                                font.pixelSize: 10
                                                font.weight: root.isWifiOn ? Font.DemiBold : Font.Medium
                                                renderType: Text.NativeRendering
                                                color: root.isWifiOn ? Qt.rgba(255, 255, 255, 0.90) : Qt.rgba(255, 255, 255, 0.45)
                                                elide: Text.ElideRight
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }
                                        }

                                        Text {
                                            text: "›"
                                            font.family: "Inter, sans-serif"
                                            font.pixelSize: 16
                                            font.weight: Font.DemiBold
                                            renderType: Text.NativeRendering
                                            color: root.isWifiOn ? "#ffffff" : Qt.rgba(255, 255, 255, 0.35)
                                            opacity: root.isWifiOn ? 1.0 : 0.45
                                            scale: wifiRowM.containsMouse ? 1.20 : 1.0
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on opacity { NumberAnimation { duration: 150 } }
                                            Behavior on scale { NumberAnimation { duration: 100 } }
                                        }
                                    }

                                    MouseArea {
                                        id: wifiRowM
                                        anchors.fill: parent
                                        anchors.leftMargin: 46
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openWifiWidget()
                                    }
                                }

                                // Linha Divisória Sutil Estilo iOS
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 6
                                    Layout.rightMargin: 6
                                    height: 1
                                    color: Qt.rgba(255, 255, 255, 0.08)
                                }

                                // Linha Bluetooth
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 14
                                    color: btRowM.containsMouse ? Qt.rgba(255, 255, 255, 0.10) : "transparent"
                                    border.width: 0
                                    scale: btRowM.pressed ? 0.96 : (btRowM.containsMouse ? 1.02 : 1.0)
                                    Behavior on color { ColorAnimation { duration: 140 } }
                                    Behavior on scale { NumberAnimation { duration: 110 } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        // Badge Circular Bluetooth
                                        Rectangle {
                                            width: 36
                                            height: 36
                                            radius: 18
                                            color: root.isBtOn ? "#0a84ff" : Qt.rgba(255, 255, 255, 0.10)
                                            scale: btBadgeM.pressed ? 0.90 : (btBadgeM.containsMouse ? 1.06 : 1.0)
                                            Behavior on color { ColorAnimation { duration: 160 } }
                                            Behavior on scale { NumberAnimation { duration: 100 } }

                                            SvgIcon {
                                                anchors.centerIn: parent
                                                name: "bluetooth"
                                                size: 17
                                                color: "#ffffff"
                                            }

                                            MouseArea {
                                                id: btBadgeM
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const nextState = root.isBtOn ? "off" : "on"
                                                    root.isBtOn = !root.isBtOn
                                                    root.exec(nextState === "on" ? "rfkill unblock bluetooth; bluetoothctl power on" : "bluetoothctl power off")
                                                    btWidget.isBtEnabled = root.isBtOn
                                                    btStatusTimer.restart()
                                                }
                                            }
                                        }

                                        // Textos
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                text: "Bluetooth"
                                                font.family: "Inter, sans-serif"
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                renderType: Text.NativeRendering
                                                color: "#ffffff"
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: root.isBtOn ? (root.btDevice && root.btDevice !== "Disabled" && root.btDevice !== "None" ? root.btDevice : "Ativado") : "Desativado"
                                                font.family: "Inter, sans-serif"
                                                font.pixelSize: 10
                                                font.weight: root.isBtOn ? Font.DemiBold : Font.Medium
                                                renderType: Text.NativeRendering
                                                color: root.isBtOn ? Qt.rgba(255, 255, 255, 0.90) : Qt.rgba(255, 255, 255, 0.45)
                                                elide: Text.ElideRight
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }
                                        }

                                        Text {
                                            text: "›"
                                            font.family: "Inter, sans-serif"
                                            font.pixelSize: 16
                                            font.weight: Font.DemiBold
                                            renderType: Text.NativeRendering
                                            color: root.isBtOn ? "#ffffff" : Qt.rgba(255, 255, 255, 0.35)
                                            opacity: root.isBtOn ? 1.0 : 0.45
                                            scale: btRowM.containsMouse ? 1.20 : 1.0
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on opacity { NumberAnimation { duration: 150 } }
                                            Behavior on scale { NumberAnimation { duration: 100 } }
                                        }
                                    }

                                    MouseArea {
                                        id: btRowM
                                        anchors.fill: parent
                                        anchors.leftMargin: 46
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openBtWidget()
                                    }
                                }
                            }
                        }

                        // ── 2. NOW PLAYING CARD (Player iOS Estilo Liquid Bubble) ──
                        Rectangle {
                            Layout.preferredWidth: 170
                            Layout.fillHeight: true
                            radius: 20
                            color: root.glassBgColor
                            border.width: 0

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4

                                // Topo: Capa + Título + Artista
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        width: 34
                                        height: 34
                                        radius: 12
                                        color: Qt.rgba(255, 255, 255, 0.18)
                                        clip: true

                                        Image {
                                            id: ccMediaArtImg
                                            anchors.fill: parent
                                            source: root.mediaArt ? root.mediaArt : ""
                                            fillMode: Image.PreserveAspectCrop
                                            visible: root.mediaArt.length > 0 && status === Image.Ready
                                        }
                                        SvgIcon {
                                            anchors.centerIn: parent
                                            name: "music"
                                            size: 16
                                            color: Qt.rgba(255, 255, 255, 0.8)
                                            visible: !root.mediaArt || root.mediaArt.length === 0 || ccMediaArtImg.status !== Image.Ready
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.openMusicWidget()
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            text: root.mediaStat === "Playing" ? root.mediaTitle : "Snooze"
                                            font.family: "Inter, sans-serif"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            renderType: Text.NativeRendering
                                            color: "#ffffff"
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: root.mediaStat === "Playing" ? root.mediaArtist : "SZA"
                                            font.family: "Inter, sans-serif"
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                            renderType: Text.NativeRendering
                                            color: Qt.rgba(255, 255, 255, 0.70)
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                // Meio: Timestamps e Barra Interativa
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 18

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 2

                                        Repeater {
                                            model: 16
                                            Item {
                                                width: 3
                                                height: 18

                                                Rectangle {
                                                    anchors.bottom: parent.bottom
                                                    width: 3
                                                    radius: 1.5
                                                    property real baseH: [4, 6, 9, 12, 15, 12, 8, 13, 10, 7, 11, 14, 10, 7, 5, 3][index]
                                                    property real cavaVal: (root.mediaStat === "Playing" && root.cavaBars && root.cavaBars[index] !== undefined) ? root.cavaBars[index] : 0
                                                    property real dynamicH: (root.mediaStat === "Playing") ? Math.max(3, Math.min(18, (cavaVal * 0.18) + (cavaVal > 5 ? 2 : 0))) : baseH
                                                    height: dynamicH
                                                    property real curProgress: (root.mediaLen > 0) ? (root.mediaPos / root.mediaLen) : 0.35
                                                    property bool isPlayed: (index / 16.0) <= curProgress
                                                    color: isPlayed ? "#ffffff" : Qt.rgba(255, 255, 255, 0.35)
                                                    Behavior on height { NumberAnimation { duration: 60 } }
                                                    Behavior on color { ColorAnimation { duration: 100 } }
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: (mouse) => {
                                            const pct = mouse.x / width
                                            root.seekMedia(pct)
                                        }
                                    }
                                }

                                // Base: Controles de Áudio (⏮ ▶ ⏭)
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 12

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: prevM.containsMouse ? Qt.rgba(255, 255, 255, 0.26) : Qt.rgba(255, 255, 255, 0.14)
                                        scale: prevM.pressed ? 0.88 : (prevM.containsMouse ? 1.08 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 100 } }
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        SvgIcon {
                                            anchors.centerIn: parent
                                            name: "track-prev"
                                            size: 13
                                            color: "#ffffff"
                                        }
                                        MouseArea {
                                            id: prevM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.exec("playerctl previous")
                                        }
                                    }

                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 18
                                        color: ppM.containsMouse ? Qt.rgba(255, 255, 255, 0.34) : Qt.rgba(255, 255, 255, 0.22)
                                        scale: ppM.pressed ? 0.88 : (ppM.containsMouse ? 1.08 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 100 } }
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        SvgIcon {
                                            anchors.centerIn: parent
                                            name: root.mediaStat === "Playing" ? "pause" : "play"
                                            size: 16
                                            color: "#ffffff"
                                        }
                                        MouseArea {
                                            id: ppM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.exec("playerctl play-pause")
                                                root.mediaStat = (root.mediaStat === "Playing") ? "Paused" : "Playing"
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: nextM.containsMouse ? Qt.rgba(255, 255, 255, 0.26) : Qt.rgba(255, 255, 255, 0.14)
                                        scale: nextM.pressed ? 0.88 : (nextM.containsMouse ? 1.08 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 100 } }
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        SvgIcon {
                                            anchors.centerIn: parent
                                            name: "track-next"
                                            size: 13
                                            color: "#ffffff"
                                        }
                                        MouseArea {
                                            id: nextM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.exec("playerctl next")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ========================================================
                    // ── ROW 2: FOCUS / APPS (ESQ) + DUAL VERTICAL SLIDERS (DIR) ──
                    // ========================================================
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 144
                        spacing: 10

                        // ── COLUNA ESQUERDA: Focus (DND) + Wallpapers & Apps ──
                        ColumnLayout {
                            Layout.preferredWidth: 170
                            Layout.fillHeight: true
                            spacing: 8

                            // Cápsula Do Not Disturb / Focus (Estilo iOS Focus Pill)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: 20
                                color: root.isDnd ? Qt.rgba(255, 255, 255, 0.22) : (dndPillM.containsMouse ? root.glassHoverColor : root.glassBgColor)
                                border.width: 0
                                scale: dndPillM.pressed ? 0.96 : (dndPillM.containsMouse ? 1.02 : 1.0)
                                Behavior on color { ColorAnimation { duration: 140 } }
                                Behavior on scale { NumberAnimation { duration: 110 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 18
                                        color: root.isDnd ? Qt.rgba(255, 255, 255, 0.25) : Qt.rgba(255, 255, 255, 0.12)
                                        scale: dndPillM.pressed ? 0.90 : 1.0
                                        Behavior on color { ColorAnimation { duration: 140 } }

                                        SvgIcon {
                                            anchors.centerIn: parent
                                            name: "moon"
                                            size: 18
                                            color: "#ffffff"
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            text: "Não Perturbe"
                                            font.family: "Inter, sans-serif"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            renderType: Text.NativeRendering
                                            color: "#ffffff"
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: root.isDnd ? "Ativado" : "Desativado"
                                            font.family: "Inter, sans-serif"
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                            renderType: Text.NativeRendering
                                            color: root.isDnd ? Qt.rgba(255, 255, 255, 0.85) : Qt.rgba(255, 255, 255, 0.50)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: dndPillM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleDnd()
                                }
                            }

                            // Dois Botões Squircles: Wallpapers & Apps
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 8

                                // Botão 1: Wallpapers
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 20
                                    color: wallBtnM.containsMouse ? root.glassHoverColor : root.glassBgColor
                                    border.width: 0
                                    scale: wallBtnM.pressed ? 0.94 : (wallBtnM.containsMouse ? 1.04 : 1.0)
                                    Behavior on color { ColorAnimation { duration: 130 } }
                                    Behavior on scale { NumberAnimation { duration: 110 } }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        SvgIcon {
                                            Layout.alignment: Qt.AlignHCenter
                                            name: "disc"
                                            size: 22
                                            color: "#ffffff"
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "Fundo"
                                            font.family: "Inter, sans-serif"
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            renderType: Text.NativeRendering
                                            color: Qt.rgba(255, 255, 255, 0.85)
                                        }
                                    }

                                    MouseArea {
                                        id: wallBtnM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openWallpaperWidget()
                                    }
                                }

                                // Botão 2: Apps Launcher
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 20
                                    color: appsBtnM.containsMouse ? root.glassHoverColor : root.glassBgColor
                                    border.width: 0
                                    scale: appsBtnM.pressed ? 0.94 : (appsBtnM.containsMouse ? 1.04 : 1.0)
                                    Behavior on color { ColorAnimation { duration: 130 } }
                                    Behavior on scale { NumberAnimation { duration: 110 } }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        SvgIcon {
                                            Layout.alignment: Qt.AlignHCenter
                                            name: "apps"
                                            size: 22
                                            color: "#ffffff"
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "Apps"
                                            font.family: "Inter, sans-serif"
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            renderType: Text.NativeRendering
                                            color: Qt.rgba(255, 255, 255, 0.85)
                                        }
                                    }

                                    MouseArea {
                                        id: appsBtnM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openAppsWidget()
                                    }
                                }
                            }
                        }

                        // ── COLUNA DIREITA: OS DOIS SLIDERS VERTICAIS ESTILO iOS BUBBLE ──
                        RowLayout {
                            Layout.preferredWidth: 170
                            Layout.fillHeight: true
                            spacing: 10

                            // ── 1. SLIDER VERTICAL DE BRILHO (iOS DISPLAY BUBBLE) ──
                            Rectangle {
                                id: brCapsule
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 20
                                color: root.glassBgColor
                                border.width: 0

                                // Preenchimento Branco Líquido Subindo da Base
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: Math.max(0, parent.height * root.brightnessVal)
                                    bottomLeftRadius: 20
                                    bottomRightRadius: 20
                                    topLeftRadius: (height >= parent.height - 2) ? 20 : 0
                                    topRightRadius: (height >= parent.height - 2) ? 20 : 0
                                    color: Qt.rgba(255, 255, 255, 0.88)

                                    Behavior on height {
                                        enabled: !root.isDraggingBr
                                        NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                                    }
                                }

                                // Texto da Porcentagem no Topo
                                Text {
                                    anchors.top: parent.top
                                    anchors.topMargin: 12
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Math.round(root.brightnessVal * 100) + "%"
                                    font.family: "Inter, sans-serif"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    renderType: Text.NativeRendering
                                    color: (root.brightnessVal > 0.86) ? "#1a1a1a" : "#ffffff"
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                // Ícone do Sol na Base
                                SvgIcon {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 16
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: root.brightnessVal > 0.5 ? "sun-high" : "sun-low"
                                    size: 22
                                    color: (root.brightnessVal > 0.24) ? "#1a1a1a" : "#ffffff"
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                MouseArea {
                                    id: brMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    function updateVal(mouse) {
                                        let pct = 1.0 - (mouse.y / height)
                                        pct = Math.max(0.05, Math.min(1.0, pct))
                                        root.brightnessVal = pct
                                        root.applyBrightness(pct)
                                    }

                                    onPressed: (mouse) => {
                                        root.isDraggingBr = true
                                        updateVal(mouse)
                                    }
                                    onPositionChanged: (mouse) => { if (pressed) updateVal(mouse) }
                                    onReleased: (mouse) => {
                                        root.isDraggingBr = false
                                        updateVal(mouse)
                                    }
                                    onCanceled: root.isDraggingBr = false
                                    onWheel: (wheel) => {
                                        let step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                                        let newBr = Math.max(0.05, Math.min(1.0, root.brightnessVal + step))
                                        root.brightnessVal = newBr
                                        root.applyBrightness(newBr)
                                    }
                                }
                            }

                            // ── 2. SLIDER VERTICAL DE VOLUME (iOS SOUND BUBBLE) ──
                            Rectangle {
                                id: volCapsule
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 20
                                color: root.glassBgColor
                                border.width: 0

                                // Preenchimento Branco Líquido Subindo da Base
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: Math.max(0, parent.height * (root.isMuted ? 0.0 : root.volumeVal))
                                    bottomLeftRadius: 20
                                    bottomRightRadius: 20
                                    topLeftRadius: (height >= parent.height - 2) ? 20 : 0
                                    topRightRadius: (height >= parent.height - 2) ? 20 : 0
                                    color: root.isMuted ? "#808298" : Qt.rgba(255, 255, 255, 0.88)

                                    Behavior on height {
                                        enabled: !root.isDraggingVol
                                        NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                                    }
                                }

                                // Texto da Porcentagem no Topo
                                Text {
                                    anchors.top: parent.top
                                    anchors.topMargin: 12
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.isMuted ? "Mudo" : (Math.round(root.volumeVal * 100) + "%")
                                    font.family: "Inter, sans-serif"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    renderType: Text.NativeRendering
                                    color: (!root.isMuted && root.volumeVal > 0.86) ? "#1a1a1a" : "#ffffff"
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                // Ícone do Alto-falante na Base
                                SvgIcon {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 16
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: root.isMuted ? "volume-mute" : (root.volumeVal > 0.5 ? "speaker-high" : "speaker-low")
                                    size: 22
                                    color: (!root.isMuted && root.volumeVal > 0.24) ? "#1a1a1a" : (root.isMuted ? "#ff3b30" : "#ffffff")
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                MouseArea {
                                    id: volMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    function updateVal(mouse) {
                                        let pct = 1.0 - (mouse.y / height)
                                        pct = Math.max(0.0, Math.min(1.0, pct))
                                        root.volumeVal = pct
                                        root.isMuted = (pct === 0)
                                        root.applyVolume(pct)
                                    }

                                    onPressed: (mouse) => {
                                        root.isDraggingVol = true
                                        updateVal(mouse)
                                    }
                                    onPositionChanged: (mouse) => { if (pressed) updateVal(mouse) }
                                    onReleased: (mouse) => {
                                        root.isDraggingVol = false
                                        updateVal(mouse)
                                    }
                                    onCanceled: root.isDraggingVol = false
                                    onWheel: (wheel) => {
                                        let step = wheel.angleDelta.y > 0 ? 0.04 : -0.04
                                        let newVol = Math.max(0.0, Math.min(1.0, root.volumeVal + step))
                                        root.volumeVal = newVol
                                        root.isMuted = (newVol === 0)
                                        root.applyVolume(newVol)
                                    }
                                }
                            }
                        }
                    }

                    // ========================================================
                    // ── ROW 3: DISCORD (ESQ) + MIC & ASUS TUF POWER (DIR) ──
                    // ========================================================
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        spacing: 10

                        // Cápsula Discord
                        Rectangle {
                            Layout.preferredWidth: 170
                            Layout.fillHeight: true
                            radius: 20
                            clip: true
                            color: discordPillM.containsMouse ? root.glassHoverColor : root.glassBgColor
                            border.width: 0
                            scale: discordPillM.pressed ? 0.96 : (discordPillM.containsMouse ? 1.02 : 1.0)
                            Behavior on color { ColorAnimation { duration: 130 } }
                            Behavior on scale { NumberAnimation { duration: 110 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Rectangle {
                                    width: 34
                                    height: 34
                                    radius: 17
                                    color: Qt.rgba(255, 255, 255, 0.16)

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        name: "discord"
                                        size: 19
                                        color: "#5865F2"
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Discord"
                                        font.family: "Inter, sans-serif"
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        renderType: Text.NativeRendering
                                        color: "#ffffff"
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: "Online"
                                        font.family: "Inter, sans-serif"
                                        font.pixelSize: 10
                                        renderType: Text.NativeRendering
                                        color: Qt.rgba(255, 255, 255, 0.70)
                                    }
                                }
                            }

                            MouseArea {
                                id: discordPillM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.exec("hyprctl clients | grep -q 'class: discord' && hyprctl dispatch focuswindow class:discord || /home/gabriel/.local/bin/discord &")
                                    root.hideIsland()
                                }
                            }
                        }

                        // Cápsula Microfone (Sincronizada com Discord)
                        Rectangle {
                            Layout.preferredWidth: 170
                            Layout.fillHeight: true
                            radius: 20
                            clip: true
                            color: root.isMicMuted ? Qt.rgba(255/255, 59/255, 48/255, 0.32) : (micBtnM.containsMouse ? root.glassHoverColor : root.glassBgColor)
                            border.width: 0
                            scale: micBtnM.pressed ? 0.96 : (micBtnM.containsMouse ? 1.02 : 1.0)
                            Behavior on color { ColorAnimation { duration: 130 } }
                            Behavior on scale { NumberAnimation { duration: 110 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Rectangle {
                                    width: 34
                                    height: 34
                                    radius: 17
                                    color: root.isMicMuted ? Qt.rgba(255/255, 59/255, 48/255, 0.40) : Qt.rgba(255, 255, 255, 0.16)
                                    Behavior on color { ColorAnimation { duration: 130 } }

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        name: root.isMicMuted ? "mic-mute" : "mic"
                                        size: 19
                                        color: root.isMicMuted ? "#ff3b30" : "#ffffff"
                                        Behavior on color { ColorAnimation { duration: 130 } }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Microfone"
                                        font.family: "Inter, sans-serif"
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        renderType: Text.NativeRendering
                                        color: "#ffffff"
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.isMicMuted ? "Mutado" : "Ativado"
                                        font.family: "Inter, sans-serif"
                                        font.pixelSize: 10
                                        renderType: Text.NativeRendering
                                        color: root.isMicMuted ? "#ff3b30" : Qt.rgba(255, 255, 255, 0.70)
                                        Behavior on color { ColorAnimation { duration: 130 } }
                                    }
                                }
                            }

                            MouseArea {
                                id: micBtnM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
                                    root.isMicMuted = !root.isMicMuted
                                }
                            }
                        }
                    }

                    // ========================================================
                    // ── ROW 4: MODO TURBO TOGGLE (CHAVE APPLE) ──────────────
                    // ========================================================
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 54
                        radius: 20
                        clip: true
                        color: root.glassBgColor
                        border.width: 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 14
                            spacing: 10

                            // Badge Circular de Ícone (Flame)
                            Rectangle {
                                width: 36
                                height: 36
                                radius: 18
                                color: root.activePowerMode === "turbo" ? Qt.rgba(255/255, 71/255, 87/255, 0.28) : Qt.rgba(255, 255, 255, 0.12)
                                Behavior on color { ColorAnimation { duration: 180 } }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    name: "flame"
                                    size: 19
                                    color: root.activePowerMode === "turbo" ? "#ff4757" : "#ffffff"
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                            }

                            // Títulos e Status
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: "Modo Turbo (Overclock & Fans)"
                                    font.family: "Inter, sans-serif"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    renderType: Text.NativeRendering
                                    color: "#ffffff"
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.activePowerMode === "turbo" ? "Ativado • Fans máximas & Boost extremo" : "Desativado • Desempenho normal (fans suaves)"
                                    font.family: "Inter, sans-serif"
                                    font.pixelSize: 10
                                    renderType: Text.NativeRendering
                                    color: root.activePowerMode === "turbo" ? "#ff4757" : Qt.rgba(255, 255, 255, 0.65)
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                            }

                            // Interruptor Deslizante Estilo Apple (Chave Liga/Desliga)
                            Rectangle {
                                id: turboSwitchTrack
                                width: 48
                                height: 26
                                radius: 13
                                color: root.activePowerMode === "turbo" ? "#ff4757" : Qt.rgba(255, 255, 255, 0.18)
                                border.width: root.activePowerMode === "turbo" ? 0 : 1
                                border.color: Qt.rgba(255, 255, 255, 0.25)
                                scale: turboSwitchM.pressed ? 0.94 : (turboSwitchM.containsMouse ? 1.04 : 1.0)

                                Behavior on color { ColorAnimation { duration: 180 } }
                                Behavior on scale { NumberAnimation { duration: 110 } }

                                // Botão deslizante branco (Thumb)
                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: root.activePowerMode === "turbo" ? (parent.width - width - 2) : 2
                                    color: "#ffffff"

                                    Behavior on x {
                                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                    }
                                }

                                MouseArea {
                                    id: turboSwitchM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const next = root.activePowerMode === "turbo" ? "performance" : "turbo"
                                        root.setPowerMode(next)
                                    }
                                }
                            }
                        }
                    }

                    // ========================================================
                    // ── ROW 4: XWAYLAND / GAMING MODE TOGGLE (APPLE SWITCH) ──
                    // ========================================================
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.xwaylandRestartPending ? 72 : 54
                        radius: 20
                        clip: true
                        color: root.xwaylandRestartPending ? Qt.rgba(255/255, 149/255, 0/255, 0.24) : root.glassBgColor
                        border.width: root.xwaylandRestartPending ? 1 : 0
                        border.color: root.xwaylandRestartPending ? "#ff9500" : "transparent"

                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Behavior on border.color { ColorAnimation { duration: 180 } }

                        // ── Vista Normal (Interruptor Deslizante Estilo Apple) ──
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 14
                            spacing: 10
                            visible: !root.xwaylandRestartPending

                            // Badge Circular de Ícone
                            Rectangle {
                                width: 36
                                height: 36
                                radius: 18
                                color: root.xwaylandEnabled ? Qt.rgba(52/255, 199/255, 89/255, 0.28) : Qt.rgba(255, 255, 255, 0.12)
                                Behavior on color { ColorAnimation { duration: 180 } }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    name: "rocket"
                                    size: 19
                                    color: root.xwaylandEnabled ? "#34c759" : "#ffffff"
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                            }

                            // Títulos e Status
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: "Xwayland (Compatibilidade Jogos)"
                                    font.family: "Inter, sans-serif"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    renderType: Text.NativeRendering
                                    color: "#ffffff"
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.xwaylandEnabled ? "Ativado • Suporta jogos X11" : "Desativado • +105 MB RAM livres"
                                    font.family: "Inter, sans-serif"
                                    font.pixelSize: 10
                                    renderType: Text.NativeRendering
                                    color: root.xwaylandEnabled ? "#34c759" : Qt.rgba(255, 255, 255, 0.65)
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }
                            }

                            // Interruptor Deslizante Estilo Apple (Chave Liga/Desliga)
                            Rectangle {
                                id: xwaylandSwitchTrack
                                width: 48
                                height: 26
                                radius: 13
                                color: root.xwaylandEnabled ? "#34c759" : Qt.rgba(255, 255, 255, 0.18)
                                border.width: root.xwaylandEnabled ? 0 : 1
                                border.color: Qt.rgba(255, 255, 255, 0.25)
                                scale: switchMouse.pressed ? 0.94 : (switchMouse.containsMouse ? 1.04 : 1.0)

                                Behavior on color { ColorAnimation { duration: 180 } }
                                Behavior on scale { NumberAnimation { duration: 110 } }

                                // Botão deslizante branco (Thumb)
                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: root.xwaylandEnabled ? (parent.width - width - 2) : 2
                                    color: "#ffffff"

                                    Behavior on x {
                                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                    }
                                }

                                MouseArea {
                                    id: switchMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleXwayland()
                                }
                            }
                        }

                        // ── Vista de Contagem Regressiva para Reinicialização ──
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8
                            visible: root.xwaylandRestartPending

                            // Círculo com Contagem Regressiva
                            Rectangle {
                                width: 38
                                height: 38
                                radius: 19
                                color: Qt.rgba(255/255, 149/255, 0/255, 0.35)

                                Text {
                                    anchors.centerIn: parent
                                    text: root.xwaylandCountdown + "s"
                                    font.family: "Inter, sans-serif"
                                    font.pixelSize: 15
                                    font.weight: Font.Black
                                    color: "#ff9500"
                                }
                            }

                            // Textos de Alerta
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: root.xwaylandEnabled ? "Ativando Xwayland..." : "Desativando Xwayland..."
                                    font.family: "Inter, sans-serif"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    renderType: Text.NativeRendering
                                    color: "#ffffff"
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Reiniciando o PC em " + root.xwaylandCountdown + "s para aplicar..."
                                    font.family: "Inter, sans-serif"
                                    font.pixelSize: 10
                                    renderType: Text.NativeRendering
                                    color: "#ff9500"
                                }
                            }

                            // Botão Cancelar
                            Rectangle {
                                width: 68
                                height: 30
                                radius: 15
                                color: cancelMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.25) : Qt.rgba(255, 255, 255, 0.15)
                                scale: cancelMouse.pressed ? 0.92 : 1.0

                                Behavior on scale { NumberAnimation { duration: 90 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Cancelar"
                                    font.family: "Inter, sans-serif"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: "#ffffff"
                                }

                                MouseArea {
                                    id: cancelMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.cancelXwaylandCountdown()
                                }
                            }

                            // Botão Reiniciar Agora
                            Rectangle {
                                width: 64
                                height: 30
                                radius: 15
                                color: rebootNowMouse.containsMouse ? "#ff3b30" : Qt.rgba(255/255, 59/255, 48/255, 0.85)
                                scale: rebootNowMouse.pressed ? 0.92 : 1.0

                                Behavior on scale { NumberAnimation { duration: 90 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Reiniciar"
                                    font.family: "Inter, sans-serif"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: "#ffffff"
                                }

                                MouseArea {
                                    id: rebootNowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.rebootNow()
                                }
                            }
                        }
                    }
                }
            }

            // ========================================================
            // PÁGINA 1: WIDGET DE WI-FI (LISTAGEM, SENHA, ESQUECER)
            // ========================================================
            WifiWidget {
                id: wifiWidget
                controlCenter: root
                anchors.top: parent.top
                width: parent.width
                transformOrigin: Item.Top

                scale: root.currentView === "wifi" ? 1.0 : 0.93
                opacity: root.currentView === "wifi" ? 1 : 0
                enabled: root.currentView === "wifi"
                visible: opacity > 0.005

                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
            }

            // ========================================================
            // PÁGINA 2: WIDGET DE BLUETOOTH (LISTAGEM, PAREAR, ESQUECER)
            // ========================================================
            BluetoothWidget {
                id: btWidget
                controlCenter: root
                anchors.top: parent.top
                width: parent.width
                transformOrigin: Item.Top

                scale: root.currentView === "bluetooth" ? 1.0 : 0.93
                opacity: root.currentView === "bluetooth" ? 1 : 0
                enabled: root.currentView === "bluetooth"
                visible: opacity > 0.005

                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
            }

            // ========================================================
            // PÁGINA 3: WIDGET DE WALLPAPERS (SELETOR VISUAL)
            // ========================================================
            WallpaperWidget {
                id: wallpaperWidget
                controlCenter: root
                anchors.top: parent.top
                width: parent.width
                transformOrigin: Item.Top

                scale: root.currentView === "wallpaper" ? 1.0 : 0.93
                opacity: root.currentView === "wallpaper" ? 1 : 0
                enabled: root.currentView === "wallpaper"
                visible: opacity > 0.005

                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
            }

            // ========================================================
            // PÁGINA 4: WIDGET DE APLICATIVOS (LAUNCHER & BUSCA)
            // ========================================================
            AppsWidget {
                id: appsWidget
                controlCenter: root
                anchors.top: parent.top
                width: parent.width
                transformOrigin: Item.Top

                scale: root.currentView === "apps" ? 1.0 : 0.93
                opacity: root.currentView === "apps" ? 1 : 0
                enabled: root.currentView === "apps"
                visible: opacity > 0.005

                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
            }
        }
        }
    }
}
