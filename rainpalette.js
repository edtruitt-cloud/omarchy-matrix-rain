// Rain colours shared by the wallpaper (Service.qml, RainPanel.qml) and the
// screensaver (screensaver/Screensaver.qml), so both always match. Classic
// green keeps each surface's own hand-tuned colours; this covers the rest.
.pragma library

// Single colours, in panel order. Each is a real look of its own: the
// stream's bright head, its body and the tail it fades into (some shift hue
// along the trail, like Ember's yellow -> orange -> red). Each is meant to
// look clearly different from every other one.
var presets = {
    gold:     { head: "#ffffff", body: "#ffd84a", tail: "#5a4600" },
    ember:    { head: "#fff3a0", body: "#ff5a00", tail: "#7a000e" },
    blood:    { head: "#ffb08a", body: "#d0001a", tail: "#2a0006" },
    rust:     { head: "#ffc9a0", body: "#b8461e", tail: "#2e0f04" },
    rose:     { head: "#fff0f7", body: "#ff9fcf", tail: "#5a1a3a" },
    plasma:   { head: "#ffffff", body: "#ff38e8", tail: "#2a00a0" },
    lavender: { head: "#f7f0ff", body: "#c3a6ff", tail: "#2e2250" },
    violet:   { head: "#f0d6ff", body: "#9d4dff", tail: "#1c0048" },
    cobalt:   { head: "#c8d4ff", body: "#1f44ff", tail: "#000632" },
    cyan:     { head: "#eaffff", body: "#00f0e0", tail: "#003a38" },
    mint:     { head: "#f0fff6", body: "#8fffc4", tail: "#12402a" },
    venom:    { head: "#f4ffc0", body: "#aaff00", tail: "#1e3a00" },
    moss:     { head: "#e6ecc0", body: "#8e9a3c", tail: "#1c2208" },
    sepia:    { head: "#fff0d8", body: "#c89a6a", tail: "#3a2410" },
    ghost:    { head: "#ffffff", body: "#cdd6e8", tail: "#2a2e38" },
    noir:     { head: "#ffffff", body: "#6e6e6e", tail: "#141414" },
    amber:    { head: "#fff0c0", body: "#ffa200", tail: "#4a2600" },
    chocolate:{ head: "#e8c0a0", body: "#6e3a1a", tail: "#1a0a02" },
    wine:     { head: "#ffb0cc", body: "#8c1040", tail: "#220010" },
    hotpink:  { head: "#ffe0f0", body: "#ff2d8c", tail: "#4a0024" },
    orchid:   { head: "#fbe0ff", body: "#d86ee0", tail: "#3a1040" },
    navy:     { head: "#b8c4ff", body: "#1c2c80", tail: "#02061e" },
    teal:     { head: "#c0fff4", body: "#00857a", tail: "#001e1c" },
    pine:     { head: "#c8ffd4", body: "#1f8a3a", tail: "#021e08" },
    // Near-black rain with blazing gold heads, like falling sparks.
    eclipse:  { head: "#ffd84a", body: "#262018", tail: "#050402" },
    // Deep indigo rain with neon yellow-green heads (a UV poster).
    blacklight: { head: "#e4ff3a", body: "#3a1a9a", tail: "#0a0428" },
    // Metallic copper whose trails age into verdigris.
    copper:   { head: "#ffd6a8", body: "#b87333", tail: "#12453c" },
    // Warm off-white, like old bone or piano keys, fading brown.
    ivory:    { head: "#fffaf0", body: "#efe2c4", tail: "#4a3a22" },
    // Deep old-gold yellow.
    mustard:  { head: "#fff1b0", body: "#c49a1a", tail: "#3a2c00" }
}
var presetNames = ["gold", "amber", "ember", "blood", "rust", "chocolate", "wine", "rose", "hotpink",
                   "plasma", "orchid", "lavender", "violet", "cobalt", "navy", "cyan", "teal", "mint",
                   "pine", "venom", "moss", "mustard", "copper", "sepia", "ivory", "ghost", "noir",
                   "eclipse", "blacklight"]
// Earlier colour names, mapped to the closest current look.
var aliases = {
    // singles
    orange: "ember", amber: "ember", peach: "sepia", red: "blood", crimson: "blood",
    magenta: "plasma", blue: "cobalt", sky: "cyan", frost: "cyan",
    ice: "cyan", lime: "venom", toxic: "venom",
    sulfur: "gold", white: "ghost",
    // multi-colour looks
    cyberpunk: "neon", dusk: "sunset"
}

// Multi-colour looks. mode: "streams" (each column picks one of the colours),
// "gradient" (top to bottom of the screen, colours kept exactly as given) or
// "rainbow" (hues drift across). `variation` darkens a few random streams.
var multi = {
    rainbow: { mode: "rainbow", colors: ["#ff2a2a", "#ffd000", "#00e5ff", "#b46cff"] },
    neon: { mode: "streams", colors: ["#ff3df0", "#00e5ff", "#b6ff3a", "#ffd000"] },
    vapor: { mode: "streams", colors: ["#ff71ce", "#01cdfe", "#b967ff", "#05ffa1"] },
    // Mostly classic green, with the odd red or white stream.
    glitch: { mode: "streams", colors: ["#00ff41", "#00ff41", "#ff2a2a", "#ffffff"] },
    // Candy cane: red and white streams.
    candy: { mode: "streams", colors: ["#ff1f3d", "#ffffff", "#ff1f3d", "#ffffff"] },
    // Police lights: red and blue.
    siren: { mode: "streams", colors: ["#ff1a1a", "#1a4dff", "#ff1a1a", "#1a4dff"] },
    // Holly: red and green.
    holly: { mode: "streams", colors: ["#e8102e", "#10c040", "#e8102e", "#10c040"] },
    // Complementary orange and blue.
    icefire: { mode: "streams", colors: ["#ff6a00", "#3aa0ff", "#ffb000", "#1a50ff"] },
    // Newsprint: white, grey and faded streams.
    ink: { mode: "streams", colors: ["#ffffff", "#9a9a9a", "#d8d8d8", "#5a5a5a"], variation: 0.5 },
    fire: { mode: "gradient", colors: ["#fff27a", "#ffb000", "#ff5a1a", "#d4143c"] },
    // Lava: dark at the top, glowing towards the bottom (Fire upside down).
    lava: { mode: "gradient", colors: ["#3a0000", "#a01000", "#ff4a00", "#ffd84a"] },
    sunset: { mode: "gradient", colors: ["#ffd24a", "#ff7a1a", "#ff3d7f", "#8a3dff"] },
    synthwave: { mode: "gradient", colors: ["#2af7ff", "#ff4fd8", "#b02cff", "#3a0a78"] },
    aurora: { mode: "gradient", colors: ["#3dff8a", "#00d6c8", "#3a7bff", "#b46cff"] },
    // White at the very top, blues darkening downwards; some streams darker.
    ocean: { mode: "gradient", colors: ["#ffffff", "#8fd3ff", "#2a6fd6", "#0a2a6a"], variation: 0.4 },
    // Forest: leaf green at the top, deeper green, bark brown, then grey-brown
    // stone at the bottom (some streams darker, for grey and brown there).
    forest: { mode: "gradient", colors: ["#5ee05a", "#2e9e3c", "#7a4e24", "#7a7268"], variation: 0.45 },
    // Deep purple through magenta to blue, with dark "space" streams.
    galaxy: { mode: "gradient", colors: ["#2a0a5a", "#9a1aff", "#ff3dc0", "#1a3aff"], variation: 0.7 },
}
var multiNames = ["rainbow", "neon", "vapor", "glitch", "candy", "siren", "holly", "icefire",
                  "ink", "fire", "lava", "sunset", "synthwave", "aurora", "ocean", "forest", "galaxy"]
var modes = { single: 0, streams: 1, gradient: 2, rainbow: 3 }

function isMulti(spec) { return multi[spec] !== undefined }

// "#aaaaaa,#bbbbbb,...": a list of colours used like a per-stream look
// (the Wallpaper colour, and what the screensaver gets for it).
function listOf(spec) {
    return typeof spec === "string" && spec.indexOf(",") >= 0 ? spec.split(",") : null
}

// Current name for a saved colour name (old names map to their replacement).
function canonical(spec) { return aliases[spec] || spec }

// The colours a setting stands for ("theme" uses the given accent). A single
// look gives its body colour.
function colorsOf(spec, accent) {
    if (spec === "theme") return [accent]
    if (listOf(spec)) return listOf(spec).map(function(h) { return Qt.color(h) })
    if (multi[spec]) return multi[spec].colors.map(function(h) { return Qt.color(h) })
    if (presets[spec]) return [Qt.color(presets[spec].body)]
    return [Qt.color(spec)]
}

// Main colour of a setting: the only one, or a multi look's first.
function base(spec, accent) { return colorsOf(spec, accent)[0] }

// Swatch squares for the panel: head, body and tail, or a look's colours.
function swatch(spec) {
    if (multi[spec]) return multi[spec].colors
    if (listOf(spec)) return listOf(spec)
    if (presets[spec]) return [presets[spec].head, presets[spec].body, presets[spec].tail]
    return [spec]
}

function bright(c) {
    var m = Math.max(c.r, c.g, c.b, 0.001)
    return Qt.rgba(c.r / m, c.g / m, c.b / m, 1)
}

// The Daylight colour: follows the time of day (hour 0..24), from night
// violet-blue through a rose dawn, gold morning, cyan noon, golden hour and
// a red sunset.
var daylightStops = [[0, "#3a4dff"], [5, "#7a4dff"], [6.5, "#ff6a8a"], [8, "#ffc66a"], [12, "#7df9ff"],
                     [17, "#ffd24a"], [19, "#ff5a3a"], [21, "#b04dff"], [24, "#3a4dff"]]
function daylight(hour) {
    var h = ((hour % 24) + 24) % 24
    for (var i = 1; i < daylightStops.length; i++) {
        if (h <= daylightStops[i][0]) {
            var a = daylightStops[i - 1], b = daylightStops[i]
            var t = (h - a[0]) / (b[0] - a[0]), ca = Qt.color(a[1]), cb = Qt.color(b[1])
            return hex(Qt.rgba(ca.r + (cb.r - ca.r) * t, ca.g + (cb.g - ca.g) * t, ca.b + (cb.b - ca.b) * t, 1))
        }
    }
    return daylightStops[0][1]
}

// Brighten to full intensity, near-white head, dim tail, faint haze/background.
function derived(c) {
    var b = bright(c)
    var r = b.r, g = b.g, bl = b.b
    var h = 0.91
    return {
        head: Qt.rgba(r + (1 - r) * h, g + (1 - g) * h, bl + (1 - bl) * h, 1),
        body: Qt.rgba(r, g, bl, 1),
        tail: Qt.rgba(r * 0.32, g * 0.32, bl * 0.32, 1),
        haze: Qt.rgba(r * 0.20, g * 0.20, bl * 0.20, 1),
        background: Qt.rgba(0.012 + r * 0.05, 0.012 + g * 0.05, 0.012 + bl * 0.05, 1)
    }
}

// Everything a rain layer needs: the single-colour palette plus, for multi
// looks, the mode and four brightened colours the shader picks between.
function full(spec, accent) {
    var cs = colorsOf(spec, accent)
    var p = derived(cs[0])
    if (presets[spec]) {
        p.head = Qt.color(presets[spec].head)
        p.body = Qt.color(presets[spec].body)
        p.tail = Qt.color(presets[spec].tail)
    }
    p.mode = multi[spec] ? modes[multi[spec].mode] : listOf(spec) ? modes.streams : modes.single
    p.variation = multi[spec] && multi[spec].variation ? multi[spec].variation : 0
    // Gradients keep their colours (dark stops stay dark); the others are
    // brightened to full intensity like single colours.
    var exact = p.mode === modes.gradient
    var four = [0, 1, 2, 3].map(function(i) { var c = cs[i % cs.length]; return exact ? Qt.rgba(c.r, c.g, c.b, 1) : bright(c) })
    p.colorA = four[0]; p.colorB = four[1]; p.colorC = four[2]; p.colorD = four[3]
    return p
}

function hex(c) {
    function h(v) { var s = Math.round(v * 255).toString(16); return s.length < 2 ? "0" + s : s }
    return "#" + h(c.r) + h(c.g) + h(c.b)
}

function hueGap(a, b) {
    var d = Math.abs(a.hslHue - b.hslHue)
    return Math.min(d, 1 - d)
}

// Hex list for tools/rain-theme.py ("#aaaaaa,#bbbbbb,..."). A single look
// whose head or tail shifts hue passes those too, so its theme mixes them in
// (highlights take the head, shadows the tail).
function themeSpec(spec, accent) {
    if (presets[spec]) {
        var p = presets[spec], body = Qt.color(p.body), head = Qt.color(p.head), tail = Qt.color(p.tail)
        var list = [body]
        if (head.hslSaturation > 0.25 && hueGap(head, body) > 20 / 360) list.push(head)
        if (tail.hslSaturation > 0.25 && hueGap(tail, body) > 20 / 360) list.push(tail)
        return list.map(hex).join(",")
    }
    // Near-white or grey colours cannot lead a theme (it would come out grey),
    // so a look's first saturated colour leads.
    var cs = colorsOf(spec, accent)
    var vivid = cs.filter(function(c) { return c.hslSaturation > 0.2 && c.hslLightness < 0.9 })
    var ordered = vivid.length ? vivid.concat(cs.filter(function(c) { return vivid.indexOf(c) < 0 && c.hslSaturation > 0.2 })) : cs
    return ordered.map(hex).join(",")
}
