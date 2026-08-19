import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "protonvpn"
  ipcTarget: "protonvpn"
  manageIpc: true

  // { connected, serverId, location, load, protocol }
  property var status: ({ connected: false, serverId: "", location: "", load: "", protocol: "" })
  property var countries: []
  property bool countriesLoaded: false
  property string selectedCountry: ""
  property string selectedCity: ""
  property var cities: []
  property var servers: []
  property string selectedServer: ""
  property string selectedServerLoad: ""
  property string errorText: ""

  // Live tunnel stats, read from the WireGuard interface itself (nmcli +
  // ip) since `protonvpn status` doesn't report throughput.
  property string tunnelDevice: ""
  property string tunnelIp: ""
  property real tunnelRxBytes: 0
  property real tunnelTxBytes: 0
  property real tunnelSampleTime: 0
  property real downloadRate: 0
  property real uploadRate: 0
  property real connectedSince: 0
  property int elapsedTick: 0

  property bool settingsOpen: false
  property var config: ({})
  property bool configLoaded: false
  property string configError: ""
  property bool customDnsEditing: false
  property bool confirmSignOut: false

  // Auth state. authChecked guards against flashing the sign-in prompt
  // before the first `protonvpn info` check has actually returned.
  property string accountName: ""
  property bool authChecked: false
  property bool signinLaunched: false

  readonly property bool busy: actionProc.running
  readonly property bool configBusy: configActionProc.running
  readonly property bool signoutBusy: signoutProc.running
  readonly property var countryOptions: root.countries
  readonly property var cityOptions: root.cities
  readonly property var serverOptions: root.servers
  readonly property bool hasTunnelStats: root.tunnelDevice !== ""
  readonly property bool loggedIn: root.authChecked && root.accountName !== ""

  function refreshStatus() {
    if (statusProc.running) return
    statusProc.running = true
  }

  function checkAuth() {
    if (infoProc.running) return
    infoProc.running = true
  }

  // Opens a real terminal running `protonvpn signin <email>` so the user
  // types their password (and 2FA code, if any) directly into a proper
  // TTY — safer and far more robust than trying to pipe credentials
  // through the plugin's own process handling. The terminal closes on
  // its own once the command exits; login state is picked up by polling
  // (see the auth Timer below).
  function launchSignin(username) {
    var trimmed = String(username || "").trim()
    if (!trimmed || !root.bar) return
    root.signinLaunched = true
    root.bar.run("omarchy-launch-terminal protonvpn signin " + Util.shellQuote(trimmed))
  }

  function loadCountries() {
    if (countriesLoaded || countriesProc.running) return
    countriesProc.running = true
  }

  onLoggedInChanged: {
    if (root.loggedIn) {
      root.signinLaunched = false
      if (root.opened) root.loadCountries()
    }
  }

  function loadCities(code) {
    if (!code) { root.cities = []; return }
    citiesProc.command = ["protonvpn", "cities", "list", code]
    citiesProc.running = true
  }

  // Reads the CLI's own local server cache (~/.cache/Proton/VPN/serverlist.json,
  // refreshed by the CLI itself) and filters it with jq rather than parsing
  // a ~20MB JSON blob inside the QML engine. There is no CLI subcommand
  // that lists individual servers, only this cache file.
  function loadServers(country, city) {
    root.servers = []
    root.selectedServer = ""
    root.selectedServerLoad = ""
    if (!country || !city) return
    var cachePath = Quickshell.env("HOME") + "/.cache/Proton/VPN/serverlist.json"
    var filter = ". as $root | $root.LogicalServers"
      + " | map(select(.EntryCountry == $country and .City == $city and .Status == 1 and .Tier <= $root.MaxTier))"
      + " | sort_by(.Load)"
      + " | map({"
      + "     value: .Name,"
      + "     free: (.Tier == 0),"
      + "     label: (.Name + (if .Tier == 0 then \" · Free\" else \"\" end) + \" — \" + (.Load | tostring) + \"% load\"),"
      + "     description: ((if .Tier == 0 then \"Free · \" else \"\" end) + (.Load | tostring) + \"% load\")"
      + "   })"
    serversProc.command = ["jq", "-c", "--arg", "country", country, "--arg", "city", city, filter, cachePath]
    serversProc.running = true
  }

  function runAction(command) {
    if (actionProc.running) return
    root.errorText = ""
    actionProc.command = command
    actionProc.running = true
  }

  // SearchableDropdown assigns its own `value` property internally when an
  // item is picked, which severs the one-way `value: root.selectedX`
  // binding from below. Once severed, resetting root.selectedCity/Server
  // no longer reaches the dropdown on its own, so every place that clears
  // a selection also has to poke the dropdown's `value` directly.
  function selectCountry(code) {
    root.selectedCountry = code
    root.selectedCity = ""
    root.cities = []
    root.servers = []
    root.selectedServer = ""
    root.selectedServerLoad = ""
    if (cityDropdown) cityDropdown.value = ""
    if (serverDropdown) serverDropdown.value = ""
    root.loadCities(code)
  }
  function selectCity(city) {
    root.selectedCity = city
    root.servers = []
    root.selectedServer = ""
    root.selectedServerLoad = ""
    if (serverDropdown) serverDropdown.value = ""
    root.loadServers(root.selectedCountry, city)
  }
  function selectServer(name) {
    root.selectedServer = name
    root.selectedServerLoad = ""
    for (var i = 0; i < root.servers.length; i++) {
      if (root.servers[i].value === name) { root.selectedServerLoad = root.servers[i].description; break }
    }
  }

  function countryLabel(code) {
    for (var i = 0; i < root.countries.length; i++) {
      if (root.countries[i].value === code) return root.countries[i].label
    }
    return code
  }

  // What Connect will do right now, in priority order: a chosen server
  // beats a chosen city, which beats a chosen country, which falls back to
  // globally fastest. Reused for both the button's helper text and the
  // click handler so they can never disagree.
  function selectionSummary() {
    if (root.selectedServer !== "") {
      return root.selectedServer + (root.selectedServerLoad ? " (" + root.selectedServerLoad + ")" : "")
    }
    if (root.selectedCity !== "") {
      return root.selectedCountry ? root.selectedCity + ", " + root.countryLabel(root.selectedCountry) : root.selectedCity
    }
    if (root.selectedCountry !== "") return root.countryLabel(root.selectedCountry)
    return "Fastest server"
  }

  function connectFastest() { runAction(["protonvpn", "connect"]) }
  function connectSelection() {
    if (root.selectedServer !== "") { runAction(["protonvpn", "connect", root.selectedServer]); return }
    if (root.selectedCity !== "") { runAction(["protonvpn", "connect", "--city", root.selectedCity]); return }
    if (root.selectedCountry !== "") { runAction(["protonvpn", "connect", "--country", root.selectedCountry]); return }
    connectFastest()
  }
  function disconnectVpn() { runAction(["protonvpn", "disconnect"]) }

  function loadConfig() {
    if (configListProc.running) return
    configListProc.running = true
  }

  function openSettings() {
    root.settingsOpen = true
    if (!root.configLoaded) root.loadConfig()
  }

  function closeSettings() {
    root.settingsOpen = false
    root.customDnsEditing = false
  }

  // Applies the new value to the displayed config immediately (each
  // `config set` + follow-up `config list` round trip is ~1.5-2s, which
  // reads as an unresponsive switch otherwise) and reconciles with the
  // real value once the command confirms. A failed command's loadConfig()
  // call in onExited snaps the optimistic value back automatically.
  function applyConfigOptimistically(setting, value) {
    var next = Object.assign({}, root.config)
    next[setting] = value
    root.config = next
  }

  function setConfig(setting, value) {
    if (configActionProc.running) return
    root.configError = ""
    root.applyConfigOptimistically(setting, value)
    configActionProc.command = ["protonvpn", "config", "set", setting, value]
    configActionProc.running = true
  }

  function setCustomDns(dns) {
    var trimmed = String(dns || "").trim()
    if (!trimmed || configActionProc.running) return
    root.configError = ""
    root.applyConfigOptimistically("custom-dns", "on")
    configActionProc.command = ["protonvpn", "config", "set", "custom-dns", "on", "--dns", trimmed]
    configActionProc.running = true
    root.customDnsEditing = false
  }

  function disableCustomDns() { root.setConfig("custom-dns", "off") }

  function signOut() {
    if (signoutProc.running) return
    root.configError = ""
    signoutProc.running = true
  }

  function findTunnelDevice() {
    if (deviceProc.running) return
    deviceProc.running = true
  }

  function refreshTunnelStats() {
    if (!root.tunnelDevice || ipStatsProc.running) return
    ipStatsProc.command = ["ip", "-j", "-s", "addr", "show", root.tunnelDevice]
    ipStatsProc.running = true
  }

  function resetTunnelStats() {
    root.tunnelDevice = ""
    root.tunnelIp = ""
    root.tunnelRxBytes = 0
    root.tunnelTxBytes = 0
    root.tunnelSampleTime = 0
    root.downloadRate = 0
    root.uploadRate = 0
    root.connectedSince = 0
  }

  onStatusChanged: {
    if (root.status.connected) {
      if (root.connectedSince === 0) root.connectedSince = Date.now() / 1000
      root.findTunnelDevice()
    } else {
      root.resetTunnelStats()
    }
  }

  onOpenedChanged: {
    if (opened) {
      root.checkAuth()
      refreshStatus()
      if (root.loggedIn) root.loadCountries()
    } else {
      root.settingsOpen = false
      root.customDnsEditing = false
    }
  }

  Component.onCompleted: {
    refreshStatus()
    checkAuth()
  }

  Process {
    id: statusProc
    command: ["protonvpn", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.status = Model.parseStatus(text)
    }
  }

  Process {
    id: infoProc
    command: ["protonvpn", "info"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.accountName = Model.parseAccountName(text)
        root.authChecked = true
      }
    }
  }

  Process {
    id: countriesProc
    command: ["protonvpn", "countries", "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.countries = Model.parseCountries(text)
        root.countriesLoaded = true
      }
    }
  }

  Process {
    id: citiesProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.cities = Model.parseCities(text)
    }
  }

  Process {
    id: serversProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.servers = JSON.parse(text || "[]") } catch (e) { root.servers = [] }
      }
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { id: actionStdout; waitForEnd: true }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var msg = Model.lastMessageLine(actionStderr.text) || Model.lastMessageLine(actionStdout.text)
        root.errorText = msg || "Command failed (exit " + exitCode + ")"
      }
      root.refreshStatus()
    }
  }

  Process {
    id: configListProc
    command: ["protonvpn", "config", "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.config = Model.parseConfigList(text)
        root.configLoaded = true
      }
    }
  }

  Process {
    id: configActionProc
    stdout: StdioCollector { id: configStdout; waitForEnd: true }
    stderr: StdioCollector { id: configStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var msg = Model.lastMessageLine(configStderr.text) || Model.lastMessageLine(configStdout.text)
        root.configError = msg || "Command failed (exit " + exitCode + ")"
      }
      root.loadConfig()
    }
  }

  Process {
    id: signoutProc
    command: ["protonvpn", "signout"]
    stdout: StdioCollector { id: signoutStdout; waitForEnd: true }
    stderr: StdioCollector { id: signoutStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var msg = Model.lastMessageLine(signoutStderr.text) || Model.lastMessageLine(signoutStdout.text)
        root.configError = msg || "Sign out failed (exit " + exitCode + ")"
      } else {
        // Everything below is scoped to the now-closed session and would
        // otherwise show stale data (or silently fail with auth errors)
        // the moment the sign-in page reappears.
        root.settingsOpen = false
        root.selectedCountry = ""
        root.selectedCity = ""
        root.selectedServer = ""
        root.selectedServerLoad = ""
        root.cities = []
        root.servers = []
        root.countries = []
        root.countriesLoaded = false
        if (typeof cityDropdown !== "undefined" && cityDropdown) cityDropdown.value = ""
        if (typeof serverDropdown !== "undefined" && serverDropdown) serverDropdown.value = ""
        root.configLoaded = false
        root.config = ({})
      }
      root.checkAuth()
      root.refreshStatus()
    }
  }

  Process {
    id: deviceProc
    command: ["nmcli", "-t", "-f", "DEVICE,TYPE", "connection", "show", "--active"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.tunnelDevice = Model.parseActiveWireguardDevice(text)
        if (root.tunnelDevice) root.refreshTunnelStats()
      }
    }
  }

  Process {
    id: ipStatsProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseIpAddrStats(text)
        if (!parsed) return
        root.tunnelIp = parsed.ipv4
        var state = Model.tunnelStatsState(
          { rxBytes: root.tunnelRxBytes, txBytes: root.tunnelTxBytes, sampleTime: root.tunnelSampleTime },
          { rxBytes: parsed.rxBytes, txBytes: parsed.txBytes },
          Date.now() / 1000)
        root.tunnelRxBytes = state.rxBytes
        root.tunnelTxBytes = state.txBytes
        root.tunnelSampleTime = state.sampleTime
        root.downloadRate = state.downloadRate
        root.uploadRate = state.uploadRate
      }
    }
  }

  Timer {
    interval: root.opened ? 4000 : 15000
    running: true
    repeat: true
    onTriggered: root.refreshStatus()
  }

  Timer {
    interval: 1000
    running: root.opened && root.status.connected
    repeat: true
    onTriggered: root.elapsedTick++
  }

  // Faster poll while signed out and the panel is open, so finishing the
  // signin in the launched terminal is picked up quickly instead of
  // waiting for the slower background status poll above.
  Timer {
    interval: 2000
    running: root.opened && !root.loggedIn
    repeat: true
    onTriggered: root.checkAuth()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: !root.loggedIn
      ? "Proton VPN: Sign in required"
      : (root.status.connected
        ? "Proton VPN: " + root.status.serverId + " (" + root.status.location + ")"
        : "Proton VPN: Disconnected")
    iconComponent: Component {
      Image {
        source: Qt.resolvedUrl("icon.png")
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        opacity: root.status.connected ? 1.0 : 0.45
        Behavior on opacity { NumberAnimation { duration: 160 } }
      }
    }
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        Column {
        id: authPage
        visible: root.authChecked && !root.loggedIn
        width: parent.width
        spacing: Style.space(14)

        Image {
          anchors.horizontalCenter: parent.horizontalCenter
          width: Style.font.display * 2
          height: Style.font.display * 2
          source: Qt.resolvedUrl("icon.png")
          fillMode: Image.PreserveAspectFit
          smooth: true
          mipmap: true
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: "Sign in to Proton VPN"
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          text: "Enter your Proton account email, then finish signing in (including 2FA, if any) in the terminal that opens. It closes on its own once you're done."
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        TextField {
          id: signinField
          width: parent.width
          placeholderText: "you@proton.me"
          foreground: root.barForeground
          onAccepted: root.launchSignin(text)
        }

        Button {
          width: parent.width
          text: "Log In"
          iconText: "\uf090"
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          bordered: true
          enabled: signinField.text.trim() !== ""
          onClicked: root.launchSignin(signinField.text)
        }

        Text {
          visible: root.signinLaunched
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: "Waiting for you to finish in the terminal…"
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }
        }

        Column {
        id: mainPage
        visible: root.loggedIn && !root.settingsOpen
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: root.status.connected ? (root.status.serverId || "Connected") : "Disconnected"
          meta: root.status.connected
            ? (root.status.location + (root.status.protocol ? " · " + root.status.protocol : ""))
            : "Not connected to Proton VPN"
          detail: root.status.connected ? root.status.load : ""
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          iconComponent: Component {
            Image {
              width: Style.font.display
              height: Style.font.display
              source: Qt.resolvedUrl("icon.png")
              fillMode: Image.PreserveAspectFit
              smooth: true
              mipmap: true
              opacity: root.status.connected ? 1.0 : 0.45
              Behavior on opacity { NumberAnimation { duration: 160 } }
            }
          }
          trailingControl: Component {
            PanelActionButton {
              iconText: "\uf013"
              tooltipText: "Settings"
              foreground: root.barForeground
              onClicked: root.openSettings()
            }
          }
        }

        Text {
          visible: root.errorText !== ""
          width: parent.width
          text: root.errorText
          color: root.bar ? root.bar.urgent : Color.urgent
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        PanelSeparator { visible: root.status.connected; foreground: root.barForeground }

        PanelSectionHeader { visible: root.status.connected; text: "Connection stats"; foreground: root.barForeground }

        GridLayout {
          visible: root.status.connected
          width: parent.width
          columns: 2
          columnSpacing: Style.space(20)
          rowSpacing: Style.spacing.labelGap

          Text {
            text: "Connected for"
            color: Qt.darker(root.barForeground, 1.4)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
          Text {
            text: { var _tick = root.elapsedTick; return Model.formatDuration(Date.now() / 1000 - root.connectedSince) }
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
          }

          Text {
            text: "Tunnel IP"
            color: Qt.darker(root.barForeground, 1.4)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
          Text {
            text: root.tunnelIp || "--"
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
          }

          Text {
            text: "Download"
            color: Qt.darker(root.barForeground, 1.4)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
          Text {
            text: root.hasTunnelStats
              ? Model.formatRate(root.downloadRate) + " · " + Model.formatBytes(root.tunnelRxBytes) + " total"
              : "--"
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
          }

          Text {
            text: "Upload"
            color: Qt.darker(root.barForeground, 1.4)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
          Text {
            text: root.hasTunnelStats
              ? Model.formatRate(root.uploadRate) + " · " + Model.formatBytes(root.tunnelTxBytes) + " total"
              : "--"
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
          }
        }

        PanelSeparator { foreground: root.barForeground }

        PanelSectionHeader { text: "Quick connect"; foreground: root.barForeground }

        RowLayout {
          width: parent.width
          spacing: Style.space(8)

          Button {
            text: root.busy && !root.status.connected ? "Connecting…" : "Fastest"
            iconText: "\uf0e7"
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            bordered: true
            enabled: !root.busy
            onClicked: root.connectFastest()
          }

          Button {
            visible: root.status.connected
            text: root.busy ? "Disconnecting…" : "Disconnect"
            iconText: "\uf09c"
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            bordered: true
            enabled: !root.busy
            onClicked: root.disconnectVpn()
          }

          Item { Layout.fillWidth: true }
        }

        PanelSeparator { foreground: root.barForeground }

        PanelSectionHeader { text: "Choose a destination"; foreground: root.barForeground }

        SearchableDropdown {
          width: parent.width
          value: root.selectedCountry
          options: root.countryOptions
          showLabel: true
          label: "Country"
          placeholderText: root.countriesLoaded ? "Search countries…" : "Loading countries…"
          triggerLabel: root.countriesLoaded ? "" : "Loading countries…"
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          enabled: !root.busy
          onChanged: function(value) { root.selectCountry(value) }
        }

        SearchableDropdown {
          id: cityDropdown
          visible: root.selectedCountry !== "" && root.cities.length > 0
          width: parent.width
          value: root.selectedCity
          options: root.cityOptions
          showLabel: true
          label: "City"
          placeholderText: "Search cities…"
          triggerLabel: ""
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          enabled: !root.busy
          onChanged: function(value) { root.selectCity(value) }
        }

        Text {
          visible: root.selectedCity !== "" && root.servers.length === 0 && serversProc.running
          text: "Loading servers…"
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        SearchableDropdown {
          id: serverDropdown
          visible: root.selectedCity !== "" && root.servers.length > 0
          width: parent.width
          value: root.selectedServer
          options: root.serverOptions
          showLabel: true
          label: "Server"
          placeholderText: "Search servers…"
          triggerLabel: ""
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          enabled: !root.busy
          onChanged: function(value) { root.selectServer(value) }
        }

        PanelSeparator { foreground: root.barForeground }

        Column {
          width: parent.width
          spacing: Style.space(10)

          Text {
            text: "Will connect to: " + root.selectionSummary()
            color: Qt.darker(root.barForeground, 1.4)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            width: parent.width
          }

          Button {
            width: parent.width
            text: root.busy && !root.status.connected ? "Connecting…" : "Connect"
            iconText: "\uf061"
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            bordered: true
            enabled: !root.busy
            onClicked: root.connectSelection()
          }
        }
        }

        Column {
        id: settingsPage
        visible: root.loggedIn && root.settingsOpen
        width: parent.width
        spacing: Style.space(12)

        RowLayout {
          width: parent.width
          spacing: Style.space(8)

          PanelActionButton {
            iconText: "\uf060"
            tooltipText: "Back"
            foreground: root.barForeground
            onClicked: root.closeSettings()
          }

          PanelSectionHeader { text: "Settings"; foreground: root.barForeground }

          Item { Layout.fillWidth: true }

          Text {
            visible: root.configBusy
            text: "Applying…"
            color: Qt.darker(root.barForeground, 1.4)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        Text {
          visible: root.configError !== ""
          width: parent.width
          text: root.configError
          color: root.bar ? root.bar.urgent : Color.urgent
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Text {
          visible: !root.configLoaded
          text: "Loading settings…"
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }

        Text {
          visible: root.configLoaded
          width: parent.width
          text: "Changes may need a fresh connection to take effect."
          color: Qt.darker(root.barForeground, 1.4)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Column {
          visible: root.configLoaded
          width: parent.width
          spacing: Style.space(14)

          Column {
            width: parent.width
            spacing: Style.spacing.labelGap

            PanelSectionHeader { text: "NetShield"; foreground: root.barForeground }

            ButtonGroup {
              width: parent.width
              options: [
                { value: "off", label: "Off" },
                { value: "malware-only", label: "Malware" },
                { value: "malware-ads-trackers", label: "Malware+Ads" }
              ]
              value: root.config["netshield"] || "off"
              foreground: root.barForeground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              enabled: !root.configBusy
              onChanged: function(v) { root.setConfig("netshield", v) }
            }
          }

          Toggle {
            width: parent.width
            label: "Kill Switch"
            description: "Block internet if the VPN connection drops"
            checked: root.config["kill-switch"] === "standard"
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            enabled: !root.configBusy
            onClicked: root.setConfig("kill-switch", root.config["kill-switch"] === "standard" ? "off" : "standard")
          }

          Toggle {
            width: parent.width
            label: "VPN Accelerator"
            description: "Faster connections (recommended on)"
            checked: root.config["vpn-accelerator"] === "on"
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            enabled: !root.configBusy
            onClicked: root.setConfig("vpn-accelerator", root.config["vpn-accelerator"] === "on" ? "off" : "on")
          }

          Toggle {
            width: parent.width
            label: "Moderate NAT"
            description: "Better connectivity for gaming/P2P"
            checked: root.config["moderate-nat"] === "on"
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            enabled: !root.configBusy
            onClicked: root.setConfig("moderate-nat", root.config["moderate-nat"] === "on" ? "off" : "on")
          }

          Toggle {
            width: parent.width
            label: "Port Forwarding"
            description: "For P2P apps (needs an external helper script)"
            checked: root.config["port-forwarding"] === "on"
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            enabled: !root.configBusy
            onClicked: root.setConfig("port-forwarding", root.config["port-forwarding"] === "on" ? "off" : "on")
          }

          Toggle {
            width: parent.width
            label: "IPv6"
            description: "Route IPv6 traffic through the tunnel"
            checked: root.config["ipv6"] === "on"
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            enabled: !root.configBusy
            onClicked: root.setConfig("ipv6", root.config["ipv6"] === "on" ? "off" : "on")
          }

          Toggle {
            width: parent.width
            label: "Anonymous Crash Reports"
            description: "Help Proton find and fix bugs"
            checked: root.config["anonymous-crash-reports"] === "on"
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            enabled: !root.configBusy
            onClicked: root.setConfig("anonymous-crash-reports", root.config["anonymous-crash-reports"] === "on" ? "off" : "on")
          }

          Column {
            width: parent.width
            spacing: Style.spacing.labelGap

            Toggle {
              width: parent.width
              label: "Custom DNS"
              description: root.config["custom-dns"] === "on" ? "Enabled" : "Use Proton's DNS servers"
              checked: root.config["custom-dns"] === "on"
              foreground: root.barForeground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              enabled: !root.configBusy
              onClicked: {
                if (root.config["custom-dns"] === "on") root.disableCustomDns()
                else root.customDnsEditing = true
              }
            }

            RowLayout {
              visible: root.customDnsEditing
              width: parent.width
              spacing: Style.space(8)

              TextField {
                id: dnsField
                Layout.fillWidth: true
                placeholderText: "1.1.1.1,8.8.8.8"
                foreground: root.barForeground
                enabled: !root.configBusy
                onAccepted: root.setCustomDns(text)
              }

              PanelActionButton {
                iconText: "\uf00c"
                tooltipText: "Enable custom DNS"
                foreground: root.barForeground
                enabled: !root.configBusy && dnsField.text.trim() !== ""
                onClicked: root.setCustomDns(dnsField.text)
              }
            }
          }

          PanelSeparator { foreground: root.barForeground }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Text {
              visible: root.accountName !== ""
              text: "Signed in as " + root.accountName
              color: Qt.darker(root.barForeground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }

            Button {
              width: parent.width
              text: root.signoutBusy ? "Signing out…" : "Sign Out"
              iconText: "\uf2f5"
              foreground: root.bar ? root.bar.urgent : Color.urgent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              bordered: true
              enabled: !root.signoutBusy
              onClicked: root.confirmSignOut = true
            }
          }
        }
        }
      }

      ConfirmDialog {
        anchors.fill: parent
        opened: root.confirmSignOut
        message: "Sign out of Proton VPN? You'll need to sign in again to connect."
        cancelText: "Cancel"
        confirmText: "Sign Out"
        onCanceled: root.confirmSignOut = false
        onConfirmed: {
          root.confirmSignOut = false
          root.signOut()
        }
      }
    }
  }
}
