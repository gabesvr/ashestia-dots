pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Música (MPRIS via playerctl): um processo --follow só, compartilhado por todas as variantes do player.
// Posição interpolada a cada 50 ms e reancorada no playerctl (1 s; 250 ms em players de posição grossa).
Singleton {
    id: svc

    property string title: "minor"
    property string artist: "Gracie Abrams"
    property string artUrl: ""
    property string status: "Paused"
    property real position: 26  // 0:26
    property real length: 161   // 2:41
    readonly property bool isPlaying: status === "Playing"

    // High-precision MPRIS position sync & sub-second clock
    property string _lastMediaArtUrl: ""
    property real positionMs: position * 1000
    property real _lastAnchorRealSec: 0
    property real _lastAnchorSystemTimeMs: 0

    function syncWithRealPosition(sec) {
        if (isNaN(sec) || sec < 0) return;
        _lastAnchorRealSec = sec;
        _lastAnchorSystemTimeMs = Date.now();
        position = sec;
        positionMs = sec * 1000;
    }

    // Player seguido pelo mediaFollower (posição/controles vão sempre p/ ele, não p/ "o primeiro" do playerctl)
    property string playerName: ""
    // Firefox/YouTube reporta a posição truncada em segundos inteiros → posição real ∈ [sec, sec + 1)
    property bool coarsePosition: false

    Process {
        id: posQueryProc
        command: svc.playerName ? ["playerctl", "-p", svc.playerName, "position"] : ["playerctl", "position"]
        stdout: SplitParser {
            onRead: (line) => {
                const sec = parseFloat(line.trim());
                if (isNaN(sec) || sec < 0) return;
                const coarse = Math.abs(sec - Math.round(sec)) < 0.001;
                svc.coarsePosition = coarse;
                if (svc._lastAnchorSystemTimeMs === 0) {
                    svc.syncWithRealPosition(coarse ? sec + 0.5 : sec);
                    return;
                }
                const elapsed = (Date.now() - svc._lastAnchorSystemTimeMs) / 1000;
                const expectedSec = svc._lastAnchorRealSec + elapsed;
                // Só corrige se a estimativa saiu da faixa possível; seek grande → reancora direto
                const lo = coarse ? sec : sec - 0.15;
                const hi = coarse ? sec + 1.0 : sec + 0.15;
                if (Math.abs(expectedSec - sec) > 3) svc.syncWithRealPosition(coarse ? sec + 0.5 : sec);
                else if (expectedSec < lo) svc.syncWithRealPosition(lo);
                else if (expectedSec > hi) svc.syncWithRealPosition(hi);
            }
        }
    }

    Process {
        id: mediaFollower
        command: ["playerctl", "metadata", "--follow", "--format",
            "{{title}}│{{artist}}│{{mpris:artUrl}}│{{xesam:url}}│{{position}}│{{mpris:length}}│{{status}}│{{playerName}}"
        ]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const parts = line.trim().split("│");
                    if (parts.length < 8) return;

                    const title   = parts[0] || "";
                    const artist  = parts[1] || "";
                    const artUrl  = parts[2] || "";
                    const url     = parts[3] || "";
                    const pos     = parseInt(parts[4]) || 0;
                    const len     = parseInt(parts[5]) || 0;
                    const stat    = parts[6] || "Stopped";
                    const player  = parts[7] || "";

                    if (stat !== "Stopped") {
                        if (player && player !== svc.playerName) {
                            svc.playerName = player;
                            svc._lastAnchorSystemTimeMs = 0;
                        }
                        svc.title = title || "Unknown";
                        svc.artist = artist || "Unknown Artist";

                        let art = artUrl;
                        if (!art && url) {
                            let vid = "";
                            const rxWatch = url.match(/[?&]v=([a-zA-Z0-9_-]{11})/);
                            if (rxWatch) {
                                vid = rxWatch[1];
                            } else {
                                const rxShort = url.match(/youtu\.be\/([a-zA-Z0-9_-]{11})/);
                                if (rxShort) {
                                    vid = rxShort[1];
                                } else {
                                    const rxEmbed = url.match(/\/(?:embed|shorts|v)\/([a-zA-Z0-9_-]{11})/);
                                    if (rxEmbed) vid = rxEmbed[1];
                                }
                            }
                            if (vid) {
                                art = "https://img.youtube.com/vi/" + vid + "/maxresdefault.jpg";
                            }
                        }

                        if (art !== svc._lastMediaArtUrl) {
                            svc._lastMediaArtUrl = art;
                            svc.artUrl = art;
                        }

                        svc.length = len > 0 ? (len / 1000000) : 0;
                        svc.status = stat;
                    } else {
                        svc.status = "Stopped";
                    }
                } catch (e) {}
            }
        }
    }

    // Consulta periódica (1s) para reancorar e evitar drift
    Timer {
        id: posAnchorTimer
        interval: svc.coarsePosition ? 250 : 1000
        running: svc.isPlaying
        repeat: true
        onTriggered: {
            if (!posQueryProc.running) posQueryProc.running = true;
        }
    }

    // Interpolação suave a cada 50ms para lyrics 100% em tempo real com Spotify
    Timer {
        id: preciseTickTimer
        interval: 50
        running: svc.isPlaying
        repeat: true
        onTriggered: {
            if (svc._lastAnchorSystemTimeMs > 0) {
                const elapsed = Date.now() - svc._lastAnchorSystemTimeMs;
                const curSec = svc._lastAnchorRealSec + (elapsed / 1000);
                if (svc.length > 0 && curSec <= svc.length) {
                    svc.position = curSec;
                    svc.positionMs = curSec * 1000;
                }
            }
        }
    }

    onStatusChanged: {
        if (isPlaying) {
            posQueryProc.running = true;
        } else {
            _lastAnchorSystemTimeMs = 0;
        }
    }

    onTitleChanged: {
        _lastAnchorSystemTimeMs = 0;
        posQueryProc.running = true;
    }

    // Command executions
    Process { id: playPauseCmd; command: svc.playerName ? ["playerctl", "-p", svc.playerName, "play-pause"] : ["playerctl", "play-pause"] }
    Process { id: prevCmd;      command: svc.playerName ? ["playerctl", "-p", svc.playerName, "previous"] : ["playerctl", "previous"] }
    Process { id: nextCmd;      command: svc.playerName ? ["playerctl", "-p", svc.playerName, "next"] : ["playerctl", "next"] }
    Process { id: seekCmd }

    function togglePlay() {
        svc.status = svc.isPlaying ? "Paused" : "Playing";
        playPauseCmd.running = true;
    }

    function previous() {
        prevCmd.running = true;
    }

    function next() {
        nextCmd.running = true;
    }

    function seek(sec) {
        svc.syncWithRealPosition(sec);
        seekCmd.command = (svc.playerName ? ["playerctl", "-p", svc.playerName] : ["playerctl"]).concat(["position", String(sec.toFixed(2))]);
        seekCmd.running = true;
    }
}
