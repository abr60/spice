.pragma library

// Parses `protonvpn status` output into a plain object.
//
// Connected example:
//   Status: Connected
//   Server: PT#65 in Lisbon, Portugal
//   Load: 20%
//   Protocol: wireguard
//
// Disconnected example:
//   Status: Disconnected
function parseStatus(raw) {
  var fields = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var m = /^\s*([^:]+):\s*(.*)$/.exec(lines[i])
    if (!m) continue
    fields[m[1].trim().toLowerCase()] = m[2].trim()
  }

  var connected = (fields["status"] || "").toLowerCase() === "connected"
  var serverField = fields["server"] || ""
  var serverId = serverField
  var location = ""
  var inIdx = serverField.indexOf(" in ")
  if (inIdx !== -1) {
    serverId = serverField.slice(0, inIdx)
    location = serverField.slice(inIdx + 4)
  }

  return {
    connected: connected,
    serverId: serverId,
    location: location,
    load: fields["load"] || "",
    protocol: fields["protocol"] || ""
  }
}

// Splits a tabulate "simple" table into rows of columns, using the
// dashed header separator to find where data starts and runs of 2+
// spaces as the column boundary. Stops at the first blank line after
// data begins. Tolerates leading noise lines (e.g. a cache-refresh
// notice printed before the table on the first run).
function parseDashTable(raw) {
  var lines = String(raw || "").split("\n")
  var sepIndex = -1
  for (var i = 0; i < lines.length; i++) {
    if (/^-+(\s+-+)+\s*$/.test(lines[i].trim())) { sepIndex = i; break }
  }
  if (sepIndex === -1) return []

  var rows = []
  for (var j = sepIndex + 1; j < lines.length; j++) {
    var line = lines[j]
    if (line.trim() === "") break
    var cols = line.split(/\s{2,}/).map(function(c) { return c.trim() }).filter(function(c) { return c !== "" })
    if (cols.length > 0) rows.push(cols)
  }
  return rows
}

// `protonvpn countries list` -> [{ value: "US", label: "United States" }]
function parseCountries(raw) {
  var rows = parseDashTable(raw)
  var out = []
  for (var i = 0; i < rows.length; i++) {
    var cols = rows[i]
    if (cols.length < 2) continue
    out.push({ value: cols[cols.length - 1], label: cols[0] })
  }
  return out
}

// `protonvpn cities list <country>` -> [{ value: "Miami", label: "Miami", description: "P2P" }]
function parseCities(raw) {
  var rows = parseDashTable(raw)
  var out = []
  for (var i = 0; i < rows.length; i++) {
    var cols = rows[i]
    if (cols.length < 1) continue
    out.push({ value: cols[0], label: cols[0], description: cols[1] || "" })
  }
  return out
}

// `protonvpn info` -> account email, or "" if not signed in (prints
// "Account: 'None'" when logged out; never errors either way).
function parseAccountName(raw) {
  var m = /Account:\s*'([^']*)'/.exec(String(raw || ""))
  if (!m) return ""
  var v = m[1].trim()
  return (v === "" || v === "None") ? "" : v
}

// `protonvpn config list` -> { netshield: "malware-only", "kill-switch": "off", ... }
function parseConfigList(raw) {
  var rows = parseDashTable(raw)
  var out = {}
  for (var i = 0; i < rows.length; i++) {
    var cols = rows[i]
    if (cols.length < 2) continue
    out[cols[0]] = cols[1]
  }
  return out
}

// Trims and takes the last non-empty line of an action's combined
// stdout/stderr, for a compact error banner.
function lastMessageLine(raw) {
  var lines = String(raw || "").split("\n").map(function(l) { return l.trim() }).filter(function(l) { return l !== "" })
  return lines.length > 0 ? lines[lines.length - 1] : ""
}

// `nmcli -t -f DEVICE,TYPE connection show --active` -> the wireguard
// device name, e.g. "proton0". Empty string if none is active.
function parseActiveWireguardDevice(raw) {
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var parts = lines[i].split(":")
    if (parts.length >= 2 && parts[1].trim() === "wireguard") return parts[0].trim()
  }
  return ""
}

// `ip -j -s addr show <dev>` -> { ifname, ipv4, rxBytes, txBytes }, or
// null if the output isn't parseable (interface gone, empty output, ...).
function parseIpAddrStats(raw) {
  try {
    var arr = JSON.parse(raw)
    if (!arr || !arr.length) return null
    var iface = arr[0]
    var ipv4 = ""
    var addrs = iface.addr_info || []
    for (var i = 0; i < addrs.length; i++) {
      if (addrs[i].family === "inet") { ipv4 = addrs[i].local; break }
    }
    var rx = (iface.stats64 && iface.stats64.rx && iface.stats64.rx.bytes) || 0
    var tx = (iface.stats64 && iface.stats64.tx && iface.stats64.tx.bytes) || 0
    return { ifname: iface.ifname || "", ipv4: ipv4, rxBytes: rx, txBytes: tx }
  } catch (e) {
    return null
  }
}

// Computes a new throughput sample from a previous one. If the byte
// counters went backwards (the tunnel interface was torn down and
// recreated by a reconnect, resetting its counters to zero) the rate is
// reported as 0 for this tick rather than a bogus negative/huge spike;
// the new lower counters still become the baseline for the next tick.
function tunnelStatsState(prev, next, nowSeconds) {
  var downloadRate = 0
  var uploadRate = 0
  if (prev.sampleTime > 0 && next.rxBytes >= prev.rxBytes && next.txBytes >= prev.txBytes) {
    var dt = nowSeconds - prev.sampleTime
    if (dt > 0) {
      downloadRate = (next.rxBytes - prev.rxBytes) / dt
      uploadRate = (next.txBytes - prev.txBytes) / dt
    }
  }
  return {
    rxBytes: next.rxBytes,
    txBytes: next.txBytes,
    sampleTime: nowSeconds,
    downloadRate: downloadRate,
    uploadRate: uploadRate
  }
}

function formatBytes(bytes) {
  var value = Number(bytes) || 0
  if (value <= 0) return "0 B"
  var units = ["B", "KB", "MB", "GB", "TB"]
  var i = 0
  while (value >= 1024 && i < units.length - 1) { value /= 1024; i++ }
  return (i === 0 ? value.toFixed(0) : value.toFixed(1)) + " " + units[i]
}

function formatRate(bytesPerSec) {
  return formatBytes(bytesPerSec) + "/s"
}

function formatDuration(seconds) {
  var s = Math.floor(Number(seconds) || 0)
  if (s < 0) return "--"
  var h = Math.floor(s / 3600)
  var m = Math.floor((s % 3600) / 60)
  var sec = s % 60
  if (h > 0) return h + "h " + m + "m"
  if (m > 0) return m + "m " + sec + "s"
  return sec + "s"
}
