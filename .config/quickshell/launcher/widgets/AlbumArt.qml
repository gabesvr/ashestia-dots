import QtQuick

Item {
    id: art

    property string artUrl: ""
    property real radius: 14
    property color fallbackColor: "#1c1c1e"

    // Background placeholder
    Rectangle {
        anchors.fill: parent
        color: art.fallbackColor
        radius: art.radius
        opacity: 0.35
    }

    // Cover image
    Image {
        id: coverImage
        anchors.fill: parent
        source: art.artUrl && art.artUrl.length > 0 ? art.artUrl : GlassTheme.home + "/.config/quickshell/assets/icons/music_widget/no_album.png"
        sourceSize.width: 256
        sourceSize.height: 256
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        visible: false
        layer.enabled: true
    }

    // Capa recortada com cantos arredondados e borda suavizada (shaders/roundimg.frag)
    ShaderEffect {
        anchors.fill: parent
        property variant source: coverImage
        property size itemSize: Qt.size(width, height)
        property real radius: art.radius
        fragmentShader: "shaders/roundimg.frag.qsb"
    }

    // Subtle inner border highlight
    Rectangle {
        anchors.fill: parent
        radius: art.radius
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.15)
        border.width: 1
    }
}
