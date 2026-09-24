import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects

// Visualizador de áudio (cava) em Liquid Glass. Cores = gradiente do cava do terminal (~/.config/cava/config, gerado pelo matugen).
Item {
    id: root
    anchors.fill: parent

    property alias cardItem: full
    property alias sharedBackdrop: glass.sharedBackdrop

    function setWallpaper(path) {
        glass.setWallpaper(path);
    }

    property real targetX: 1158
    property real targetY: 832
    property real targetWidth: 340
    property real targetHeight: 90
    property string variant: "classic"   // visual escolhido pelo layout ("classic" = o de sempre)
    // Some com animação quando o layout atual não tem espaço para ele (ex.: painel expandido)
    property bool shown: true

    // Troca de wallpaper → o matugen regrava o config do cava; relê as cores depois
    property string wallpaper: ""
    onWallpaperChanged: { colorRetry.count = 0; colorRetry.restart(); }

    // Estilo: barras a partir da base ou espelhadas no centro. Cartões baixos ficam espelhados sempre.
    property bool mirrorPref: false
    readonly property bool mirror: mirrorPref || targetHeight < 72

    // ── Níveis vindos do cava (0..1) ──
    // O cava gera exatamente as barras que cabem no card (estéreo: graves no centro, como no terminal)
    property int cavaBars: 32
    property var levels: []
    property bool silent: true

    // ── Cores (matugen) ──
    property color c1: "#bece7f"
    property color c2: "#daea98"
    property color c3: "#c5caa8"
    property color c4: "#a1d0c4"
    Behavior on c1 { enabled: !GlassTheme.gaming; ColorAnimation { duration: 700 } }
    Behavior on c2 { enabled: !GlassTheme.gaming; ColorAnimation { duration: 700 } }
    Behavior on c3 { enabled: !GlassTheme.gaming; ColorAnimation { duration: 700 } }
    Behavior on c4 { enabled: !GlassTheme.gaming; ColorAnimation { duration: 700 } }

    function parseColors(txt) {
        const g = {};
        const re = /gradient_color_(\d+)\s*=\s*'?(#[0-9a-fA-F]{6})'?/g;
        let mt;
        while ((mt = re.exec(txt)) !== null) g[parseInt(mt[1])] = mt[2];
        // 1 primary → 3 primary_fixed → 5 secondary → 8 tertiary (6 é secondary_container, escuro demais)
        if (g[1]) root.c1 = g[1];
        if (g[3]) root.c2 = g[3];
        if (g[5]) root.c3 = g[5];
        if (g[8]) root.c4 = g[8];
    }

    FileView {
        id: cavaColors
        path: "/home/gabriel/.config/cava/config"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseColors(text())
    }

    Timer {
        id: colorRetry
        property int count: 0
        interval: 1200
        onTriggered: {
            cavaColors.reload();
            if (++count < 3) restart();
        }
    }

    // ── Processo cava (saída raw ASCII: "v;v;...;\n" por frame) ──
    readonly property bool active: shown && full.opacity > 0.01 && visible && !GlassTheme.gaming
    // running é reatribuído pelos timers (quebra o binding) → segue "active" explicitamente
    onActiveChanged: cavaProc.running = root.active

    readonly property string runConf: "/run/user/1000/qs-cava-widget.conf"
    Process {
        id: cavaProc
        command: ["sh", "-c",
            "sed 's/^bars = .*/bars = " + root.cavaBars + "/' /home/gabriel/.config/quickshell/cava/widget.conf > " + root.runConf +
            " && exec cava -p " + root.runConf]
        running: root.active
        stdout: SplitParser {
            onRead: (line) => {
                const parts = line.split(";");
                const n = root.cavaBars;
                const out = new Array(n);
                let sum = 0;
                for (let i = 0; i < n; i++) {
                    const v = Math.min(1, (parseInt(parts[i]) || 0) / 1000);
                    out[i] = v;
                    sum += v;
                }
                root.levels = out;
                if (sum > 0.02) { root.silent = false; silenceTimer.restart(); }
            }
        }
        // Se o cava cair (ex.: pipewire reiniciou), tenta de novo
        onExited: if (root.active) restartTimer.restart()
    }
    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: if (root.active && !cavaProc.running) cavaProc.running = true
    }
    // Largura mudou (troca de layout) → reinicia o cava com o novo nº de barras quando a animação assenta
    Timer {
        id: barsTimer
        interval: 700
        onTriggered: {
            if (root.cavaBars === stage.count) return;
            root.cavaBars = stage.count;
            if (cavaProc.running) { cavaProc.running = false; cavaProc.running = true; }
        }
    }
    Timer {
        id: silenceTimer
        interval: 1500
        onTriggered: root.silent = true
    }

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

        opacity: root.shown ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        scale: !root.shown ? 0.85 : (cardMouse.pressed ? 0.96 : (cardMouse.containsMouse ? 1.02 : 1.0))
        Behavior on scale { enabled: !GlassTheme.gaming; NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

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

        // ── Barras ──
        Item {
            id: stage
            anchors.fill: parent
            anchors.leftMargin: Math.max(14, glass.radius * 0.55)
            anchors.rightMargin: anchors.leftMargin
            anchors.topMargin: 12
            anchors.bottomMargin: 12

            readonly property real gap: width < 240 ? 3 : 4
            readonly property real barW: width < 240 ? 4 : 5
            // par, p/ os dois canais do estéreo ficarem simétricos
            readonly property int count: Math.max(8, Math.floor((width + gap) / (barW + gap))) & ~1
            onCountChanged: barsTimer.restart()
            Component.onCompleted: root.cavaBars = count
            readonly property real used: count * barW + (count - 1) * gap
            readonly property real minH: barW

            // Máscara (barras brancas) — só serve de alfa para o gradiente
            Item {
                id: barsMask
                anchors.fill: parent
                visible: false
                layer.enabled: true

                Repeater {
                    model: stage.count
                    Rectangle {
                        required property int index
                        // 1 barra = 1 bin do cava, sem animação extra (o cava já tem a própria queda/gravidade)
                        width: stage.barW
                        height: Math.max(stage.minH, (root.levels[index] || 0) * stage.height)
                        radius: width / 2
                        x: (stage.width - stage.used) / 2 + index * (stage.barW + stage.gap)
                        // y calculado (sem âncoras: trocar âncora em runtime deixava as barras presas ao alternar o modo)
                        y: root.mirror ? Math.round((stage.height - height) / 2) : stage.height - height
                        color: "white"
                    }
                }
            }

            // Gradiente absoluto (como o cava do terminal): base = primary → topo = tertiary.
            // Espelhado: primary no centro → tertiary nas pontas.
            Rectangle {
                id: gradFill
                anchors.fill: parent
                visible: false
                layer.enabled: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.c4 }
                    GradientStop { position: root.mirror ? 0.25 : 0.35; color: root.mirror ? root.c2 : root.c3 }
                    GradientStop { position: root.mirror ? 0.5 : 0.7; color: root.mirror ? root.c1 : root.c2 }
                    GradientStop { position: root.mirror ? 0.75 : 0.9; color: root.mirror ? root.c2 : root.c1 }
                    GradientStop { position: 1.0; color: root.mirror ? root.c4 : root.c1 }
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: gradFill
                maskEnabled: true
                maskSource: barsMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0.5
                opacity: root.silent ? 0.45 : 0.95
                Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 400 } }
            }
        }

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.mirrorPref = !root.mirrorPref
            onPositionChanged: (mouse) => {
                glass.mouseU = mouse.x / Math.max(1, full.width);
                glass.mouseV = mouse.y / Math.max(1, full.height);
                glass.mouseFade = 1;
            }
            onEntered: glass.mouseFade = 1
            onExited: {
                glass.mouseFade = 0;
                glass.mouseU = -1;
                glass.mouseV = -1;
            }
        }
    }
}
