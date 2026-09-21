import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: musicWindow
    anchors.fill: parent

    property alias cardItem: full
    property alias sharedBackdrop: glass.sharedBackdrop

    FontLoader {
        id: sfRegular
        source: Qt.resolvedUrl("fonts/sf_pro_display_regular.otf")
    }

    // Animated Target Position (Driven by Layout Manager)
    property real targetX: 1530
    property real targetY: 420
    property real targetWidth: 340
    property real targetHeight: 160
    property real tallHeight: 420   // altura do modo lyrics (definida pelo layout)

    function setWallpaper(path) {
        glass.setWallpaper(path);
    }

    // Layout mode: "wide" (default) | "bar" (compact pill) | "tall" (lyrics)
    property string layoutMode: "wide"
    readonly property bool isLyricsOpen: layoutMode === "tall"

    // Media properties
    property string trackTitle: "minor"
    property string trackArtist: "Gracie Abrams"
    property string trackArtUrl: ""
    property string playerStatus: "Paused"
    property real playbackPos: 26  // 0:26
    property real playbackLen: 161 // 2:41
    property bool isPlaying: playerStatus === "Playing"

    // Synced Lyrics state
    property var syncedLyrics: [
        { timestamp: 0, text: "I would drive all night to get to you" },
        { timestamp: 4000, text: "But my curfew is early and mom's up at home" },
        { timestamp: 9000, text: "I would run for miles to get to you" },
        { timestamp: 14000, text: "But you gotta understand, I can't 'cause" },
        { timestamp: 19000, text: "M-I-N-O-R" },
        { timestamp: 24000, text: "I'm minorly stuck" },
        { timestamp: 28000, text: "And it's not your fault" }
    ]
    property string lyricsTrackKey: ""

    // High-precision MPRIS position sync & sub-second clock
    property string _lastMediaArtUrl: ""
    property real precisePositionMs: playbackPos * 1000
    property real _lastAnchorRealSec: 0
    property real _lastAnchorSystemTimeMs: 0

    function syncWithRealPosition(sec) {
        if (isNaN(sec) || sec < 0) return;
        _lastAnchorRealSec = sec;
        _lastAnchorSystemTimeMs = Date.now();
        playbackPos = sec;
        precisePositionMs = sec * 1000;
    }

    Process {
        id: posQueryProc
        command: ["playerctl", "position"]
        stdout: SplitParser {
            onRead: (line) => {
                const sec = parseFloat(line.trim());
                if (!isNaN(sec) && sec >= 0) {
                    if (musicWindow._lastAnchorSystemTimeMs === 0) {
                        musicWindow.syncWithRealPosition(sec);
                    } else {
                        const elapsed = (Date.now() - musicWindow._lastAnchorSystemTimeMs) / 1000;
                        const expectedSec = musicWindow._lastAnchorRealSec + elapsed;
                        if (Math.abs(sec - expectedSec) > 0.15) {
                            musicWindow.syncWithRealPosition(sec);
                        }
                    }
                }
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

                    if (stat !== "Stopped") {
                        musicWindow.trackTitle = title || "Unknown";
                        musicWindow.trackArtist = artist || "Unknown Artist";

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

                        if (art !== musicWindow._lastMediaArtUrl) {
                            musicWindow._lastMediaArtUrl = art;
                            musicWindow.trackArtUrl = art;
                        }

                        musicWindow.playbackLen = len > 0 ? (len / 1000000) : 0;
                        musicWindow.playerStatus = stat;
                    } else {
                        musicWindow.playerStatus = "Stopped";
                    }
                } catch (e) {}
            }
        }
    }

    // Consulta periódica (1s) para reancorar e evitar drift
    Timer {
        id: posAnchorTimer
        interval: 1000
        running: musicWindow.isPlaying
        repeat: true
        onTriggered: {
            if (!posQueryProc.running) posQueryProc.running = true;
        }
    }

    // Interpolação suave a cada 50ms para lyrics 100% em tempo real com Spotify
    Timer {
        id: preciseTickTimer
        interval: 50
        running: musicWindow.isPlaying
        repeat: true
        onTriggered: {
            if (musicWindow._lastAnchorSystemTimeMs > 0) {
                const elapsed = Date.now() - musicWindow._lastAnchorSystemTimeMs;
                const curSec = musicWindow._lastAnchorRealSec + (elapsed / 1000);
                if (musicWindow.playbackLen > 0 && curSec <= musicWindow.playbackLen) {
                    musicWindow.playbackPos = curSec;
                    musicWindow.precisePositionMs = curSec * 1000;
                }
            }
        }
    }

    onPlayerStatusChanged: {
        if (isPlaying) {
            posQueryProc.running = true;
        } else {
            _lastAnchorSystemTimeMs = 0;
        }
    }

    onTrackTitleChanged: {
        _lastAnchorSystemTimeMs = 0;
        posQueryProc.running = true;
        checkFetchLyrics(trackTitle, trackArtist, playbackLen);
    }
    onTrackArtistChanged: checkFetchLyrics(trackTitle, trackArtist, playbackLen)

    Component.onCompleted: {
        if (trackTitle && trackArtist) {
            checkFetchLyrics(trackTitle, trackArtist, playbackLen);
        }
    }

    function cleanTrackTitle(title) {
        if (!title) return "";
        var clean = title;
        // Remove (feat. ...), [feat. ...], (with ...), [with ...]
        clean = clean.replace(/[\(\[](feat|ft|with)[\.\s][^\)\]]+[\)\]]/gi, "");
        // Remove - Remastered..., (Remastered...)
        clean = clean.replace(/[\(\-]?\s*remaster(ed)?(\s*\d{4})?\s*[\)]?/gi, "");
        // Remove - Live..., (Live...)
        clean = clean.replace(/[\(\-]?\s*live(\s*(at|in|from)[^\)\]]+)?\s*[\)]?/gi, "");
        // Remove - Bonus Track, [Bonus Track]
        clean = clean.replace(/[\(\-]?\s*bonus\s*track\s*[\)]?/gi, "");
        // Remove trailing dashes or spaces
        clean = clean.replace(/\s*-\s*$/, "").trim();
        return clean.length > 0 ? clean : title;
    }

    function cleanArtist(artist) {
        if (!artist) return "";
        // If multiple artists separated by comma or feat, extract primary
        var clean = artist.split(/[,&]|\sfeat\.?|\swith\s/i)[0].trim();
        return clean.length > 0 ? clean : artist;
    }

    function checkFetchLyrics(title, artist, duration) {
        if (!title || !artist) {
            syncedLyrics = [];
            return;
        }
        const key = artist + "|" + title;
        if (key === lyricsTrackKey) return;
        lyricsTrackKey = key;
        syncedLyrics = [];

        // 1. Direct get request (without duration constraint to prevent 404 on duration variances)
        var exactUrl = "https://lrclib.net/api/get?artist_name=" + encodeURIComponent(artist) +
                       "&track_name=" + encodeURIComponent(title);

        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                try {
                    var resp = JSON.parse(xhr.responseText);
                    if (resp.syncedLyrics && resp.syncedLyrics.length > 0) {
                        musicWindow.syncedLyrics = musicWindow.parseLrc(resp.syncedLyrics);
                        return;
                    } else if (resp.plainLyrics && resp.plainLyrics.length > 0) {
                        musicWindow.syncedLyrics = musicWindow.parsePlainLyrics(resp.plainLyrics, duration);
                        return;
                    }
                } catch(e) {}
            }
            // If exact match failed, query fallback search with sanitized metadata
            musicWindow.fetchLyricsFallback(title, artist, duration);
        };
        xhr.open("GET", exactUrl);
        xhr.send();
    }

    function fetchLyricsFallback(title, artist, duration) {
        var cTitle = cleanTrackTitle(title);
        var cArtist = cleanArtist(artist);

        var searchUrl = "https://lrclib.net/api/search?track_name=" + encodeURIComponent(cTitle) +
                        "&artist_name=" + encodeURIComponent(cArtist);

        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                try {
                    var items = JSON.parse(xhr.responseText);
                    if (items && items.length > 0) {
                        // Find first item with syncedLyrics
                        for (var i = 0; i < items.length; i++) {
                            if (items[i].syncedLyrics && items[i].syncedLyrics.length > 0) {
                                musicWindow.syncedLyrics = musicWindow.parseLrc(items[i].syncedLyrics);
                                return;
                            }
                        }
                        // Otherwise fallback to plain lyrics
                        for (var j = 0; j < items.length; j++) {
                            if (items[j].plainLyrics && items[j].plainLyrics.length > 0) {
                                musicWindow.syncedLyrics = musicWindow.parsePlainLyrics(items[j].plainLyrics, duration);
                                return;
                            }
                        }
                    }
                } catch(e) {}
            }
        };
        xhr.open("GET", searchUrl);
        xhr.send();
    }

    function parsePlainLyrics(plain, duration) {
        var lines = plain.split("\n").map(function(l) { return l.trim(); }).filter(function(l) { return l.length > 0; });
        if (lines.length === 0) return [];
        var durMs = (duration > 0 ? duration : (lines.length * 4)) * 1000;
        var step = durMs / lines.length;
        var res = [];
        for (var i = 0; i < lines.length; i++) {
            res.push({ timestamp: Math.round(i * step), text: lines[i] });
        }
        return res;
    }

    function parseLrc(lrc) {
        var lines = lrc.split("\n");
        var res = [];
        var re = /\[(\d{1,2}):(\d{2})[.:](\d{2,3})\](.*)/;
        for (var i = 0; i < lines.length; i++) {
            var m = re.exec(lines[i]);
            if (m) {
                var min = parseInt(m[1]);
                var sec = parseInt(m[2]);
                var fracStr = m[3];
                var frac = parseInt(fracStr);
                var fracMs = fracStr.length === 2 ? (frac * 10) : frac;
                var ms = (min * 60000) + (sec * 1000) + fracMs;
                var txt = m[4].trim();
                if (txt.length > 0) {
                    res.push({ timestamp: ms, text: txt });
                }
            }
        }
        res.sort(function(a, b) { return a.timestamp - b.timestamp; });
        return res;
    }

    // Command executions
    Process { id: playPauseCmd; command: ["playerctl", "play-pause"] }
    Process { id: prevCmd;      command: ["playerctl", "previous"] }
    Process { id: nextCmd;      command: ["playerctl", "next"] }
    Process { id: seekCmd }

    function togglePlay() {
        musicWindow.playerStatus = musicWindow.isPlaying ? "Paused" : "Playing";
        playPauseCmd.running = true;
    }

    function playPrevious() {
        prevCmd.running = true;
    }

    function playNext() {
        nextCmd.running = true;
    }

    function seekPosition(sec) {
        musicWindow.syncWithRealPosition(sec);
        seekCmd.command = ["playerctl", "position", String(Math.round(sec))];
        seekCmd.running = true;
    }

    function toggleLyrics() {
        if (musicWindow.layoutMode === "tall") {
            musicWindow.layoutMode = "wide";
        } else {
            musicWindow.layoutMode = "tall";
        }
    }

    function cycleMode() {
        if (musicWindow.layoutMode === "wide") {
            musicWindow.layoutMode = "bar";
        } else if (musicWindow.layoutMode === "bar") {
            musicWindow.layoutMode = "wide";
        } else {
            musicWindow.layoutMode = "wide";
        }
    }

    // The Music Card
    Item {
        id: full
        x: musicWindow.targetX
        y: musicWindow.targetY

        width: musicWindow.targetWidth > 0 ? musicWindow.targetWidth : 340
        height: musicWindow.layoutMode === "tall" ? musicWindow.tallHeight : (musicWindow.layoutMode === "bar" ? 62 : (musicWindow.targetHeight > 0 ? musicWindow.targetHeight : 160))

        Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on y { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on width { NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }
        Behavior on height { NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }

        // Liquid Glass Background
        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: musicWindow.layoutMode === "bar" ? (full.height / 2) : 40
            roundness: 4.6
            tint: musicWindow.layoutMode === "tall" ? "#0a1024" : "#ffffff"
            tintAlpha: musicWindow.layoutMode === "tall" ? 0.28 : 0.15
            lumaCap: musicWindow.layoutMode === "tall" ? 0.50 : 0.80
            Behavior on tint { ColorAnimation { duration: 320 } }
            Behavior on tintAlpha { NumberAnimation { duration: 320 } }
            Behavior on lumaCap { NumberAnimation { duration: 320 } }
            widgetX: full.x
            widgetY: full.y
            screenWidth: musicWindow.width > 0 ? musicWindow.width : 1920
            screenHeight: musicWindow.height > 0 ? musicWindow.height : 1080
        }

        // ══════════════════════════════════════════════════════════════════
        // LAYOUT 1: WIDE PLAYER (Top Left in Image 0)
        // ══════════════════════════════════════════════════════════════════
        Item {
            id: wideView
            anchors.fill: parent
            anchors.margins: 14
            visible: musicWindow.layoutMode === "wide"
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            // "Lyrics" Toggle Button (Top Right)
            Rectangle {
                id: lyricsPill
                anchors.top: parent.top
                anchors.right: parent.right
                height: 24
                width: lyricsRow.width + 16
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.25)

                Row {
                    id: lyricsRow
                    anchors.centerIn: parent
                    spacing: 5

                    Image {
                        source: "/home/gabriel/.config/quickshell/assets/icons/music_widget/lyrics.svg"
                        width: 14
                        height: 14
                        anchors.verticalCenter: parent.verticalCenter
                        smooth: true
                    }

                    Text {
                        text: "Lyrics"
                        color: "#ffffff"
                        font.family: sfRegular.name
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: musicWindow.toggleLyrics()
                }
            }

            // Compact Bar Mode Button
            Rectangle {
                id: pillToggleBtn
                anchors.top: parent.top
                anchors.right: lyricsPill.left
                anchors.rightMargin: 6
                height: 24
                width: 24
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.20)

                Text {
                    anchors.centerIn: parent
                    text: "━"
                    color: "#ffffff"
                    font.pixelSize: 9
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: musicWindow.layoutMode = "bar"
                }
            }

            // Top Area: Album Art + Song Info + Controls
            Item {
                id: wideTopArea
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: wideSlider.top
                anchors.bottomMargin: 8

                // Square Album Artwork
                AlbumArt {
                    id: wideArt
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: height
                    radius: 14
                    artUrl: musicWindow.trackArtUrl
                }

                // Title, Artist, and Playback Controls
                Item {
                    anchors.left: wideArt.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: lyricsPill.width + 42
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 2

                        // Song Title
                        MarqueeText {
                            width: parent.width
                            height: 22
                            text: musicWindow.trackTitle
                            fontSize: 16
                            fontWeight: Font.DemiBold
                            fontFamily: sfRegular.name
                            textColor: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // Artist
                        MarqueeText {
                            width: parent.width
                            height: 16
                            text: musicWindow.trackArtist
                            fontSize: 12
                            fontWeight: Font.Normal
                            fontFamily: sfRegular.name
                            textColor: "#ffffff"
                            textOpacity: 0.65
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Item { width: 1; height: 6 }

                        // Previous, Play/Pause, Next Controls
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 18

                            ControlButton {
                                iconSource: "/home/gabriel/.config/quickshell/assets/icons/music_widget/previous.svg"
                                iconSize: 18
                                onClicked: musicWindow.playPrevious()
                            }

                            ControlButton {
                                iconSource: musicWindow.isPlaying
                                    ? "/home/gabriel/.config/quickshell/assets/icons/music_widget/pause.svg"
                                    : "/home/gabriel/.config/quickshell/assets/icons/music_widget/play.svg"
                                iconSize: 22
                                onClicked: musicWindow.togglePlay()
                            }

                            ControlButton {
                                iconSource: "/home/gabriel/.config/quickshell/assets/icons/music_widget/next.svg"
                                iconSize: 18
                                onClicked: musicWindow.playNext()
                            }
                        }
                    }
                }
            }

            // Bottom Seekbar Slider
            MusicSlider {
                id: wideSlider
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                position: musicWindow.playbackPos
                length: musicWindow.playbackLen
                fontFamily: sfRegular.name
                fontSize: 10
                onSeek: function(sec) { musicWindow.seekPosition(sec) }
            }
        }

        // ══════════════════════════════════════════════════════════════════
        // LAYOUT 2: COMPACT BAR PILL (Bottom Left in Image 0)
        // ══════════════════════════════════════════════════════════════════
        Item {
            id: barView
            anchors.fill: parent
            anchors.margins: 8
            visible: musicWindow.layoutMode === "bar"
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            // Album art on left
            AlbumArt {
                id: barArt
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: height
                radius: height / 2
                artUrl: musicWindow.trackArtUrl

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: musicWindow.layoutMode = "wide"
                }
            }

            // Info column in center
            Item {
                anchors.left: barArt.right
                anchors.leftMargin: 10
                anchors.right: barControls.left
                anchors.rightMargin: 10
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 1

                    MarqueeText {
                        width: parent.width
                        height: 18
                        text: musicWindow.trackTitle
                        fontSize: 13
                        fontWeight: Font.DemiBold
                        fontFamily: sfRegular.name
                        textColor: "#ffffff"
                    }

                    MarqueeText {
                        width: parent.width
                        height: 14
                        text: musicWindow.trackArtist
                        fontSize: 11
                        fontFamily: sfRegular.name
                        textColor: "#ffffff"
                        textOpacity: 0.65
                    }

                    Item { width: 1; height: 3 }

                    // Slim progress line
                    Rectangle {
                        width: parent.width
                        height: 2.5
                        radius: 1.5
                        color: Qt.rgba(1, 1, 1, 0.18)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: musicWindow.playbackLen > 0
                                ? (parent.width * Math.min(1, musicWindow.playbackPos / musicWindow.playbackLen))
                                : 0
                            radius: parent.radius
                            color: "#ffffff"
                        }
                    }
                }
            }

            // Controls on right
            Row {
                id: barControls
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                ControlButton {
                    iconSource: "/home/gabriel/.config/quickshell/assets/icons/music_widget/previous.svg"
                    iconSize: 15
                    onClicked: musicWindow.playPrevious()
                }

                ControlButton {
                    iconSource: musicWindow.isPlaying
                        ? "/home/gabriel/.config/quickshell/assets/icons/music_widget/pause.svg"
                        : "/home/gabriel/.config/quickshell/assets/icons/music_widget/play.svg"
                    iconSize: 18
                    onClicked: musicWindow.togglePlay()
                }

                ControlButton {
                    iconSource: "/home/gabriel/.config/quickshell/assets/icons/music_widget/next.svg"
                    iconSize: 15
                    onClicked: musicWindow.playNext()
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════
        // LAYOUT 3: TALL SYNCED LYRICS VIEW (Right in Image 0)
        // ══════════════════════════════════════════════════════════════════
        Item {
            id: tallView
            anchors.fill: parent
            anchors.margins: 16
            visible: musicWindow.layoutMode === "tall"
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            // Synced Scrolling Lyrics Area
            SyncedLyricsView {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: tallBottomArea.top
                anchors.bottomMargin: 10
                syncedLyrics: musicWindow.syncedLyrics
                currentPositionMs: musicWindow.precisePositionMs
                fontFamily: sfRegular.name
                baseFontSize: 16
                blurEnabled: true
                onSeekTo: function(sec) { musicWindow.seekPosition(sec) }
            }

            // Bottom Area: Lyrics toggle button & Playback controls
            Item {
                id: tallBottomArea
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 56

                // "Lyrics" Toggle Button (Right side, pill)
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 22
                    width: tallLyricsRow.width + 14
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.35)

                    Row {
                        id: tallLyricsRow
                        anchors.centerIn: parent
                        spacing: 4

                        Image {
                            source: "/home/gabriel/.config/quickshell/assets/icons/music_widget/lyrics.svg"
                            width: 12
                            height: 12
                            anchors.verticalCenter: parent.verticalCenter
                            smooth: true
                        }

                        Text {
                            text: "Lyrics"
                            color: "#ffffff"
                            font.family: sfRegular.name
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: musicWindow.toggleLyrics()
                    }
                }

                // Controls centered at bottom
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    spacing: 22

                    ControlButton {
                        iconSource: "/home/gabriel/.config/quickshell/assets/icons/music_widget/previous.svg"
                        iconSize: 20
                        onClicked: musicWindow.playPrevious()
                    }

                    ControlButton {
                        iconSource: musicWindow.isPlaying
                            ? "/home/gabriel/.config/quickshell/assets/icons/music_widget/pause.svg"
                            : "/home/gabriel/.config/quickshell/assets/icons/music_widget/play.svg"
                        iconSize: 26
                        onClicked: musicWindow.togglePlay()
                    }

                    ControlButton {
                        iconSource: "/home/gabriel/.config/quickshell/assets/icons/music_widget/next.svg"
                        iconSize: 20
                        onClicked: musicWindow.playNext()
                    }
                }
            }
        }

        // Smooth Click & Specular Interaction (Dragging disabled - driven by Layouts)
        MouseArea {
            id: clickArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor
            z: -1 // Behind buttons/sliders, captures on empty card surface

            onPositionChanged: (mouse) => {
                glass.mouseU = mouse.x / Math.max(1, full.width);
                glass.mouseV = mouse.y / Math.max(1, full.height);
                glass.mouseFade = 1;
            }

            onDoubleClicked: {
                musicWindow.cycleMode();
            }

            onEntered: {
                glass.mouseFade = 1;
            }

            onExited: {
                glass.mouseFade = 0;
                glass.mouseU = -1;
                glass.mouseV = -1;
            }
        }
    }
}
