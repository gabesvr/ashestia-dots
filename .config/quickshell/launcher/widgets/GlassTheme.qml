pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Estado global do tema dos widgets: vidro líquido (false) ou sólido cinza-escuro (true)
Singleton {
    id: theme

    // Pasta do usuário (nada de caminho fixo: o rice roda em qualquer $HOME)
    readonly property string home: Quickshell.env("HOME")

    property bool solid: false
    // Ponto de origem da "onda" de transição (centro do botão-chave)
    property real originX: 0
    property real originY: 0
    // Só anima depois do carregamento inicial (evita animar ao iniciar o shell)
    property bool animate: false

    readonly property string stateFile: theme.home + "/.config/quickshell/theme_mode.json"

    // Modo gaming (tile "Gaming" / ~/.local/bin/gaming-mode): vidro vira sólido sem shader,
    // animações e cava desligados. Estado no arquivo lido também pelo Hyprland e pelo fish.
    property bool gaming: false
    readonly property bool effectiveSolid: solid || gaming

    function toggleGaming() {
        gaming = !gaming;   // resposta imediata; o arquivo confirma logo depois
        gamingProc.command = ["systemd-run", "--user", "--scope", "--quiet", "--collect",
                              theme.home + "/.local/bin/gaming-mode", gaming ? "on" : "off"];
        gamingProc.running = false;
        gamingProc.running = true;
    }

    Process {
        id: gamingProc
        running: false
    }

    FileView {
        id: gamingFile
        path: theme.home + "/.config/hypr/gaming_mode"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: theme.gaming = text().trim() === "on"
    }

    // Notificações (mako) acompanham o tema: modo "glass" = vidro claro, sem ele = sólido
    onEffectiveSolidChanged: syncMako()
    function syncMako() {
        makoProc.command = ["makoctl", "mode", effectiveSolid ? "-r" : "-a", "glass"];
        makoProc.running = false;
        makoProc.running = true;
    }

    Process {
        id: makoProc
        running: false
    }

    function toggle() {
        solid = !solid;
        saver.command = ["sh", "-c", "echo '{\"solid\":" + (solid ? "true" : "false") + "}' > " + stateFile];
        saver.running = false;
        saver.running = true;
    }

    Process {
        id: saver
        running: false
    }

    Process {
        id: loader
        command: ["cat", theme.stateFile]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const d = JSON.parse(line.trim());
                    theme.solid = !!d.solid;
                } catch (e) {}
            }
        }
        onExited: armTimer.start()
    }

    Timer {
        id: armTimer
        interval: 900
        onTriggered: { theme.animate = true; theme.syncMako(); }
    }
}
