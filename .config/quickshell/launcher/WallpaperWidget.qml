import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var controlCenter

    implicitHeight: mainLayout.implicitHeight
    implicitWidth: 350

    property var wallpapers: []
    property string activeWallpaper: ""
    property bool isLoading: false
    property string statusMessage: ""
    property string searchQuery: ""

    readonly property var filteredWallpapers: {
        if (!searchQuery || searchQuery.trim() === "") return wallpapers;
        const q = searchQuery.toLowerCase().trim();
        return wallpapers.filter(w => (w.name && w.name.toLowerCase().includes(q)) || (w.path && w.path.toLowerCase().includes(q)));
    }

    // ── Processo de Listagem de Wallpapers ────────────────────
    Process {
        id: wpLister
        command: ["/home/gabriel/.config/quickshell/scripts/wallpaper_tool.sh", "list"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const data = JSON.parse(line.trim())
                    root.wallpapers = data.wallpapers || []
                    root.activeWallpaper = data.active || ""
                    root.isLoading = false
                    if (data.colors && root.controlCenter) {
                        root.controlCenter.applyColors(data.colors)
                    }
                } catch (e) {
                    root.isLoading = false
                }
            }
        }
    }

    // ── Processo de Mudança de Wallpaper ─────────────────────
    Process {
        id: wpSetter
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const res = JSON.parse(line.trim())
                    const newPath = res.active || res.wallpaper
                    if (newPath) {
                        root.activeWallpaper = newPath
                        root.statusMessage = "Papel de parede aplicado!"
                    }
                    if (res.colors && root.controlCenter) {
                        root.controlCenter.applyColors(res.colors)
                    }
                } catch (e) {}
                statusTimer.restart()
            }
        }
    }

    Timer {
        id: statusTimer
        interval: 2500
        onTriggered: root.statusMessage = ""
    }

    function refresh() {
        root.isLoading = true
        wpLister.running = true
    }

    function setWallpaper(path) {
        if (!path) return;
        root.activeWallpaper = path;

        // Disparo INSTANTÂNEO em 0ms para o ClockWidget e LiquidGlass
        if (root.controlCenter && root.controlCenter.wallpaperChanged) {
            root.controlCenter.wallpaperChanged(path);
        }

        root.statusMessage = "Aplicando..."
        wpSetter.command = ["/home/gabriel/.config/quickshell/scripts/wallpaper_tool.sh", "set", path]
        wpSetter.running = true
    }

    function selectRandom() {
        if (root.wallpapers && root.wallpapers.length > 0) {
            const idx = Math.floor(Math.random() * root.wallpapers.length);
            const chosen = root.wallpapers[idx];
            if (chosen && chosen.path) {
                root.setWallpaper(chosen.path);
                return;
            }
        }
        root.statusMessage = "Selecionando aleatório..."
        wpSetter.command = ["/home/gabriel/.config/quickshell/scripts/wallpaper_tool.sh", "random"]
        wpSetter.running = true
    }

    Component.onCompleted: {
        refresh()
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: 10

        // ── 1. HEADER APPLE (Voltar, Título, Shuffle, Refresh) ───
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: 20
            color: root.controlCenter.glassBgColor
            border.width: 0

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 12
                spacing: 8

                // Botão Voltar (Círculo de Vidro)
                Rectangle {
                    width: 34
                    height: 34
                    radius: 17
                    color: backMouse.containsMouse ? root.controlCenter.glassHoverColor : Qt.rgba(255, 255, 255, 0.14)
                    scale: backMouse.pressed ? 0.92 : (backMouse.containsMouse ? 1.05 : 1.0)

                    Behavior on color { ColorAnimation { duration: 130 } }
                    Behavior on scale { NumberAnimation { duration: 110 } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "chevron-left"
                        size: 16
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.controlCenter.currentView = "main"
                    }
                }

                // Título
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: "Papéis de Parede"
                            color: "#ffffff"
                            font.family: "Inter, sans-serif"
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            renderType: Text.NativeRendering
                        }
                        Text {
                            text: root.isLoading ? "Carregando..." : (root.wallpapers.length + " papéis de parede")
                            color: Qt.rgba(255, 255, 255, 0.60)
                            font.family: "Inter, sans-serif"
                            font.pixelSize: 10
                            renderType: Text.NativeRendering
                        }
                    }
                }

                // Botão Aleatório / Shuffle (Estilo Apple Glass)
                Rectangle {
                    width: 34
                    height: 34
                    radius: 17
                    color: shuffleMouse.containsMouse ? root.controlCenter.glassHoverColor : Qt.rgba(255, 255, 255, 0.14)
                    scale: shuffleMouse.pressed ? 0.92 : (shuffleMouse.containsMouse ? 1.05 : 1.0)

                    Behavior on color { ColorAnimation { duration: 130 } }
                    Behavior on scale { NumberAnimation { duration: 110 } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "shuffle"
                        size: 15
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: shuffleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectRandom()
                    }
                }

                // Botão Atualizar
                Rectangle {
                    width: 34
                    height: 34
                    radius: 17
                    color: refreshMouse.containsMouse ? root.controlCenter.glassHoverColor : Qt.rgba(255, 255, 255, 0.14)
                    scale: refreshMouse.pressed ? 0.92 : (refreshMouse.containsMouse ? 1.05 : 1.0)

                    Behavior on color { ColorAnimation { duration: 130 } }
                    Behavior on scale { NumberAnimation { duration: 110 } }

                    SvgIcon {
                        id: refreshIcon
                        anchors.centerIn: parent
                        name: "refresh"
                        size: 15
                        color: "#ffffff"

                        RotationAnimation on rotation {
                            running: root.isLoading
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 750
                        }
                    }

                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refresh()
                    }
                }
            }
        }

        // ── 2. BARRA DE BUSCA APPLE (Com Lupa e Clear) ───────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 14
            color: root.controlCenter.glassBgColor
            border.width: 0

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 8

                SvgIcon {
                    name: "search"
                    size: 15
                    color: searchInput.activeFocus ? "#ffffff" : Qt.rgba(255, 255, 255, 0.60)
                }

                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    placeholderText: "Buscar papéis de parede..."
                    placeholderTextColor: Qt.rgba(255, 255, 255, 0.45)
                    color: "#ffffff"
                    font.family: "Inter, sans-serif"
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                    background: null
                    onTextChanged: root.searchQuery = text
                }

                Rectangle {
                    visible: searchInput.text.length > 0
                    width: 20
                    height: 20
                    radius: 10
                    color: Qt.rgba(255, 255, 255, 0.22)

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#ffffff"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = ""
                            root.searchQuery = ""
                        }
                    }
                }
            }
        }

        // ── 3. MENSAGEM DE STATUS ────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 12
            color: root.controlCenter.glassBgColor
            visible: root.statusMessage.length > 0
            border.width: 0

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6

                SvgIcon {
                    name: "check"
                    size: 13
                    color: "#34c759"
                }

                Text {
                    Layout.fillWidth: true
                    text: root.statusMessage
                    color: "#ffffff"
                    font.family: "Inter, sans-serif"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                    elide: Text.ElideRight
                }
            }
        }

        // ── 4. GRADE DE WALLPAPERS APPLE STYLE (2 COLUNAS) ──────
        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(340, gridFlow.implicitHeight)
            contentHeight: gridFlow.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Flow {
                id: gridFlow
                width: parent.width
                spacing: 10

                // Mensagem de busca vazia
                Text {
                    visible: root.filteredWallpapers.length === 0
                    width: parent.width
                    text: root.searchQuery ? "Nenhum papel de parede encontrado com \"" + root.searchQuery + "\"" : "Nenhum papel de parede encontrado em ~/Pictures/Wallpapers"
                    color: Qt.rgba(255, 255, 255, 0.60)
                    font.family: "Inter, sans-serif"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 30
                    bottomPadding: 30
                    renderType: Text.NativeRendering
                }

                Repeater {
                    model: root.filteredWallpapers

                    delegate: Rectangle {
                        id: wallTile
                        width: (gridFlow.width - 10) / 2
                        height: 105
                        radius: 16
                        color: root.controlCenter.glassBgColor
                        border.width: isCurrent ? 2 : 0
                        border.color: isCurrent ? "#34c759" : "transparent"
                        clip: true

                        scale: tileMouse.pressed ? 0.94 : (tileMouse.containsMouse ? 1.03 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                        readonly property bool isCurrent: (modelData.path === root.activeWallpaper) || modelData.active

                        // Imagem de Fundo (Full Preview)
                        Image {
                            anchors.fill: parent
                            source: "file://" + modelData.path
                            sourceSize.width: 256
                            sourceSize.height: 160
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            mipmap: true
                            opacity: isCurrent ? 0.95 : (tileMouse.containsMouse ? 0.88 : 0.68)
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        // Gradiente Escuro na Base para Textos Legíveis
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: parent.height * 0.60
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.0) }
                                GradientStop { position: 0.50; color: Qt.rgba(0, 0, 0, 0.45) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.80) }
                            }
                        }

                        // Badge de Ativo (Apple Checkmark Circle)
                        Rectangle {
                            visible: isCurrent
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            width: 22
                            height: 22
                            radius: 11
                            color: "#34c759"

                            SvgIcon {
                                anchors.centerIn: parent
                                name: "check"
                                size: 12
                                color: "#ffffff"
                            }
                        }

                        // Informação do Wallpaper (Nome Limpo)
                        ColumnLayout {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 8
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: "#ffffff"
                                font.family: "Inter, sans-serif"
                                font.pixelSize: 11
                                font.weight: isCurrent ? Font.Bold : Font.DemiBold
                                renderType: Text.NativeRendering
                                elide: Text.ElideRight
                            }

                            Text {
                                text: isCurrent ? "Ativo" : "Aplicar"
                                color: isCurrent ? "#34c759" : Qt.rgba(255, 255, 255, 0.65)
                                font.family: "Inter, sans-serif"
                                font.pixelSize: 9
                                font.weight: Font.Medium
                                renderType: Text.NativeRendering
                            }
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.setWallpaper(modelData.path)
                            }
                        }
                    }
                }
            }
        }
    }
}
