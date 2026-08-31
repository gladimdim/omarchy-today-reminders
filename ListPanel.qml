import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "TodayPing.js" as TodayPing

Panel {
  id: root
  moduleName: "gladimdim.today-ping"
  ipcTarget: ""
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME")
  readonly property string path: TodayPing.statePath(home, stateHome)
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property color contentMuted: Qt.darker(contentForeground, 1.4)
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  property var reminders: []
  property bool writing: false
  property string rawText: ""

  function open() {
    reload()
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function reload() {
    store.reload()
  }

  function apply(text) {
    rawText = String(text || "")
    var result = TodayPing.reconcile(rawText, new Date())
    reminders = result.state.reminders
  }

  function dismissReminder(id) {
    var result = TodayPing.removeReminder(root.rawText, id, new Date())
    writing = true
    rawText = TodayPing.encode(result.state)
    store.setText(rawText)
    reminders = result.state.reminders
    writing = false
    if (reminders.length === 0) root.close()
  }

  FileView {
    id: store
    path: root.path
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: if (!root.writing) root.apply(text())
    onLoadFailed: if (!root.writing) root.apply("")
    onFileChanged: if (!root.writing) reload()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(Math.min(listColumn.implicitHeight, Style.space(360)))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Flickable {
        id: listScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: listColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

      Column {
        id: listColumn
        width: listScroll.width
        spacing: Style.space(10)

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: "Today"
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Text {
          visible: root.reminders.length === 0
          textFormat: Text.PlainText
          width: parent.width
          text: "Nothing waiting today"
          color: root.contentMuted
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        Repeater {
          model: root.reminders

          Rectangle {
            required property var modelData
            width: listColumn.width
            height: Math.max(Style.space(36), row.implicitHeight + Style.space(10))
            radius: Style.cornerRadius
            color: rowHover.hovered ? Util.alpha(root.contentForeground, 0.08) : "transparent"

            HoverHandler { id: rowHover }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.dismissReminder(modelData.id)
            }

            Row {
              id: row
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(10)

              Text {
                textFormat: Text.PlainText
                text: modelData.atLabel
                color: Color.accent
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                width: Style.space(48)
              }

              Text {
                textFormat: Text.PlainText
                text: modelData.message
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
                width: parent.width - Style.space(48) - Style.space(22) - parent.spacing * 2
              }

              Text {
                textFormat: Text.PlainText
                text: "✕"
                color: root.contentMuted
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }
      }
      }
    }
  }
}
