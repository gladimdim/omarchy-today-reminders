import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "TodayPing.js" as TodayPing

Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME")
  readonly property string dir: TodayPing.stateDir(home, stateHome)
  readonly property string path: TodayPing.statePath(home, stateHome)
  readonly property string pluginDir: manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : ""
  readonly property string fallbackChime: "/usr/share/sounds/freedesktop/stereo/complete.oga"

  property string rawText: ""
  property bool ready: false
  property bool writing: false

  function applyRaw(text) {
    rawText = String(text || "")
    var result = TodayPing.reconcile(rawText, new Date())
    if (result.changed) persist(result.state)
  }

  function persist(state) {
    writing = true
    rawText = TodayPing.encode(state)
    store.setText(rawText)
    writing = false
  }

  function fileUrlToPath(url) {
    var s = String(url || "")
    if (s.indexOf("file://") === 0) s = decodeURIComponent(s.slice(7))
    return s
  }

  function pluginFile(rel) {
    if (root.pluginDir !== "") return root.pluginDir + "/" + rel
    return root.fileUrlToPath(Qt.resolvedUrl(rel))
  }

  function fire(reminder) {
    var toast = TodayPing.toastForReminder(reminder)
    Util.execArgv([
      "omarchy-notification-send",
      "-g", "󰂚",
      "-u", "normal",
      "-t", "15000",
      toast.title,
      toast.body
    ])
    playChime()
  }

  function playChime() {
    var sound = root.pluginFile("assets/chime.wav")
    if (!sound) sound = root.fallbackChime
    var script = root.pluginFile("scripts/play-chime")
    if (chimeProc.running) chimeProc.running = false
    // Play as a child of omarchy-shell so we share its PipeWire client and
    // the current default sink (headphones, HDMI, or analog).
    if (script)
      chimeProc.command = ["bash", script, sound]
    else
      chimeProc.command = ["pw-play", "--volume=0.85", sound]
    chimeProc.running = true
  }

  function tick() {
    if (!ready) return
    var result = TodayPing.reconcile(rawText, new Date())
    if (result.due.length === 0 && !result.changed) return
    for (var i = 0; i < result.due.length; i++) root.fire(result.due[i])
    persist(result.state)
  }

  Component.onCompleted: ensureDir.running = true

  Process {
    id: ensureDir
    command: ["mkdir", "-p", root.dir]
    onExited: store.reload()
  }

  Process {
    id: chimeProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var err = String(text || "").trim()
        if (err !== "") console.warn("today-ping chime:", err)
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0)
        console.warn("today-ping chime: player exited", exitCode)
    }
  }

  FileView {
    id: store
    path: root.path
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      if (root.writing) return
      root.ready = true
      root.applyRaw(text())
    }
    onLoadFailed: {
      root.ready = true
      root.applyRaw("")
    }
    onFileChanged: if (!root.writing) reload()
  }

  Timer {
    interval: 1000
    running: root.ready
    repeat: true
    onTriggered: root.tick()
  }

  SystemClock {
    precision: SystemClock.Minutes
    onDateChanged: root.tick()
  }
}
