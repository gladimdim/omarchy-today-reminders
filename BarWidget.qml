import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "TodayPing.js" as TodayPing

BarWidget {
  id: root
  moduleName: "gladimdim.today-ping"

  property int pendingCount: 0
  property int lastCount: 0
  property bool countReady: false
  property bool menuOpen: false
  property real catchScale: 1
  property var reminders: []
  readonly property string statusTooltip: TodayPing.tooltipFor(reminders)

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME")
  readonly property string path: TodayPing.statePath(home, stateHome)
  readonly property bool opened: (listLoader.item && listLoader.item.opened === true) || menuOpen
  readonly property bool popoutSwitchClosing: listLoader.item ? listLoader.item.popoutSwitchClosing === true : false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function injectList() {
    var target = listLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function openCreate() {
    root.menuOpen = false
    Quickshell.execDetached(["omarchy-shell", "shell", "toggle", root.moduleName, "{}"])
  }

  function openList() {
    if (listLoader.item && listLoader.item.open) listLoader.item.open()
  }

  function closeList() {
    if (listLoader.item && listLoader.item.close) listLoader.item.close()
  }

  function close() {
    root.menuOpen = false
    closeList()
  }

  function closeForPopoutSwitch() {
    if (listLoader.item && listLoader.item.closeForPopoutSwitch)
      listLoader.item.closeForPopoutSwitch()
    else
      close()
  }

  function showReminders() {
    root.menuOpen = false
    Qt.callLater(function() { root.openList() })
  }

  function applyCount(text) {
    var result = TodayPing.reconcile(text, new Date())
    root.reminders = result.state.reminders
    var next = result.state.reminders.length
    if (root.countReady && next > root.lastCount) catchDelay.restart()
    root.pendingCount = next
    root.lastCount = next
    root.countReady = true
  }

  onBarChanged: injectList()
  onSettingsChanged: injectList()

  FileView {
    id: store
    path: root.path
    watchChanges: true
    printErrors: false
    onLoaded: root.applyCount(text())
    onLoadFailed: root.applyCount("")
    onFileChanged: reload()
  }

  Timer {
    interval: 15000
    running: true
    repeat: true
    onTriggered: store.reload()
  }

  Loader {
    id: listLoader
    active: true
    source: Qt.resolvedUrl("ListPanel.qml")
    visible: false
    onLoaded: {
      root.injectList()
      Qt.callLater(root.injectList)
    }
  }

  Timer {
    id: catchDelay
    interval: 300
    onTriggered: catchAnim.restart()
  }

  SequentialAnimation {
    id: catchAnim
    NumberAnimation { target: root; property: "catchScale"; to: 1.32; duration: 150; easing.type: Easing.OutBack }
    NumberAnimation { target: root; property: "catchScale"; to: 1; duration: 240; easing.type: Easing.OutCubic }
  }

  Item {
    id: iconFace
    anchors.fill: parent
    transformOrigin: Item.Center
    scale: root.catchScale

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰂚"
    active: root.pendingCount > 0
    tooltipText: root.statusTooltip
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.closeList()
        root.menuOpen = !root.menuOpen
      } else {
        root.menuOpen = false
        root.openCreate()
      }
    }
  }

  Rectangle {
    visible: root.pendingCount > 0
    width: Math.max(10, badgeText.implicitWidth + 6)
    height: 12
    radius: 6
    color: Color.accent
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: -3
    anchors.topMargin: 2

    Text {
      id: badgeText
      textFormat: Text.PlainText
      anchors.centerIn: parent
      text: root.pendingCount > 9 ? "9+" : String(root.pendingCount)
      color: Color.background
      font.pixelSize: 8
      font.bold: true
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
    }
  }
  }

  KeyboardPanel {
    id: menu
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.menuOpen
    padding: Style.space(8)
    focusTarget: menuCatcher
    contentWidth: menu.fittedContentWidth(Style.space(200))
    contentHeight: menu.fittedContentHeight(Style.space(36))

    PanelKeyCatcher {
      id: menuCatcher
      anchors.fill: parent
      onActivateRequested: root.showReminders()
      onCloseRequested: root.menuOpen = false

      MouseArea {
        id: menuRow
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.showReminders()

        Rectangle {
          anchors.fill: parent
          radius: Math.max(0, Style.cornerRadius - 2)
          color: menuRow.containsMouse
            ? Style.hoverFillFor(Color.popups.text, Color.accent)
            : "transparent"
        }

        Text {
          textFormat: Text.PlainText
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          text: "Show reminders"
          color: Color.popups.text
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          verticalAlignment: Text.AlignVCenter
          horizontalAlignment: Text.AlignLeft
          elide: Text.ElideRight
          renderType: Text.NativeRendering
        }
      }
    }
  }
}
