import QtQuick

// Cabeçalho comum dos painéis expandidos (Wi-Fi, Bluetooth, Wallpapers)
Item {
    id: hdr
    property url iconSource: ""
    property string title: ""
    property string subtitle: ""
    property color accent: "#0a84ff"
    property bool showSwitch: false
    property bool switchOn: false
    property bool showRefresh: true
    property bool busy: false

    signal switchToggled()
    signal refreshClicked()
    signal closeClicked()

    height: 38


    // Ícone-selo
    Rectangle {
        id: badge
        width: 34; height: 34
        radius: 17
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: hdr.accent
        Image {
            anchors.centerIn: parent
            width: 18; height: 18
            source: hdr.iconSource
            sourceSize.width: 48
            sourceSize.height: 48
            fillMode: Image.PreserveAspectFit
        }
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: 10
        anchors.right: controls.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            text: hdr.title
            color: "#ffffff"
            font.family: "SF Pro Rounded"
            font.pixelSize: 16
            font.weight: Font.Bold
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.35)
        }
        Text {
            width: parent.width
            text: hdr.subtitle
            color: Qt.rgba(1, 1, 1, 0.78)
            font.family: "SF Pro Display"
            font.pixelSize: 10
            elide: Text.ElideRight
            visible: text !== ""
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.30)
        }
    }

    Row {
        id: controls
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        PillSwitch {
            visible: hdr.showSwitch
            on: hdr.switchOn
            anchors.verticalCenter: parent.verticalCenter
            onToggled: hdr.switchToggled()
        }
        GlassIconButton {
            visible: hdr.showRefresh
            size: 26
            iconSource: "file://" + GlassTheme.home + "/.config/quickshell/assets/icons/refresh.svg"
            spinning: hdr.busy
            anchors.verticalCenter: parent.verticalCenter
            onClicked: hdr.refreshClicked()
        }
        GlassIconButton {
            kind: "close"
            size: 26
            anchors.verticalCenter: parent.verticalCenter
            onClicked: hdr.closeClicked()
        }
    }
}
