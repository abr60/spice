// Minimal notification parsing helpers for Herald Notification Center.
// Derived from Omarchy's first-party notifications plugin logic.

function historyEntry(value, normalUrgency) {
  var e = value || {}
  return {
    id: e.id || 0,
    originalId: e.originalId || e.id || 0,
    app: e.app || "",
    appIcon: e.appIcon || "",
    summary: e.summary || "",
    body: e.body || "",
    image: e.image || "",
    glyph: e.glyph || "",
    exec: e.exec || "",
    urgency: typeof e.urgency === "number" ? e.urgency : normalUrgency,
    expireTimeout: 0,
    timestamp: e.timestamp || 0
  }
}

function popupFileName(entry) {
  return imageStem(entry) + ".json"
}

function imageStem(entry) {
  var e = entry || {}
  return String(e.timestamp || 0) + "-" + String(e.originalId || 0)
}

function parsePopupFiles(raw, normalUrgency) {
  var lines = String(raw || "").split("\n")
  var entries = []
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (!line) continue
    try {
      var value = JSON.parse(line)
      if (value && typeof value === "object") entries.push(historyEntry(value, normalUrgency))
    } catch (e) {
      // Corrupted line; skip.
    }
  }
  entries.sort(function(a, b) { return (b.timestamp || 0) - (a.timestamp || 0) })
  return entries
}

function formatRelativeTime(timestamp, now) {
  var ms = Number(now || Date.now()) - Number(timestamp || 0)
  if (!isFinite(ms) || ms < 0) ms = 0
  var seconds = Math.floor(ms / 1000)
  var minutes = Math.floor(seconds / 60)
  var hours = Math.floor(minutes / 60)
  var days = Math.floor(hours / 24)

  if (days > 0) return days + "d ago"
  if (hours > 0) return hours + "h ago"
  if (minutes > 0) return minutes + "m ago"
  return "now"
}

var domainIconMap = {
  "web.whatsapp.com": "whatsapp",
  "whatsapp.com": "whatsapp",
  "web.telegram.org": "telegram",
  "telegram.org": "telegram",
  "mail.google.com": "gmail",
  "gmail.com": "gmail",
  "instagram.com": "instagram",
  "facebook.com": "facebook",
  "messenger.com": "facebook-messenger",
  "twitter.com": "twitter",
  "x.com": "twitter",
  "github.com": "github",
  "reddit.com": "reddit",
  "youtube.com": "youtube",
  "linkedin.com": "linkedin",
  "discord.com": "discord",
  "web.discord.com": "discord",
  "spotify.com": "spotify",
  "netflix.com": "netflix",
  "twitch.tv": "twitch"
}

var domainSiteMap = {
  "web.whatsapp.com": "WhatsApp",
  "whatsapp.com": "WhatsApp",
  "web.telegram.org": "Telegram",
  "telegram.org": "Telegram",
  "mail.google.com": "Gmail",
  "gmail.com": "Gmail",
  "instagram.com": "Instagram",
  "facebook.com": "Facebook",
  "messenger.com": "Messenger",
  "twitter.com": "Twitter",
  "x.com": "X",
  "github.com": "GitHub",
  "reddit.com": "Reddit",
  "youtube.com": "YouTube",
  "linkedin.com": "LinkedIn",
  "discord.com": "Discord",
  "web.discord.com": "Discord",
  "spotify.com": "Spotify",
  "netflix.com": "Netflix",
  "twitch.tv": "Twitch"
}

function extractFirstHref(text) {
  var t = String(text || "")
  var m = t.match(/href=["'](https?:\/\/[^"']+)["']/i)
  return m ? m[1] : ""
}

function domainFromUrl(url) {
  var u = String(url || "")
  var m = u.match(/^https?:\/\/([^\/]+)/i)
  return m ? m[1].toLowerCase() : ""
}

function iconNameForDomain(domain) {
  var d = String(domain || "").toLowerCase()
  if (!d) return ""
  if (domainIconMap[d]) return domainIconMap[d]
  // Strip common subdomains and try again.
  var stripped = d.replace(/^(www\.|web\.|mail\.|app\.|m\.)+/i, "")
  if (domainIconMap[stripped]) return domainIconMap[stripped]
  return ""
}

function isBrowserApp(app) {
  var a = String(app || "").toLowerCase()
  return a.indexOf("brave") !== -1 ||
         a.indexOf("chrome") !== -1 ||
         a.indexOf("chromium") !== -1 ||
         a.indexOf("firefox") !== -1 ||
         a.indexOf("edge") !== -1 ||
         a.indexOf("opera") !== -1 ||
         a.indexOf("vivaldi") !== -1 ||
         a.indexOf("origin") !== -1
}

function siteNameFromDomain(domain) {
  var d = String(domain || "").toLowerCase()
  if (!d) return ""
  if (domainSiteMap[d]) return domainSiteMap[d]
  var stripped = d.replace(/^(www\.|web\.|mail\.|app\.|m\.)+/i, "")
  if (domainSiteMap[stripped]) return domainSiteMap[stripped]
  return ""
}

function formatAppTitle(app, body) {
  if (!isBrowserApp(app)) return { primary: app || "", secondary: "" }
  var href = extractFirstHref(body)
  var domain = domainFromUrl(href)
  var site = siteNameFromDomain(domain)
  var browser = String(app || "")
  if (!site) return { primary: browser, secondary: "" }
  return { primary: site, secondary: browser }
}

var heraldEmptyPhrases = [
  "No proclamations today",
  "The herald rests",
  "All is quiet in the realm",
  "No tidings to bear"
]

function randomEmptyPhrase(defaultText) {
  if (Math.random() > 0.30) return defaultText
  var idx = Math.floor(Math.random() * heraldEmptyPhrases.length)
  return heraldEmptyPhrases[idx]
}

if (typeof module !== "undefined") {
  module.exports = {
    historyEntry: historyEntry,
    popupFileName: popupFileName,
    imageStem: imageStem,
    parsePopupFiles: parsePopupFiles,
    formatRelativeTime: formatRelativeTime,
    extractFirstHref: extractFirstHref,
    domainFromUrl: domainFromUrl,
    iconNameForDomain: iconNameForDomain,
    isBrowserApp: isBrowserApp,
    siteNameFromDomain: siteNameFromDomain,
    formatAppTitle: formatAppTitle,
    randomEmptyPhrase: randomEmptyPhrase,
    heraldEmptyPhrases: heraldEmptyPhrases
  }
}
