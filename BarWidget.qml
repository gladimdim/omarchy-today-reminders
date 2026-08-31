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
  property bool menuOpen: false

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
    pendingCount = result.state.reminders.length
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

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰂚"
    active: root.pendingCount > 0
    tooltipText: root.pendingCount > 0
      ? (root.pendingCount === 1 ? "1 ping today" : root.pendingCount + " pings today")
      : "Today Ping — click to set"
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
      anchors.centerIn: parent
      text: root.pendingCount > 9 ? "9+" : String(root.pendingCount)
      color: Color.background
      font.pixelSize: 8
      font.bold: true
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
    }
  }

  PopupCard {
    id: menu
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.menuOpen
    padding: Style.space(6)
    contentWidth: menu.fittedContentWidth(Style.space(196))
    contentHeight: menu.fittedContentHeight(menuColumn.implicitHeight)

    Column {
      id: menuColumn
      anchors.fill: parent
      spacing: 0

      Item {
        id: menuRow
        width: parent.width
        implicitHeight: Style.space(32)
        height: implicitHeight

        Rectangle {
          anchors.fill: parent
          radius: Math.max(0, Style.cornerRadius - 2)
          color: menuHover.hovered
            ? Style.hoverFillFor(Color.popups.text, Color.accent)
            : "transparent"
        }

        Text {
          id: menuLabel
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          text: "Show reminders"
          color: Color.popups.text
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
          renderType: Text.NativeRendering
        }

        HoverHandler { id: menuHover }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.showReminders()
        }
      }
    }
  }
}
