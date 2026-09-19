import QtQuick
import Quickshell
import Quickshell.Io

// Reusable liquid frosted glass background for Quickshell
// Pure native C++ / Qt Quick shader pipeline - ZERO Python, Instant Updates
Item {
    id: glass

    // Shape
    property real radius: 100
    // Superellipse exponent: 2 = plain rounded rect, 5.5 ≈ iOS squircle, 7.5 = KDE liquid glass squircle
    property real roundness: 7.5

    // Snell-on-a-dome refraction parameters
    property real refractThickness: 35
    property real refractIOR: 1.7
    property real refractScale: 65
    property color tint: "#ffffff"
    property real tintAlpha: 0.10
    property real chromaStrength: 0.30

    // Dual Kawase blur spread in widget pixels
    property real blurRadius: 6

    // Border specular highlight
    property bool specEnabled: true
    property real specStrength: 0.70

    // Screen and positioning
    property string wallpaperPath: ""
    property real screenWidth: 1536
    property real screenHeight: 960
    property real widgetX: 0
    property real widgetY: 0

    // Instant direct wallpaper setter (0ms in-memory update)
    function setWallpaper(path) {
        if (!path || path === glass.wallpaperPath) return;
        glass.wallpaperPath = path;
        wallpaperTex.scheduleUpdate();
        glass.markDirty();
    }

    // Startup wallpaper reader from persistent config
    Process {
        id: initWpLoader
        command: ["cat", "/home/gabriel/.config/hypr/current_wallpaper"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                const p = line.trim();
                if (p.startsWith("/") && (!glass.wallpaperPath || glass.wallpaperPath === "")) {
                    glass.setWallpaper(p);
                }
            }
        }
    }

    // Instant external wallpaper watcher using Linux kernel inotify (tail -F) - 0% CPU, 0ms lag
    Process {
        id: wpTailWatcher
        command: ["tail", "-F", "-n", "1", "/home/gabriel/.config/hypr/current_wallpaper"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                const p = line.trim();
                if (p.startsWith("/") && p !== glass.wallpaperPath) {
                    glass.setWallpaper(p);
                }
            }
        }
    }


    // Specular mouse tracking
    property real mouseU: -1
    property real mouseV: -1
    property real mouseFade: 0

    Behavior on mouseFade {
        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }

    // Optimized wallpaper source (sourceSize capped to screen to save RAM)
    Image {
        id: wallpaperItem
        source: glass.wallpaperPath ? (glass.wallpaperPath.startsWith("/") ? ("file://" + glass.wallpaperPath) : glass.wallpaperPath) : ""
        sourceSize.width: 960
        sourceSize.height: 540
        width: Math.max(100, glass.screenWidth)
        height: Math.max(100, glass.screenHeight)
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        asynchronous: false
        cache: true
        visible: true
        onStatusChanged: {
            if (status === Image.Ready) {
                wallpaperTex.scheduleUpdate();
                glass.markDirty();
            }
        }
    }

    ShaderEffectSource {
        id: wallpaperTex
        sourceItem: wallpaperItem
        hideSource: true
        live: glass._chainLive
        mipmap: true
        textureMirroring: ShaderEffectSource.MirrorVertically
        onSourceItemChanged: scheduleUpdate()
    }

    // Redraw gating for maximum GPU & CPU efficiency (active during changes/dragging, idle at rest)
    property bool _dirtyBurst: true
    function markDirty() {
        _dirtyBurst = true
        settleTimer.restart()
    }

    Timer {
        id: settleTimer
        interval: 600
        onTriggered: glass._dirtyBurst = false
    }

    readonly property bool _chainLive: glass._dirtyBurst

    onWidgetXChanged: markDirty()
    onWidgetYChanged: markDirty()
    onWidthChanged: markDirty()
    onHeightChanged: markDirty()
    onWallpaperPathChanged: {
        wallpaperTex.scheduleUpdate();
        markDirty();
    }

    readonly property bool _blurActive: glass.blurRadius > 0
    readonly property int _maxBlurIters: 6
    readonly property int _blurIters: {
        if (!_blurActive) return 0;
        var r = glass.blurRadius;
        var iters;
        if (r <= 2) iters = 1;
        else if (r <= 4) iters = 2;
        else if (r <= 8) iters = 3;
        else if (r <= 16) iters = 4;
        else if (r <= 32) iters = 5;
        else iters = 6;
        return Math.min(iters, _maxBlurIters);
    }

    readonly property vector2d _uvOff: Qt.vector2d(
        Math.max(0, glass.widgetX) / Math.max(1, glass.screenWidth),
        Math.max(0, glass.widgetY) / Math.max(1, glass.screenHeight)
    )
    readonly property vector2d _uvSc: Qt.vector2d(
        glass.width / Math.max(1, glass.screenWidth),
        glass.height / Math.max(1, glass.screenHeight)
    )

    readonly property real _widgetW: Math.max(1, glass.width)
    readonly property real _widgetH: Math.max(1, glass.height)

    // Crop shader
    ShaderEffect {
        id: cropPass
        anchors.fill: parent
        visible: false
        fragmentShader: Qt.resolvedUrl("shaders/crop.frag.qsb")
        property variant source: wallpaperTex
        property vector2d uvOffset: glass._uvOff
        property vector2d uvScale: glass._uvSc
    }
    ShaderEffectSource {
        id: cropTex
        anchors.fill: parent
        opacity: 0
        sourceItem: cropPass
        live: glass._chainLive
        hideSource: true
        smooth: true
    }

    // Dual Kawase Blur: Downsample Passes
    ShaderEffect {
        id: down1; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
        property variant source: cropTex
        property vector2d halfpixel: Qt.vector2d(0.5 / glass._widgetW, 0.5 / glass._widgetH)
    }
    ShaderEffectSource {
        id: down1Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurIters >= 1 ? down1 : null
        live: glass._chainLive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(glass._widgetW / 2)),
                             Math.max(1, Math.round(glass._widgetH / 2)))
    }

    ShaderEffect {
        id: down2; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
        property variant source: down1Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down1Tex.textureSize.width),
                                                  0.5 / Math.max(1, down1Tex.textureSize.height))
    }
    ShaderEffectSource {
        id: down2Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurIters >= 2 ? down2 : null
        live: glass._chainLive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(glass._widgetW / 4)),
                             Math.max(1, Math.round(glass._widgetH / 4)))
    }

    ShaderEffect {
        id: down3; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
        property variant source: down2Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down2Tex.textureSize.width),
                                                  0.5 / Math.max(1, down2Tex.textureSize.height))
    }
    ShaderEffectSource {
        id: down3Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurIters >= 3 ? down3 : null
        live: glass._chainLive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(glass._widgetW / 8)),
                             Math.max(1, Math.round(glass._widgetH / 8)))
    }

    ShaderEffect {
        id: down4; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
        property variant source: down3Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down3Tex.textureSize.width),
                                                  0.5 / Math.max(1, down3Tex.textureSize.height))
    }
    ShaderEffectSource {
        id: down4Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurIters >= 4 ? down4 : null
        live: glass._chainLive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(glass._widgetW / 16)),
                             Math.max(1, Math.round(glass._widgetH / 16)))
    }

    // Dual Kawase Blur: Upsample Passes
    ShaderEffect {
        id: up4; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_up.frag.qsb")
        property variant source: down4Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down3Tex.textureSize.width),
                                                  0.5 / Math.max(1, down3Tex.textureSize.height))
    }
    ShaderEffectSource {
        id: up4Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurIters >= 4 ? up4 : null
        live: glass._chainLive; hideSource: true; smooth: true
        textureSize: down3Tex.textureSize
    }

    ShaderEffect {
        id: up3; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_up.frag.qsb")
        property variant source: glass._blurIters >= 4 ? up4Tex : down3Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down2Tex.textureSize.width),
                                                  0.5 / Math.max(1, down2Tex.textureSize.height))
    }
    ShaderEffectSource {
        id: up3Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurIters >= 3 ? up3 : null
        live: glass._chainLive; hideSource: true; smooth: true
        textureSize: down2Tex.textureSize
    }

    ShaderEffect {
        id: up2; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_up.frag.qsb")
        property variant source: glass._blurIters >= 3 ? up3Tex : down2Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / Math.max(1, down1Tex.textureSize.width),
                                                  0.5 / Math.max(1, down1Tex.textureSize.height))
    }
    ShaderEffectSource {
        id: up2Tex; anchors.fill: parent; opacity: 0
        sourceItem: glass._blurIters >= 2 ? up2 : null
        live: glass._chainLive; hideSource: true; smooth: true
        textureSize: down1Tex.textureSize
    }

    ShaderEffect {
        id: up1; anchors.fill: parent; visible: false
        fragmentShader: Qt.resolvedUrl("shaders/kawase_up.frag.qsb")
        property variant source: glass._blurIters >= 2 ? up2Tex : down1Tex
        property vector2d halfpixel: Qt.vector2d(0.5 / glass._widgetW, 0.5 / glass._widgetH)
    }
    ShaderEffectSource {
        id: up1Tex; anchors.fill: parent; opacity: 0
        sourceItem: up1
        live: glass._chainLive; hideSource: true; smooth: true
        textureSize: Qt.size(Math.round(glass._widgetW), Math.round(glass._widgetH))
    }

    // Liquid Glass Snell Shader
    ShaderEffect {
        id: glassShader
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("shaders/liquidglass.frag.qsb")

        property variant backdrop: glass._blurActive ? up1Tex : wallpaperTex
        property size size: Qt.size(glass._widgetW, glass._widgetH)
        property real radius: glass.radius
        property real roundness: glass.roundness
        property real refractThickness: glass.refractThickness
        property real refractIOR: glass.refractIOR
        property real refractScale: glass.refractScale
        property real chromaStrength: glass.chromaStrength
        property vector4d tint: Qt.vector4d(glass.tint.r, glass.tint.g, glass.tint.b, glass.tintAlpha)
        property vector4d tintBottom: Qt.vector4d(0, 0, 0, 0)
        property vector2d mousePos: Qt.vector2d(glass.mouseU, glass.mouseV)
        property real mouseFade: glass.mouseFade
        property real specStrength: glass.specEnabled ? glass.specStrength : 0.0
        property vector4d overlayDarken: Qt.vector4d(0, 0, 0, 0)
        property vector2d uvOffset: Qt.vector2d(0, 0)
        property vector2d uvScale: Qt.vector2d(1, 1)
    }

    Component.onCompleted: markDirty()
}
