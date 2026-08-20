import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "NotificationLogic.js" as NotificationLogic

BorderSurface {
  id: root

  property var entry: null
  property string fontFamily: Style.font.family
  property color foreground: Color.foreground
  property double nowMs: Date.now()

  signal activated()
  signal dismissed()

  readonly property var e: entry || {}
  readonly property string appName: e.app || ""
  readonly property string appNamePrimary: e.appNamePrimary || ""
  readonly property string appNameSecondary: e.appNameSecondary || ""
  readonly property bool hasSplitTitle: appNamePrimary.length > 0 && appNameSecondary.length > 0
  readonly property string summaryText: e.summary || ""
  readonly property string bodyText: e.body || ""
  readonly property string imageSource: e.image || ""
  readonly property string iconName: e.appIcon || ""
  readonly property string glyph: e.glyph || ""
  readonly property int urgency: typeof e.urgency === "number" ? e.urgency : 1
  readonly property double timestamp: e.timestamp || 0

  readonly property string smallIconSource: imageSource.length > 0 ? imageSource : resolvedIcon(iconName)
  readonly property bool hasGlyph: glyph.length > 0
  readonly property bool hasImage: smallIconSource.length > 0 && iconImage.status !== Image.Error
  readonly property bool showGlyph: hasGlyph && (!hasImage || iconImage.status !== Image.Ready)
  readonly property bool showIconSlot: hasImage || showGlyph

  function resolvedIcon(icon) {
    var value = String(icon || "")
    if (value.length === 0) return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    return Quickshell.iconPath(value, true)
  }

  implicitHeight: row.implicitHeight + Style.space(16)
  radius: Style.cornerRadius
  color: hoverTracker.hovered ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
  borderSpec: Border.none()

  HoverHandler { id: hoverTracker }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.dismissed()
      else root.activated()
    }
  }

  RowLayout {
    id: row
    anchors.fill: parent
    anchors.margins: Style.space(8)
    spacing: Style.space(10)

    Item {
      Layout.preferredWidth: visible ? Style.space(36) : 0
      Layout.preferredHeight: visible ? Style.space(36) : 0
      Layout.alignment: Qt.AlignVCenter
      visible: root.showIconSlot

      Image {
        id: iconImage
        anchors.fill: parent
        source: root.smallIconSource
        sourceSize.width: width * Screen.devicePixelRatio
        sourceSize.height: height * Screen.devicePixelRatio
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        visible: root.hasImage
      }

      Text {
        anchors.centerIn: parent
        visible: root.showGlyph
        text: root.glyph
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      spacing: Style.space(2)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(4)
          visible: root.appName.length > 0 || root.summaryText.length > 0

          Text {
            text: root.hasSplitTitle ? root.appNamePrimary : (root.appName || root.summaryText)
            color: root.urgency === 2 ? Color.urgent : Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            text: root.hasSplitTitle ? "·" + root.appNameSecondary : ""
            color: Qt.darker(root.foreground, 1.6)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            elide: Text.ElideRight
            visible: root.hasSplitTitle
          }
        }

        Text {
          text: NotificationLogic.formatRelativeTime(root.timestamp, root.nowMs)
          color: Qt.darker(root.foreground, 1.6)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Text {
        Layout.fillWidth: true
        text: root.summaryText
        color: Qt.darker(root.foreground, 1.15)
        linkColor: Color.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
        elide: Text.ElideRight
        maximumLineCount: 2
        visible: root.appName.length > 0 && root.summaryText.length > 0
      }

      Text {
        Layout.fillWidth: true
        text: root.bodyText
        color: Qt.darker(root.foreground, 1.4)
        linkColor: Color.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
        elide: Text.ElideRight
        maximumLineCount: 2
        visible: root.bodyText.length > 0
      }
    }
  }
}
