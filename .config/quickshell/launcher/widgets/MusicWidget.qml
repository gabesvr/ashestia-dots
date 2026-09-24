import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../services"

Item {
    id: musicWindow
    anchors.fill: parent

    property alias cardItem: full
    property alias sharedBackdrop: glass.sharedBackdrop


    // Animated Target Position (Driven by Layout Manager)
    property real targetX: 1530
    property real targetY: 420
    property real targetWidth: 340
    property real targetHeight: 160
    property string variant: "classic"   // visual escolhido pelo layout ("classic" = o de sempre)
    // variant "hidden": some com fade (o layout não usa este widget)
    opacity: variant === "hidden" ? 0 : 1
    visible: opacity > 0.01
    Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 260 } }
    property real tallHeight: 420   // altura do modo lyrics (definida pelo layout)

    function setWallpaper(path) {
        glass.setWallpaper(path);
    }

    // Layout mode: "wide" (default) | "bar" (compact pill) | "tall" (lyrics)
    property string layoutMode: "wide"
    readonly property bool isLyricsOpen: layoutMode === "tall"

    // Dados da música vêm do MusicService (um playerctl só para todas as variantes)
    readonly property string trackTitle: MusicService.title
    readonly property string trackArtist: MusicService.artist
    readonly property string trackArtUrl: MusicService.artUrl
    readonly property string playerStatus: MusicService.status
    readonly property real playbackPos: MusicService.position
    readonly property real playbackLen: MusicService.length
    readonly property bool isPlaying: MusicService.isPlaying
    readonly property real precisePositionMs: MusicService.positionMs
    readonly property string playerName: MusicService.playerName

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

    onTrackTitleChanged: lyricsDebounce.restart()
    onTrackArtistChanged: lyricsDebounce.restart()

    // título e artista chegam em eventos separados → espera os dois antes de buscar
    Timer {
        id: lyricsDebounce
        interval: 300
        onTriggered: musicWindow.checkFetchLyrics(musicWindow.trackTitle, musicWindow.trackArtist, musicWindow.playbackLen)
    }
    // falha de rede → tenta de novo (até 3x)
    property int _lyricsRetries: 0
    Timer {
        id: lyricsRetryTimer
        interval: 5000
        onTriggered: {
            musicWindow.lyricsTrackKey = "";
            musicWindow.checkFetchLyrics(musicWindow.trackTitle, musicWindow.trackArtist, musicWindow.playbackLen, true);
        }
    }
    function _lyricsNetFail(key) {
        if (key !== lyricsTrackKey || _lyricsRetries >= 3) return;
        _lyricsRetries++;
        lyricsRetryTimer.restart();
    }

    // YouTube: "Artista - Topic", "ArtistaVEVO", "Artista - Música (Official Video)"
    function normalizeMeta(title, artist) {
        var a = (artist || "").replace(/\s*-\s*topic$/i, "").replace(/vevo$/i, "").replace(/\s*official$/i, "").trim();
        var t = (title || "").replace(/[\(\[][^\)\]]*(official|video|audio|lyric|visuali[sz]er|clipe|\bmv\b|\bhd\b|4k)[^\)\]]*[\)\]]/gi, "")
                             .replace(/\s*\|.*$/, "").trim();
        var dash = t.indexOf(" - ");
        if (dash > 0) {
            var left = t.substring(0, dash).trim(), right = t.substring(dash + 3).trim();
            var sq = function(x) { return x.toLowerCase().replace(/[^a-z0-9]/g, ""); };
            if (!a || sq(left).indexOf(sq(a)) === 0 || sq(a).indexOf(sq(left)) === 0) {
                a = left; t = right;
            }
        }
        return { title: t || title, artist: a || artist };
    }

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

    function checkFetchLyrics(title, artist, duration, isRetry) {
        if (!title || !artist) {
            syncedLyrics = [];
            return;
        }
        const key = artist + "|" + title;
        if (key === lyricsTrackKey) return;
        lyricsTrackKey = key;
        if (!isRetry) { _lyricsRetries = 0; lyricsRetryTimer.stop(); }
        syncedLyrics = [];
        const nm = normalizeMeta(title, artist);
        title = nm.title;
        artist = nm.artist;

        // 1. Direct get request (without duration constraint to prevent 404 on duration variances)
        var exactUrl = "https://lrclib.net/api/get?artist_name=" + encodeURIComponent(artist) +
                       "&track_name=" + encodeURIComponent(title);

        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (key !== musicWindow.lyricsTrackKey) return;   // resposta de uma música antiga
            if (xhr.status === 0 || xhr.status >= 500) { musicWindow._lyricsNetFail(key); return; }
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
            musicWindow.fetchLyricsFallback(title, artist, duration, key);
        };
        xhr.timeout = 8000;
        xhr.open("GET", exactUrl);
        xhr.send();
    }

    function fetchLyricsFallback(title, artist, duration, key) {
        var cTitle = cleanTrackTitle(title);
        var cArtist = cleanArtist(artist);

        var searchUrl = "https://lrclib.net/api/search?track_name=" + encodeURIComponent(cTitle) +
                        "&artist_name=" + encodeURIComponent(cArtist);

        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (key !== musicWindow.lyricsTrackKey) return;
            if (xhr.status === 0 || xhr.status >= 500) { musicWindow._lyricsNetFail(key); return; }
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
        xhr.timeout = 8000;
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

    function togglePlay() { MusicService.togglePlay(); }
    function playPrevious() { MusicService.previous(); }
    function playNext() { MusicService.next(); }
    function seekPosition(sec) { MusicService.seek(sec); }

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
        opacity: vhost.active || musicWindow.variant === "hidden" ? 0 : 1   // clássico some quando uma variante assume ou quando o layout esconde o widget (senão pisca no fade-out)
        visible: opacity > 0.01
        Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 200 } }
        x: musicWindow.targetX
        y: musicWindow.targetY

        width: musicWindow.targetWidth > 0 ? musicWindow.targetWidth : 340
        height: musicWindow.layoutMode === "tall" ? musicWindow.tallHeight : (musicWindow.layoutMode === "bar" ? 62 : (musicWindow.targetHeight > 0 ? musicWindow.targetHeight : 160))

        Behavior on x { enabled: !GlassTheme.gaming; NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on y { enabled: !GlassTheme.gaming; NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
        Behavior on width { enabled: !GlassTheme.gaming; NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }
        Behavior on height { enabled: !GlassTheme.gaming; NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }

        // Liquid Glass Background
        LiquidGlass {
            id: glass
            anchors.fill: parent
            radius: musicWindow.layoutMode === "bar" ? (full.height / 2) : 40
            roundness: 4.6
            tint: musicWindow.layoutMode === "tall" ? "#0a1024" : "#ffffff"
            tintAlpha: musicWindow.layoutMode === "tall" ? 0.28 : 0.15
            lumaCap: musicWindow.layoutMode === "tall" ? 0.50 : 0.80
            Behavior on tint { enabled: !GlassTheme.gaming; ColorAnimation { duration: 320 } }
            Behavior on tintAlpha { enabled: !GlassTheme.gaming; NumberAnimation { duration: 320 } }
            Behavior on lumaCap { enabled: !GlassTheme.gaming; NumberAnimation { duration: 320 } }
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
            Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 200 } }

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
                        font.family: "SF Pro Display"
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
                            fontFamily: "SF Pro Display"
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
                            fontFamily: "SF Pro Display"
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
                fontFamily: "SF Pro Display"
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
            Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 200 } }

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
                        fontFamily: "SF Pro Display"
                        textColor: "#ffffff"
                    }

                    MarqueeText {
                        width: parent.width
                        height: 14
                        text: musicWindow.trackArtist
                        fontSize: 11
                        fontFamily: "SF Pro Display"
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
            Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 200 } }

            // Synced Scrolling Lyrics Area
            SyncedLyricsView {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: tallBottomArea.top
                anchors.bottomMargin: 10
                syncedLyrics: musicWindow.syncedLyrics
                currentPositionMs: musicWindow.precisePositionMs
                fontFamily: "SF Pro Display"
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
                            font.family: "SF Pro Display"
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

    // Visuais alternativos escolhidos pelo layout (widgets/variants/)
    VariantHost {
        id: vhost
        variant: musicWindow.variant
        sources: ({ pill: Qt.resolvedUrl("variants/MusicPill.qml"), cover: Qt.resolvedUrl("variants/MusicCover.qml"), vinyl: Qt.resolvedUrl("variants/MusicVinyl.qml"), poster: Qt.resolvedUrl("variants/MusicPoster.qml") })
        targetX: musicWindow.targetX
        targetY: musicWindow.targetY
        targetWidth: musicWindow.targetWidth
        targetHeight: musicWindow.targetHeight
        sharedBackdrop: musicWindow.sharedBackdrop
        screenW: musicWindow.width > 0 ? musicWindow.width : 1920
        screenH: musicWindow.height > 0 ? musicWindow.height : 1200
    }
}
