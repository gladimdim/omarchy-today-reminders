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
  property bool folding: false
  property real foldScaleX: 1
  property real foldScaleY: 1
  property var pendingNotice: null

  function refreshPlaceholders() {
    root.whenPlaceholder = TodayPing.suggestedWhen(new Date())
    root.whatPlaceholder = TodayPing.randomPhrase()
  }

  function resetFlyer() {
    root.folding = false
    root.foldScaleX = 1
    root.foldScaleY = 1
    flyer.opacity = 1
    scrimRect.opacity = 1
    Qt.callLater(root.centerFlyer)
  }

  function centerFlyer() {
    if (root.folding || !flyer || !panel) return
    flyer.x = Math.round((panel.width - flyer.width) / 2)
    flyer.y = Math.round((panel.height - flyer.height) / 2)
  }

  function iconCenter() {
    var fallback = Qt.point(panel.width / 2, panel.height - Style.space(20))
    try {
      var bar = root.shell ? root.shell.bar : null
      if (!bar || typeof bar.moduleWidgets !== "function") return fallback
      var items = bar.moduleWidgets("gladimdim.today-ping")
      if (!items || items.length === 0) return fallback
      var icon = items[0]
      for (var i = 0; i < items.length; i++) {
        var win = items[i].QsWindow ? items[i].QsWindow.window : null
        if (win && win.screen && panel.screen && win.screen === panel.screen) {
          icon = items[i]
          break
        }
      }
      if (!icon || typeof icon.mapToGlobal !== "function") return fallback
      var g = icon.mapToGlobal(icon.width / 2, icon.height / 2)
      var gx = g && g.x !== undefined ? g.x : Number(g)
      var gy = g && g.y !== undefined ? g.y : 0
      var loc = (typeof panel.mapFromGlobal === "function") ? panel.mapFromGlobal(gx, gy) : Qt.point(gx, gy)
      if (!loc || loc.x === undefined) return fallback
      if (loc.x < 0 || loc.x > panel.width || loc.y < 0 || loc.y > panel.height) return fallback
      return loc
    } catch (e) {
      return fallback
    }
  }

  function playFold() {
    if (root.folding) return
    root.folding = true
    if (field) field.focus = false
    var target = root.iconCenter()
    flyX.to = Math.round(target.x - flyer.width / 2)
    flyY.to = Math.round(target.y - flyer.height / 2)
    foldAnim.restart()
  }

  function hideOverlay() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "gladimdim.today-ping")
  }

  function finishFold() {
    var notice = root.pendingNotice
    root.pendingNotice = null
    root.folding = false
    root.hideOverlay()
    root.resetFlyer()
    if (notice)
      root.notify(notice.title, notice.body)
  }

  function open(payloadJson) {
    if (foldAnim.running) foldAnim.stop()
    root.opened = true
    root.step = "when"
    root.whenText = ""
    root.pendingNotice = null
    refreshPlaceholders()
    if (field) field.text = ""
    root.resetFlyer()
    store.reload()
    Qt.callLater(function() { if (field) field.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    if (foldAnim.running) foldAnim.stop()
    root.folding = false
    root.hideOverlay()
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
      root.pendingNotice = {
        title: result.reminder.message,
        body: "I'll ping you at " + result.reminder.atLabel
      }
      root.playFold()
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
    WlrLayershell.keyboardFocus: root.folding ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    onWidthChanged: if (visible && !root.folding) root.centerFlyer()
    onHeightChanged: if (visible && !root.folding) root.centerFlyer()

    Rectangle {
      id: scrimRect
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      enabled: !root.folding
      onClicked: root.dismiss()
    }

    Item {
      id: flyer
      width: card.width
      height: card.height
      transformOrigin: Item.Center
      clip: true

      transform: Scale {
        origin.x: flyer.width / 2
        origin.y: flyer.height / 2
        xScale: root.foldScaleX
        yScale: root.foldScaleY
      }

      BorderSurface {
        id: card
        width: root.cardWidth
        height: form.implicitHeight + contentMargin * 2 + Style.space(8)
        radius: root.cornerRadius
        color: root.background
        borderSpec: root.borderSpec
        padding: root.contentMargin

        MouseArea { anchors.fill: parent; enabled: !root.folding; onClicked: {} }

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
            enabled: !root.folding
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

    SequentialAnimation {
      id: foldAnim
      ParallelAnimation {
        NumberAnimation { target: root; property: "foldScaleX"; to: 1.08; duration: 120; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "foldScaleY"; to: 0.62; duration: 120; easing.type: Easing.OutCubic }
      }
      ParallelAnimation {
        NumberAnimation { id: flyX; target: flyer; property: "x"; duration: 340; easing.type: Easing.InCubic }
        NumberAnimation { id: flyY; target: flyer; property: "y"; duration: 340; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "foldScaleX"; to: 0.06; duration: 340; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "foldScaleY"; to: 0.02; duration: 340; easing.type: Easing.InCubic }
        NumberAnimation { target: flyer; property: "opacity"; to: 0; duration: 260; easing.type: Easing.InQuad }
        NumberAnimation { target: scrimRect; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InQuad }
      }
      onFinished: root.finishFold()
    }
  }
}
