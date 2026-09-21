import QtQuick
import Quickshell
import Quickshell.Io

// Reusable liquid frosted glass background for Quickshell
// Highly optimized native C++ / Qt Quick shader pipeline - Zero redundant FBOs, 180 FPS fluid
Item {
    id: glass

    // Shape
    property real radius: 100
    // Superellipse exponent: 2 = plain rounded rect, 5.5 ≈ iOS squircle, 7.5 = KDE liquid glass squircle
    property real roundness: 4.6

    // Snell-on-a-dome refraction parameters
    property real refractThickness: 18
    property real refractIOR: 1.5
    property real refractScale: 34
    property color tint: "#ffffff"
    property real tintAlpha: 0.12
    property real chromaStrength: 0.05

    // Limitador de brilho do fundo (legibilidade sobre nuvens/áreas brancas). 1.0 = desligado.
    property real lumaCap: 0.80

    // Estilo Liquid Glass: vibrância do fundo, fio de luz na borda, brilho de topo e sombra de profundidade
    property real saturation: 1.45
    property real rim: 0.0
    property real sheen: 0.7
    property real innerShade: 0.0
    // Tema sólido (botão-chave): 0 = vidro, 1 = cinza-escuro. Transição em "onda" a partir do botão.
    property real solidT: 0
    Behavior on solidT { enabled: GlassTheme.animate; NumberAnimation { duration: 520; easing.type: Easing.InOutCubic } }

    Timer {
        id: rippleTimer
        repeat: false
        onTriggered: glass.solidT = GlassTheme.solid ? 1 : 0
    }
    function _applySolid() {
        if (!GlassTheme.animate) { glass.solidT = GlassTheme.solid ? 1 : 0; return; }
        const cx = glass.widgetX + glass.width / 2 - GlassTheme.originX;
        const cy = glass.widgetY + glass.height / 2 - GlassTheme.originY;
        rippleTimer.interval = Math.min(650, Math.sqrt(cx * cx + cy * cy) * 0.5);
        rippleTimer.restart();
    }
    Connections {
        target: GlassTheme
        function onSolidChanged() { glass._applySolid(); }
    }
    Component.onCompleted: glass.solidT = GlassTheme.solid ? 1 : 0

    property bool shadowEnabled: false
    property real shadowStrength: 0.045
    property real shadowBlur: 24
    property real shadowOffset: 8

    // Dual Kawase blur spread in widget pixels (used in fallback mode)
    property real blurRadius: 6

    // Border specular highlight
    property bool specEnabled: true
    property real specStrength: 0.0

    // Screen and positioning
    property string wallpaperPath: ""
    property real screenWidth: 1920
    property real screenHeight: 1200
    property real widgetX: 0
    property real widgetY: 0

    // Shared full-screen backdrop support (eliminates per-widget blur overhead and enables 180 FPS)
    property variant sharedBackdrop: null

    // Specular mouse tracking
    property real mouseU: -1
    property real mouseV: -1
    property real mouseFade: 0

    Behavior on mouseFade {
        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }

    // Instant direct wallpaper setter
    function setWallpaper(path) {
        if (!path || path === glass.wallpaperPath) return;
        glass.wallpaperPath = path;
        if (fallbackBlurLoader.item) {
            fallbackBlurLoader.item.updateWallpaper(path);
        }
    }

    function markDirty() {
        if (fallbackBlurLoader.item) {
            fallbackBlurLoader.item.markDirty();
        }
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

    // Sombra suave sob o vidro (analítica, sem passes de blur)
    ShaderEffect {
        id: shadowFx
        visible: glass.shadowEnabled && glass.width > 1 && glass.height > 1
        z: -1
        readonly property real padPx: glass.shadowBlur * 1.6 + glass.shadowOffset
        x: -padPx
        y: -padPx
        width: glass.width + 2 * padPx
        height: glass.height + 2 * padPx
        fragmentShader: Qt.resolvedUrl("shaders/glassshadow.frag.qsb")
        property size size: Qt.size(glass._widgetW, glass._widgetH)
        property real pad: padPx
        property real radius: glass.radius
        property real roundness: glassShader.roundness
        property real blur: glass.shadowBlur
        property real strength: glass.shadowStrength
        property real offsetY: glass.shadowOffset
    }

    // Liquid Glass Snell Shader
    ShaderEffect {
        id: glassShader
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("shaders/liquidglass.frag.qsb")

        property variant backdrop: glass.sharedBackdrop ? glass.sharedBackdrop : (fallbackBlurLoader.item ? fallbackBlurLoader.item.outTexture : null)
        property size size: Qt.size(glass._widgetW, glass._widgetH)
        property real radius: glass.radius
        property real roundness: Math.min(glass._widgetW, glass._widgetH) < 110 ? 2.8 : glass.roundness
        property real refractThickness: Math.min(glass.refractThickness, Math.min(glass._widgetW, glass._widgetH) * 0.20)
        property real refractIOR: glass.refractIOR
        property real refractScale: Math.min(glass.refractScale, Math.min(glass._widgetW, glass._widgetH) * 0.55)
        property real chromaStrength: glass.chromaStrength
        property vector4d tint: Qt.vector4d(glass.tint.r, glass.tint.g, glass.tint.b, glass.tintAlpha)
        property vector4d tintBottom: Qt.vector4d(0, 0, 0, 0)
        property vector2d mousePos: Qt.vector2d(glass.mouseU, glass.mouseV)
        property real mouseFade: glass.mouseFade
        property real specStrength: glass.specEnabled ? glass.specStrength : 0.0
        property vector4d overlayDarken: Qt.vector4d(0, 0, 0, 0)
        property real lumaCap: glass.lumaCap
        property real solidT: glass.solidT
        property vector4d style: Qt.vector4d(glass.saturation, glass.rim, glass.sheen, glass.innerShade)
        property vector2d uvOffset: glass.sharedBackdrop ? glass._uvOff : Qt.vector2d(0, 0)
        property vector2d uvScale: glass.sharedBackdrop ? glass._uvSc : Qt.vector2d(1, 1)
    }

    // ── Fallback Blur Pipeline Loader (ONLY instantiated if sharedBackdrop is null) ──
    // Saves over 200 redundant ShaderEffects and 100+ MB RAM across the desktop widgets
    Loader {
        id: fallbackBlurLoader
        active: !glass.sharedBackdrop
        sourceComponent: Component {
            Item {
                id: fbRoot
                property alias outTexture: up1Tex

                function updateWallpaper(p) {
                    wallpaperTex.scheduleUpdate();
                    markDirty();
                }

                property bool _dirtyBurst: true
                function markDirty() {
                    _dirtyBurst = true;
                    settleTimer.restart();
                }

                Timer {
                    id: settleTimer
                    interval: 350
                    onTriggered: fbRoot._dirtyBurst = false
                }

                readonly property bool _blurActive: glass.blurRadius > 0
                readonly property int _blurIters: _blurActive ? 1 : 0

                function qSize(val, div, step) {
                    var raw = Math.max(1, Math.round(val / div));
                    return Math.max(step, Math.ceil(raw / step) * step);
                }

                Image {
                    id: wallpaperItem
                    source: glass.wallpaperPath ? (glass.wallpaperPath.startsWith("/") ? ("file://" + glass.wallpaperPath) : glass.wallpaperPath) : ""
                    sourceSize.width: glass.screenWidth
                    sourceSize.height: glass.screenHeight
                    width: glass.screenWidth
                    height: glass.screenHeight
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    mipmap: false
                    asynchronous: false
                    cache: false
                    visible: true
                    onStatusChanged: {
                        if (status === Image.Ready) {
                            wallpaperTex.scheduleUpdate();
                            fbRoot.markDirty();
                        }
                    }
                }

                ShaderEffectSource {
                    id: wallpaperTex
                    sourceItem: wallpaperItem
                    hideSource: true
                    live: false
                    mipmap: false
                    textureMirroring: ShaderEffectSource.MirrorVertically
                }

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
                    live: fbRoot._dirtyBurst
                    hideSource: true
                    smooth: true
                }

                ShaderEffect {
                    id: down1; anchors.fill: parent; visible: false
                    fragmentShader: Qt.resolvedUrl("shaders/kawase_down.frag.qsb")
                    property variant source: cropTex
                    property vector2d halfpixel: Qt.vector2d(0.5 / glass._widgetW, 0.5 / glass._widgetH)
                }
                ShaderEffectSource {
                    id: down1Tex; anchors.fill: parent; opacity: 0
                    sourceItem: fbRoot._blurIters >= 1 ? down1 : null
                    live: fbRoot._dirtyBurst; hideSource: true; smooth: true
                    textureSize: Qt.size(fbRoot.qSize(glass._widgetW, 2, 64), fbRoot.qSize(glass._widgetH, 2, 64))
                }

                ShaderEffect {
                    id: up1; anchors.fill: parent; visible: false
                    fragmentShader: Qt.resolvedUrl("shaders/kawase_up.frag.qsb")
                    property variant source: down1Tex
                    property vector2d halfpixel: Qt.vector2d(0.5 / glass._widgetW, 0.5 / glass._widgetH)
                }
                ShaderEffectSource {
                    id: up1Tex; anchors.fill: parent; opacity: 0
                    sourceItem: up1
                    live: fbRoot._dirtyBurst; hideSource: true; smooth: true
                    textureSize: Qt.size(fbRoot.qSize(glass._widgetW, 1, 64), fbRoot.qSize(glass._widgetH, 1, 64))
                }
            }
        }
    }
}
