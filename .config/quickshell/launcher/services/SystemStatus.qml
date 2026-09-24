pragma Singleton
import QtQuick
import "../widgets"
import Quickshell
import Quickshell.Io

// Estado do sistema lido pelo controls_status (um processo só, saída JSON a cada 1,2 s).
// Propriedades graváveis: o shell faz atualização otimista e o poller confirma.
Singleton {
    id: st
    property real volume: 0.5
    property bool muted: false
    property int brightness: 80
    property bool wifiOn: true
    property string wifiSsid: "Wi-Fi"
    property bool btOn: false
    property int power: 1                 // 0 silencioso · 1 equilibrado · 2 desempenho
    property double powerHoldUntil: 0     // ignora o poller logo após um clique (o power-mode leva ~1 s)
    property bool dnd: false
    property bool xwayland: false

    function restart() { poller.running = true; }

    Process {
        id: poller
        command: [GlassTheme.home + "/.config/quickshell/scripts/controls_status"]
        running: true
        onExited: restartTimer.start()
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const d = JSON.parse(line.trim());
                    if (d.vol !== undefined) { st.volume = d.vol; st.muted = d.muted; }
                    if (d.br !== undefined) st.brightness = d.br;
                    if (d.wifi_on !== undefined) st.wifiOn = d.wifi_on;
                    if (d.wifi_ssid !== undefined) st.wifiSsid = d.wifi_ssid;
                    if (d.bt_on !== undefined) st.btOn = d.bt_on;
                    if (d.power !== undefined && Date.now() > st.powerHoldUntil) st.power = d.power;
                    if (d.dnd !== undefined) st.dnd = d.dnd;
                    if (d.xwayland !== undefined) st.xwayland = d.xwayland;
                } catch (e) {}
            }
        }
    }
    Timer { id: restartTimer; interval: 2000; onTriggered: poller.running = true }
}
