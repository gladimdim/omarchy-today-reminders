import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "TodayPing.js" as TodayPing

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property var service: null

  property bool opened: false
  property string step: "when"
  property string whenText: ""
  property string filterText: ""
  property string fontFamily: Style.font.menuFamily

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  readonly property int cornerRadius: Style.cornerRadius
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int cardWidth: Math.min(Style.space(360), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(contentMargin * 2 + headerHeight, panel.height - Style.gapsOut * 2)
  readonly property string promptText: root.step === "what" ? "What to tell you" : "When to notify you"

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME")
  readonly property string path: TodayPing.statePath(home, stateHome)

  property string rawText: ""
  property bool writing: false

  function open(payloadJson) {
    root.opened = true
    root.step = "when"
    root.whenText = ""
    root.filterText = ""
    store.reload()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "gladimdim.today-ping")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function setFilter(nextFilter) {
    root.filterText = nextFilter
  }

  function notify(title, body) {
    Util.execArgv(["omarchy-notification-send", "-g", "󰂚", String(title), String(body || "")])
  }

  function persist(state) {
    writing = true
    rawText = TodayPing.encode(state)
    store.setText(rawText)
    writing = false
  }

  function submit() {
    var selection = root.filterText

    if (root.step === "when") {
      if (!selection.trim()) {
        root.dismiss()
        return
      }
      var when = TodayPing.parseWhen(selection, new Date())
      if (!when.ok) {
        root.notify("Today Ping", when.error)
        return
      }
      root.whenText = selection
      root.step = "what"
      root.filterText = ""
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      return
    }

    if (root.step === "what") {
      var result = TodayPing.addReminder(root.rawText, root.whenText, selection, new Date())
      if (!result.ok) {
        root.notify("Today Ping", result.error)
        return
      }
      persist(result.state)
      root.dismiss()
      root.notify(result.reminder.message, "I'll ping you at " + result.reminder.atLabel)
    }
  }

  FileView {
    id: store
    path: root.path
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: if (!root.writing) root.rawText = text()
    onLoadFailed: if (!root.writing) root.rawText = ""
    onFileChanged: if (!root.writing) reload()
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-today-ping"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.dismiss()
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.submit()
            event.accepted = true
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }
      }

      Item {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

        Text {
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.filterText || (root.promptText + "...")
          color: root.foreground
          opacity: root.filterText ? 1 : 0.58
          font.family: root.fontFamily
          font.pixelSize: Style.font.heading
          elide: Text.ElideRight
        }
      }
    }
  }
}
