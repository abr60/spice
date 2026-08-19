import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "NotificationLogic.js" as NotificationLogic

Panel {
  id: root
  moduleName: "herald-notification"
  ipcTarget: ""
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property var notificationService: bar?.shell?.firstPartyServiceFor("omarchy.notifications")
  readonly property string historyDir: notificationService?.historyDir || ""
  readonly property string imagesDir: notificationService?.imagesDir || ""
  readonly property string popupStateDir: notificationService?.popupStateDir || ""

  property var historyNotifications: []
  property bool historyLoading: false
  property double nowMs: Date.now()
  property string emptyStateText: "No notifications"
  property int titleIndex: 0
  readonly property var titleModel: ["Notifications", "Herald's Scroll", "Tidings", "Royal Dispatch"]

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color surface: Color.popups.background

  function open() {
    if (!root.controller) {
      Qt.callLater(root.open)
      return
    }
    root.controller.show()
  }
  function close() {
    if (!root.controller) return
    root.controller.hide()
  }
  function toggle() { root.opened ? root.close() : root.open() }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function refreshHistory() {
    if (!root.historyDir || !root.opened) return
    historyLoading = true
    readHistoryProc.running = true
  }

  function onHistoryRead(raw) {
    var entries = NotificationLogic.parsePopupFiles(raw, 1)
    root.historyNotifications = entries.map(function(e) {
      var title = root.resolveAppTitle(e)
      return {
        source: "history",
        fileName: NotificationLogic.popupFileName(e),
        app: e.app,
        appNamePrimary: title.primary,
        appNameSecondary: title.secondary,
        appIcon: root.resolveAppIcon(e),
        summary: e.summary,
        body: e.body,
        image: e.image,
        glyph: e.glyph,
        exec: e.exec,
        urgency: e.urgency,
        timestamp: e.timestamp
      }
    })
    historyLoading = false
  }

  function clearAll() {
    if (!root.notificationService) return
    root.notificationService.clearHistory()
    root.notificationService.clearPopups()
    root.historyNotifications = []
  }

  function focusCandidates(entry) {
    var candidates = []
    var app = String(entry.app || "")
    if (app) candidates.push(app)

    var lower = app.toLowerCase()
    if (lower.indexOf("brave") !== -1) {
      candidates.push("brave-browser", "Brave-browser", "brave", "Brave")
    } else if (lower.indexOf("chrome") !== -1 || lower.indexOf("chromium") !== -1) {
      candidates.push("google-chrome", "Google-chrome", "chromium", "Chromium", "chrome", "Chrome")
    } else if (lower.indexOf("firefox") !== -1) {
      candidates.push("firefox", "Firefox", "firefoxdeveloperedition", "Firefox Developer Edition")
    } else if (lower.indexOf("edge") !== -1) {
      candidates.push("microsoft-edge", "Microsoft-edge", "edge", "Edge")
    } else if (lower.indexOf("opera") !== -1) {
      candidates.push("opera", "Opera")
    } else if (lower.indexOf("vivaldi") !== -1) {
      candidates.push("vivaldi", "Vivaldi")
    }

    var seen = {}
    var unique = []
    for (var i = 0; i < candidates.length; i++) {
      var c = candidates[i]
      if (!c || seen[c]) continue
      seen[c] = true
      unique.push(c)
    }
    return unique
  }

  function resolveAppIcon(entry) {
    var appIcon = String(entry.appIcon || "")
    if (!NotificationLogic.isBrowserApp(entry.app)) return appIcon
    var href = NotificationLogic.extractFirstHref(entry.body)
    var domain = NotificationLogic.domainFromUrl(href)
    var iconName = NotificationLogic.iconNameForDomain(domain)
    if (!iconName) return appIcon
    var themed = Quickshell.iconPath(iconName, true)
    return themed || appIcon
  }

  function resolveAppTitle(entry) {
    return NotificationLogic.formatAppTitle(entry.app, entry.body)
  }

  function focusEntry(entry) {
    if (!entry || !root.notificationService) return
    var candidates = root.focusCandidates(entry)
    for (var i = 0; i < candidates.length; i++) {
      root.notificationService.focusApp({ app: candidates[i] })
    }
  }

  function activateEntry(entry) {
    if (!entry) return
    if (entry.source === "popup" && root.notificationService) {
      root.notificationService.invokePopupDefault(entry.index)
    } else if (entry.exec && root.bar) {
      root.bar.run(entry.exec)
    } else if (root.notificationService) {
      root.focusEntry(entry)
    }
    root.close()
  }

  function dismissEntry(entry) {
    if (!entry) return
    if (entry.source === "history") {
      deleteHistoryEntry(entry.fileName)
    } else if (entry.source === "popup" && root.notificationService) {
      root.notificationService.dismissPopup(entry.index)
    }
  }

  function deleteHistoryEntry(fileName) {
    if (!fileName || !root.historyDir) return
    var stem = String(fileName).replace(/\.json$/, "")
    deleteProc.command = [
      "bash", "-c",
      "rm -f \"$1/$2\" \"$3/$4\"-*",
      "--", root.historyDir, fileName, root.imagesDir, stem
    ]
    deleteProc.running = true
  }

  Process {
    id: readHistoryProc
    running: false
    command: ["bash", "-c", "awk 1 \"$1\"/*.json 2>/dev/null || true", "--", root.historyDir]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.onHistoryRead(text)
    }
  }

  Process {
    id: deleteProc
    running: false
    onExited: root.refreshHistory()
  }

  Timer {
    id: clockTimer
    interval: 30000
    repeat: true
    running: root.opened
    onTriggered: root.nowMs = Date.now()
  }

  Timer {
    id: historyRetryTimer
    interval: 100
    repeat: false
    running: false
    onTriggered: root.refreshHistory()
  }

  onOpenedChanged: {
    if (panel.open !== root.opened) panel.open = root.opened
    if (root.opened) {
      root.nowMs = Date.now()
      root.emptyStateText = NotificationLogic.randomEmptyPhrase("No notifications")
      root.refreshHistory()
    } else {
      root.titleIndex = 0
    }
  }

  onHistoryDirChanged: {
    if (root.opened && root.historyDir) {
      historyRetryTimer.restart()
    }
  }

  onBarChanged: {
    if (root.opened) {
      historyRetryTimer.restart()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    onOpenChanged: {
      if (!panel.open && root.opened) root.close()
    }
    centerOnBar: false
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(500))

    Flickable {
      id: flickable
      anchors.fill: parent
      contentWidth: parent.width
      contentHeight: contentColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: contentColumn
        width: parent.width
        spacing: Style.space(8)

        // Header
        RowLayout {
        width: parent.width
        height: Style.space(36)

        Text {
          id: titleText
          text: root.titleModel[root.titleIndex]
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.title
          font.bold: true

          MouseArea {
            anchors.fill: parent
            onClicked: root.titleIndex = (root.titleIndex + 1) % root.titleModel.length
          }
        }

        Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }

        PanelActionButton {
          id: clearBtn
          iconText: "󰩹"
          tooltipText: "Clear all"
          foreground: root.contentForeground
          hoverColor: Color.urgent
          onClicked: root.clearAll()
        }
      }

      PanelSeparator { width: parent.width }

      // Empty state
      Item {
        width: parent.width
        height: Style.space(80)
        visible: !root.historyLoading && listRepeater.count === 0 && popupRepeater.count === 0

        Text {
          anchors.centerIn: parent
          text: root.emptyStateText
          color: Qt.darker(root.contentForeground, 1.6)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }
      }

      // History list
      Column {
        width: parent.width
        spacing: Style.space(6)

        Repeater {
          id: listRepeater
          model: root.historyNotifications

          delegate: NotificationListItem {
            required property var modelData
            width: parent.width
            entry: modelData
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            nowMs: root.nowMs
            onActivated: root.activateEntry(modelData)
            onDismissed: root.dismissEntry(modelData)
          }
        }
      }

      // Popup list (active toasts)
      Column {
        width: parent.width
        spacing: Style.space(6)
        visible: popupRepeater.count > 0

        Repeater {
          id: popupRepeater
          model: root.notificationService ? root.notificationService.popupModel : null

          delegate: NotificationListItem {
            required property int index
            required property string app
            required property string appIcon
            required property string summary
            required property string body
            required property string image
            required property string glyph
            required property string exec
            required property int urgency
            required property double timestamp

            width: parent.width
            property var popupEntry: null
            Component.onCompleted: {
              var e = {}
              e.source = "popup"
              e.index = index
              e.app = app
              var title = root.resolveAppTitle({ app: app, body: body })
              e.appNamePrimary = title.primary
              e.appNameSecondary = title.secondary
              e.appIcon = root.resolveAppIcon({ app: app, appIcon: appIcon, body: body })
              e.summary = summary
              e.body = body
              e.image = image
              e.glyph = glyph
              e.exec = exec
              e.urgency = urgency
              e.timestamp = timestamp
              popupEntry = e
              entry = e
            }
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            nowMs: root.nowMs
            onActivated: root.activateEntry(popupEntry)
            onDismissed: root.dismissEntry(popupEntry)
          }
        }
      }
    } // Column
  } // Flickable
} // KeyboardPanel
}
