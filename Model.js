// No QML imports on purpose, so every function here runs in a plain JS harness.

var ANC_OFF = 0
var ANC_LOW = 1
var ANC_MID = 2
var ANC_HIGH = 3
var ANC_ADAPTIVE = 4
var ANC_TRANSPARENCY = 5

var EQ_BALANCED = 0
var EQ_MORE_BASS = 1
var EQ_MORE_TREBLE = 2
var EQ_VOICE = 3

var EAR_PAUSE_ONE_OUT = 0
var EAR_PAUSE_BOTH_OUT = 1
var EAR_DISABLED = 2

var SUPPORTED_SCHEMA = 1
var LEVEL_UNKNOWN = -1
var ANC_UNKNOWN = -1
var EQ_UNKNOWN = -1
var EAR_BEHAVIOR_COUNT = 3

var GLYPH_CHECK = "\uDB80\uDD2C"

var MAX_ERROR_CHARS = 140
var ELIDED_ERROR_CHARS = 137

function defaultPod() {
  return { level: LEVEL_UNKNOWN, charging: false, inEar: false }
}

function defaultStatus() {
  return {
    ok: false,
    lastError: "",
    schemaVersion: 0,
    schemaTooNew: false,
    connected: false,
    deviceName: "",
    modelName: "",
    firmwareVersion: "",
    serialNumber: "",
    ancMode: ANC_UNKNOWN,
    eqPreset: EQ_UNKNOWN,
    inEarDetection: true,
    lowLatencyMode: false,
    left: defaultPod(),
    right: defaultPod(),
    caseBattery: { level: LEVEL_UNKNOWN, charging: false }
  }
}

function intOr(value, fallback) {
  var n = parseInt(value, 10)
  return isFinite(n) ? n : fallback
}

function boolOr(value, fallback) {
  return value === undefined ? fallback : value === true
}

function podFrom(raw) {
  var pod = defaultPod()
  if (!raw || typeof raw !== "object") return pod
  if (raw.available !== true) return pod
  pod.level = intOr(raw.level, LEVEL_UNKNOWN)
  pod.charging = raw.charging === true
  pod.inEar = raw.in_ear === true
  return pod
}

function parseStatus(raw) {
  var status = defaultStatus()
  var text = String(raw || "").trim()
  if (text === "") {
    status.lastError = "The nothingear status file is empty"
    return status
  }

  var parsed
  try {
    parsed = JSON.parse(text)
  } catch (e) {
    status.lastError = "Could not read the nothingear status file"
    return status
  }
  if (!parsed || typeof parsed !== "object" || parsed.schema_version === undefined) {
    status.lastError = "The nothingear status file carried no schema_version"
    return status
  }

  status.schemaVersion = intOr(parsed.schema_version, 0)
  if (status.schemaVersion > SUPPORTED_SCHEMA) {
    status.schemaTooNew = true
    status.lastError = "nothingear speaks status schema " + status.schemaVersion + ", this panel reads " + SUPPORTED_SCHEMA
    return status
  }

  status.ok = true
  status.connected = parsed.connected === true
  status.deviceName = String(parsed.device_name || "")
  status.modelName = String(parsed.model_name || "")
  status.firmwareVersion = String(parsed.firmware_version || "")
  status.serialNumber = String(parsed.serial_number || "")
  status.ancMode = intOr(parsed.anc_mode, ANC_UNKNOWN)
  status.eqPreset = intOr(parsed.eq_preset, EQ_UNKNOWN)
  status.inEarDetection = boolOr(parsed.in_ear_detection, true)
  status.lowLatencyMode = boolOr(parsed.low_latency_mode, false)
  status.left = podFrom(parsed.left)
  status.right = podFrom(parsed.right)
  var caseRaw = podFrom(parsed["case"])
  status.caseBattery = { level: caseRaw.level, charging: caseRaw.charging }
  return status
}

function ancModeName(mode) {
  if (mode === ANC_OFF) return "Off"
  if (mode === ANC_LOW) return "ANC Low"
  if (mode === ANC_MID) return "ANC Mid"
  if (mode === ANC_HIGH) return "ANC High"
  if (mode === ANC_ADAPTIVE) return "Adaptive"
  if (mode === ANC_TRANSPARENCY) return "Transparency"
  return "Unknown"
}

function ancModeVerb(mode) {
  var verbs = ["anc:off", "anc:low", "anc:mid", "anc:high", "anc:adaptive", "anc:transparency"]
  if (mode < 0 || mode >= verbs.length) return ""
  return verbs[mode]
}

function eqPresetName(preset) {
  if (preset === EQ_BALANCED) return "Balanced"
  if (preset === EQ_MORE_BASS) return "More Bass"
  if (preset === EQ_MORE_TREBLE) return "More Treble"
  if (preset === EQ_VOICE) return "Voice"
  return "Unknown"
}

function eqPresetVerb(preset) {
  var verbs = ["eq:balanced", "eq:bass", "eq:treble", "eq:voice"]
  if (preset < 0 || preset >= verbs.length) return ""
  return verbs[preset]
}

function earDetectionVerb(behavior) {
  var verbs = ["ear:one", "ear:both", "ear:off"]
  if (behavior < 0 || behavior >= verbs.length) return ""
  return verbs[behavior]
}

function earDetectionName(behavior) {
  if (behavior === EAR_PAUSE_ONE_OUT) return "Pause when one is out"
  if (behavior === EAR_PAUSE_BOTH_OUT) return "Pause when both are out"
  if (behavior === EAR_DISABLED) return "Never pause"
  return "Unknown"
}

function levelText(level) {
  return level === LEVEL_UNKNOWN ? "--" : String(level) + "%"
}

function levelFraction(level) {
  if (level === LEVEL_UNKNOWN) return 0
  return Math.max(0, Math.min(100, level)) / 100
}

function podMeta(pod) {
  if (pod.charging) return "Charging"
  if (pod.inEar) return "In ear"
  return ""
}

function elideError(text) {
  var value = String(text || "").replace(/\s+/g, " ").trim()
  return value.length > MAX_ERROR_CHARS ? value.substring(0, ELIDED_ERROR_CHARS) + "\u2026" : value
}
