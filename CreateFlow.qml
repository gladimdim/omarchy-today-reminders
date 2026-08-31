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
  property string whenPlaceholder: ""
  property string whatPlaceholder: ""
  property string fontFamily: Style.font.menuFamily

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  readonly property int cornerRadius: Style.cornerRadius
  property int contentMargin: Style.spacing.panelPadding
  property int cardWidth: Math.min(Style.space(380), panel.width - Style.gapsOut * 2)
  readonly property string titleText: root.step === "what" ? "What to notify" : "When to notify"
  readonly property string fieldPlaceholder: root.step === "what" ? root.whatPlaceholder : root.whenPlaceholder

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME")
  readonly property string path: TodayPing.statePath(home, stateHome)

  property string rawText: ""
  property bool writing: false

  function refreshPlaceholders() {
    root.whenPlaceholder = TodayPing.suggestedWhen(new Date())
    root.whatPlaceholder = TodayPing.randomPhrase()
  }

  function open(payloadJson) {
    root.opened = true
    root.step = "when"
    root.whenText = ""
    refreshPlaceholders()
    if (field) field.text = ""
    store.reload()
    Qt.callLater(function() { if (field) field.forceActiveFocus() })
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
    var selection = field ? String(field.text || "").trim() : ""

    if (root.step === "when") {
      if (!selection) selection = root.whenPlaceholder
      if (!selection) {
        root.notify("Today Ping", "Enter a time for today")
        return
      }
      var when = TodayPing.parseWhen(selection, new Date())
      if (!when.ok) {
        root.notify("Today Ping", when.error)
        return
      }
      root.whenText = selection
      root.step = "what"
      if (field) field.text = ""
      Qt.callLater(function() { if (field) field.forceActiveFocus() })
      return
    }

    if (root.step === "what") {
      if (!selection) selection = root.whatPlaceholder
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
      height: form.implicitHeight + contentMargin * 2 + Style.space(8)
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Column {
        id: form
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.space(10)

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: root.titleText
          color: Qt.darker(root.foreground, 1.25)
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          renderType: Text.NativeRendering
        }

        TextField {
          id: field
          width: parent.width
          foreground: root.foreground
          accent: Color.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.heading
          placeholderText: root.fieldPlaceholder
          onAccepted: root.submit()

          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              root.dismiss()
              event.accepted = true
            }
          }
        }
      }
    }
  }
}
