import QtQuick

// Hospeda o visual alternativo de um widget (variante escolhida pelo layout).
// Só a variante ativa existe na memória (Loader). A geometria anima como a dos cards clássicos
// e a variante entra/sai com fade enquanto o card "classic" faz o inverso.
// A variante carregada recebe `host` (este item): usa host.width/height, host.x/y (posição na tela,
// para o vidro), host.sharedBackdrop e host.screenW/screenH.
Item {
    id: host

    property string variant: "classic"
    property var sources: ({})          // nome da variante -> url do .qml
    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 100
    property real targetHeight: 100
    property variant sharedBackdrop: null
    property real screenW: 1920
    property real screenH: 1200

    readonly property bool active: sources[variant] !== undefined
    // mantém a última variante carregada durante o fade de saída
    property string shownVariant: ""
    onVariantChanged: if (sources[variant] !== undefined) shownVariant = variant
    Component.onCompleted: if (sources[variant] !== undefined) shownVariant = variant

    x: targetX
    y: targetY
    width: targetWidth
    height: targetHeight
    Behavior on x { enabled: !GlassTheme.gaming; NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
    Behavior on y { enabled: !GlassTheme.gaming; NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 0.75 } }
    Behavior on width { enabled: !GlassTheme.gaming; NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }
    Behavior on height { enabled: !GlassTheme.gaming; NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.45 } }

    opacity: active ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    Loader {
        anchors.fill: parent
        active: host.visible && host.shownVariant !== ""
        source: host.shownVariant !== "" ? host.sources[host.shownVariant] : ""
        onLoaded: item.host = host
    }
}
