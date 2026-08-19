import QtQuick
import Qt.labs.settings
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "herald-notification"

  readonly property var notificationService: bar?.shell?.firstPartyServiceFor("omarchy.notifications")
  readonly property int popupCount: notificationService?.popupModel?.count || 0
  property int historyCount: 0
  readonly property int totalCount: popupCount + historyCount
  readonly property bool hasNotifications: totalCount > 0

  readonly property string historyDir: notificationService?.historyDir || ""

  property bool tidingsThresholdShown: false
  property bool proclamationsThresholdShown: false
  property string thresholdMessage: ""

  function refreshHistoryCount() {
    if (!historyDir) return
    historyCountProc.running = true
  }

  function clearAll() {
    if (!notificationService) return
    notificationService.clearHistory()
    notificationService.clearPopups()
  }

  function formatTooltipCount(count) {
    if (count === 0) return "No notifications"
    if (count === 1) return "1 notification"
    if (count <= 6) return count + " notifications"
    if (count <= 10) return count + " tidings await"
    return count + " proclamations!"
  }

  function positionThresholdPopup() {
    if (!root.bar || !thresholdPopup.parent) {
      thresholdPopup.x = -thresholdPopup.width - Style.space(2)
      return
    }
    var widgetGlobal = root.mapToGlobal(0, 0)
    var barGlobal = root.bar.mapToGlobal(0, 0)
    var barWidth = root.bar.width
    var widgetCenterX = widgetGlobal.x + root.width / 2
    var barLeftThird = barGlobal.x + barWidth / 3
    var barRightThird = barGlobal.x + 2 * barWidth / 3

    if (widgetCenterX < barLeftThird) {
      thresholdPopup.x = button.width + Style.space(2)
    } else if (widgetCenterX > barRightThird) {
      thresholdPopup.x = -thresholdPopup.width - Style.space(2)
    } else {
      var targetGlobalX = barGlobal.x + barWidth / 2 - thresholdPopup.width / 2
      thresholdPopup.x = targetGlobalX - widgetGlobal.x
    }
  }

  function showThresholdOverlay(message) {
    root.thresholdMessage = message
    root.positionThresholdPopup()
    thresholdPopup.open()
    thresholdPopupTimer.restart()
  }

  onTotalCountChanged: {
    if (root.totalCount < 7) root.tidingsThresholdShown = false
    if (root.totalCount < 11) root.proclamationsThresholdShown = false

    if (root.totalCount >= 7 && root.totalCount <= 10 && !root.tidingsThresholdShown) {
      root.showThresholdOverlay(root.totalCount + " tidings await, my liege.")
      root.tidingsThresholdShown = true
    }

    if (root.totalCount >= 11 && !root.proclamationsThresholdShown) {
      root.showThresholdOverlay(root.totalCount + " proclamations! The Herald is overwhelmed.")
      root.proclamationsThresholdShown = true
    }
  }

  function togglePanel() {
    if (!panelLoader.item) {
      root.ensurePanelReady()
      return
    }
    panelLoader.item.toggle()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function ensurePanelReady() {
    if (!panelLoader.item) return
    root.injectPanel()
    Qt.callLater(root.injectPanel)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: root.ensurePanelReady()
  onSettingsChanged: root.ensurePanelReady()

  IpcHandler {
    target: "herald-notification"

    function open(): void { if (panelLoader.item) panelLoader.item.open() }
    function close(): void { if (panelLoader.item) panelLoader.item.close() }
    function show(): void { if (panelLoader.item) panelLoader.item.open() }
    function hide(): void { if (panelLoader.item) panelLoader.item.close() }
    function toggle(): void { if (panelLoader.item) panelLoader.item.toggle() }
  }

  Timer {
    id: historyRefreshTimer
    interval: 2000
    repeat: true
    running: root.bar !== null
    triggeredOnStart: true
    onTriggered: root.refreshHistoryCount()
  }

  Process {
    id: historyCountProc
    running: false
    command: ["bash", "-c", "ls -1 \"$1\"/*.json 2>/dev/null | wc -l", "--", root.historyDir]
    stdout: StdioCollector {
      onStreamFinished: {
        var n = parseInt(text.trim(), 10)
        root.historyCount = isNaN(n) ? 0 : n
      }
    }
  }

  Settings {
    id: heraldSettings
    category: "herald-notification"
    property double lastWelcomeTimestamp: 0
  }

  Process {
    id: welcomeProc
    running: false
    command: ["notify-send", "-a", "Herald", "Herald Notification Center", "Hear ye, hear ye! The Herald has arrived. 🎺"]
  }

  Component.onCompleted: {
    var now = Date.now()
    if (now - heraldSettings.lastWelcomeTimestamp > 30000) {
      welcomeProc.running = true
      heraldSettings.lastWelcomeTimestamp = now
    }
    if (root.totalCount >= 7) root.tidingsThresholdShown = true
    if (root.totalCount >= 11) root.proclamationsThresholdShown = true
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: root.ensurePanelReady()
    onItemChanged: root.ensurePanelReady()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰂚"
    fontSize: Style.bar.iconFont - 2
    opticalSize: Style.bar.iconCanvas - 2
    tooltipText: root.formatTooltipCount(root.totalCount)
    active: root.hasNotifications
    activeColor: Color.accent

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.clearAll()
      else root.togglePanel()
    }
  }

  Popup {
    id: thresholdPopup
    parent: button
    x: -width - Style.space(16)
    y: (button.height - height) / 2
    width: popupText.implicitWidth + Style.space(16)
    height: popupText.implicitHeight + Style.space(10)
    closePolicy: Popup.NoAutoClose
    padding: Style.space(5)

    contentItem: Text {
      id: popupText
      text: root.thresholdMessage
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }

    background: Rectangle {
      color: Color.popups.background
      radius: Style.cornerRadius
      opacity: 0.95
    }

    Timer {
      id: thresholdPopupTimer
      interval: 5000
      repeat: false
      onTriggered: thresholdPopup.close()
    }
  }
}
