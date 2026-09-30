import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "Api.js" as Api

// Headless half of OmaKraken. One instance for the whole shell, so only one
// helper talks to the headset and battery alerts happen once, no matter how
// many monitors show the bar. The bar widget reads everything from here.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property var settings: ({})

  // Last status line from the helper.
  property var status: ({})
  property string lastError: ""
  property bool panelOpen: false

  readonly property string helper: Api.helperPath(Qt.resolvedUrl("../helpers/omakrakenctl"))

  readonly property bool dongle: !!(status && status.dongle)
  readonly property bool connected: !!(status && status.connected)
  readonly property int battery: connected && status.battery !== undefined ? Number(status.battery) : -1
  readonly property bool charging: connected && !!status.charging
  readonly property string batteryText: Api.batteryText(status)
  readonly property var saved: status && status.settings ? status.settings : ({})

  // ---- Helper ------------------------------------------------------------
  // It runs as long as the plugin is loaded, holds the dongle's port, runs the
  // lighting effects and prints one JSON line per change. It limits its own
  // output and every call it makes to the dongle has a deadline.
  function send(message) {
    if (!helperProc.running) return
    helperProc.write(JSON.stringify(message) + "\n")
  }

  function change(key, value) {
    send({ cmd: "set", key: key, value: value })
  }

  function refresh() {
    send({ cmd: "refresh" })
  }

  Process {
    id: helperProc
    command: ["python3", root.helper, "run"]
    running: true
    stdinEnabled: true
    stdout: SplitParser {
      onRead: function(line) {
        var data = Api.parseJson(line)
        if (!data) return
        root.status = data
        root.lastError = String(data.error || "")
        root.checkBattery()
      }
    }
    onExited: function(code) {
      root.status = Object.assign({}, root.status, { connected: false })
      restartTimer.restart()
    }
  }

  // If the helper stops (another copy holds the headset, or it crashed),
  // try again a little later instead of spinning.
  Timer {
    id: restartTimer
    interval: 10000
    onTriggered: helperProc.running = true
  }

  onPanelOpenChanged: send({ cmd: "fast", value: panelOpen })

  // ---- Battery alerts ----------------------------------------------------
  readonly property int lowBattery: 20
  readonly property int criticalBattery: 10
  property int alertedLevel: 101

  function checkBattery() {
    if (battery < 0) return
    if (charging || battery > lowBattery + 5) { alertedLevel = 101; return }
    if (battery <= criticalBattery && alertedLevel > criticalBattery) {
      alertedLevel = criticalBattery
      Quickshell.execDetached(["timeout", "10", "notify-send", "-u", "critical", "-a", "OmaKraken",
        "Headset battery critical", battery + "% left. Charge your Kraken V3 Pro."])
    } else if (battery <= lowBattery && alertedLevel > lowBattery) {
      alertedLevel = lowBattery
      Quickshell.execDetached(["timeout", "10", "notify-send", "-a", "OmaKraken",
        "Headset battery low", battery + "% left."])
    }
  }

  // ---- Microphone volume -------------------------------------------------
  // Mic volume is ordinary USB audio, so it goes through PipeWire, not the
  // helper.
  readonly property var micNode: {
    var nodes = Pipewire.nodes ? Pipewire.nodes.values : []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (n && !n.isStream && n.isSink === false && String(n.name || "").indexOf("Razer_Kraken_V3_Pro") >= 0)
        return n
    }
    return null
  }
  readonly property real micVolume: micNode && micNode.audio ? micNode.audio.volume : -1
  readonly property bool micMuted: micNode && micNode.audio ? micNode.audio.muted : false

  function setMicVolume(v) {
    if (micNode && micNode.audio) micNode.audio.volume = Math.max(0, Math.min(1, v))
  }

  function toggleMicMute() {
    if (micNode && micNode.audio) micNode.audio.muted = !micNode.audio.muted
  }

  PwObjectTracker { objects: root.micNode ? [root.micNode] : [] }
}
