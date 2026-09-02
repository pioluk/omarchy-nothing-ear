import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})

  property bool daemonReachable: false
  property bool connected: false
  property string deviceName: ""
  property string modelName: ""
  property string firmwareVersion: ""
  property string serialNumber: ""
  property int ancMode: Model.ANC_UNKNOWN
  property int eqPreset: Model.EQ_UNKNOWN
  property bool inEarDetection: true
  property bool lowLatencyMode: false
  property var leftPod: Model.defaultPod()
  property var rightPod: Model.defaultPod()
  property var caseBattery: ({ level: Model.LEVEL_UNKNOWN, charging: false })
  property string lastError: ""
  property string actionStatus: ""

  readonly property string ctlPath: String(setting("ctlPath", "") || "nothingearctl")
  readonly property bool busy: commandProcess.running
  readonly property string statePath: (Quickshell.env("XDG_STATE_HOME")
    || Quickshell.env("HOME") + "/.local/state") + "/nothingear/status.json"
  readonly property bool hasEarbuds: daemonReachable && connected
  readonly property bool hasBattery: daemonReachable
    && (leftPod.level !== Model.LEVEL_UNKNOWN
      || rightPod.level !== Model.LEVEL_UNKNOWN
      || caseBattery.level !== Model.LEVEL_UNKNOWN)

  readonly property int settleHoldMs: 4000
  readonly property int actionStatusMs: 2200

  property string _pendingField: ""
  property var _pendingValue: null
  property var _queued: null

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function refresh() {
    stateFile.reload()
  }

  function applyLine(raw) {
    var status = Model.parseStatus(raw)
    if (!status.ok) {
      daemonReachable = true
      connected = false
      schemaUnsupported = status.schemaTooNew
      lastError = status.lastError
      return
    }
    daemonReachable = true
    schemaUnsupported = false
    lastError = ""
    applyStatus(status)
  }

  function stateGone() {
    daemonReachable = false
    connected = false
    schemaUnsupported = false
    lastError = ""
  }

  property bool schemaUnsupported: false

  function applyStatus(status) {
    connected = status.connected
    deviceName = status.deviceName
    modelName = status.modelName
    firmwareVersion = status.firmwareVersion
    serialNumber = status.serialNumber
    leftPod = status.left
    rightPod = status.right
    caseBattery = status.caseBattery

    ancMode = _settle("ancMode", status.ancMode)
    eqPreset = _settle("eqPreset", status.eqPreset)
    inEarDetection = _settle("inEarDetection", status.inEarDetection)
    lowLatencyMode = _settle("lowLatencyMode", status.lowLatencyMode)
  }

  function _settle(field, reported) {
    if (_pendingField !== field) return reported
    if (reported === _pendingValue) {
      _clearPending()
      return reported
    }
    return _pendingValue
  }

  function _clearPending() {
    _pendingField = ""
    _pendingValue = null
    settleTimer.stop()
  }

  function _send(verb, field, optimistic) {
    if (verb === "") return
    if (commandProcess.running) {
      _queued = { verb: verb, field: field, optimistic: optimistic }
      _pendingField = field
      _pendingValue = optimistic
      root[field] = optimistic
      settleTimer.restart()
      return
    }
    _pendingField = field
    _pendingValue = optimistic
    root[field] = optimistic
    settleTimer.restart()
    commandProcess.command = [ctlPath, verb]
    commandProcess.running = true
  }

  function setAncMode(mode) {
    _send(Model.ancModeVerb(mode), "ancMode", mode)
  }

  function cycleAncMode() {
    if (!hasEarbuds) return
    var modes = [Model.ANC_OFF, Model.ANC_LOW, Model.ANC_MID, Model.ANC_HIGH, Model.ANC_ADAPTIVE, Model.ANC_TRANSPARENCY]
    var at = modes.indexOf(ancMode)
    setAncMode(at < 0 ? modes[0] : modes[(at + 1) % modes.length])
  }

  function setEqPreset(preset) {
    _send(Model.eqPresetVerb(preset), "eqPreset", preset)
  }

  function cycleEqPreset() {
    if (!hasEarbuds) return
    var presets = [Model.EQ_BALANCED, Model.EQ_MORE_BASS, Model.EQ_MORE_TREBLE, Model.EQ_VOICE]
    var at = presets.indexOf(eqPreset)
    setEqPreset(at < 0 ? presets[0] : presets[(at + 1) % presets.length])
  }

  function setInEarDetection(enabled) {
    _send(enabled ? "ear:on" : "ear:off", "inEarDetection", enabled)
  }

  function setLowLatencyMode(enabled) {
    _send(enabled ? "latency:on" : "latency:off", "lowLatencyMode", enabled)
  }

  function setEarDetectionBehavior(behavior) {
    _send(Model.earDetectionVerb(behavior), "inEarDetection", behavior === Model.EAR_DISABLED ? false : true)
  }

  function cycleEarDetection() {
    setInEarDetection(!inEarDetection)
  }

  Timer {
    id: settleTimer
    interval: root.settleHoldMs
    repeat: false
    onTriggered: { root._clearPending(); root.refresh() }
  }

  Timer {
    id: actionStatusTimer
    interval: root.actionStatusMs
    repeat: false
    onTriggered: root.actionStatus = ""
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyLine(text())
    onLoadFailed: root.stateGone()
  }

  Process {
    id: commandProcess
    running: false
    command: []
    stderr: StdioCollector { id: commandErr; waitForEnd: true }
    onExited: function (exitCode) {
      if (exitCode !== 0) {
        root._clearPending()
        root.refresh()
        root._queued = null
        root.actionStatus = Model.elideError(commandErr.text || "nothingearctl rejected the command")
        actionStatusTimer.restart()
      }
      if (root._queued) {
        var next = root._queued
        root._queued = null
        root._send(next.verb, next.field, next.optimistic)
      }
    }
  }
}
