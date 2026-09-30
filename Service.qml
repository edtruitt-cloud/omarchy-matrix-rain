import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import "rainpalette.js" as Palette
import "atlas.js" as Atlas

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var pluginRegistry: null

  readonly property string pluginId: "ertiv.matrix-rain"
  readonly property string home: Quickshell.env("HOME")
  readonly property string stateDir: home + "/.local/state/ertiv.matrix-rain"
  readonly property string statePath: stateDir + "/state.json"
  readonly property var timeoutPrefix: ["timeout", "-k", "1", "5"]

  property bool enabled: true
  property bool manualPaused: false
  property bool pauseOnFullscreen: true
  property real letterSize: 16
  property real speed: 0.15
  property real density: 0.75
  // "green" (classic), "theme" (follows the Omarchy accent) or "#rrggbb".
  property string rainColor: "green"
  // Only Colour for -> Theme sets the Omarchy theme (tools/rain-theme.py);
  // rain colours never do. The test harness turns this off so it never
  // rethemes a desktop.
  property bool themeFollowsRain: true
  property string themeStatus: ""
  property real time: 0
  property real rainPhase: 0

  // --- Weather presets: letter size / fall speed / density. Each remembers
  // Presets are fixed: picking one sets its values, and changing any of those
  // settings afterwards simply deselects it (rainPreset is "" then).
  // A preset sets the whole look: size, fall, density, trail, flicker, depth.
  readonly property var weatherKeys: ["letterSize", "speed", "density", "trailScale", "glyphFlicker",
                                      "depthLevel", "depthLayers", "depthScale", "crtAmount",
                                      "mirrorAmount", "glyphWeight", "gravity", "speedVariety", "trailVariety",
                                      "headGlow", "bloomAmount", "aberration", "vignette"]
  // Shape and light every preset starts from (the original look).
  readonly property var plainShape: ({ mirrorAmount: 0, glyphWeight: 0, gravity: 0, speedVariety: 1, trailVariety: 1,
                                       headGlow: 0, bloomAmount: 0, aberration: 0, vignette: 0 })
  readonly property var weatherPresets: withShape({
    // Slow, large, sparse and soft.
    drizzle: { letterSize: 22, speed: 0.10, density: 0.50, trailScale: 0.6, glyphFlicker: 0.4,
               depthLevel: 0.40, depthLayers: 1, depthScale: 0.40, crtAmount: 0 },
    // The film: one dense sheet of mid-size code, long fading trails, busy
    // glyphs, only a faint hint of depth, on a full CRT.
    classic: { letterSize: 16, speed: 0.22, density: 0.85, trailScale: 1.35, glyphFlicker: 1.2,
               depthLevel: 0.20, depthLayers: 1, depthScale: 0.60, crtAmount: 1.0 },
    // Mid-size, fast, packed, longest trails, fastest flicker, every layer.
    storm: { letterSize: 14, speed: 0.60, density: 1.0, trailScale: 2.0, glyphFlicker: 2.0,
             depthLevel: 0.20, depthLayers: 3, depthScale: 0.45, crtAmount: 0 },
    // Tiny and as fast as it goes, a data feed with only a faint layer.
    terminal: { letterSize: 6, speed: 1.0, density: 0.85, trailScale: 1.0, glyphFlicker: 1.0,
                depthLevel: 0.20, depthLayers: 1, depthScale: 0.60, crtAmount: 0 }
  })
  function withShape(presets) {
    var out = ({})
    for (var n in presets) out[n] = Object.assign({}, plainShape, presets[n])
    return out
  }
  readonly property var weatherNames: ["drizzle", "classic", "storm", "terminal"]
  // The preset the current values match exactly ("" = your own mix).
  readonly property string rainPreset: {
    for (var i = 0; i < weatherNames.length; i++) {
      var pr = weatherPresets[weatherNames[i]], same = true
      for (var j = 0; j < weatherKeys.length && same; j++)
        same = Math.abs(Number(root[weatherKeys[j]]) - Number(pr[weatherKeys[j]])) < 1e-4
      if (same) return weatherNames[i]
    }
    return ""
  }
  // 3: presets are fixed (2026-09-27): a preset saved with tweaks goes back
  // to its real values.
  readonly property int weatherVersion: 3

  // --- Look and reactions. Every amount is a slider where 0 means off.
  // Depth: a second, smaller, slower layer behind the main rain.
  property real depthLevel: 0.45        // visibility, 0..0.9
  property real depthScale: 0.6         // farthest layer's letter size relative to the main rain
  property int depthLayers: 1           // extra layers behind the main rain, 0 (off)..5
  // Depth quality: resolution the layers behind the front render at.
  property string depthQuality: "balanced"
  readonly property var depthQualities: ({ sharp: 1.0, balanced: 0.66, fast: 0.5 })
  readonly property real depthResolution: depthQualities[depthQuality] || 0.66
  readonly property bool depthOn: depthLevel > 0.001 && depthLayers > 0
  // Shape of the streams (1 = the original look).
  property real trailScale: 1.0         // trail length, 0.5..2
  property real glyphFlicker: 1.0       // how fast characters change, 0..2
  // Beat flash on the kick while Sound Lab plays; a notification burst;
  // speed pulled toward Sound Lab's tempo or up with CPU load.
  property real flashAmount: 0.6
  // CRT look: scanlines and darker corners (0..1).
  property real crtAmount: 0
  property real burstAmount: 0.7
  property real tempoPull: 0
  property real cpuPull: 0
  // Glyph shapes and stream motion (0 = off; the varieties' 1 = original).
  property real mirrorAmount: 0      // share of glyphs drawn mirrored
  property real glyphWeight: 0       // bolder glyphs
  property real gravity: 0           // streams speed up as they fall
  property real speedVariety: 1      // spread of stream speeds
  property real trailVariety: 1      // spread of trail lengths
  // Light.
  property real headGlow: 0          // bigger, brighter heads
  property real bloomAmount: 0       // soft halo around glyphs
  property real aberration: 0        // red/blue colour fringes
  property real vignette: 0          // darker corners
  // Interaction.
  property real mouseAmount: 0.5     // the cursor parts the rain
  property real workspaceRush: 0.5   // switching workspace sweeps the rain
  property real idleDrift: 0.5       // away: rain slows and dims; back: a surge
  property real chainChance: 0       // an event can set off another
  property real typingAmount: 0      // each keypress sends a ripple (off until you turn it up: it adds key hooks)
  // Panel sections folded away (by heading).
  property var collapsedSections: []
  function toggleSection(name) {
    var c = root.collapsedSections.slice(), i = c.indexOf(name)
    if (i >= 0) c.splice(i, 1); else c.push(name)
    root.collapsedSections = c
    persist()
  }
  readonly property var rainAmountRanges: ({
    depthLevel: [0, 0.9], depthScale: [0.4, 0.9], depthLayers: [0, 5], trailScale: [0.5, 2], glyphFlicker: [0, 2],
    flashAmount: [0, 1], burstAmount: [0, 1], tempoPull: [0, 1], cpuPull: [0, 1],
    crtAmount: [0, 1], mirrorAmount: [0, 1], glyphWeight: [0, 1], gravity: [0, 1], speedVariety: [0, 2],
    trailVariety: [0, 3], headGlow: [0, 1], bloomAmount: [0, 1], aberration: [0, 1], vignette: [0, 1],
    mouseAmount: [0, 1], workspaceRush: [0, 1], idleDrift: [0, 1], chainChance: [0, 1], typingAmount: [0, 1]
  })
  // Glyph sets: ranges of atlas.js (build-atlas.py). "matrix" is the rain's
  // own mix of katakana, digits, letters and symbols.
  readonly property var glyphSets: ({
    matrix: [[0, Atlas.rainCount]],
    katakana: Atlas.blocks.katakana,
    binary: [[45, 2]],
    digits: [[45, 10]],
    hex: [[45, 10], [Atlas.blocks.text[0][0], 6]],
    latin: [[Atlas.blocks.text[0][0], 26]],
    greek: Atlas.blocks.greek,
    runes: Atlas.blocks.runes,
    braille: Atlas.blocks.braille,
    box: Atlas.blocks.box,
    hieroglyphs: Atlas.blocks.hieroglyphs,
    alchemy: Atlas.blocks.alchemy,
    // Your own symbols, drawn into their own texture (customAtlasPath).
    custom: [[0, Math.max(1, customCount)]]
  })
  readonly property var glyphSetNames: ["matrix", "katakana", "binary", "digits", "hex", "latin", "greek", "runes",
                                        "braille", "box", "hieroglyphs", "alchemy", "custom"]
  property string glyphSet: "matrix"
  // The set being drawn right now (a Glyph swap can stand in for a while).
  readonly property string shownSet: swapSet || glyphSet
  readonly property bool customShown: shownSet === "custom" && customCount > 0
  readonly property vector4d glyphRange: {
    var r = root.glyphSets[root.shownSet === "custom" && root.customCount === 0 ? "matrix" : root.shownSet] || root.glyphSets.matrix
    return Qt.vector4d(r[0][0], r[0][1], r.length > 1 ? r[1][0] : 0, r.length > 1 ? r[1][1] : 0)
  }

  // --- Custom glyphs: you type symbols; tools/custom-glyphs.py draws every
  // one a font can draw into customAtlasPath, made one colour and cleaned up
  // so it reads as rain (locally; nothing is sent anywhere).
  readonly property string customAtlasPath: stateDir + "/custom-glyphs.png"
  property string customChars: ""      // the symbols in use (checked)
  property int customCount: 0
  property int customRows: 0
  property int customRev: 0            // bumped to reload the texture
  property string customStatus: ""
  readonly property bool customBusy: customProc.running
  function setCustomGlyphs(text) {
    var t = String(text || "").slice(0, 200)
    if (customProc.running) return false
    root.customStatus = "Drawing your symbols…"
    customProc.command = ["python3", root.pluginDir + "/tools/custom-glyphs.py", t, root.customAtlasPath]
    customProc.running = true
    return true
  }
  function customResult(text) {
    var r
    try { r = JSON.parse(String(text).trim().split("\n").pop()) } catch (e) { r = null }
    if (!r || typeof r.count !== "number") {
      root.customStatus = "Couldn't draw those symbols (needs python-pillow and fontconfig)."
      return
    }
    root.customChars = String(r.chars || "")
    root.customCount = r.count
    root.customRows = r.rows
    root.customRev++
    var gone = (r.removed || []).map(function(x) { return x.ch + " (" + x.why + ")" })
    var tidy = (r.cleaned || []).map(function(x) { return x.ch + " " + x.what })
    root.customStatus = (r.count ? "Using " + r.count + " symbol" + (r.count === 1 ? "" : "s") : "No symbols to use")
      + (tidy.length ? "; " + tidy.join(", ") : "")
      + (gone.length ? "; left out " + gone.join(", ") : "") + "."
    if (r.count > 0) root.glyphSet = "custom"
    persist()
  }
  Process {
    id: customProc
    stdout: StdioCollector { onStreamFinished: root.customResult(text) }
  }
  // Stream heads: the look's own, white, the body colour or the theme accent.
  readonly property var headModes: ["look", "white", "body", "accent"]
  property string headColor: "look"
  // Heads for the depth layers: all of them ("" = same as the rain), and each
  // layer on its own (index 0 = Layer 1; "" = same as all layers).
  property string backHeadColor: ""
  property var layerHeadColors: []
  // The depth layers' own colour look ("" = same as the front).
  property string backColor: ""
  // Each depth layer's own look (index 0 = the first layer behind the rain;
  // "" = the depth layers' colour above).
  property var layerColors: []
  // The Omarchy theme's own colour ("" = follow the rain colour).
  property string themeColor: ""
  // Saved looks: [{ name, look }] (see lookKeys).
  property var savedLooks: []
  // Events: now and then something happens to the rain. eventRate picks how
  // often; eventsOn which ones may happen (one is chosen at random).
  readonly property var eventNames: ["dejavu", "rewind", "bullet", "surge", "scramble", "binary",
                                     "blackout", "glitch", "dive", "pan", "drift", "cascade"]
  property var eventsOn: ["dejavu", "rewind", "bullet", "surge", "scramble", "binary",
                          "blackout", "glitch", "dive", "pan", "drift", "cascade"]
  // 2: Drift and Cascade added (2026-09-27); older saved lists gain them.
  readonly property int eventsVersion: 2
  property string eventRate: "off"
  readonly property var eventMinutes: ({ rare: [8, 15], sometimes: [3, 6], often: [1, 2] })

  // Runtime reaction levels (not saved).
  property real beatFlash: 0
  property real burstLevel: 0
  property real cpuLoad: 0
  property var _cpuPrev: null
  // The event in progress ("" = none) and its clock.
  property string activeEvent: ""
  property real _eventT: 0
  property real _eventStart: 0
  readonly property real dejaVuLoop: 0.4
  readonly property int dejaVuRepeats: 3
  readonly property var eventSeconds: ({ dejavu: 1.2, rewind: 1.6, bullet: 3.0, surge: 1.6, scramble: 0.7,
                                         binary: 10.0, blackout: 2.2, glitch: 0.9, dive: 4.7, pan: 4.0,
                                         drift: 3.2, cascade: 3.4 })
  // --- Rain layers at depths. At rest the front slot is the main rain
  // (distance 1), slot k the k-th depth layer (1 + k/n), and one more slot
  // waits hidden just behind the back (2 + 1/n). layerSlots[i] is the slot
  // layer i rests in. Every layer draws at the same letter size and is
  // scaled by a camera zoom for its distance, so moving never re-bins its
  // streams. A Dive flies the whole pack toward the camera at one speed:
  // each layer grows, fades only as it passes the screen, and rejoins
  // directly behind the last layer of the pack, so the pack stays tight.
  // The pack then coasts forward into the resting slots: layers still in
  // front of the front slot fly on through the screen into the back slots,
  // the rest drift forward into the front slots. Nothing ever moves back
  // (each layer keeps its own stream pattern).
  readonly property int layerCount: (depthOn ? depthLayers : 0) + 2
  readonly property real diveSpacing: 1 / Math.max(1, layerCount - 2)
  property var layerSlots: []
  property var layerD: []          // distances while a dive is in progress
  property var layerFadeIn: []     // 0..1 per layer: fading back in after rejoining
  property var _settleFrom: []
  property var _settleTo: []
  property var _settleLen: []
  property var _settleRejoin: []
  readonly property real diveFlight: 3.6   // seconds of flight, then settle
  readonly property real diveTopSpeed: 1.0 // distance units per second
  onLayerCountChanged: layerSlots = []
  property real pan: 0
  // Glyph swap (the Binary event): a random other glyph set for 10 s. It runs
  // on its own clock, so other events can happen while it lasts.
  property string swapSet: ""
  property real swapT: 0
  // What events do to the rain layers.
  property real rainFade: 1       // blackout
  property real scrambleBoost: 0  // extra glyph flicker
  property real glitchLevel: 0
  property real glitchSeed: 0
  property real driftPhase: 0      // Drift: grows during the event and stays (no jump back)
  property real cascadeT: 0        // Cascade wave position (0 = off)
  property real cascadeSeed: 0
  property int _chainLeft: 0
  // Interaction state.
  property real wsT: 1             // workspace sweep progress (1 = done)
  property int wsDir: 1
  property int _lastWorkspace: -1
  property real idleSeconds: 0
  property real netLoad: 0
  Behavior on netLoad { NumberAnimation { duration: 1500 } }
  property var _netPrev: null
  readonly property real idleLevel: idleDrift * Math.min(1, idleSeconds / 600)
  readonly property real wsKick: Math.sin(Math.PI * Math.min(1, wsT)) * workspaceRush

  // Everything the reactions add on top of the sliders and Sound Lab's LFO.
  readonly property real reactiveSpeed: {
    var f = 1.0
    if (linkPlaying) f *= 1.0 + tempoPull * (clamp(linkBpm, 60, 180) / 122 - 1.0)
    f *= 1.0 + cpuPull * cpuLoad
    f *= 1.0 + 0.8 * burst
    f *= 1.0 + 0.25 * netLoad
    f *= 1.0 + 1.5 * wsKick
    f *= 1.0 - 0.6 * idleLevel
    return rainSpeed * f
  }
  readonly property real burst: burstLevel * burstAmount
  readonly property real reactiveDensity: clamp(rainDensity + 0.3 * burst + 0.12 * netLoad, 0.5, 1.0)
  readonly property real rainFlash: Math.max(beatFlash * flashAmount, burst * 0.8)
  // rain.frag PERIOD: fall rates repeat exactly every rainPeriod units, so the
  // phase wraps without a visible jump and stays precise as a shader float.
  readonly property real rainPeriod: 256
  property bool _stateLoaded: false
  property bool _stateCorrupt: false
  // Monitor name -> true while its active workspace has a fullscreen window.
  readonly property var hyprFullscreen: {
    var set = ({})
    var mons = Hyprland.monitors.values
    for (var i = 0; i < mons.length; i++) {
      var ws = mons[i].activeWorkspace
      if (ws && ws.hasFullscreen) set[String(mons[i].name)] = true
    }
    return set
  }
  // Tests may set an override map; null follows Hyprland.
  property var fullscreenOverride: null
  readonly property var fullscreenMonitors: fullscreenOverride || hyprFullscreen

  // Sound Lab (the separate synth plugin), over the rain link socket: while
  // it runs it reports play state, tempo and its LFO, and sends a beat on
  // every audible kick. Nothing here is saved.
  readonly property string linkPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ertiv-matrix-rain-link.sock"
  property var linkClients: []
  readonly property bool soundLinked: linkClients.length > 0
  property bool linkPlaying: false
  property real linkBpm: 122
  property real linkLfoRate: 0.08
  property real linkLfoDepth: 0
  property string linkLfoDest: ""

  readonly property string pluginDir: (manifest && manifest.__sourceDir)
    ? String(manifest.__sourceDir)
    : (home + "/.config/omarchy/plugins/ertiv.matrix-rain")

  property bool shuttingDown: false
  readonly property var screens: Quickshell.screens
  function screenCanAnimate(name) {
    return enabled && !manualPaused && !shuttingDown
      && !(pauseOnFullscreen && fullscreenMonitors[String(name)] === true)
  }
  readonly property bool rendering: {
    for (var i = 0; i < screens.length; i++)
      if (screenCanAnimate(screens[i].name)) return true
    return false
  }
  // Sound Lab's LFO can also sway the rain's speed, density or size.
  readonly property real lfoValue: 0.5 + 0.5 * Math.sin(time * Math.max(0.01, linkLfoRate) * Math.PI * 2)
  readonly property string lfoDest: soundLinked ? linkLfoDest : ""
  readonly property real lfoDepth: linkLfoDepth
  readonly property real rainSpeed: {
    if (lfoDest !== "speed") return speed
    return clamp(speed * (1.0 + lfoDepth * (2.0 * lfoValue - 1.0) * 0.7), 0.02, 1.0)
  }
  readonly property real rainDensity: {
    if (lfoDest !== "density") return density
    return clamp(density * (1.0 + lfoDepth * (2.0 * lfoValue - 1.0) * 0.5), 0.50, 1.00)
  }
  readonly property real rainSize: {
    if (lfoDest !== "size") return letterSize
    return clamp(letterSize * (1.0 + lfoDepth * (2.0 * lfoValue - 1.0) * 0.22), 4, 100)
  }

  readonly property var rainPresets: Palette.presets
  // Classic green keeps its hand-tuned phosphor/CRT/tail colours; any other
  // colour (single or multi-colour) comes from rainpalette.js, shared with
  // the screensaver and the panel's swatches.
  readonly property var rainPalette: paletteOf(root.rainColor)
  // Daylight follows the clock (updated every minute); Wallpaper holds the
  // strongest colours of the current wallpaper, taken when it was picked.
  property real dayHour: 12
  property var wallpaperColors: []
  function resolvedColor(spec) {
    if (spec === "daylight") return Palette.daylight(root.dayHour)
    if (spec === "wallpaper") return root.wallpaperColors.length ? root.wallpaperColors.join(",") : "#cdd6e8"
    return spec
  }
  Timer {
    interval: 60000
    repeat: true
    running: !root.shuttingDown
    triggeredOnStart: true
    onTriggered: { var d = new Date(); root.dayHour = d.getHours() + d.getMinutes() / 60 }
  }
  function paletteOf(spec) {
    spec = resolvedColor(spec)
    if (spec === "green") {
      var g = Qt.rgba(0.00, 1.00, 0.255, 1)
      return { head: Qt.rgba(0.91, 1.00, 0.91, 1), body: g, tail: Qt.rgba(0.00, 0.32, 0.03, 1),
               mode: 0, colorA: g, colorB: g, colorC: g, colorD: g, variation: 0 }
    }
    return Palette.full(spec, Color.accent)
  }
  readonly property var backPalette: backColor === "" ? rainPalette : paletteOf(backColor)
  // Colour of each resting depth slot: 0 is the rain, k the k-th layer behind.
  function slotColor(k) {
    if (k <= 0) return root.rainColor
    return root.layerColors[k - 1] || root.backColor || root.rainColor
  }
  readonly property bool layersColoured: backColor !== "" || layerColors.some(function(c) { return !!c })
  readonly property var slotPalettes: {
    var list = [root.rainPalette]
    for (var k = 1; k <= 5; k++) {
      var spec = slotColor(k)
      list.push(spec === root.rainColor ? root.rainPalette : paletteOf(spec))
    }
    return list
  }
  // A layer's palette at distance d: the colours of the slots it lies
  // between, blended, so colours travel smoothly with the layers in a Dive.
  function layerPaletteAt(d) {
    if (!root.layersColoured) return root.rainPalette
    var n = Math.max(1, root.layerCount - 2)
    var pos = clamp((d - 1) * n, 0, root.depthOn ? root.depthLayers : 0)
    var k = Math.floor(pos), f = pos - k
    var a = root.slotPalettes[Math.min(k, 5)], b = root.slotPalettes[Math.min(k + 1, 5)]
    return f <= 0 ? a : mixPalettes(a, b, f)
  }
  function mixPalettes(a, b, m) {
    if (m <= 0 || a === b) return a
    function mix(x, y) { return Qt.rgba(x.r + (y.r - x.r) * m, x.g + (y.g - x.g) * m, x.b + (y.b - x.b) * m, 1) }
    return { head: mix(a.head, b.head), body: mix(a.body, b.body), tail: mix(a.tail, b.tail),
             mode: m < 0.5 ? a.mode : b.mode,
             colorA: mix(a.colorA, b.colorA), colorB: mix(a.colorB, b.colorB),
             colorC: mix(a.colorC, b.colorC), colorD: mix(a.colorD, b.colorD),
             variation: (a.variation || 0) + ((b.variation || 0) - (a.variation || 0)) * m }
  }
  readonly property int headModeIndex: Math.max(0, headModes.indexOf(headColor))
  readonly property color headFixed: headColor === "accent" ? Color.accent : "#ffffff"
  // Heads of the layer resting in slot k (0 = the rain).
  function headModeAt(k) {
    if (k <= 0) return root.headColor
    return root.layerHeadColors[k - 1] || root.backHeadColor || root.headColor
  }
  // For a layer at distance d: the nearest slot's heads.
  function headModeFor(d) {
    var n = Math.max(1, root.layerCount - 2)
    var k = root.depthOn ? Math.round(clamp((d - 1) * n, 0, root.depthLayers)) : 0
    return headModeAt(k)
  }
  function setLayerHead(layer, mode) {
    var i = Math.round(Number(layer)) - 1
    if (!(i >= 0 && i < 5) || (mode !== "" && root.headModes.indexOf(mode) < 0)) return false
    var next = root.layerHeadColors.slice()
    while (next.length < 5) next.push("")
    next[i] = mode
    root.layerHeadColors = next
    persist()
    return true
  }
  function cleanHeads(list) {
    if (!Array.isArray(list)) return []
    return list.slice(0, 5).map(function(m) { return root.headModes.indexOf(m) >= 0 ? m : "" })
  }

  function validRainColor(v) {
    var t = Palette.canonical(String(v || "").trim().toLowerCase())
    if (t === "green" || t === "theme" || t === "daylight" || t === "wallpaper" || root.rainPresets[t] !== undefined || Palette.isMulti(t)) return t
    if (/^#[0-9a-f]{6}$/.test(t)) return t
    return ""
  }

  function applyRainColor(v) {
    var t = validRainColor(v)
    if (t === "") return false
    root.rainColor = t
    if (t === "wallpaper") readWallpaper()
    persist()
    return true
  }

  // Set the Omarchy theme's colour (the only way Matrix Rain changes the theme).
  // Theme (the accent) and Daylight (changes all day) can't lead a theme.
  function applyThemeColor(v) {
    var t = v === "" ? "" : validRainColor(v)
    if (v !== "" && (t === "" || t === "theme" || t === "daylight")) return false
    if (t === "") return false
    root.themeColor = t
    if (t === "wallpaper" && !root.wallpaperColors.length) readWallpaper()
    persist()
    if (root.themeFollowsRain && rainThemeSpec() !== "") themeDebounce.restart()
    return true
  }

  // One depth layer's colour (layer 1 = just behind the rain), "" = default.
  function setLayerColor(layer, v) {
    var i = Math.round(Number(layer)) - 1
    if (!(i >= 0 && i < 5)) return false
    var t = v === "" ? "" : validRainColor(v)
    if (v !== "" && t === "") return false
    var next = root.layerColors.slice()
    while (next.length < 5) next.push("")
    next[i] = t
    root.layerColors = next
    persist()
    return true
  }


  // Theme script argument for a colour: "green", "#rrggbb" or
  // "#aaaaaa,#bbbbbb,..." (multi-colour looks); "" for colours that can't
  // lead a theme (Theme itself, Daylight).
  function themeSpecFor(spec) {
    if (spec === "" || spec === "theme" || spec === "daylight") return ""
    if (spec === "green") return "green"
    return Palette.themeSpec(resolvedColor(spec), Color.accent)
  }
  // What the Omarchy theme should be: the colour picked for it, or ""
  // (Matrix Rain leaves the theme alone).
  function rainThemeSpec() { return themeSpecFor(root.themeColor) }

  property bool _themePending: false

  // Take the wallpaper's strongest colours: vivid and bright first, then
  // how much of the picture they cover; hues kept apart.
  function readWallpaper() {
    if (!wallpaperProc.running) wallpaperProc.running = true
  }
  Process {
    id: wallpaperProc
    command: root.timeoutPrefix.concat(["bash", "-c",
      'f=$(readlink -f -- "$HOME/.local/state/omarchy/current/background") && exec magick "$f" -resize 128x128 -colors 24 -format %c histogram:info:-'])
    stdout: StdioCollector { onStreamFinished: root.pickWallpaperColors(text) }
  }
  function pickWallpaperColors(text) {
    var found = []
    String(text).split("\n").forEach(function(line) {
      var m = line.match(/^\s*(\d+):.*(#[0-9A-Fa-f]{6})/)
      if (!m) return
      var c = Qt.color(m[2].toLowerCase())
      var v = Math.max(c.r, c.g, c.b), sat = v > 0 ? (v - Math.min(c.r, c.g, c.b)) / v : 0
      found.push({ hex: m[2].toLowerCase(), c: c, score: Math.pow(Number(m[1]), 0.3) * sat * (0.3 + v) })
    })
    found.sort(function(a, b) { return b.score - a.score })
    var picked = []
    found.forEach(function(f) {
      if (picked.length >= 4 || f.score <= 0) return
      if (picked.some(function(p) { return Palette.hueGap(p.c, f.c) < 25 / 360 })) return
      picked.push(f)
    })
    if (!picked.length && found.length) picked = [found[0]]
    root.wallpaperColors = picked.map(function(p) { return Palette.hex(Palette.bright(p.c)) })
    if (!picked.length) root.themeStatus = "Could not read the wallpaper's colours."
    persist()
  }

  function applyRainTheme() {
    var spec = rainThemeSpec()
    if (spec === "" || root.shuttingDown) return
    if (themeProc.running) { root._themePending = true; return }
    root.themeStatus = "Applying Omarchy theme… the desktop will refresh in a few seconds"
    // Detached (setsid): the script ends by restarting the shell, which would
    // otherwise kill it. Its output goes to theme.log in the state folder.
    themeProc.command = ["setsid", "-f", "bash", "-c",
      'exec timeout -k 5 180 python3 "$1" "$2" --restart-shell >"$3" 2>&1',
      "_", root.pluginDir + "/tools/rain-theme.py", spec, root.stateDir + "/theme.log"]
    themeProc.running = true
  }

  // A theme colour picked just before a theme change restarted the shell
  // never got applied. On start, compare the theme colour with the last one
  // the theme script was asked for (theme-request) and catch up.
  function checkThemeCaughtUp(lastRequest) {
    var want = rainThemeSpec()
    if (!root.themeFollowsRain || want === "" || String(lastRequest).trim() === want) return false
    themeDebounce.restart()
    return true
  }
  Process {
    id: themeCheckProc
    command: root.timeoutPrefix.concat(["bash", "-c", 'cat -- "$1" 2>/dev/null || true', "_", root.stateDir + "/theme-request"])
    stdout: StdioCollector { onStreamFinished: root.checkThemeCaughtUp(text) }
  }

  // Theme changes restart terminals and re-render the desktop, so wait until
  // the user settles on a colour instead of applying every chip clicked.
  Timer {
    id: themeDebounce
    interval: 1200
    onTriggered: root.applyRainTheme()
  }

  Process {
    id: themeProc
    stderr: StdioCollector { id: themeErr }
    onExited: (exitCode) => {
      // setsid returns once the detached job starts; failures land in theme.log.
      if (exitCode !== 0) root.themeStatus = "Could not start the theme change: " + (String(themeErr.text || "").trim().split("\n").pop() || "exit " + exitCode)
      if (root._themePending) {
        root._themePending = false
        root.applyRainTheme()
      }
    }
  }

  function clamp(v, lo, hi) {
    var n = Number(v)
    if (!(n === n)) return lo
    return Math.max(lo, Math.min(hi, n))
  }

  function applyLetterSize(v) {
    root.letterSize = clamp(v, 4, 100)
    persist()
  }

  function applySpeed(v) {
    root.speed = clamp(v, 0.02, 1.0)
    persist()
  }

  function applyDensity(v) {
    root.density = clamp(v, 0.50, 1.00)
    persist()
  }

  function weatherValue(key, v) {
    if (key === "letterSize") return clamp(v, 4, 100)
    if (key === "speed") return clamp(v, 0.02, 1.0)
    if (key === "density") return clamp(v, 0.5, 1.0)
    var r = root.rainAmountRanges[key]
    return key === "depthLayers" ? Math.round(clamp(v, r[0], r[1])) : clamp(v, r[0], r[1])
  }

  function applyRainPreset(name) {
    name = String(name)
    if (!root.weatherPresets[name]) return false
    var v = root.weatherPresets[name]
    for (var i = 0; i < root.weatherKeys.length; i++) {
      var k = root.weatherKeys[i]
      root[k] = weatherValue(k, v[k])
    }
    persist()
    return true
  }

  function setRainOption(key, value) {
    if (key === "glyphSet") {
      if (!root.glyphSets[value]) return false
      root.glyphSet = value
    } else if (key === "headColor") {
      if (root.headModes.indexOf(value) < 0) return false
      root.headColor = value
    } else if (key === "backHeadColor") {
      if (value !== "" && root.headModes.indexOf(value) < 0) return false
      root.backHeadColor = value
    } else if (key === "backColor") {
      var bc = value === "" ? "" : validRainColor(value)
      if (value !== "" && bc === "") return false
      root.backColor = bc
    } else if (key === "depthQuality") {
      if (!root.depthQualities[value]) return false
      root.depthQuality = value
    } else if (key === "eventRate") {
      if (value !== "off" && !root.eventMinutes[value]) return false
      root.eventRate = value
      scheduleEvent()
    } else if (root.rainAmountRanges[key]) {
      var r = root.rainAmountRanges[key]
      root[key] = key === "depthLayers" ? Math.round(clamp(value, r[0], r[1])) : clamp(value, r[0], r[1])
      if (key === "cpuPull" && root.cpuPull === 0) root.cpuLoad = 0
      if (key === "typingAmount") syncTypingKeys()
    } else {
      return false
    }
    persist()
    return true
  }

  // --- reactions
  // A kick Sound Lab just played.
  // Switching workspace sends a short rush down the rain (it never slides sideways).
  function workspaceSwitched(id) {
    if (!(id > 0)) return
    var last = root._lastWorkspace
    root._lastWorkspace = id
    if (id !== last) workspaceLookFor(id)
    if (last < 0 || id === last || root.workspaceRush <= 0) return
    root.wsDir = id > last ? -1 : 1
    root.wsT = 0
  }

  // --- A look per workspace (1-5). Each workspace can use a weather preset
  // or a saved look, or "" to keep your own look. Your own look is kept in
  // workspaceBase while a workspace look is showing, and comes back on a
  // workspace without one. Workspace looks never change the desktop theme.
  readonly property int workspaceCount: 5
  property var workspaceLooks: ({})
  property var workspaceBase: null
  property real wsFade: 1
  property var _wsPending: null
  function workspaceChoices() {
    // Only saved looks: they carry colours as well as the weather.
    return [""].concat(root.savedLooks.map(function(l) { return "look:" + l.name }))
  }
  function lookForChoice(choice) {
    var c = String(choice || "")
    if (c.indexOf("look:") === 0) {
      var l = root.savedLooks.filter(function(x) { return x.name === c.slice(5) })[0]
      return l ? l.look : null
    }
    return null
  }
  // Step a workspace to the next (or previous) choice: Your look, then each saved look.
  function cycleWorkspaceLook(ws, dir) {
    var list = workspaceChoices(), cur = list.indexOf(root.workspaceLooks[String(ws)] || "")
    return setWorkspaceLook(ws, list[((cur < 0 ? 0 : cur) + (dir < 0 ? -1 : 1) + list.length) % list.length])
  }
  function setWorkspaceLook(ws, choice) {
    ws = Math.round(Number(ws))
    if (!(ws >= 1 && ws <= root.workspaceCount)) return false
    choice = String(choice || "")
    if (choice !== "" && !lookForChoice(choice)) return false
    var next = Object.assign({}, root.workspaceLooks)
    if (choice === "") delete next[String(ws)]
    else next[String(ws)] = choice
    root.workspaceLooks = next
    persist()
    if (ws === root._lastWorkspace) workspaceLookFor(ws)
    return true
  }
  function workspaceLookFor(id) {
    var look = lookForChoice(root.workspaceLooks[String(id)])
    if (look) {
      if (!root.workspaceBase) root.workspaceBase = currentLook()
      fadeToLook(look)
    } else if (root.workspaceBase) {
      var base = root.workspaceBase
      root.workspaceBase = null
      fadeToLook(base)
    }
  }
  // Dip the rain for a moment and change the look while it is dark.
  function fadeToLook(look) {
    root._wsPending = look
    if (!root.rendering) { applyLook(look, true); root._wsPending = null; return }
    wsFadeAnim.restart()
  }
  SequentialAnimation {
    id: wsFadeAnim
    NumberAnimation { target: root; property: "wsFade"; to: 0; duration: 160; easing.type: Easing.InQuad }
    ScriptAction { script: { if (root._wsPending) root.applyLook(root._wsPending, true); root._wsPending = null } }
    NumberAnimation { target: root; property: "wsFade"; to: 1; duration: 380; easing.type: Easing.OutQuad }
  }

  // Away from the keyboard: the rain slows and dims; coming back sets off a surge.
  IdleMonitor {
    id: idleMon
    enabled: root.idleDrift > 0 && root.enabled && !root.shuttingDown
    timeout: 60
    respectInhibitors: true
    onIsIdleChanged: if (!isIdle) root.wakeUp()
  }
  Timer {
    interval: 1000
    repeat: true
    running: idleMon.isIdle && root.idleDrift > 0 && root.rendering
    onTriggered: root.idleSeconds += 1
  }
  function wakeUp() {
    var was = root.idleLevel
    root.idleSeconds = 0
    if (was > 0.15 && root.activeEvent === "" && root.eventsOn.indexOf("surge") >= 0) root.startEvent("surge")
  }

  // Download traffic thickens the rain a little (always on; /proc/net/dev).
  Timer {
    interval: 2000
    repeat: true
    running: root.rendering && !root.shuttingDown
    onTriggered: if (!netProc.running) netProc.running = true
  }
  Process {
    id: netProc
    command: ["cat", "/proc/net/dev"]
    stdout: StdioCollector { onStreamFinished: root.readNet(text, Date.now()) }
  }
  function readNet(text, now) {
    var rx = 0
    String(text).split("\n").forEach(function(line) {
      var m = line.match(/^\s*([^:\s]+):\s*(\d+)/)
      if (m && m[1] !== "lo") rx += Number(m[2])
    })
    var prev = root._netPrev
    root._netPrev = { rx: rx, t: now }
    if (!prev || now <= prev.t || rx < prev.rx) return
    var rate = (rx - prev.rx) / ((now - prev.t) / 1000)
    // 20 KB/s and below: nothing; 20 MB/s: full.
    root.netLoad = clamp(Math.log(Math.max(rate, 1) / 20000) / Math.log(1000), 0, 1)
  }

  // --- Saved looks and share codes. A look is everything that shapes the
  // rain (weather, glyphs, light, colours), not reactions or events.
  readonly property var lookKeys: weatherKeys
  function currentLook() {
    var l = ({})
    root.lookKeys.forEach(function(k) { l[k] = root[k] })
    l.rainColor = root.rainColor; l.glyphSet = root.glyphSet
    l.headColor = root.headColor; l.backColor = root.backColor
    l.backHeadColor = root.backHeadColor; l.layerHeadColors = root.layerHeadColors.slice()
    l.layerColors = root.layerColors.slice()
    // The Omarchy theme's colour ("" = not set by Matrix Rain).
    l.themeColor = root.themeColor
    return l
  }
  // quiet: a workspace look; the rain colour changes without retheming the desktop.
  function applyLook(l, quiet) {
    if (!l || typeof l !== "object") return false
    root.lookKeys.forEach(function(k) { if (l[k] !== undefined) root[k] = weatherValue(k, l[k]) })
    if (root.glyphSets[l.glyphSet]) root.glyphSet = l.glyphSet
    if (root.headModes.indexOf(l.headColor) >= 0) root.headColor = l.headColor
    root.backHeadColor = root.headModes.indexOf(l.backHeadColor) >= 0 ? l.backHeadColor : ""
    root.layerHeadColors = cleanHeads(l.layerHeadColors)
    if (l.backColor === "" || (typeof l.backColor === "string" && validRainColor(l.backColor) !== "")) root.backColor = l.backColor === "" ? "" : validRainColor(l.backColor)
    root.layerColors = cleanLayerColors(l.layerColors)
    // The theme colour comes back too, except for workspace looks (a theme
    // change restarts the shell), and only when it differs.
    if (!quiet && typeof l.themeColor === "string" && l.themeColor !== "" && validRainColor(l.themeColor) !== root.themeColor)
      applyThemeColor(l.themeColor)
    var colour = typeof l.rainColor === "string" ? validRainColor(l.rainColor) : ""
    if (colour !== "" && colour !== root.rainColor) {
      if (quiet) { root.rainColor = colour; if (colour === "wallpaper" && !root.wallpaperColors.length) readWallpaper(); persist() }
      else applyRainColor(colour)
    } else persist()
    return true
  }
  function cleanLayerColors(list) {
    if (!Array.isArray(list)) return []
    return list.slice(0, 5).map(function(c) { return typeof c === "string" && c !== "" ? validRainColor(c) : "" })
  }
  function saveLook(name) {
    var n = String(name || "").trim().slice(0, 24) || ("Look " + (root.savedLooks.length + 1))
    // Saving over a name keeps its place in your order.
    var list = root.savedLooks.slice(), at = -1
    for (var i = 0; i < list.length; i++) if (list[i].name === n) at = i
    if (at >= 0) list[at] = { name: n, look: currentLook() }
    else list.push({ name: n, look: currentLook() })
    root.savedLooks = list.slice(-12)
    persist()
    return n
  }
  // Drag and drop in the panel: move a saved look to another place.
  function moveLook(from, to) {
    var list = root.savedLooks.slice()
    if (!(from >= 0 && from < list.length && to >= 0 && to < list.length) || from === to) return false
    var item = list.splice(from, 1)[0]
    list.splice(to, 0, item)
    root.savedLooks = list
    persist()
    return true
  }
  function deleteLook(name) {
    var before = root.savedLooks.length
    root.savedLooks = root.savedLooks.filter(function(x) { return x.name !== name })
    var ws = Object.assign({}, root.workspaceLooks)
    for (var k in ws) if (ws[k] === "look:" + name) delete ws[k]
    root.workspaceLooks = ws
    persist()
    return root.savedLooks.length < before
  }
  // Whether the rain looks exactly like a saved look (lights its chip).
  function lookIs(name) {
    var l = root.savedLooks.filter(function(x) { return x.name === name })[0]
    if (!l) return false
    var c = currentLook(), k = l.look
    for (var i = 0; i < root.lookKeys.length; i++) {
      var key = root.lookKeys[i]
      if (k[key] !== undefined && Math.abs(Number(k[key]) - Number(c[key])) > 1e-4) return false
    }
    function same(a, b) { return (a === undefined ? "" : String(a)) === String(b) }
    return (k.rainColor === undefined || validRainColor(k.rainColor) === c.rainColor) && same(k.glyphSet || "matrix", c.glyphSet)
      && same(k.headColor || "look", c.headColor) && same(k.backColor || "", c.backColor)
      && JSON.stringify(cleanLayerColors(k.layerColors)) === JSON.stringify(cleanLayerColors(c.layerColors))
  }
  function recallLook(name) {
    var l = root.savedLooks.filter(function(x) { return x.name === name })[0]
    return l ? applyLook(l.look) : false
  }
  // Base64 of UTF-8 text (Qt.btoa/atob on strings are deprecated).
  readonly property string _b64: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  function toBase64(text) {
    var bytes = [], u = encodeURIComponent(text)
    for (var i = 0; i < u.length; i++) {
      if (u[i] === "%") { bytes.push(parseInt(u.substr(i + 1, 2), 16)); i += 2 }
      else bytes.push(u.charCodeAt(i))
    }
    var out = "", a = root._b64
    for (i = 0; i < bytes.length; i += 3) {
      var n = (bytes[i] << 16) | ((bytes[i + 1] || 0) << 8) | (bytes[i + 2] || 0)
      out += a[(n >> 18) & 63] + a[(n >> 12) & 63] + (i + 1 < bytes.length ? a[(n >> 6) & 63] : "=") + (i + 2 < bytes.length ? a[n & 63] : "=")
    }
    return out
  }
  function fromBase64(b64) {
    var a = root._b64, clean = String(b64).replace(/[^A-Za-z0-9+/]/g, ""), bytes = []
    for (var i = 0; i + 1 < clean.length; i += 4) {
      var n = 0, k
      for (k = 0; k < 4; k++) n = (n << 6) | (i + k < clean.length ? a.indexOf(clean[i + k]) : 0)
      bytes.push((n >> 16) & 255)
      if (i + 2 < clean.length) bytes.push((n >> 8) & 255)
      if (i + 3 < clean.length) bytes.push(n & 255)
    }
    return decodeURIComponent(bytes.map(function(b) { return "%" + (b < 16 ? "0" : "") + b.toString(16) }).join(""))
  }
  // "MR1:" + base64 of the look (with a name), to paste somewhere else.
  function lookCode(name) {
    var l = currentLook(); l.name = String(name || "Shared look").slice(0, 24)
    return "MR1:" + toBase64(JSON.stringify(l))
  }
  function readLookCode(code) {
    var c = String(code || "").trim()
    if (c.indexOf("MR1:") !== 0) return null
    try {
      var l = JSON.parse(fromBase64(c.slice(4)))
      return l && typeof l === "object" ? l : null
    } catch (e) { return null }
  }
  // Paste: add the look to Saved looks and use it.
  function importLook(code) {
    var l = readLookCode(code)
    if (!l) return ""
    var name = String(l.name || "Pasted look").slice(0, 24)
    applyLook(l)
    return saveLook(name)
  }
  property string shareStatus: ""
  function copyLookCode(name) {
    copyProc.command = ["wl-copy", "--", lookCode(name)]
    copyProc.running = true
    root.shareStatus = "Copied a code for this look. Paste it into Matrix Rain anywhere to use it."
  }
  function pasteLookCode() {
    if (!pasteProc.running) pasteProc.running = true
  }
  Process { id: copyProc }
  Process {
    id: pasteProc
    command: ["wl-paste", "--no-newline"]
    stdout: StdioCollector {
      onStreamFinished: {
        var n = root.importLook(String(text).slice(0, 4000))
        root.shareStatus = n ? "Added \u201c" + n + "\u201d from the clipboard." : "The clipboard has no Matrix Rain look code (it starts with MR1:)."
      }
    }
  }

  // --- Typing ripples. tools/typing-keys.py adds pass-through Hyprland binds
  // for the typing keys that only emit custom>>ertiv-matrix-rain:key (never
  // which key); they exist only while Typing is above 0% and the rain runs.
  property var ripples: []           // { x, y (screen fractions), t (s), s (strength) }
  property bool _typingBound: false
  readonly property bool typingWanted: typingAmount > 0 && enabled && _stateLoaded && !shuttingDown
  onTypingWantedChanged: syncTypingKeys()
  function syncTypingKeys(force) {
    if (root.typingWanted === root._typingBound && !force) return
    root._typingBound = root.typingWanted
    typingProc.command = ["python3", root.pluginDir + "/tools/typing-keys.py", root.typingWanted ? "on" : "off"]
    if (!typingProc.running) typingProc.running = true
    else typingRetry.restart()
  }
  Process { id: typingProc }
  Timer { id: typingRetry; interval: 400; onTriggered: root.syncTypingKeys(true) }
  function keyRipple() {
    if (root.typingAmount <= 0 || !root.rendering) return
    var next = root.ripples.slice(-5)
    next.push({ x: 0.05 + Math.random() * 0.9, y: 0.05 + Math.random() * 0.9, t: 0, s: root.typingAmount })
    root.ripples = next
  }
  function ripVec(i) {
    var r = root.ripples[i]
    return r ? Qt.vector4d(r.x, r.y, r.t, r.s) : Qt.vector4d(0, 0, 9, 0)
  }

  function linkBeat() {
    if (root.flashAmount <= 0 || !root.linkPlaying) return
    beatAnim.restart()
  }

  function readLink(line) {
    var m
    try { m = JSON.parse(line) } catch (e) { return }
    if (!m || typeof m !== "object") return
    if (m.t === "beat") root.linkBeat()
    else if (m.t === "state") {
      if (typeof m.playing === "boolean") root.linkPlaying = m.playing
      if (m.bpm !== undefined) root.linkBpm = clamp(m.bpm, 60, 180)
      var l = m.lfo || {}
      if (l.rate !== undefined) root.linkLfoRate = clamp(l.rate, 0.02, 4)
      if (l.depth !== undefined) root.linkLfoDepth = clamp(l.depth, 0, 1)
      if (typeof l.dest === "string") root.linkLfoDest = l.dest
    }
  }

  // Tell Sound Lab (if connected) about a rain event so the music reacts.
  function linkSend(msg) {
    var line = JSON.stringify(msg) + "\n"
    for (var i = 0; i < root.linkClients.length; i++) {
      var c = root.linkClients[i]
      if (c && c.connected) { c.write(line); c.flush() }
    }
  }

  function linkClosed(sock) {
    root.linkClients = root.linkClients.filter(function(c) { return c !== sock })
    if (!root.soundLinked) root.linkPlaying = false
  }

  SocketServer {
    active: !root.shuttingDown
    path: root.linkPath
    handler: Socket {
      id: client
      parser: SplitParser { onRead: line => root.readLink(line) }
      onConnectedChanged: {
        if (connected) root.linkClients = root.linkClients.concat([client])
        else root.linkClosed(client)
      }
    }
  }

  // Omarchy's Do Not Disturb, read from its notification settings file so
  // bursts stay calm while notifications are silenced.
  property bool doNotDisturb: false

  FileView {
    id: dndFile
    path: root.home + "/.local/state/omarchy/notifications.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readDnd(text())
    onLoadFailed: root.doNotDisturb = false
  }

  function readDnd(text) {
    try { root.doNotDisturb = JSON.parse(text).dnd === true } catch (e) { root.doNotDisturb = false }
  }

  function triggerBurst() {
    if (root.burstAmount <= 0 || root.doNotDisturb) return
    burstAnim.restart()
  }

  // One /proc/stat "cpu" line -> load since the previous sample (0..1).
  function readCpu(line) {
    var f = String(line || "").trim().split(/\s+/)
    if (f[0] !== "cpu" || f.length < 5) return
    var n = f.slice(1).map(Number)
    var idle = n[3] + (n[4] || 0)
    var total = n.reduce(function(a, b) { return a + b }, 0)
    if (root._cpuPrev) {
      var dt = total - root._cpuPrev.total, di = idle - root._cpuPrev.idle
      if (dt > 0) root.cpuLoad = clamp(1 - di / dt, 0, 1)
    }
    root._cpuPrev = { total: total, idle: idle }
  }

  function toggleEvent(name) {
    if (root.eventNames.indexOf(name) < 0) return false
    var on = root.eventsOn.slice()
    var i = on.indexOf(name)
    if (i >= 0) on.splice(i, 1); else on.push(name)
    root.eventsOn = on
    // Switched off while it's happening: it stops now.
    if (i >= 0) {
      if (name === "binary") root.swapSet = ""
      else if (root.activeEvent === name) endEvent()
    }
    if (!on.length) { eventTimer.stop(); chainTimer.stop() }
    persist()
    return true
  }

  function scheduleEvent() {
    eventTimer.stop()
    var r = root.eventMinutes[root.eventRate]
    if (!r || root.eventsOn.length === 0) return
    eventTimer.interval = Math.round((r[0] + Math.random() * (r[1] - r[0])) * 60000)
    eventTimer.start()
  }

  // Start an event now: a named one, or a random one of those switched on.
  function startGlyphSwap() {
    var others = root.glyphSetNames.filter(function(n) { return n !== root.glyphSet && n !== root.swapSet && (n !== "custom" || root.customCount > 0) })
    root.swapSet = others[Math.floor(Math.random() * others.length)]
    logEvent("binary", "glyph swap")
    root.swapT = 0
    linkSend({ t: "event", name: "binary", seconds: root.eventSeconds.binary })
    return true
  }

  // A named event starts on request (right-click preview, IPC); a random one
  // (the schedule, chains) only ever comes from the events switched on.
  // The last events and what started them (status IPC), for tracking down
  // an event that happens when it shouldn't.
  property var eventLog: []
  function logEvent(name, how) {
    var l = root.eventLog.slice(-19)
    l.push({ at: Qt.formatTime(new Date(), "HH:mm:ss"), name: name, how: how, on: root.eventsOn.slice() })
    root.eventLog = l
  }
  function startEvent(name, chained) {
    var how = name ? "asked for" : chained ? "chain" : "schedule"
    if (!name && root.eventsOn.length === 0) return false
    // The glyph swap runs alongside whatever else is happening.
    if (name === "binary") return startGlyphSwap()
    if (root.activeEvent !== "") {
      if (!name && !chained && root.eventsOn.indexOf("binary") >= 0 && root.swapSet === "" && Math.random() < 1 / Math.max(1, root.eventsOn.length))
        return startGlyphSwap()
      return false
    }
    if (!chained) root._chainLeft = 3
    name = name || root.eventsOn[Math.floor(Math.random() * root.eventsOn.length)]
    if (name === "binary") {
      // The glyph swap runs on its own clock, so the next event is planned
      // now (a chain carries on as if this link had ended).
      startGlyphSwap()
      if (chained && root._chainLeft > 0 && Math.random() < root.chainChance) { root._chainLeft--; chainTimer.restart() }
      else { root._chainLeft = 0; scheduleEvent() }
      return true
    }
    if (root.eventNames.indexOf(name) < 0) return false
    root._eventStart = root.rainPhase
    root._eventT = 0
    root.activeEvent = name
    logEvent(name, how)
    if (name === "cascade") root.cascadeSeed = Math.random() * 100
    linkSend({ t: "event", name: name, seconds: root.eventSeconds[name] })
    return true
  }

  function startDejaVu() { return startEvent("dejavu") }

  function endEvent() {
    var chained = root._chainLeft > 0 && Math.random() < root.chainChance
    root.activeEvent = ""
    root.cascadeT = 0
    root.rainFade = 1
    root.scrambleBoost = 0
    root.glitchLevel = 0
    root.layerD = []
    root.layerFadeIn = []
    root._settleTo = []
    root.pan = 0
    if (chained) {
      root._chainLeft--
      chainTimer.restart()
    } else {
      root._chainLeft = 0
      scheduleEvent()
    }
  }

  // Events can set off another (Chain events): up to four in a row.
  Timer {
    id: chainTimer
    interval: 350
    onTriggered: if (!root.startEvent("", true)) root.scheduleEvent()
  }

  // Positive remainder, so rewinding clocks stay in 0..rainPeriod.
  function wrapPhase(x) { var p = root.rainPeriod; return ((x % p) + p) % p }

  function slotOf(i) { return root.layerSlots.length === root.layerCount ? root.layerSlots[i] : i }

  // Distance from the camera to layer i: its slot at rest, or where the
  // dive has carried it.
  function layerDist(i) {
    if (root.layerD.length === root.layerCount) return root.layerD[i]
    return 1 + slotOf(i) * root.diveSpacing
  }

  // One step of dive flight: every layer moves `step` closer; one that
  // passes the screen rejoins directly behind the pack's last layer and
  // fades back in there over 0.4 s.
  function flyPack(step, dt) {
    var d = root.layerD.slice()
    var f = root.layerFadeIn.length === d.length ? root.layerFadeIn.slice() : d.map(function() { return 1 })
    for (var i = 0; i < d.length; i++) { d[i] -= step; f[i] = Math.min(1, f[i] + dt / 0.4) }
    for (i = 0; i < d.length; i++) {
      if (d[i] <= 0) {
        var back = -Infinity
        for (var j = 0; j < d.length; j++) if (j !== i) back = Math.max(back, d[j])
        d[i] = back + root.diveSpacing
        f[i] = 0
      }
    }
    root.layerD = d
    root.layerFadeIn = f
  }

  // Opacity of layer i right now: by distance, times any rejoin fade-in.
  function layerAlpha(i) {
    var f = root.layerFadeIn.length === root.layerCount ? root.layerFadeIn[i] : 1
    return distanceAlpha(layerDist(i)) * f
  }

  // Distance of the back slot: 2 with depth layers, 1 (the front) without.
  function backDistance() { return root.layerCount > 2 ? 2 : 1 }

  // A depth layer's normal opacity at distance d.
  function depthOpacity(d) { return clamp(root.depthLevel * (1 + 0.5 * (2 - d)), 0, 0.95) }

  // Opacity at distance d: the main rain's 1 at the front, depth opacity
  // behind, fading only while flying past the camera or waiting at the back.
  function distanceAlpha(d) {
    var n = root.layerCount - 2, s = 1 / Math.max(1, n), back = backDistance()
    var a = d < 1 ? Math.min(1, d / 0.35) : d < 1 + s ? 1 + (depthOpacity(1 + s) - 1) * (d - 1) / s : depthOpacity(d)
    if (d > back) a *= clamp((back + s - d) / s, 0, 1)
    return a
  }

  // Camera zoom at distance d: magnified while passing the camera, and
  // shrinking to depthScale at the back slot (and a little beyond).
  function distanceZoom(d) {
    if (d < 1) return Math.min(20, 1 / Math.max(0.05, d))
    return Math.max(0.2, 1 - (d - 1) * (1 - root.depthScale))
  }

  // How far a layer is into the depth (0 front .. 1 first depth slot and on).
  function depthMix(d) { var s = 1 / Math.max(1, root.layerCount - 2); return clamp((d - 1) / s, 0, 1) }

  // The brightest layer's opacity (for checks: the view never goes dark).
  function brightest() {
    var m = 0
    for (var i = 0; i < root.layerCount; i++) m = Math.max(m, layerAlpha(i))
    return m
  }

  // Sideways slide in pixels for a layer at distance d (nearer moves more).
  // Only the Pan event slides the rain sideways.
  function layerPan(d, width) { return root.pan * width * 0.25 / Math.max(0.3, d) }

  // Advance the rain clocks by dt seconds, applying the event in progress:
  // déjà vu replays dejaVuLoop seconds dejaVuRepeats times, rewind runs the
  // rain backwards, bullet time slows it nearly to a stop, and scramble,
  // blackout and glitch change how the layers draw.
  function advanceRain(dt) {
    if (root.wsT < 1) root.wsT = Math.min(1, root.wsT + dt / 0.9)
    if (root.swapSet !== "") {
      root.swapT += dt
      if (root.swapT >= root.eventSeconds.binary) root.swapSet = ""
    }
    if (root.ripples.length) {
      root.ripples = root.ripples.map(function(r) { return { x: r.x, y: r.y, t: r.t + dt, s: r.s } }).filter(function(r) { return r.t < 1.4 })
    }
    var rate = Math.max(0, root.reactiveSpeed)
    var ev = root.activeEvent
    if (ev !== "") {
      var t = (root._eventT += dt)
      var end = root.eventSeconds[ev]
      if (ev === "dejavu") {
        var loop = root.dejaVuLoop
        if (t >= loop * root.dejaVuRepeats) {
          root.rainPhase = wrapPhase(root._eventStart + loop * rate)
          endEvent()
        } else {
          var into = t % loop
          root.rainPhase = wrapPhase(root._eventStart + into * rate)
        }
        return
      }
      if (ev === "rewind")
        rate *= t < 1.2 ? -0.9 : -0.9 + 1.9 * (t - 1.2) / 0.4
      else if (ev === "bullet")
        rate *= 1 - 0.95 * Math.sin(Math.PI * Math.min(t / end, 1))
      else if (ev === "surge")
        rate *= 1 + 3 * Math.sin(Math.PI * Math.min(t / end, 1))
      else if (ev === "dive") {
        if (root.layerD.length !== root.layerCount) {
          var start = []
          for (var li = 0; li < root.layerCount; li++) start.push(layerDist(li))
          root.layerD = start
        }
        var fl = root.diveFlight
        if (t < fl) {
          // Speed up, cruise, then slow before the pack coasts into place.
          var v = root.diveTopSpeed * Math.min(1, t / 0.6, Math.max(0.3, (fl - t) / 0.7))
          flyPack(v * dt, dt)
        } else if (t < end) {
          if (root._settleTo.length !== root.layerCount) {
            // Settle by moving forward only. Layers still in front of the
            // front slot fly on through the screen and rejoin behind the
            // pack into the back slots; the others drift forward into the
            // front slots in order. Each gets a forward path to its slot.
            var sp = root.diveSpacing
            var order = []
            for (li = 0; li < root.layerCount; li++) order.push(li)
            order.sort(function(a, b) { return root.layerD[a] - root.layerD[b] })
            var passers = order.filter(function(i) { return root.layerD[i] < 1 })
            var keepers = order.filter(function(i) { return root.layerD[i] >= 1 })
            var to = [], len = [], rejoin = [], slots = []
            keepers.forEach(function(i, k) {
              to[i] = 1 + k * sp; slots[i] = k; rejoin[i] = -1
              len[i] = root.layerD[i] - to[i]
            })
            passers.forEach(function(i, k) {
              var slot = keepers.length + k
              to[i] = 1 + slot * sp; slots[i] = slot
              rejoin[i] = to[i] + passers.length * sp   // out of sight behind the back
              len[i] = root.layerD[i] + (rejoin[i] - to[i])
            })
            root._settleFrom = root.layerD.slice()
            root._settleTo = to
            root._settleLen = len
            root._settleRejoin = rejoin
            root.layerSlots = slots
          }
          var su = (t - fl) / (end - fl)
          su = 1 - (1 - su) * (1 - su)   // ease out: the pack coasts to a stop
          var dd = [], fade = root.layerFadeIn.map(function(f) { return Math.min(1, f + dt / 0.4) })
          for (li = 0; li < root.layerCount; li++) {
            var x = root._settleLen[li] * su, from = root._settleFrom[li]
            if (root._settleRejoin[li] < 0 || x < from) {
              dd.push(from - x)
            } else {
              // Passed the screen: rejoin behind and fade back in.
              if (root.layerD[li] < root._settleRejoin[li] - (x - from) - 1e-9) fade[li] = 0
              dd.push(root._settleRejoin[li] - (x - from))
            }
          }
          root.layerD = dd
          root.layerFadeIn = fade
        }
      } else if (ev === "pan")
        root.pan = Math.sin(Math.PI * Math.min(t / end, 1)) * (root._eventStart % 2 < 1 ? 1 : -1)
      else if (ev === "scramble")
        root.scrambleBoost = t < end ? 30 : 0
      else if (ev === "blackout")
        root.rainFade = t < 0.5 ? 1 - t / 0.5 : t < 1.1 ? 0 : Math.min(1, (t - 1.1) / 1.1)
      else if (ev === "drift")
        root.driftPhase += dt * 1.1 * Math.sin(Math.PI * Math.min(t / end, 1))
      else if (ev === "cascade") {
        // Not a steady sweep: it surges and eases along the way.
        var u = Math.min(t / end, 1)
        root.cascadeT = 1.45 * (u + 0.06 * Math.sin(u * 9.0 + root.cascadeSeed))
      } else if (ev === "glitch") {
        root.glitchLevel = t < end && Math.random() < 0.75 ? 1 - 0.6 * t / end : 0
        root.glitchSeed = Math.floor(t * 16)
      }
      if (t >= end) endEvent()
    }
    root.rainPhase = wrapPhase(root.rainPhase + dt * rate)
  }

  NumberAnimation { id: beatAnim; target: root; property: "beatFlash"; from: 1; to: 0; duration: 220; easing.type: Easing.OutQuad }
  NumberAnimation { id: burstAnim; target: root; property: "burstLevel"; from: 1; to: 0; duration: 1800; easing.type: Easing.OutCubic }

  Timer {
    id: eventTimer
    repeat: false
    onTriggered: { if (!root.startEvent("")) root.scheduleEvent() }
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.cpuPull > 0 && root.rendering && !root.shuttingDown
    onTriggered: if (!cpuProc.running) cpuProc.running = true
  }

  Process {
    id: cpuProc
    command: ["head", "-n", "1", "/proc/stat"]
    stdout: StdioCollector { onStreamFinished: root.readCpu(text) }
  }

  // Watches the session bus for notifications being sent (any app); only
  // the fact that one arrived is used, never its content.
  Process {
    id: notifyWatch
    running: root.burstAmount > 0 && root.enabled && root._stateLoaded && !root.shuttingDown
    command: ["dbus-monitor", "--session",
      "type='method_call',interface='org.freedesktop.Notifications',member='Notify'"]
    stdout: SplitParser {
      onRead: line => { if (String(line).indexOf("member=Notify") >= 0) root.triggerBurst() }
    }
  }

  function applyEnabled(on) {
    root.enabled = !!on
    persist()
  }

  function applyPause() { root.manualPaused = true; persist() }
  function applyResume() { root.manualPaused = false; persist() }

  function applyToggle() {
    if (!root.enabled) {
      root.enabled = true
      root.manualPaused = false
    } else if (root.manualPaused) {
      root.manualPaused = false
    } else {
      root.manualPaused = true
    }
    persist()
    return !root.manualPaused && root.enabled
  }

  function applySetPauseOnFullscreen(on) {
    root.pauseOnFullscreen = (on === true || String(on) === "true")
    persist()
  }

  // Everything saved in state.json.
  function statePayload() {
    return JSON.stringify({
      enabled: root.enabled,
      manualPaused: root.manualPaused,
      pauseOnFullscreen: root.pauseOnFullscreen,
      letterSize: root.letterSize,
      speed: root.speed,
      density: root.density,
      rainColor: root.rainColor,
      rainPreset: root.rainPreset,
      weatherVersion: root.weatherVersion,
      depthLevel: root.depthLevel,
      depthScale: root.depthScale,
      depthLayers: root.depthLayers,
      trailScale: root.trailScale,
      glyphFlicker: root.glyphFlicker,
      flashAmount: root.flashAmount,
      burstAmount: root.burstAmount,
      tempoPull: root.tempoPull,
      cpuPull: root.cpuPull,
      eventRate: root.eventRate,
      depthQuality: root.depthQuality,
      eventsOn: root.eventsOn,
      crtAmount: root.crtAmount,
      mirrorAmount: root.mirrorAmount,
      glyphWeight: root.glyphWeight,
      gravity: root.gravity,
      speedVariety: root.speedVariety,
      trailVariety: root.trailVariety,
      headGlow: root.headGlow,
      bloomAmount: root.bloomAmount,
      aberration: root.aberration,
      vignette: root.vignette,
      mouseAmount: root.mouseAmount,
      workspaceRush: root.workspaceRush,
      idleDrift: root.idleDrift,
      chainChance: root.chainChance,
      typingAmount: root.typingAmount,
      collapsedSections: root.collapsedSections,
      glyphSet: root.glyphSet,
      customChars: root.customChars,
      customCount: root.customCount,
      customRows: root.customRows,
      wallpaperColors: root.wallpaperColors,
      rainColorResolved: root.resolvedColor(root.rainColor),
      headColor: root.headColor,
      backHeadColor: root.backHeadColor,
      layerHeadColors: root.layerHeadColors,
      backColor: root.backColor,
      layerColors: root.layerColors,
      themeColor: root.themeColor,
      savedLooks: root.savedLooks,
      workspaceLooks: root.workspaceLooks,
      workspaceBase: root.workspaceBase,
      eventsVersion: root.eventsVersion
    })
  }

  function persist() {
    writeState(statePayload())
  }

  function applyStateText(txt) {
    if (!txt) return
    try {
      var s = JSON.parse(txt)
      if (typeof s.enabled === "boolean") root.enabled = s.enabled
      if (typeof s.manualPaused === "boolean") root.manualPaused = s.manualPaused
      if (typeof s.pauseOnFullscreen === "boolean") root.pauseOnFullscreen = s.pauseOnFullscreen
      if (s.letterSize !== undefined) root.letterSize = clamp(s.letterSize, 4, 100)
      if (s.speed !== undefined) root.speed = clamp(s.speed, 0.02, 1.0)
      if (s.density !== undefined) root.density = clamp(s.density, 0.50, 1.00)
      for (var ak in root.rainAmountRanges)
        if (s[ak] !== undefined) root[ak] = clamp(s[ak], root.rainAmountRanges[ak][0], root.rainAmountRanges[ak][1])
      if (typeof s.eventRate === "string" && (s.eventRate === "off" || root.eventMinutes[s.eventRate])) root.eventRate = s.eventRate
      if (typeof s.depthQuality === "string" && root.depthQualities[s.depthQuality]) root.depthQuality = s.depthQuality
      if (Array.isArray(s.eventsOn)) {
        var on = s.eventsOn.filter(function(e) { return root.eventNames.indexOf(e) >= 0 })
        // Lists saved before Drift and Cascade existed get them switched on.
        if (!(s.eventsVersion >= 2)) ["drift", "cascade"].forEach(function(e) { if (on.indexOf(e) < 0) on.push(e) })
        root.eventsOn = on
      }
      if (typeof s.glyphSet === "string" && root.glyphSets[s.glyphSet]) root.glyphSet = s.glyphSet
      if (typeof s.customChars === "string") root.customChars = s.customChars.slice(0, 200)
      if (typeof s.customCount === "number") root.customCount = Math.max(0, Math.min(48, Math.round(s.customCount)))
      if (typeof s.customRows === "number") root.customRows = Math.max(0, Math.min(3, Math.round(s.customRows)))
      if (Array.isArray(s.collapsedSections)) root.collapsedSections = s.collapsedSections.filter(function(x) { return typeof x === "string" }).slice(0, 20)
      if (Array.isArray(s.wallpaperColors)) root.wallpaperColors = s.wallpaperColors.filter(function(h) { return /^#[0-9a-f]{6}$/.test(h) }).slice(0, 4)
      if (typeof s.headColor === "string" && root.headModes.indexOf(s.headColor) >= 0) root.headColor = s.headColor
      if (typeof s.backHeadColor === "string") root.backHeadColor = root.headModes.indexOf(s.backHeadColor) >= 0 ? s.backHeadColor : ""
      if (Array.isArray(s.layerHeadColors)) root.layerHeadColors = root.cleanHeads(s.layerHeadColors)
      if (s.backColor === "" || (typeof s.backColor === "string" && validRainColor(s.backColor) !== "")) root.backColor = s.backColor === "" ? "" : validRainColor(s.backColor)
      if (Array.isArray(s.layerColors)) root.layerColors = root.cleanLayerColors(s.layerColors)
      if (typeof s.themeColor === "string") { var tc = s.themeColor === "" ? "" : validRainColor(s.themeColor); if (tc !== "theme" && tc !== "daylight") root.themeColor = tc }
      if (Array.isArray(s.savedLooks)) root.savedLooks = s.savedLooks.filter(function(x) { return x && typeof x.name === "string" && x.look && typeof x.look === "object" }).slice(-12)
      if (s.workspaceLooks && typeof s.workspaceLooks === "object") {
        var wl = ({})
        for (var wk in s.workspaceLooks) if (Number(wk) >= 1 && Number(wk) <= root.workspaceCount && typeof s.workspaceLooks[wk] === "string" && s.workspaceLooks[wk].indexOf("look:") === 0) wl[wk] = s.workspaceLooks[wk]
        root.workspaceLooks = wl
      }
      if (s.workspaceBase && typeof s.workspaceBase === "object") root.workspaceBase = s.workspaceBase
      // Déjà vu used to be the only event: its rate carries over.
      if (s.eventRate === undefined && typeof s.dejaVuRate === "string" && root.eventMinutes[s.dejaVuRate] && s.dejaVu !== false) {
        root.eventRate = s.dejaVuRate
        root.eventsOn = ["dejavu"]
      }
      // Switches from before every effect became a 0-100% amount.
      if (s.depthOn === false) root.depthLevel = 0
      if (s.musicReact === false) root.flashAmount = 0
      if (s.followTempo === true && s.tempoPull === undefined) root.tempoPull = 1
      if (s.notifyBurst === false) root.burstAmount = 0
      if (s.cpuReact === true && s.cpuPull === undefined) root.cpuPull = 0.6
      root.scheduleEvent()
      if (typeof s.rainPreset === "string" && root.weatherPresets[s.rainPreset] && !(s.weatherVersion >= root.weatherVersion)) {
        // Presets used to keep your tweaks; now they are fixed, so a saved
        // preset goes back to its real values.
        root.applyRainPreset(s.rainPreset)
      }
      if (typeof s.rainColor === "string" && validRainColor(s.rainColor) !== "") root.rainColor = validRainColor(s.rainColor)
    } catch (e) {
      // Keep the unreadable file: the next write backs it up first.
      root._stateCorrupt = true
      console.warn("ertiv.matrix-rain: bad state.json; it will be kept as state.json.bad")
    }
  }

  function statusObject() {
    return {
      enabled: root.enabled,
      paused: root.manualPaused,
      rendering: root.rendering,
      letterSize: root.letterSize,
      speed: root.speed,
      density: root.density,
      rainColor: root.rainColor,
      rainPreset: root.rainPreset,
      weatherVersion: root.weatherVersion,
      depthLevel: root.depthLevel,
      depthScale: root.depthScale,
      depthLayers: root.depthLayers,
      trailScale: root.trailScale,
      glyphFlicker: root.glyphFlicker,
      flashAmount: root.flashAmount,
      burstAmount: root.burstAmount,
      tempoPull: root.tempoPull,
      cpuPull: root.cpuPull,
      eventRate: root.eventRate,
      depthQuality: root.depthQuality,
      eventsOn: root.eventsOn,
      crtAmount: root.crtAmount,
      themeStatus: root.themeStatus,
      soundLinked: root.soundLinked,
      activeEvent: root.activeEvent,
      pan: root.pan,
      eventLog: root.eventLog,
      soundPlaying: root.linkPlaying,
      soundBpm: root.linkBpm,
      pauseOnFullscreen: root.pauseOnFullscreen
    }
  }

  FrameAnimation {
    running: root.rendering
    onTriggered: {
      root.time += frameTime
      // Integrate fall velocity so LFO / slider changes only speed up
      // or slow down the rain. Multiplying wall-clock time by the current
      // speed rewinds heads whenever the LFO dips (rain appears to fall up).
      root.advanceRain(frameTime)
    }
  }

  property string _pendingState: ""

  function writeState(payload) {
    if (root.shuttingDown) return
    if (stateWriteProc.running) { root._pendingState = payload; return }
    var backup = root._stateCorrupt
    root._stateCorrupt = false
    stateWriteProc.command = root.timeoutPrefix.concat(["bash", "-c",
      'd=$(dirname -- "$1"); mkdir -p -- "$d" || exit 1; ' +
      '[ "$3" = 1 ] && [ -f "$1" ] && cp -f -- "$1" "$1.bad"; ' +
      't=$(mktemp -- "$1.XXXXXX") || exit 1; ' +
      'printf %s "$2" > "$t" && mv -f -- "$t" "$1" || { rm -f -- "$t"; exit 1; }',
      "_", root.statePath, payload, backup ? "1" : "0"])
    stateWriteProc.running = true
  }

  Process {
    id: stateWriteProc
    onExited: if (root._pendingState !== "") {
      var q = root._pendingState
      root._pendingState = ""
      root.writeState(q)
    }
  }

  Process {
    id: mkStateDir
    command: root.timeoutPrefix.concat(["mkdir", "-p", root.stateDir])
    onExited: stateReadProc.running = true
  }

  Process {
    id: stateReadProc
    command: root.timeoutPrefix.concat(["bash", "-c",
      '[ -f "$1" ] && head -c 65536 "$1" || true', "_", root.statePath])
    stdout: StdioCollector {
      onStreamFinished: {
        if (root._stateLoaded) return
        root.applyStateText(text)
        root._stateLoaded = true
      }
    }
    onExited: {
      if (!root._stateLoaded) root._stateLoaded = true
      themeCheckProc.running = true
      var mon = Hyprland.focusedMonitor
      if (mon && mon.activeWorkspace) root.workspaceSwitched(mon.activeWorkspace.id)
    }
  }

  Component.onCompleted: mkStateDir.running = true
  Component.onDestruction: {
    root.shuttingDown = true
    // Take the typing binds away with the plugin (detached: this object goes).
    if (root._typingBound) Quickshell.execDetached(["python3", root.pluginDir + "/tools/typing-keys.py", "off"])
  }

  // Quickshell tracks hasFullscreen from Hyprland events; refreshing the
  // workspace list (one in-process IPC request) covers closes and moves.
  Timer {
    id: fsDebounce
    interval: 120
    repeat: false
    onTriggered: Hyprland.refreshWorkspaces()
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "workspacev2") root.workspaceSwitched(parseInt(String(event.data).split(",")[0]))
      else if (event.name === "custom" && String(event.data) === "ertiv-matrix-rain:key") root.keyRipple()
      // A config reload drops runtime binds: add the typing binds again.
      else if (event.name === "configreloaded" && root._typingBound) root.syncTypingKeys(true)
      switch (event.name) {
        case "fullscreen":
        case "openwindow":
        case "closewindow":
        case "movewindow":
        case "movewindowv2":
          fsDebounce.restart()
          break
      }
    }
  }

  component RainAt: RainLayer {
    required property int index
    // true: only drawn while near the front (full resolution); false: only
    // while farther back, inside the reduced-resolution depth buffer.
    property bool nearCopy: true
    property bool active: true      // the window's shouldRun
    property vector4d mouseVec: Qt.vector4d(0, 0, 0, 1)
    readonly property real dist: root.layerDist(index)
    readonly property real deep: root.depthMix(dist)
    anchors.fill: parent
    z: 10 - dist
    showBackground: false
    readonly property bool nearFront: dist <= 1.15 || root.depthResolution >= 1
    visible: opacity > 0.002 && nearCopy === nearFront
    seed: index === 0 ? 0 : 37 + 29 * index
    time: root.rainPhase
    letterSize: root.rainSize
    speed: 1.0
    density: root.reactiveDensity * (1 - 0.1 * deep)
    flash: root.rainFlash * (1 - 0.5 * deep)
    trailScale: root.trailScale
    glyphFlicker: root.glyphFlicker + root.scrambleBoost
    readonly property var pal: root.layerPaletteAt(dist)
    headColor: pal.head
    bodyColor: pal.body
    tailColor: pal.tail
    colorMode: pal.mode
    colorA: pal.colorA
    colorB: pal.colorB
    colorC: pal.colorC
    colorD: pal.colorD
    colorVariation: pal.variation || 0
    readonly property string heads: root.headModeFor(dist)
    headMode: Math.max(0, root.headModes.indexOf(heads))
    headFixed: heads === "accent" ? Color.accent : "#ffffff"
    glyphSet: root.glyphRange
    customSource: root.customShown ? "file://" + root.customAtlasPath + "?v=" + root.customRev : ""
    customRows: root.customShown ? root.customRows : 0
    mirror: root.mirrorAmount
    weight: root.glyphWeight
    gravity: root.gravity
    speedVariety: root.speedVariety
    trailVariety: root.trailVariety
    drift: root.driftPhase
    headGlow: root.headGlow
    bloom: root.bloomAmount
    aberration: root.aberration
    vignette: root.vignette
    cascade: Qt.vector2d(root.cascadeT, root.cascadeSeed)
    mouse: mouseVec
    // Ripples only on the layer resting at the front.
    readonly property bool front: root.slotOf(index) === 0
    rip0: front ? root.ripVec(0) : Qt.vector4d(0, 0, 9, 0)
    rip1: front ? root.ripVec(1) : Qt.vector4d(0, 0, 9, 0)
    rip2: front ? root.ripVec(2) : Qt.vector4d(0, 0, 9, 0)
    rip3: front ? root.ripVec(3) : Qt.vector4d(0, 0, 9, 0)
    rip4: front ? root.ripVec(4) : Qt.vector4d(0, 0, 9, 0)
    rip5: front ? root.ripVec(5) : Qt.vector4d(0, 0, 9, 0)
    zoom: root.distanceZoom(dist)
    panX: root.layerPan(dist, width)
    crt: root.crtAmount
    glitch: root.glitchLevel
    glitchSeed: root.glitchSeed
    opacity: root.layerAlpha(index) * root.rainFade * (1 - 0.55 * root.idleLevel) * root.wsFade
    running: active && visible
  }

  Variants {
    model: root.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: root.enabled
      color: "#000000"
      anchors { top: true; bottom: true; left: true; right: true }
      updatesEnabled: shouldRun

      WlrLayershell.namespace: "ertiv-matrix-rain"
      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      readonly property string monName: String(modelData.name)
      readonly property bool monFullscreen: root.pauseOnFullscreen
                                            && (root.fullscreenMonitors[monName] === true)
      readonly property bool shouldRun: root.screenCanAnimate(monName)

      // The cursor over the desktop parts the rain (clicks pass through
      // untouched). The parting eases in and out as it arrives and leaves.
      property real mouseStrength: hover.containsMouse ? root.mouseAmount : 0
      Behavior on mouseStrength { NumberAnimation { duration: 450; easing.type: Easing.InOutQuad } }
      readonly property vector4d mouseVec: Qt.vector4d(hover.mouseX, hover.mouseY, mouseStrength,
                                                       Math.max(60, root.rainSize * 7))
      MouseArea {
        id: hover
        anchors.fill: parent
        z: 5
        hoverEnabled: root.mouseAmount > 0
        acceptedButtons: Qt.NoButton
      }

      // Every rain layer, main and depth, on the slot conveyor (see
      // layerDist). Layers near the front draw at full resolution; the ones
      // farther back draw together into one reduced-resolution buffer
      // (depth quality) that is scaled up once: each layer is a full-screen
      // pass, and distant ones are small and dim (a touch of depth of
      // field). Nearer layers draw on top; hidden ones are skipped.
      Item {
        anchors.fill: parent
        z: 0
        layer.enabled: root.depthResolution < 1 && root.layerCount > 2
        layer.smooth: true
        layer.textureSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio * root.depthResolution),
                                   Math.ceil(height * Screen.devicePixelRatio * root.depthResolution))
        Repeater {
          model: root.layerCount
          RainAt { nearCopy: false; active: panel.shouldRun; mouseVec: panel.mouseVec }
        }
      }
      Item {
        anchors.fill: parent
        z: 1
        Repeater {
          model: root.layerCount
          RainAt { nearCopy: true; active: panel.shouldRun; mouseVec: panel.mouseVec }
        }
      }
    }
  }

  IpcHandler {
    target: "matrix-rain"

    function status(): string { return JSON.stringify(root.statusObject()) }
    function toggle(): string { return root.applyToggle() ? "on" : "off" }
    function pause(): string { root.applyPause(); return "paused" }
    function resume(): string { root.applyResume(); return "playing" }
    function enable(): string { root.applyEnabled(true); return "enabled" }
    function disable(): string { root.applyEnabled(false); return "disabled" }
    function setLetterSize(v: string): string { root.applyLetterSize(v); return String(root.letterSize) }
    function setSpeed(v: string): string { root.applySpeed(v); return String(root.speed) }
    function setDensity(v: string): string { root.applyDensity(v); return String(root.density) }
    function setWeather(name: string): string { return root.applyRainPreset(name) ? root.rainPreset : "invalid: use drizzle, classic, storm or terminal" }
    function dejaVuNow(): string { root.startEvent("dejavu"); return "ok" }
    function eventNow(name: string): string { return root.startEvent(name === "random" ? "" : name) ? root.activeEvent : "busy or unknown (dejavu, rewind, bullet, surge, scramble, binary, blackout, glitch, dive, pan, random)" }
    function notifyTest(): string { burstAnim.restart(); return "ok" }
    function rippleTest(): string { root.keyRipple(); return "ok" }
    function setCustom(symbols: string): string { return root.setCustomGlyphs(symbols) ? "checking" : "busy" }
    function setColor(v: string): string { return root.applyRainColor(v) ? root.rainColor : "invalid: use green, theme, amber, cyan, red, violet or #rrggbb" }
    function ping(): string { return "ok" }
  }
}
