.pragma library

// Shared helpers for OmaKraken's QML. Keep this free of QML imports.

// Effects the helper can run. The headset has no effects of its own, so the
// helper streams the colors (like Razer Synapse does).
var EFFECTS = [
  { value: "static", label: "Static" },
  { value: "breathing", label: "Breathing" },
  { value: "spectrum", label: "Spectrum Cycling" }
]

var HAPTIC_LEVELS = ["Low", "Medium", "High"]

var PRESET_COLORS = [
  "#ff0000", "#ff4500", "#ff9933", "#ffff00", "#00ff00", "#00ffff", "#0000ff",
  "#601986", "#ff00ff", "#e4007f", "#2ea7e0", "#8fc31f", "#d56fac", "#ffffff"
]

function helperPath(url) {
  return decodeURIComponent(String(url || "").replace(/^file:\/\//, ""))
}

function parseJson(text) {
  try {
    var data = JSON.parse(String(text || "").trim() || "null")
    return data && typeof data === "object" ? data : null
  } catch (error) {
    return null
  }
}

function effectLabel(value) {
  for (var i = 0; i < EFFECTS.length; i++)
    if (EFFECTS[i].value === value) return EFFECTS[i].label
  return EFFECTS[0].label
}

function effectValue(label) {
  for (var i = 0; i < EFFECTS.length; i++)
    if (EFFECTS[i].label === label) return EFFECTS[i].value
  return "static"
}

function effectUsesColor(value) {
  return value === "static" || value === "breathing"
}

function effectUsesSpeed(value) {
  return value === "breathing" || value === "spectrum"
}

function hexByte(n) {
  var s = Math.max(0, Math.min(255, Math.round(n))).toString(16)
  return s.length < 2 ? "0" + s : s
}

function rgbHex(r, g, b) {
  return "#" + hexByte(r) + hexByte(g) + hexByte(b)
}

// Hue 0..1 at full saturation and value, for the color bar.
function hueHex(h) {
  var x = (h % 1 + 1) % 1 * 6
  var i = Math.floor(x), f = x - i
  var rgb = [[1, f, 0], [1 - f, 1, 0], [0, 1, f], [0, 1 - f, 1], [f, 0, 1], [1, 0, 1 - f]][i % 6]
  return rgbHex(rgb[0] * 255, rgb[1] * 255, rgb[2] * 255)
}

function batteryText(status) {
  if (!status || !status.dongle) return "Dongle not found"
  if (!status.connected) return "Headset not answering"
  return status.battery !== undefined ? status.battery + "%" : "Battery unknown"
}
