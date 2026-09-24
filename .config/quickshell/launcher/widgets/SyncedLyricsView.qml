import QtQuick

Item {
    id: lv

    property var syncedLyrics: []
    property real currentPositionMs: 0
    property string fontFamily: ""
    property real baseFontSize: 16
    property bool blurEnabled: true
    property real activeOpacity: 1.0
    property real inactiveOpacity: 0.40
    readonly property real activeScale: 1.04

    signal seekTo(real positionSec)

    property real syncOffsetMs: 0

    readonly property int _currentIndex: {
        if (!syncedLyrics || syncedLyrics.length === 0) return 0;
        var adj = currentPositionMs + syncOffsetMs;
        var idx = 0;
        for (var i = 0; i < syncedLyrics.length; i++) {
            if (syncedLyrics[i].timestamp <= adj) idx = i;
            else break;
        }
        return idx;
    }

    property int _previousIndex: -1
    property bool _isUserScrolling: false

    on_CurrentIndexChanged: {
        if (_currentIndex === _previousIndex) return;
        _previousIndex = _currentIndex;
        if (!_isUserScrolling && lyricsList.count > 0) {
            lyricsList.positionViewAtIndex(_currentIndex, ListView.Center);
        }
    }

    // Letra nova carregada / painel reaberto / redimensionado → recentraliza na linha atual
    function recenter() {
        if (!_isUserScrolling && lyricsList.count > 0) lyricsList.positionViewAtIndex(_currentIndex, ListView.Center);
    }
    onSyncedLyricsChanged: { _previousIndex = -1; Qt.callLater(recenter); }
    onVisibleChanged: if (visible) Qt.callLater(recenter)
    onHeightChanged: Qt.callLater(recenter)

    Timer {
        id: snapBackTimer
        interval: 2500
        onTriggered: {
            lv._isUserScrolling = false;
            if (lyricsList.count > 0) {
                lyricsList.positionViewAtIndex(lv._currentIndex, ListView.Center);
            }
        }
    }

    ListView {
        id: lyricsList
        anchors.fill: parent
        clip: true
        spacing: Math.round(lv.baseFontSize * 0.4)
        topMargin: Math.round(lv.height * 0.15)
        bottomMargin: Math.round(lv.height * 0.25)
        model: lv.syncedLyrics && lv.syncedLyrics.length > 0 ? lv.syncedLyrics.length : 0

        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 400
        highlightMoveVelocity: -1

        onMovementStarted: {
            lv._isUserScrolling = true;
        }
        onMovementEnded: {
            snapBackTimer.restart();
        }

        delegate: Item {
            id: del
            width: lyricsList.width
            height: lineText.implicitHeight + Math.round(lv.baseFontSize * 0.5)

            readonly property bool _isActive: index === lv._currentIndex
            readonly property int _dist: Math.abs(index - lv._currentIndex)
            readonly property real _targetOpacity: _isActive ? lv.activeOpacity : Math.max(0.18, lv.inactiveOpacity - _dist * 0.08)

            Item {
                id: lineContainer
                width: parent.width
                height: parent.height
                scale: del._isActive ? lv.activeScale : 1.0
                transformOrigin: Item.Left
                Behavior on scale { enabled: !GlassTheme.gaming; NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }


                Text {
                    id: lineText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: (lv.syncedLyrics && lv.syncedLyrics[index]) ? lv.syncedLyrics[index].text : ""
                    color: "#ffffff"
                    font.pixelSize: del._isActive ? Math.round(lv.baseFontSize * 1.05) : lv.baseFontSize
                    font.weight: del._isActive ? Font.Bold : Font.Normal
                    font.family: lv.fontFamily
                    wrapMode: Text.WordWrap
                    lineHeight: 1.2
                    renderType: Text.NativeRendering
                }
            }

            opacity: _targetOpacity
            Behavior on opacity { enabled: !GlassTheme.gaming; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (lv.syncedLyrics && lv.syncedLyrics[index]) {
                        var ts = lv.syncedLyrics[index].timestamp / 1000;
                        lv.seekTo(ts);
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !lv.syncedLyrics || lv.syncedLyrics.length === 0
        text: "Sem letras disponíveis"
        color: "#ffffff"
        opacity: 0.35
        font.pixelSize: 13
        font.family: lv.fontFamily
        font.weight: Font.Normal
        renderType: Text.NativeRendering
    }
}
