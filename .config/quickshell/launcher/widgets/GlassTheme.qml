pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Estado global do tema dos widgets: vidro líquido (false) ou sólido cinza-escuro (true)
Singleton {
    id: theme

    property bool solid: false
    // Ponto de origem da "onda" de transição (centro do botão-chave)
    property real originX: 0
    property real originY: 0
    // Só anima depois do carregamento inicial (evita animar ao iniciar o shell)
    property bool animate: false

    readonly property string stateFile: "/home/gabriel/.config/quickshell/theme_mode.json"

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
        onTriggered: theme.animate = true
    }
}
