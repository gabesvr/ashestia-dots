pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../widgets"

// Bateria (scripts/battery_tool.sh): um poller só; 5 s normalmente, 2 s com algum painel aberto (fast).
Singleton {
    id: svc
    property bool present: true          // false em desktop sem bateria (o tile some)
    property int percent: 0
    property string status: "Unknown"
    readonly property bool charging: status === "Charging"
    property bool onAc: false
    property real watts: 0
    property int minutes: -1
    property int health: 0
    property int cycles: 0
    property int chargeLimit: 100
    property string powerMode: ""
    property bool fast: false

    function refresh(args) {
        proc.command = [GlassTheme.home + "/.config/quickshell/scripts/battery_tool.sh"].concat(args || []);
        proc.running = false;
        proc.running = true;
    }
    function setLimit(n) {
        chargeLimit = n;
        refresh(["limit", String(n)]);
    }

    Process {
        id: proc
        command: [GlassTheme.home + "/.config/quickshell/scripts/battery_tool.sh"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const d = JSON.parse(line.trim());
                    svc.present = d.present !== false;
                    if (!svc.present) return;
                    svc.percent = d.percent;
                    svc.status = d.status;
                    svc.onAc = d.ac;
                    svc.watts = d.watts;
                    svc.minutes = d.minutes;
                    svc.health = d.health;
                    svc.cycles = d.cycles;
                    svc.chargeLimit = d.limit;
                    svc.powerMode = d.mode;
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: svc.fast ? 2000 : 5000
        repeat: true
        running: !GlassTheme.gaming
        onTriggered: if (!proc.running) svc.refresh()
    }
}
