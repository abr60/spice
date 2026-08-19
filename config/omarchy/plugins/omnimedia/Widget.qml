import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons

// Bar icon that toggles a bar-anchored popup (PopupCard) with MPRIS track
// info, playback controls, and a cava visualizer. Mirrors omarchy.media.
BarWidget {
    id: root
    moduleName: "omnimedia"

    readonly property var players: Mpris.players ? Mpris.players.values : []
    property string preferredPlayerKey: ""
    property var playerStartedAt: ({})
    property int playSerial: 0

    function playerKey(player) {
        if (!player) return ""
        return String(player.dbusName || player.desktopEntry || player.identity || "")
    }
    function hasMetadata(player) {
        return !!(player && (player.trackTitle || player.trackArtist || player.identity || player.desktopEntry))
    }
    function playerOrder(player, fallback) {
        var key = root.playerKey(player)
        var value = key ? root.playerStartedAt[key] : undefined
        return value === undefined ? fallback : value
    }
    function syncPlayingOrder() {
        var next = {}
        var alive = {}
        var serial = root.playSerial
        for (var i = 0; i < root.players.length; i++) {
            var p = root.players[i]
            var key = root.playerKey(p)
            if (!key) continue
            alive[key] = true
            if (!p.isPlaying) continue
            if (root.playerStartedAt[key] === undefined) {
                serial += 1
                next[key] = serial
            } else {
                next[key] = root.playerStartedAt[key]
            }
        }
        if (root.preferredPlayerKey && !alive[root.preferredPlayerKey]) root.preferredPlayerKey = ""
        root.playSerial = serial
        root.playerStartedAt = next
    }
    function oldestPlayingPlayer() {
        var oldest = null
        var oldestOrder = 0
        for (var i = 0; i < root.players.length; i++) {
            var p = root.players[i]
            if (!p || !p.isPlaying) continue
            var order = root.playerOrder(p, i + 1000)
            if (!oldest || order < oldestOrder) {
                oldest = p
                oldestOrder = order
            }
        }
        return oldest
    }
    function selectActivePlayer() {
        if (root.preferredPlayerKey) {
            for (var i = 0; i < root.players.length; i++) {
                var p = root.players[i]
                if (root.playerKey(p) === root.preferredPlayerKey && root.hasMetadata(p)) return p
            }
        }
        var playing = root.oldestPlayingPlayer()
        if (playing) return playing
        for (var j = 0; j < root.players.length; j++) {
            if (root.hasMetadata(root.players[j])) return root.players[j]
        }
        return null
    }

    readonly property var player: root.selectActivePlayer()

    onPlayersChanged: root.syncPlayingOrder()
    onPlayerChanged: root.refreshProgress()
    Component.onCompleted: root.syncPlayingOrder()

    Instantiator {
        model: root.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() {
                root.syncPlayingOrder()
                if (modelData === root.player) root.refreshProgress()
            }
        }
    }

    property bool popupOpen: false
    function close() { root.popupOpen = false }

    readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
    readonly property string fontFam: root.bar ? root.bar.fontFamily : Style.font.family

    readonly property string iconGlyph: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
    readonly property string labelText: {
        var p = root.player
        if (!p) return ""
        var parts = []
        if (p.trackTitle) parts.push(p.trackTitle)
        if (p.trackArtist) parts.push(p.trackArtist)
        return parts.join("  ·  ")
    }
    readonly property real labelMaxWidth: labelMetrics.advanceWidth + Style.space(2)

    property real progress: 0
    property real progressDrag: -1

    function refreshProgress() {
        if (!root.player || root.player.length <= 0) { root.progress = 0; return }
        root.progress = Math.min(1, Math.max(0, root.player.position / root.player.length))
    }

    function seekTo(x, w) {
        if (!root.player || !root.player.positionSupported) return
        if (!w || w <= 0) return
        var frac = Math.min(1, Math.max(0, x / w))
        root.progressDrag = frac
        root.progress = frac
        root.player.position = root.player.length * frac
    }

    readonly property bool isCliamp: root.player && (
        String(root.player.identity || "").toLowerCase().indexOf("cliamp") >= 0
        || String(root.player.desktopEntry || "").toLowerCase().indexOf("cliamp") >= 0)
    property bool cliampShuffle: false
    property string cliampRepeatMode: "off"
    property bool widgetRepeat: false
    readonly property bool shuffleActive: root.isCliamp
        ? root.cliampShuffle
        : root.player ? !!root.player.shuffle : false
    readonly property bool repeatActive: root.isCliamp
        ? root.cliampRepeatMode !== "off"
        : root.player && root.player.loopSupported
            ? root.player.loopState !== MprisLoopState.None
            : root.widgetRepeat
    readonly property bool shuffleEnabled: root.player && (root.player.shuffleSupported || root.isCliamp)
    readonly property bool repeatEnabled: root.player && (
        root.player.loopSupported || root.isCliamp
        || (root.player.positionSupported && root.player.length > 0))

    function runCliamp(args) {
        root.cliampProc.command = ["cliamp"].concat(args)
        root.cliampProc.running = true
    }

    function refreshCliampState() {
        if (root.isCliamp) root.runCliamp(["status"])
    }

    function toggleShuffle() {
        if (!root.player) return
        root.preferredPlayerKey = root.playerKey(root.player)
        if (root.isCliamp) root.runCliamp(["shuffle", "toggle"])
        else if (root.player.shuffleSupported) root.player.shuffle = !root.player.shuffle
    }

    function toggleRepeat() {
        if (!root.player) return
        root.preferredPlayerKey = root.playerKey(root.player)
        if (root.isCliamp) root.runCliamp(["repeat", "cycle"])
        else if (root.player.loopSupported) {
            var s = root.player.loopState
            root.player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist
                : s === MprisLoopState.Playlist ? MprisLoopState.Track
                : MprisLoopState.None
        }
        else root.widgetRepeat = !root.widgetRepeat
    }

    Timer {
        id: closeDelay
        interval: 220
        onTriggered: root.popupOpen = false
    }

    Timer {
        id: progressTimer
        interval: 250
        repeat: true
        running: root.player && root.player.isPlaying
        onTriggered: {
            root.refreshProgress()
            if (root.widgetRepeat && root.player
                && root.player.isPlaying && root.player.length > 0
                && root.player.position >= root.player.length - 0.4) {
                root.player.position = 0
            }
        }
    }

    Process {
        id: cliampProc
        stdout: SplitParser {
            onRead: line => {
                var s = String(line)
                if (s.indexOf("Shuffle:") === 0) root.cliampShuffle = s.substr(8).trim() === "on"
                else if (s.indexOf("Repeat:") === 0) root.cliampRepeatMode = s.substr(7).trim().toLowerCase()
            }
        }
    }

    implicitWidth: icon.implicitWidth + (root.labelText !== "" ? Style.space(6) + root.labelMaxWidth : 0) + Style.space(12)
    implicitHeight: barSize

    Text {
        id: icon
        x: Style.space(6)
        y: Math.round((parent.height - height) / 2)
        text: root.iconGlyph
        color: root.player && root.player.isPlaying
            ? (root.bar ? root.bar.barForeground : Color.foreground)
            : Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.5)
        font.family: root.fontFam
        font.pixelSize: Style.font.body
    }

    Text {
        id: label
        x: Math.round(icon.x + icon.width + Style.space(6))
        y: Math.round((parent.height - height) / 2)
        visible: root.labelText !== ""
        width: Math.round(root.labelMaxWidth)
        text: root.labelText
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: root.fontFam
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }



    TextMetrics {
        id: labelMetrics
        font.family: root.fontFam
        font.pixelSize: Style.font.bodySmall
        text: "012345678901234567890123456789"
    }

    MouseArea {
        id: trigger
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: { closeDelay.stop(); root.popupOpen = true; root.refreshCliampState() }
        onExited: closeDelay.restart()
        onClicked: {
            if (!root.player) return
            root.preferredPlayerKey = root.playerKey(root.player)
            root.player.togglePlaying()
        }
    }

    PopupCard {
        id: popup
        anchorItem: root
        bar: root.bar
        owner: root
        open: root.popupOpen
        triggerMode: "hover"
        contentWidth: popup.fittedContentWidth(Style.space(320))
        contentHeight: popup.fittedContentHeight(popupCol.implicitHeight)

        onContainsMouseChanged: {
            if (popup.containsMouse) closeDelay.stop()
            else if (root.popupOpen && !trigger.hovered) closeDelay.restart()
        }

        Column {
            id: popupCol
            anchors.fill: parent
            anchors.margins: Style.space(8)
            spacing: Style.space(8)

            // ── Main Card Row ──
            Row {
                width: parent.width
                spacing: Style.space(10)

                // ── Left: Album Art ──
                BorderSurface {
                    width: Style.space(64)
                    height: Style.space(64)
                    radius: Style.spacing.labelGap
                    color: Style.normalFillFor(root.fg, Color.accent)
                    borderSpec: Border.controlSpec("normal", root.fg, Color.accent)

                    Image {
                        anchors.fill: parent
                        anchors.margins: Style.space(2)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                        visible: source !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.player || !root.player.trackArtUrl
                        text: "󰝚"
                        color: root.fg
                        font.family: root.fontFam
                        font.pixelSize: Style.font.displayLarge
                    }
                }

                // ── Middle: Title, Artist, Timestamp, Seek+Prev/Next ──
                Column {
                    width: parent.width - Style.space(64) - Style.space(44) - Style.space(20)
                    spacing: Style.space(2)

                    Text {
                        text: root.player ? (root.player.trackTitle || "Nothing playing") : "No player"
                        color: root.fg
                        font.family: root.fontFam
                        font.pixelSize: Style.font.subtitle
                        font.bold: true
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Text {
                        text: root.player ? root.player.trackArtist : ""
                        color: Qt.darker(root.fg, 1.3)
                        font.family: root.fontFam
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                        width: parent.width
                        visible: text !== ""
                    }

                    Text {
                        property real pos: root.progressDrag >= 0 ? root.progressDrag * (root.player ? root.player.length : 0) : (root.player ? root.player.position : 0)
                        property real len: root.player ? root.player.length : 0
                        function fmtTime(sec) {
                            var s = Math.max(0, Math.floor(sec))
                            var m = Math.floor(s / 60)
                            s = s % 60
                            return m + ":" + (s < 10 ? "0" : "") + s
                        }
                        text: root.player && root.player.length > 0 ? fmtTime(pos) + " / " + fmtTime(len) : ""
                        color: Qt.darker(root.fg, 1.5)
                        font.family: root.fontFam
                        font.pixelSize: Style.font.caption
                        width: parent.width
                        visible: text !== ""
                    }

                    Row {
                        width: parent.width
                        spacing: Style.space(4)

                        Button {
                            iconText: "\uf048"
                            foreground: root.fg
                            enabled: root.player && root.player.canGoPrevious
                            opacity: enabled ? 1.0 : 0.4
                            onClicked: {
                                if (root.player) root.preferredPlayerKey = root.playerKey(root.player)
                                if (root.player) root.player.previous()
                            }
                        }

                        Item {
                            width: parent.width - Style.space(32) - Style.space(32)
                            height: Style.space(12)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: Style.space(4)
                                radius: height / 2
                                color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                height: Style.space(4)
                                width: parent.width * (root.progressDrag >= 0 ? root.progressDrag : root.progress)
                                radius: height / 2
                                color: root.fg
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: function(mouse) { root.seekTo(mouse.x, parent.width) }
                                onPositionChanged: function(mouse) { if (pressed) root.seekTo(mouse.x, parent.width) }
                                onReleased: root.progressDrag = -1
                            }
                        }

                        Button {
                            iconText: "\uf051"
                            foreground: root.fg
                            enabled: root.player && root.player.canGoNext
                            opacity: enabled ? 1.0 : 0.4
                            onClicked: {
                                if (root.player) root.preferredPlayerKey = root.playerKey(root.player)
                                if (root.player) root.player.next()
                            }
                        }
                    }
                }

                // ── Right: Play/Pause button ──
                Item {
                    width: Style.space(36)
                    height: Style.space(36)
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: root.player && root.player.isPlaying
                            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)
                            : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
                    }

                    Button {
                        anchors.centerIn: parent
                        iconText: root.player && root.player.isPlaying ? "\uf04c" : "\uf04b"
                        foreground: root.fg
                        enabled: root.player && root.player.canTogglePlaying
                        opacity: enabled ? 1.0 : 0.4
                        onClicked: {
                            if (root.player) root.preferredPlayerKey = root.playerKey(root.player)
                            if (root.player) root.player.togglePlaying()
                        }
                    }
                }
            }

            // ── Player Source List (compact) ──
            PanelSeparator {
                visible: root.players.length > 1
            }

            Column {
                visible: root.players.length > 1
                width: parent.width
                spacing: Style.space(4)

                Repeater {
                    model: root.players

                    BorderSurface {
                        id: sourceRow
                        required property var modelData

                        readonly property var sourcePlayer: modelData
                        readonly property bool active: root.player && sourcePlayer
                            && root.playerKey(root.player) === root.playerKey(sourcePlayer)
                        readonly property string sourceTitle: sourcePlayer
                            ? (sourcePlayer.trackTitle || sourcePlayer.identity || sourcePlayer.desktopEntry || "Media source")
                            : "Media source"
                        readonly property string sourceDetail: sourcePlayer && sourcePlayer.trackArtist
                            ? sourcePlayer.trackArtist
                            : (sourcePlayer && sourcePlayer.identity ? sourcePlayer.identity : "")

                        width: parent.width
                        height: sourceInner.implicitHeight + Style.space(6)
                        radius: Style.cornerRadius
                        color: active ? Style.selectedFillFor(root.fg, Color.accent) : "transparent"
                        borderSpec: active ? Border.controlSpec("normal", root.fg, Color.accent) : Border.none()

                        Row {
                            id: sourceInner
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: sourceRow.borderLeft + Style.space(6)
                            anchors.rightMargin: sourceRow.borderRight + Style.space(6)
                            spacing: Style.space(6)

                            Text {
                                text: sourceRow.sourcePlayer && sourceRow.sourcePlayer.isPlaying ? "󰏤" : "󰐊"
                                color: root.fg
                                font.family: root.fontFam
                                font.pixelSize: Style.font.bodySmall
                                width: Style.space(16)
                                horizontalAlignment: Text.AlignHCenter
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - Style.space(22)
                                spacing: 0
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: sourceRow.sourceTitle
                                    color: root.fg
                                    font.family: root.fontFam
                                    font.pixelSize: Style.font.caption
                                    font.bold: sourceRow.active
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Text {
                                    text: sourceRow.sourceDetail
                                    color: Qt.darker(root.fg, 1.5)
                                    font.family: root.fontFam
                                    font.pixelSize: Style.font.caption
                                    elide: Text.ElideRight
                                    width: parent.width
                                    visible: text !== ""
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!sourceRow.sourcePlayer) return
                                root.preferredPlayerKey = root.playerKey(sourceRow.sourcePlayer)
                                sourceRow.sourcePlayer.togglePlaying()
                            }
                        }
                    }
                }
            }
        }
    }
}
