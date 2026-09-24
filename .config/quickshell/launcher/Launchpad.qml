import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "./widgets"
import QtQuick.Controls
import QtQuick.Layouts

// ============================================================
// macOS Light Frosted Glass Launchpad — Menu de Aplicações
// Visual idêntico à referência: Vidro branco translúcido,
// tipografia escura nítida, busca em pílula, grid de 11 colunas
// e rodapé informativo com atalhos de navegação.
// ============================================================

PanelWindow {
    id: root

    // Ocupa a tela inteira (Fullscreen Overlay)
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    visible: root.shown || root.isClosing
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.namespace: "quickshell"

    color: "transparent"

    property bool shown: false
    property bool isClosing: false
    property var allApps: []
    property var filteredApps: []
    property string searchText: ""
    property int selectedIndex: 0

    // ── Carregamento Ultrarrápido de Aplicativos via apps_tool (C nativo) ──
    Process {
        id: appsLister
        command: [GlassTheme.home + "/.config/quickshell/scripts/apps_tool", "list"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const parsed = JSON.parse(line.trim());
                    // Ordena alfabeticamente ignorando maiúsculas
                    parsed.sort((a, b) => (a.name || "").localeCompare(b.name || "", undefined, { sensitivity: "base" }));
                    root.allApps = parsed;
                    root.filterApps(root.searchText);
                } catch (e) {
                    console.log("[Launchpad] Erro ao parsear apps:", e);
                }
            }
        }
    }

    // ── Lançador de Aplicativos ──────────────────────────────
    Process {
        id: appLauncher
        running: false
    }

    function showLaunchpad() {
        console.log("[LAUNCHPAD.QML] showLaunchpad CALLED! root.shown=", root.shown)
        if (root.shown && !root.isClosing) return;
        root.isClosing = false;
        root.shown = true;
        root.searchText = "";
        searchInput.text = "";
        root.filterApps("");
        root.selectedIndex = 0;
        appsLister.running = true;
        Qt.callLater(() => {
            searchInput.forceActiveFocus();
        });
    }

    function hideLaunchpad() {
        console.log("[LAUNCHPAD.QML] hideLaunchpad CALLED!")
        if (!root.shown || root.isClosing) return;
        root.isClosing = true;
        closeAnim.restart();
    }

    function toggleLaunchpad() {
        console.log("[LAUNCHPAD.QML] toggleLaunchpad CALLED! current shown=", root.shown)
        if (root.shown && !root.isClosing) {
            root.hideLaunchpad();
        } else {
            root.showLaunchpad();
        }
    }

    function filterApps(query) {
        root.searchText = query;
        const q = (query || "").trim().toLowerCase();
        if (q.length === 0) {
            root.filteredApps = root.allApps;
        } else {
            root.filteredApps = root.allApps.filter(app => {
                const nameMatch = (app.name || "").toLowerCase().includes(q);
                const commentMatch = (app.comment || "").toLowerCase().includes(q);
                const execMatch = (app.exec || "").toLowerCase().includes(q);
                return nameMatch || commentMatch || execMatch;
            });
        }
        root.selectedIndex = 0;
        if (appGrid) {
            appGrid.positionViewAtBeginning();
        }
    }

    function launchApp(execCmd, desktopFile, isTerminal) {
        let target = desktopFile || execCmd;
        let fallback = execCmd || "";
        if (isTerminal) {
            fallback = "foot -e " + execCmd;
            target = fallback;
        }

        console.log("[LAUNCHPAD] Launching app target:", target, "fallback:", fallback);

        // Dispara através do apps_tool otimizado com Hyprland e double-fork
        appLauncher.command = [GlassTheme.home + "/.config/quickshell/scripts/apps_tool", "launch", target, fallback];
        appLauncher.running = false;
        appLauncher.running = true;

        root.hideLaunchpad();
    }

    Component.onCompleted: {
        appsLister.running = true;
    }

    // ── Animação de Fechamento Fluida ─────────────────────────
    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: mainSurface
            property: "opacity"
            to: 0.0
            duration: 160
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: mainSurface
            property: "scale"
            to: 0.96
            duration: 160
            easing.type: Easing.InQuad
        }
        onFinished: {
            root.shown = false;
            root.isClosing = false;
            root.searchText = "";
            searchInput.text = "";
        }
    }

    // ── SUPERFÍCIE PRINCIPAL: VIDRO BRANCO FROSTED GLASS ──────
    Rectangle {
        id: mainSurface
        anchors.fill: parent

        // Branco elegante com translucidez e blur nativo do Hyprland
        color: Qt.rgba(246/255, 248/255, 252/255, 0.72)

        scale: root.shown && !root.isClosing ? 1.0 : 0.96
        opacity: root.shown && !root.isClosing ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        // Clique no fundo vazio fecha o Launchpad
        MouseArea {
            anchors.fill: parent
            onClicked: root.hideLaunchpad()
        }

        // Reflexo de luz sutil no topo do vidro
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(255, 255, 255, 0.75)
        }

        // Vinheta suave inferior para o rodapé
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 56
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.05) }
            }
        }

        // ── 1. TÍTULO "APPLICATIONS" ───────────────────────────
        Text {
            id: titleText
            anchors.top: parent.top
            anchors.topMargin: 44
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Applications"
            font.family: "Inter, -apple-system, sans-serif"
            font.pixelSize: 28
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
            color: "#1d1d1f"
        }

        // ── 2. CAMPO DE BUSCA CENTRALIZADO (Pill-shaped) ──────
        Rectangle {
            id: searchBox
            anchors.top: titleText.bottom
            anchors.topMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            width: 480
            height: 38
            radius: 19
            color: Qt.rgba(0, 0, 0, 0.04)
            border.width: 1
            border.color: searchInput.activeFocus ? Qt.rgba(0, 122/255, 255/255, 0.50) : Qt.rgba(0, 0, 0, 0.12)

            Behavior on border.color {
                ColorAnimation { duration: 140 }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 9

                SvgIcon {
                    name: "search"
                    size: 14
                    color: searchInput.activeFocus ? "#007aff" : "#86868b"
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    clip: true
                    font.family: "Inter, -apple-system, sans-serif"
                    font.pixelSize: 13
                    renderType: Text.NativeRendering
                    color: "#1d1d1f"
                    selectionColor: "#007aff"
                    selectedTextColor: "#ffffff"

                    Text {
                        anchors.fill: parent
                        text: "Search applications"
                        font: parent.font
                        color: "#86868b"
                        visible: parent.text.length === 0
                        verticalAlignment: Text.AlignVCenter
                        renderType: Text.NativeRendering
                    }

                    onTextChanged: {
                        root.filterApps(text);
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            root.hideLaunchpad();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.filteredApps.length > root.selectedIndex && root.selectedIndex >= 0) {
                                const app = root.filteredApps[root.selectedIndex];
                                root.launchApp(app.exec, app.desktop_file, app.terminal);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Right) {
                            if (root.selectedIndex < root.filteredApps.length - 1) {
                                root.selectedIndex++;
                                appGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Left) {
                            if (root.selectedIndex > 0) {
                                root.selectedIndex--;
                                appGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            const next = root.selectedIndex + appGrid.columns;
                            if (next < root.filteredApps.length) {
                                root.selectedIndex = next;
                                appGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            const prev = root.selectedIndex - appGrid.columns;
                            if (prev >= 0) {
                                root.selectedIndex = prev;
                                appGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
                            }
                            event.accepted = true;
                        }
                    }
                }

                // Botão Limpar busca
                Rectangle {
                    visible: searchInput.text.length > 0
                    width: 18
                    height: 18
                    radius: 9
                    color: Qt.rgba(0, 0, 0, 0.12)
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#555555"
                        font.pixelSize: 10
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = "";
                            root.filterApps("");
                            searchInput.forceActiveFocus();
                        }
                    }
                }
            }
        }

        // ── 3. GRID DE APLICATIVOS (11 Colunas exatas) ────────
        GridView {
            id: appGrid
            anchors.top: searchBox.bottom
            anchors.topMargin: 28
            anchors.bottom: footerHints.top
            anchors.bottomMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 80
            anchors.rightMargin: 80
            clip: true

            // 11 colunas no monitor 1920x1080 (adaptativo caso redimensione)
            property int columns: Math.max(7, Math.min(11, Math.floor(width / 145)))
            cellWidth: Math.floor(width / columns)
            cellHeight: 122

            model: root.filteredApps

            // Mensagem quando nada é encontrado
            Text {
                anchors.centerIn: parent
                visible: root.filteredApps.length === 0
                text: "No applications found for \"" + root.searchText + "\""
                color: "#86868b"
                font.family: "Inter, -apple-system, sans-serif"
                font.pixelSize: 14
            }

            delegate: Item {
                width: appGrid.cellWidth
                height: appGrid.cellHeight

                readonly property bool isSelected: index === root.selectedIndex
                readonly property bool isHovered: itemMouse.containsMouse

                // Retângulo de Destaque / Seleção Estilo macOS Light Glass
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 18
                    color: isSelected ? Qt.rgba(0, 0, 0, 0.07) : (isHovered ? Qt.rgba(0, 0, 0, 0.04) : "transparent")
                    border.width: isSelected ? 1 : (isHovered ? 1 : 0)
                    border.color: isSelected ? Qt.rgba(0, 0, 0, 0.08) : (isHovered ? Qt.rgba(0, 0, 0, 0.04) : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: 110 }
                    }
                }

                // Ícone do Aplicativo (WhiteSur macOS Theme)
                Item {
                    id: iconBox
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 56
                    height: 56

                    scale: (isHovered || isSelected) ? 1.06 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                    }

                    Image {
                        id: appIconImg
                        anchors.fill: parent
                        source: modelData.icon_path ? ("file://" + modelData.icon_path) : ""
                        sourceSize: Qt.size(112, 112)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    // Fallback caso o ícone não seja encontrado
                    SvgIcon {
                        anchors.centerIn: parent
                        visible: !appIconImg.visible
                        name: "apps"
                        size: 32
                        color: "#444444"
                    }
                }

                // Nome do Aplicativo (Texto escuro nítido sobre vidro branco)
                Text {
                    anchors.top: iconBox.bottom
                    anchors.topMargin: 7
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 12
                    text: modelData.name || ""
                    font.family: "Inter, -apple-system, sans-serif"
                    font.pixelSize: 12
                    font.weight: isSelected ? Font.DemiBold : Font.Normal
                    color: "#1d1d1f"
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.launchApp(modelData.exec, modelData.desktop_file, modelData.terminal);
                    }
                    onEntered: {
                        root.selectedIndex = index;
                    }
                }
            }
        }

        // ── 4. RODAPÉ COM CONTADOR E DICAS DE NAVEGAÇÃO ───────
        Text {
            id: footerHints
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.filteredApps.length + " applications  ·  Arrow keys to navigate  ·  Enter to open  ·  Esc to close"
            font.family: "Inter, -apple-system, sans-serif"
            font.pixelSize: 12
            color: "#6e6e73"
            renderType: Text.NativeRendering
        }
    }
}
