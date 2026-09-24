import QtQuick

// Live Liquid Glass with real compositor transparency (Hyprland Dual Kawase blur)
// ZERO static wallpaper sampling — shows whatever window or page is actually beneath it!
Item {
    id: liveGlass

    property real radius: 19
    property real roundness: 7.5
    property real refractThickness: 12
    property real refractIOR: 1.7
    property real refractScale: 45
    property real chromaStrength: 0.30

    property color tint: "#ffffff"
    property real tintAlpha: 0.14
    property color tintBottom: Qt.rgba(1, 1, 1, 0.05)
    property color darkBase: "#000000"
    property real darkAlpha: 0.32

    property bool specEnabled: true
    property real specStrength: 0.80

    property real mouseU: -1
    property real mouseV: -1
    property real mouseFade: 0

    Behavior on mouseFade { enabled: !GlassTheme.gaming;
        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }

    readonly property real _w: Math.max(1, liveGlass.width)
    readonly property real _h: Math.max(1, liveGlass.height)

    ShaderEffect {
        id: glassShader
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("shaders/liveglass.frag.qsb")

        property size size: Qt.size(liveGlass._w, liveGlass._h)
        property real radius: liveGlass.radius
        property real roundness: liveGlass.roundness
        property real refractThickness: liveGlass.refractThickness
        property real refractIOR: liveGlass.refractIOR
        property real refractScale: liveGlass.refractScale
        property real chromaStrength: liveGlass.chromaStrength

        property vector4d tint: Qt.vector4d(liveGlass.tint.r, liveGlass.tint.g, liveGlass.tint.b, liveGlass.tintAlpha)
        property vector4d tintBottom: Qt.vector4d(liveGlass.tintBottom.r, liveGlass.tintBottom.g, liveGlass.tintBottom.b, liveGlass.tintBottom.a)
        property vector4d overlayDarken: Qt.vector4d(liveGlass.darkBase.r, liveGlass.darkBase.g, liveGlass.darkBase.b, liveGlass.darkAlpha)

        property vector2d mousePos: Qt.vector2d(liveGlass.mouseU, liveGlass.mouseV)
        property real mouseFade: liveGlass.mouseFade
        property real specStrength: liveGlass.specEnabled ? liveGlass.specStrength : 0.0

        property vector2d uvOffset: Qt.vector2d(0, 0)
        property vector2d uvScale: Qt.vector2d(1, 1)
    }
}
