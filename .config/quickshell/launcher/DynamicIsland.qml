import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    function setWallpaper(path) {
    }

    // Ancoragem na tela ativa
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    mask: Region {
        item: pill
    }

    visible: root.shown || root.isClosing
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.namespace: "quickshell"

    color: "transparent"

    readonly property real screenWidth: {
        if (root.screen && root.screen.width > 100) return root.screen.width
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.width > 100) return Hyprland.focusedMonitor.width
        if (Quickshell.screens && Quickshell.screens.length > 0 && Quickshell.screens[0].width > 100) return Quickshell.screens[0].width
        return 1920
    }
    readonly property real screenHeight: {
        if (root.screen && root.screen.height > 100) return root.screen.height
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.height > 100) return Hyprland.focusedMonitor.height
        if (Quickshell.screens && Quickshell.screens.length > 0 && Quickshell.screens[0].height > 100) return Quickshell.screens[0].height
        return 1200
    }

    implicitWidth: root.screenWidth
    implicitHeight: root.screenHeight

    property color glassBgColor: Qt.rgba(20/255, 24/255, 32/255, 0.25)
    property color glassHoverColor: Qt.rgba(36/255, 42/255, 54/255, 0.38)

    property bool shown: false
    property bool isClosing: false
    property bool isReady: false
    property bool isGliding: false
    property int activeWorkspaceId: (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0) ? Hyprland.focusedWorkspace.id : 1
    property var workspaceList: [1, 2, 3, 4, 5]
    property string currentTime: "00:00"
    property int batteryVal: 100
    property string batteryStat: "Full"
    property string mediaStat: "Stopped"
    property string mediaTitle: ""
    property string mediaArtist: ""
    property color accentColor: "#38bdf8"

    signal expandRequested()
    signal morphToControlCenterRequested()

    function updateScreen() {
        if (Hyprland.focusedMonitor) {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === Hyprland.focusedMonitor.name) {
                    root.screen = Quickshell.screens[i]
                    return
                }
            }
        }
        if (Quickshell.screens && Quickshell.screens.length > 0) {
            root.screen = Quickshell.screens[0]
        }
    }

    function updateWorkspaceList() {
        let maxWs = 5
        if (root.activeWorkspaceId > maxWs) maxWs = root.activeWorkspaceId
        if (Hyprland.workspaces && Hyprland.workspaces.values) {
            for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
                let wid = Hyprland.workspaces.values[i].id
                if (wid > maxWs) {
                    maxWs = wid
                }
            }
        }
        let list = []
        for (let i = 1; i <= maxWs; i++) {
            list.push(i)
        }
        root.workspaceList = list
    }

    function isWorkspaceOccupied(wsId) {
        if (!Hyprland.workspaces || !Hyprland.workspaces.values) return false
        for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
            if (Hyprland.workspaces.values[i].id === wsId) return true
        }
        return false
    }

    function updateActiveWs() {
        if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0) {
            root.activeWorkspaceId = Hyprland.focusedWorkspace.id
        }
        root.updateWorkspaceList()
    }

    Component.onCompleted: {
        root.updateScreen()
        root.updateActiveWs()
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            root.updateActiveWs()
        }
        function onRawEvent(event) {
            if (event.name === "workspace") {
                let id = parseInt(event.data)
                if (!isNaN(id) && id > 0) {
                    root.activeWorkspaceId = id
                }
            }
            root.updateWorkspaceList()
        }
    }

    function toggleIsland() {
        if (root.shown) hideIsland()
        else showIsland()
    }

    function showIsland() {
        updateScreen()
        updateActiveWs()
        root.isGliding = false
        root.isReady = false
        closeAnim.stop()
        openAnim.stop()
        glideToCCAnim.stop()
        glideFromCCAnim.stop()
        root.isClosing = false

        // Estado inicial: a bolinha (tamanho da câmera) posicionada dentro da moldura preta (y = -40)
        pill.opacity = 1.0
        pill.y = -40
        pill.height = 38
        pill.width = 38
        pill.radius = 19
        pill.x = Qt.binding(() => (root.screenWidth - pill.width) / 2)
        contentGroup.opacity = 0.0
        contentGroup.scale = 1.0

        root.shown = true
        updateTime()
        openAnim.restart()
        batReader.running = true
    }

    function hideIsland() {
        if (!root.shown) return
        root.isGliding = false
        root.isReady = false
        root.shown = false
        root.isClosing = true
        openAnim.stop()
        glideToCCAnim.stop()
        glideFromCCAnim.stop()
        closeAnim.restart()
    }

    function glideToControlCenter() {
        if (!root.shown || root.isClosing) return
        root.isReady = false
        openAnim.stop()
        closeAnim.stop()
        glideFromCCAnim.stop()

        pill.x = (root.screenWidth - pill.width) / 2
        root.isGliding = true
        glideToCCAnim.restart()
    }

    function morphFromControlCenter() {
        updateScreen()
        updateActiveWs()
        root.isReady = false
        root.isClosing = false
        closeAnim.stop()
        openAnim.stop()
        glideToCCAnim.stop()

        root.isGliding = true
        pill.opacity = 1.0
        pill.x = root.screenWidth - 16 - 350
        pill.y = 12
        pill.width = 38
        pill.height = 38
        pill.radius = 19
        contentGroup.opacity = 0.0

        root.shown = true
        updateTime()
        batReader.running = true

        glideFromCCAnim.restart()
    }

    function updateTime() {
        const d = new Date()
        let h = d.getHours()
        let m = d.getMinutes()
        root.currentTime = (h < 10 ? "0" + h : h) + ":" + (m < 10 ? "0" + m : m)
    }

    // ── Timer de Relógio (1s) ─────────────────────────────────
    Timer {
        interval: 1000
        running: root.shown
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.updateTime()
            root.updateActiveWs()
        }
    }

    // ── Status de Bateria ─────────────────────────────────────
    Process {
        id: batReader
        command: ["bash", "-c",
            "CAP=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 100); " +
            "STAT=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null || echo Full); " +
            "echo \"$CAP;$STAT\""
        ]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                const parts = line.trim().split(";")
                if (parts.length >= 2) {
                    root.batteryVal = parseInt(parts[0]) || 100
                    root.batteryStat = parts[1] || "Full"
                }
            }
        }
    }


    // ── ANIMAÇÃO DE ENTRADA: O PINGO ESCORRE DO PRETO DA MOLDURA (y = -40 -> 8) E SE EXPANDE EM ILHA ──
    SequentialAnimation {
        id: openAnim

        // 1. FASE 1: A bolinha (38x38) desce suavemente do preto acima da tela até y = 8 (largura estritamente travada em 38)
        ParallelAnimation {
            NumberAnimation {
                target: pill
                property: "y"
                from: -40
                to: 8
                duration: 380
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: pill
                property: "width"
                from: 38
                to: 38
                duration: 380
            }
        }

        // Breve assentamento suave do pingo na tela
        PauseAnimation { duration: 50 }

        // 2. FASE 2: A bolinha se expande suavemente para os dois lados, formando a Dynamic Island (sem balanços)
        ParallelAnimation {
            NumberAnimation {
                target: pill
                property: "width"
                from: 38
                to: pill.targetWidth
                duration: 340
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: pill
                property: "x"
                from: (root.screenWidth - 38) / 2
                to: (root.screenWidth - pill.targetWidth) / 2
                duration: 340
                easing.type: Easing.OutCubic
            }

            SequentialAnimation {
                PauseAnimation { duration: 70 }
                NumberAnimation {
                    target: contentGroup
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: 250
                    easing.type: Easing.OutQuad
                }
            }
        }

        onFinished: {
            pill.x = Qt.binding(() => (root.screenWidth - pill.width) / 2)
            pill.width = Qt.binding(() => pill.targetWidth)
            pill.height = 38
            pill.radius = 19
            pill.y = 8
            contentGroup.opacity = 1.0
            contentGroup.scale = 1.0
            root.isReady = true
        }
    }

    // ── ANIMAÇÃO DE SAÍDA: REVERSO EXATO — ILHA RECOLHE EM PINGO E O PINGO SOBE DE VOLTA PARA O PRETO ──
    SequentialAnimation {
        id: closeAnim

        // 1. FASE 1: O conteúdo desvanece suavemente
        NumberAnimation {
            target: contentGroup
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: 100
            easing.type: Easing.OutQuad
        }

        // 2. FASE 2: A ilha se recolhe das duas pontas de volta para a bolinha circular (38px)
        ParallelAnimation {
            NumberAnimation {
                target: pill
                property: "width"
                to: 38
                duration: 260
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: pill
                property: "x"
                to: (root.screenWidth - 38) / 2
                duration: 260
                easing.type: Easing.InOutCubic
            }
        }

        // Breve pausa para registrar o pingo fechado
        PauseAnimation { duration: 30 }

        // 3. FASE 3: O pingo sobe em linha reta de volta para dentro da moldura preta (y = -40, travado em 38px)
        ParallelAnimation {
            NumberAnimation {
                target: pill
                property: "y"
                from: 8
                to: -40
                duration: 260
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: pill
                property: "width"
                from: 38
                to: 38
                duration: 260
            }
        }

        onFinished: {
            root.isClosing = false
            root.isReady = false
            root.isGliding = false
            pill.x = Qt.binding(() => (root.screenWidth - pill.width) / 2)
            pill.y = -40
            pill.width = 38
            pill.height = 38
            pill.radius = 19
            contentGroup.opacity = 0.0
        }
    }

    // ── ANIMAÇÃO DE MORPH: ILHA ENCOLHE EM GOTA LÍQUIDA E DESLIZA ATÉ O CONTROL CENTER ──
    SequentialAnimation {
        id: glideToCCAnim

        // 1. Desvanece o conteúdo instantaneamente
        NumberAnimation {
            target: contentGroup
            property: "opacity"
            to: 0.0
            duration: 70
            easing.type: Easing.OutQuad
        }

        // 2. Encolhe para a gota d'água circular (38x38) no centro
        ParallelAnimation {
            NumberAnimation {
                target: pill
                property: "width"
                to: 38
                duration: 160
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: pill
                property: "x"
                to: (root.screenWidth - 38) / 2
                duration: 160
                easing.type: Easing.InOutCubic
            }
        }

        // 3. A gota líquida desliza suavemente pelo topo até o canto superior do Control Center (1554, 12)
        ParallelAnimation {
            NumberAnimation {
                target: pill
                property: "x"
                from: (root.screenWidth - 38) / 2
                to: root.screenWidth - 16 - 350
                duration: 300
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: pill
                property: "y"
                from: 8
                to: 12
                duration: 300
                easing.type: Easing.InOutCubic
            }
        }

        onFinished: {
            root.shown = false
            root.isClosing = false
            root.isGliding = false
            pill.x = Qt.binding(() => (root.screenWidth - pill.width) / 2)
            root.morphToControlCenterRequested()
        }
    }

    // ── ANIMAÇÃO DE RETORNO: GOTA LÍQUIDA DESLIZA DO CONTROL CENTER DE VOLTA PARA O CENTRO E ABRE A ILHA ──
    SequentialAnimation {
        id: glideFromCCAnim

        // 1. A gota líquida desliza do Control Center até o centro da tela
        ParallelAnimation {
            NumberAnimation {
                target: pill
                property: "x"
                from: root.screenWidth - 16 - 350
                to: (root.screenWidth - 38) / 2
                duration: 300
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: pill
                property: "y"
                from: 12
                to: 8
                duration: 300
                easing.type: Easing.InOutCubic
            }
        }

        // 2. A gota se expande horizontalmente para a esquerda e direita formando a Dynamic Island
        ParallelAnimation {
            NumberAnimation {
                target: pill
                property: "width"
                from: 38
                to: pill.targetWidth
                duration: 240
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: pill
                property: "x"
                from: (root.screenWidth - 38) / 2
                to: (root.screenWidth - pill.targetWidth) / 2
                duration: 240
                easing.type: Easing.OutCubic
            }

            SequentialAnimation {
                PauseAnimation { duration: 60 }
                NumberAnimation {
                    target: contentGroup
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }
        }

        onFinished: {
            root.isGliding = false
            pill.x = Qt.binding(() => (root.screenWidth - pill.width) / 2)
            pill.width = Qt.binding(() => pill.targetWidth)
            pill.height = 38
            pill.radius = 19
            pill.y = 8
            contentGroup.opacity = 1.0
            root.isReady = true
        }
    }

    // ── Pílula / Dynamic Island OLED Puro (Sem Bordas ou Contornos - Preto Puro) ──
    Rectangle {
        id: pill
        x: (root.screenWidth - width) / 2
        y: -40

        readonly property bool isHovered: pillMouseArea.containsMouse
        readonly property bool isMusicActive: root.mediaStat === "Playing"

        // Largura calculada dinamicamente conforme estado
        readonly property real targetWidth: isMusicActive ? (isHovered ? 340 : 320) : (isHovered ? 304 : 288)

        // Estado inicial de repouso: O pingo de 38x38 na moldura preta da câmera (y = -40)
        width: 38
        height: 38
        radius: 19

        // Animação de hover ou transição de música (ativada estritamente quando a ilha está pronta e em repouso)
        Behavior on width {
            enabled: root.isReady
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        color: pill.isHovered ? root.glassHoverColor : root.glassBgColor
        border.width: 0
        clip: false
        antialiasing: true
        smooth: true

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        // Base MouseArea: Clicar na ilha expande direto para a Central de Controle completa
        MouseArea {
            id: pillMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            z: 1
            onClicked: {
                if (root.isReady) {
                    root.glideToControlCenter()
                }
            }
        }

        // ── GRUPO DE CONTEÚDO (Permite fade in/out gracioso durante o morphing da câmera) ──
        Item {
            id: contentGroup
            anchors.fill: parent
            z: 3
            opacity: 0.0
            visible: opacity > 0.01

            // ── 1. ESQUERDA: WAYBAR WORKSPACE DOTS (Espaçamento compacto e elegante) ──
            Row {
                id: wsRow
                anchors.left: parent.left
                anchors.leftMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Repeater {
                    model: root.workspaceList

                    Rectangle {
                        id: dot
                        required property int modelData
                        readonly property bool isActive: root.activeWorkspaceId === modelData
                        readonly property bool isOccupied: root.isWorkspaceOccupied(modelData)
                        readonly property bool dotHovered: dotMouse.containsMouse

                        // Bolinha ativa vira cápsula elegante (20px), inativa fica circular (7px)
                        width: isActive ? 20 : 7
                        height: 7
                        radius: 3.5
                        antialiasing: true
                        smooth: true

                        Behavior on width {
                            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                        }

                        color: isActive 
                            ? root.accentColor 
                            : (dotHovered 
                                ? "#ffffff" 
                                : (isOccupied ? Qt.rgba(255, 255, 255, 0.75) : Qt.rgba(255, 255, 255, 0.25)))

                        Behavior on color {
                            ColorAnimation { duration: 180 }
                        }

                        MouseArea {
                            id: dotMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Hyprland.dispatch("workspace " + modelData)
                            }
                        }
                    }
                }
            }

            // ── 2. CENTRO: HORÁRIO CENTRALIZADO E GRANDE (Apple SF Pro 16px Bold) ──
            Item {
                id: centerClock
                anchors.centerIn: parent
                width: clockText.implicitWidth
                height: clockText.implicitHeight

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: root.currentTime
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.bold: true
                    font.family: "SF Pro Display, SF Pro Text, Inter, -apple-system, sans-serif"
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    antialiasing: true
                }
            }

            // ── 3. DIREITA: BATERIA VETORIAL AMPLIADA (+ EQUALIZADOR SE TOCANDO) ──
            Row {
                id: rightSection
                anchors.right: parent.right
                anchors.rightMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Mini Equalizador Animado Apple (Apenas quando tocando música)
                Row {
                    visible: pill.isMusicActive
                    spacing: 2.5
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: 2.5; height: 12; radius: 1
                        color: root.accentColor
                        antialiasing: true
                        SequentialAnimation on height {
                            loops: Animation.Infinite; running: pill.isMusicActive
                            NumberAnimation { to: 4; duration: 250 }
                            NumberAnimation { to: 13; duration: 280 }
                            NumberAnimation { to: 7; duration: 220 }
                        }
                    }
                    Rectangle {
                        width: 2.5; height: 8; radius: 1
                        color: root.accentColor
                        antialiasing: true
                        SequentialAnimation on height {
                            loops: Animation.Infinite; running: pill.isMusicActive
                            NumberAnimation { to: 14; duration: 220 }
                            NumberAnimation { to: 5; duration: 260 }
                            NumberAnimation { to: 10; duration: 240 }
                        }
                    }
                    Rectangle {
                        width: 2.5; height: 13; radius: 1
                        color: root.accentColor
                        antialiasing: true
                        SequentialAnimation on height {
                            loops: Animation.Infinite; running: pill.isMusicActive
                            NumberAnimation { to: 6; duration: 270 }
                            NumberAnimation { to: 14; duration: 230 }
                            NumberAnimation { to: 8; duration: 250 }
                        }
                    }
                }

                // Bateria Apple Ampliada e Nítida
                Row {
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter

                    // Cápsula da Bateria Maior (27x14px)
                    Rectangle {
                        width: 27
                        height: 14
                        radius: 4
                        color: Qt.rgba(255, 255, 255, 0.12)
                        border.color: Qt.rgba(255, 255, 255, 0.65)
                        border.width: 1.2
                        antialiasing: true
                        anchors.verticalCenter: parent.verticalCenter

                        // Nível interno proporcional com margem de respiração
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 2
                            width: Math.max(2, (parent.width - 4) * Math.min(1.0, root.batteryVal / 100))
                            radius: 2.2
                            antialiasing: true
                            color: root.batteryStat === "Charging" 
                                ? "#30d158" 
                                : (root.batteryVal <= 20 ? "#ff453a" : "#ffffff")
                        }

                        // Polo positivo (+) da bateria
                        Rectangle {
                            anchors.left: parent.right
                            anchors.leftMargin: 1.2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2
                            height: 5
                            radius: 1
                            color: Qt.rgba(255, 255, 255, 0.65)
                            antialiasing: true
                        }
                    }

                    // Porcentagem Ampliada (12px Bold)
                    Text {
                        text: root.batteryVal + "%"
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.bold: true
                        font.family: "SF Pro Text, Inter, -apple-system, sans-serif"
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
