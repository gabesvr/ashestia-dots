import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var controlCenter

    implicitHeight: mainLayout.implicitHeight
    implicitWidth: 340

    property var allApps: []
    property var filteredApps: []
    property string searchText: ""
    property bool isLoading: false

    // ── Processo de Listagem de Apps ──────────────────────────
    Process {
        id: appsLister
        command: ["/home/gabriel/.config/quickshell/scripts/apps_tool", "list"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    root.allApps = JSON.parse(line.trim())
                    root.filterApps(root.searchText)
                    root.isLoading = false
                } catch (e) {
                    root.isLoading = false
                }
            }
        }
    }

    // ── Processo de Lançamento de Apps ────────────────────────
    Process {
        id: appLauncher
        running: false
    }

    function refresh() {
        root.isLoading = true
        appsLister.running = true
    }

    function filterApps(query) {
        root.searchText = query
        const q = (query || "").trim().toLowerCase()
        if (q.length === 0) {
            root.filteredApps = root.allApps
        } else {
            root.filteredApps = root.allApps.filter(app => {
                const nameMatch = (app.name || "").toLowerCase().includes(q)
                const commentMatch = (app.comment || "").toLowerCase().includes(q)
                const execMatch = (app.exec || "").toLowerCase().includes(q)
                return nameMatch || commentMatch || execMatch
            })
        }
    }

    function launchApp(execCmd, desktopFile, isTerminal) {
        let target = desktopFile || execCmd
        let fallback = execCmd || ""
        if (isTerminal) {
            fallback = "foot -e " + execCmd
            target = fallback
        }
        appLauncher.command = ["/home/gabriel/.config/quickshell/scripts/apps_tool", "launch", target, fallback]
        appLauncher.running = false
        appLauncher.running = true
        // Fecha o Control Center imediatamente para focar na nova janela
        root.controlCenter.hideIsland()
    }

    Component.onCompleted: {
        // Inicialização sob demanda quando aberto via openAppsWidget()
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: 10

        // ── 1. HEADER (Voltar, Título, Contador) ──────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: 20
            color: root.controlCenter.glassBgColor
            border.width: 0

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                // Botão Voltar
                Rectangle {
                    width: 34
                    height: 34
                    radius: 17
                    color: backMouse.containsMouse ? root.controlCenter.glassHoverColor : Qt.rgba(255, 255, 255, 0.14)
                    border.width: 0
                    scale: backMouse.pressed ? 0.90 : (backMouse.containsMouse ? 1.08 : 1.0)

                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 140 } }

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

                // Ícone + Título
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    SvgIcon {
                        name: "apps"
                        size: 18
                        color: "#ffffff"
                    }

                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: "Aplicativos"
                            color: "#ffffff"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                        }
                        Text {
                            text: root.isLoading ? "Carregando..." : (root.allApps.length + " instalados")
                            color: Qt.rgba(255, 255, 255, 0.60)
                            font.pixelSize: 11
                        }
                    }
                }

                // Botão Recarregar
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: refreshMouse.containsMouse ? root.controlCenter.glassHoverColor : "transparent"
                    scale: refreshMouse.pressed ? 0.90 : 1.0

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "refresh"
                        size: 15
                        color: "#ffffff"
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

        // ── 2. CAMPO DE BUSCA (Search Box) ────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 14
            color: root.controlCenter.glassBgColor
            border.width: 0

            Behavior on border.color { ColorAnimation { duration: 140 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 8

                SvgIcon {
                    name: "search"
                    size: 15
                    color: searchInput.activeFocus ? (root.controlCenter ? root.controlCenter.accentColor : "#b088ff") : "#75788e"
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    clip: true
                    color: "#ffffff"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    selectionColor: root.controlCenter ? root.controlCenter.accentColor : "#b088ff"
                    selectedTextColor: root.controlCenter ? root.controlCenter.accentTextColor : "#131418"

                    onTextChanged: {
                        root.filterApps(text)
                    }

                    onAccepted: {
                        if (root.filteredApps && root.filteredApps.length > 0) {
                            const first = root.filteredApps[0]
                            root.launchApp(first.exec, first.desktop_file)
                        }
                    }

                    Text {
                        anchors.fill: parent
                        text: "Buscar aplicativos..."
                        color: "#75788e"
                        font.pixelSize: 12
                        visible: !searchInput.text && !searchInput.activeFocus
                    }
                }

                SvgIcon {
                    visible: searchInput.text.length > 0
                    name: "trash"
                    size: 13
                    color: "#75788e"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = ""
                            root.filterApps("")
                        }
                    }
                }
            }
        }

        // ── 3. LISTA DE APLICATIVOS (Flickable + ColumnLayout) ──
        Text {
            text: root.searchText.length > 0 ? ("RESULTADOS (" + root.filteredApps.length + ")") : "TODOS OS APLICATIVOS"
            color: "#9da0b4"
            font.pixelSize: 10
            font.weight: Font.Bold
            Layout.leftMargin: 4
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(320, appsCol.implicitHeight)
            contentHeight: appsCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: appsCol
                width: parent.width
                spacing: 6

                Repeater {
                    model: root.filteredApps

                    delegate: Rectangle {
                        id: appCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 14
                        color: itemMouse.containsMouse ? root.controlCenter.glassHoverColor : root.controlCenter.glassBgColor
                        border.width: 0

                        scale: itemMouse.pressed ? 0.98 : (itemMouse.containsMouse ? 1.01 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 110 } }
                        Behavior on color { ColorAnimation { duration: 130 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 12

                            // Ícone do Aplicativo
                            Rectangle {
                                width: 36
                                height: 36
                                radius: 9
                                color: (modelData.icon_path && appImg.status !== Image.Error) ? "transparent" : Qt.rgba(255, 255, 255, 0.12)
                                border.color: "transparent"
                                border.width: 0

                                Image {
                                    id: appImg
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    source: modelData.icon_path ? ("file://" + modelData.icon_path) : ""
                                    sourceSize.width: 72
                                    sourceSize.height: 72
                                    smooth: true
                                    mipmap: true
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    visible: modelData.icon_path && status !== Image.Error
                                }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    name: "rocket"
                                    size: 18
                                    color: root.controlCenter ? root.controlCenter.accentColor : "#b088ff"
                                    visible: !modelData.icon_path || appImg.status === Image.Error
                                }
                            }

                            // Nome e Comentário
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: itemMouse.containsMouse ? "#ffffff" : "#f0f1f5"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.comment || modelData.exec
                                    color: "#83869c"
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }

                            // Chevron / Indicador de Ação
                            SvgIcon {
                                name: "chevron-right"
                                size: 13
                                color: itemMouse.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.40)
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.launchApp(modelData.exec, modelData.desktop_file, modelData.terminal)
                            }
                        }
                    }
                }

                // Mensagem quando não há resultados
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    radius: 12
                    color: "transparent"
                    visible: root.filteredApps.length === 0 && !root.isLoading

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        SvgIcon {
                            Layout.alignment: Qt.AlignHCenter
                            name: "search"
                            size: 24
                            color: "#555870"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Nenhum aplicativo encontrado"
                            color: "#83869c"
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
