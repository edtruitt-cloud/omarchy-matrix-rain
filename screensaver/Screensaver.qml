import QtQuick
import QtQuick.Window
import "../atlas.js" as Atlas
import "../rainpalette.js" as Palette

Window {
  id: win

  title: "screensaver"
  color: win.rainPalette.background
  visibility: windowed ? Window.Windowed : Window.FullScreen
  flags: windowed ? Qt.Window : (Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint)
  visible: true
  width: windowed ? 1600 : 1920
  height: windowed ? 900 : 1080
  x: windowed ? 80 : 0
  y: windowed ? 80 : 0

  property real time: 0

  // Matrix Rain wallpaper settings, read by wrapper.cpp at launch (rainState,
  // themeAccent context properties). Defaults reproduce the original look.
  readonly property var rain: typeof rainState === "object" && rainState ? rainState : ({})
  function setting(key, fallback, lo, hi) {
    var n = Number(win.rain[key])
    return isFinite(n) && win.rain[key] !== undefined ? Math.max(lo, Math.min(hi, n)) : fallback
  }
  // Fall speed 0.15 (wallpaper default) walks at the original 1.85.
  readonly property real walkSpeed: Math.max(0.5, Math.min(4.0, 1.85 * Math.sqrt(setting("speed", 0.15, 0.02, 1.0) / 0.15)))
  // Density 0.75 (default) gives the original 0.90 of columns.
  readonly property real density: Math.min(0.98, setting("density", 0.75, 0.5, 1.0) * 1.2)
  readonly property real cellScale: setting("letterSize", 16, 4, 28) / 16
  readonly property real trailScale: setting("trailScale", 1, 0.5, 2)
  readonly property real glyphFlicker: setting("glyphFlicker", 1, 0, 2)
  readonly property real crt: setting("crtAmount", 0, 0, 1)
  // Glyph shape, motion and light (wallpaper LOOK; 0 = off, varieties 1 = original).
  readonly property real mirror: setting("mirrorAmount", 0, 0, 1)
  readonly property real weight: setting("glyphWeight", 0, 0, 1)
  readonly property real gravity: setting("gravity", 0, 0, 1)
  readonly property real speedVariety: setting("speedVariety", 1, 0, 2)
  readonly property real trailVariety: setting("trailVariety", 1, 0, 3)
  readonly property real headGlow: setting("headGlow", 0, 0, 1)
  readonly property real bloom: setting("bloomAmount", 0, 0, 1)
  readonly property real aberration: setting("aberration", 0, 0, 1)
  readonly property real vignette: setting("vignette", 0, 0, 1)
  readonly property real chainChance: setting("chainChance", 0, 0, 1)
  // Glyph sets: the same ranges as the wallpaper (Service.qml glyphSets).
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
    alchemy: Atlas.blocks.alchemy
    // (Custom symbols are wallpaper-only: the screensaver shows the rain's own.)
  })
  readonly property vector4d glyphRange: {
    var r = win.glyphSets[win.swapSet || win.rain.glyphSet] || win.glyphSets.matrix
    return Qt.vector4d(r[0][0], r[0][1], r.length > 1 ? r[1][0] : 0, r.length > 1 ? r[1][1] : 0)
  }
  readonly property var headModes: ["look", "white", "body", "accent"]
  readonly property int headMode: Math.max(0, headModes.indexOf(win.rain.headColor))
  readonly property color accentColor: typeof themeAccent === "string" ? Qt.color(themeAccent) : Qt.color("#3CBF5C")
  readonly property color headFixed: win.rain.headColor === "accent" ? win.accentColor : "#ffffff"

  // --- Events, as on the wallpaper: the lit ones happen now and then at the
  // chosen rate, scaled to a screensaver's shorter sessions. Dive becomes a
  // rush forward through the rain and Pan a sideways drift.
  readonly property var eventNames: ["dejavu", "rewind", "bullet", "surge", "scramble", "binary", "blackout", "glitch", "dive", "pan", "drift", "cascade"]
  // A list from state.json, as a plain array of strings. The wrapper hands
  // lists over as Qt sequences, which Array.isArray() does not accept.
  function listOf(v) {
    var out = []
    if (v && typeof v !== "string" && v.length !== undefined)
      for (var i = 0; i < v.length; i++) out.push(v[i] ? String(v[i]) : "")
    return out
  }
  readonly property var eventsOn: {
    var on = win.listOf(win.rain.eventsOn).filter(function(e) { return eventNames.indexOf(e) >= 0 })
    // Lists saved before Drift and Cascade existed have them on (as the wallpaper does).
    if (!(win.rain.eventsVersion >= 2)) ["drift", "cascade"].forEach(function(e) { if (on.indexOf(e) < 0) on.push(e) })
    return on
  }
  readonly property var eventSeconds: ({ rare: [60, 150], sometimes: [20, 45], often: [8, 18] })
  readonly property var eventLength: ({ dejavu: 1.2, rewind: 1.6, bullet: 3.0, surge: 1.6, scramble: 0.7, binary: 3.0, blackout: 2.2, glitch: 0.9, dive: 3.0, pan: 4.0, drift: 3.2, cascade: 3.4 })
  property string activeEvent: ""
  property real eventT: 0
  property real eventStart: 0
  property real speedFactor: 1
  property real scrambleBoost: 0
  property real fade: 1
  property real glitchLevel: 0
  property real glitchSeed: 0
  // Glyph swap (Binary): another glyph set for 10 s, alongside other events.
  property string swapSet: ""
  property real swapT: 0
  property real panAmount: 0
  property real driftPhase: 0
  property real cascadeT: 0
  property real cascadeSeed: 0
  property int chainLeft: 0

  function scheduleEvent() {
    var r = win.eventSeconds[win.rain.eventRate]
    if (!r || win.eventsOn.length === 0) return
    eventTimer.interval = Math.round((r[0] + Math.random() * (r[1] - r[0])) * 1000)
    eventTimer.start()
  }

  function startGlyphSwap() {
    var own = typeof win.rain.glyphSet === "string" ? win.rain.glyphSet : "matrix"
    var others = Object.keys(win.glyphSets).filter(function(n) { return n !== own && n !== win.swapSet })
    win.swapSet = others[Math.floor(Math.random() * others.length)]
    win.swapT = 0
    return true
  }

  function startEvent(name, chained) {
    if (name === "binary") return startGlyphSwap()
    if (win.activeEvent !== "") return false
    if (!name) {
      if (win.eventsOn.length === 0) return false
      name = win.eventsOn[Math.floor(Math.random() * win.eventsOn.length)]
      // The glyph swap runs on its own clock: plan the next event now.
      if (name === "binary") { startGlyphSwap(); win.chainLeft = 0; scheduleEvent(); return true }
    }
    if (win.eventLength[name] === undefined) return false
    if (!chained) win.chainLeft = 3
    win.activeEvent = name
    win.eventT = 0
    win.eventStart = win.time
    if (name === "cascade") win.cascadeSeed = Math.random() * 100
    return true
  }

  // Advance the clock by dt, applying the event in progress.
  function advance(dt) {
    if (win.swapSet !== "") {
      win.swapT += dt
      if (win.swapT >= 10) win.swapSet = ""
    }
    var ev = win.activeEvent
    var rate = 1
    if (ev !== "") {
      var t = (win.eventT += dt), end = win.eventLength[ev], u = Math.min(t / end, 1)
      if (ev === "dejavu") {
        if (t >= end) { win.time = win.eventStart + 0.4; finishEvent(); return }
        win.time = win.eventStart + (t % 0.4)
        return
      }
      if (ev === "rewind") rate = t < 1.2 ? -0.9 : -0.9 + 1.9 * (t - 1.2) / 0.4
      else if (ev === "bullet") rate = 1 - 0.95 * Math.sin(Math.PI * u)
      else if (ev === "surge" || ev === "dive") rate = 1 + (ev === "dive" ? 4 : 3) * Math.sin(Math.PI * u)
      else if (ev === "scramble") win.scrambleBoost = t < end ? 30 : 0
      else if (ev === "blackout") win.fade = t < 0.5 ? 1 - t / 0.5 : t < 1.1 ? 0 : Math.min(1, (t - 1.1) / 1.1)
      else if (ev === "glitch") { win.glitchLevel = t < end && Math.random() < 0.75 ? 1 - 0.6 * u : 0; win.glitchSeed = Math.floor(t * 16) }
      else if (ev === "pan") win.panAmount = Math.sin(Math.PI * u) * 0.6
      else if (ev === "drift") win.driftPhase += dt * 1.1 * Math.sin(Math.PI * u)
      else if (ev === "cascade") win.cascadeT = 1.45 * (u + 0.06 * Math.sin(u * 9.0 + win.cascadeSeed))
      if (t >= end) finishEvent()
    }
    win.time += dt * rate
  }

  function finishEvent() {
    var chained = win.chainLeft > 0 && Math.random() < win.chainChance
    win.activeEvent = ""
    win.cascadeT = 0
    win.scrambleBoost = 0
    win.fade = 1
    win.glitchLevel = 0
    win.panAmount = 0
    if (chained) {
      // Chain events: one sets off another, up to four in a row.
      win.chainLeft--
      chainTimer.restart()
    } else {
      win.chainLeft = 0
      scheduleEvent()
    }
  }

  Timer {
    id: chainTimer
    interval: 350
    onTriggered: if (!win.startEvent("", true)) win.scheduleEvent()
  }

  Timer {
    id: eventTimer
    repeat: false
    onTriggered: { if (!win.startEvent("")) win.scheduleEvent() }
  }
  // Daylight and Wallpaper change over time or come from an image, so the
  // plugin also saves the colours they stood for (rainColorResolved).
  readonly property string colorSpec: {
    var c = typeof win.rain.rainColor === "string" ? win.rain.rainColor : "green"
    if (c === "daylight") { var d = new Date(); return Palette.daylight(d.getHours() + d.getMinutes() / 60) }
    if (c === "wallpaper" && typeof win.rain.rainColorResolved === "string") return win.rain.rainColorResolved
    return win.resolveSpec(c)
  }
  function resolveSpec(c) {
    if (c === "daylight") { var d = new Date(); return Palette.daylight(d.getHours() + d.getMinutes() / 60) }
    if (c === "wallpaper") { var w = win.listOf(win.rain.wallpaperColors); return w.length ? w.join(",") : "#cdd6e8" }
    return c
  }
  function paletteFor(spec) {
    if (spec === "green")
      return {
        head: Qt.rgba(0.93, 1.00, 0.93, 1), body: Qt.rgba(0.00, 1.00, 0.28, 1), tail: Qt.rgba(0.00, 0.28, 0.00, 1),
        haze: Qt.rgba(0.0, 0.20, 0.05, 1), background: Qt.rgba(0.012, 0.065, 0.018, 1),
        mode: 0, variation: 0, colorA: Qt.rgba(0, 1, 0.28, 1), colorB: Qt.rgba(0, 1, 0.28, 1),
        colorC: Qt.rgba(0, 1, 0.28, 1), colorD: Qt.rgba(0, 1, 0.28, 1)
      }
    return Palette.full(Palette.canonical(spec), win.accentColor)
  }
  // Depth layer colours, as on the wallpaper: layer k uses layerColors[k-1],
  // else the depth layers' colour (backColor), else the rain's. slotPalettes[k]
  // is layer k's look (0 = the rain); layerSlots is how many are in use.
  readonly property var layerSpecs: win.listOf(win.rain.layerColors).slice(0, 5)
  readonly property string backSpec: typeof win.rain.backColor === "string" && win.rain.backColor !== "" ? win.rain.backColor : ""
  readonly property bool layersColoured: backSpec !== "" || layerSpecs.some(function(c) { return typeof c === "string" && c !== "" })
  readonly property int layerSlots: {
    if (!layersColoured) return 0
    var n = Math.round(Number(win.rain.depthLayers) || 1)
    var depthOn = win.rain.depthLevel === undefined || Number(win.rain.depthLevel) > 0.001
    return depthOn ? Math.max(1, Math.min(5, n)) : (backSpec !== "" ? 1 : 0)
  }
  readonly property var slotPalettes: {
    var list = [rainPalette]
    for (var k = 1; k <= 5; k++) {
      var spec = (typeof layerSpecs[k - 1] === "string" && layerSpecs[k - 1]) || backSpec
      list.push(spec ? paletteFor(win.resolveSpec(spec)) : rainPalette)
    }
    return list
  }
  readonly property var rainPalette: paletteFor(win.colorSpec)
  property bool armed: false
  readonly property var appArgs: Qt.application.arguments
  readonly property bool windowed: {
    var args = win.appArgs
    for (var i = 0; i < args.length; i++)
      if (args[i] === "--windowed")
        return true
    return false
  }
  readonly property int previewSeconds: {
    var args = win.appArgs
    for (var i = 0; i < args.length; i++) {
      if (args[i] === "--preview") {
        var n = (i + 1 < args.length) ? Number(args[i + 1]) : 8
        if (!(n > 0)) n = 8
        return Math.floor(n)
      }
    }
    return 0
  }

  function dismiss() {
    if (!win.armed)
      return
    Qt.quit()
  }

  Component.onCompleted: {
    win.requestActivate()
    keySink.forceActiveFocus()
    armTimer.start()
    if (win.previewSeconds > 0)
      previewTimer.start()
    win.scheduleEvent()
    // `--event NAME` starts that event right away (for trying events).
    var args = win.appArgs
    for (var i = 0; i + 1 < args.length; i++)
      if (args[i] === "--event") win.startEvent(args[i + 1])
  }

  onActiveChanged: if (active) keySink.forceActiveFocus()

  FrameAnimation {
    running: win.visible
    onTriggered: win.advance(frameTime)
  }

  Timer {
    id: armTimer
    interval: 2500
    repeat: false
    onTriggered: win.armed = true
  }

  Timer {
    id: previewTimer
    interval: Math.max(1, win.previewSeconds) * 1000
    repeat: false
    onTriggered: Qt.quit()
  }

  Image {
    id: atlasImg
    source: Qt.resolvedUrl("../atlas.png")
    visible: false
    mipmap: true
    smooth: true
  }

  Rectangle {
    anchors.fill: parent
    color: win.rainPalette.background
    z: -1
  }

  ShaderEffect {
    id: fx
    anchors.fill: parent
    visible: atlasImg.status === Image.Ready
    blending: false
    supportsAtlasTextures: false

    property real time: win.time
    property real iWidth: Math.max(width, 2)
    property real iHeight: Math.max(height, 2)
    property real walkSpeed: win.walkSpeed
    property real density: win.density
    property real atlasCols: Atlas.cols
    property real atlasRows: Atlas.rows
    property vector4d glyphSet: win.glyphRange
    property real cellScale: win.cellScale
    property color headColor: win.rainPalette.head
    property color bodyColor: win.rainPalette.body
    property color tailColor: win.rainPalette.tail
    property color hazeColor: win.rainPalette.haze
    property color bgColor: win.rainPalette.background
    property real trailScale: win.trailScale
    property real glyphFlicker: win.glyphFlicker + win.scrambleBoost
    property real crt: win.crt
    property real colorMode: win.rainPalette.mode || 0
    property color colorA: win.rainPalette.colorA
    property color colorB: win.rainPalette.colorB
    property color colorC: win.rainPalette.colorC
    property color colorD: win.rainPalette.colorD
    property real colorVariation: win.rainPalette.variation || 0
    property real glitch: win.glitchLevel
    property real glitchSeed: win.glitchSeed
    property real panX: win.panAmount
    property real mirror: win.mirror
    property real weight: win.weight
    property real gravity: win.gravity
    property real speedVariety: win.speedVariety
    property real trailVariety: win.trailVariety
    property real drift: win.driftPhase
    property real headGlow: win.headGlow
    property real bloom: win.bloom
    property real aberration: win.aberration
    property real vignette: win.vignette
    property real headMode: win.headMode
    property color headFixed: win.headFixed
    property real layerSlots: win.layerSlots
    property vector4d l1Info: Qt.vector4d(win.slotPalettes[1].mode || 0, win.slotPalettes[1].variation || 0, 0, 0)
    property color l1Head: win.slotPalettes[1].head
    property color l1Body: win.slotPalettes[1].body
    property color l1Tail: win.slotPalettes[1].tail
    property color l1A: win.slotPalettes[1].colorA
    property color l1B: win.slotPalettes[1].colorB
    property color l1C: win.slotPalettes[1].colorC
    property color l1D: win.slotPalettes[1].colorD
    property vector4d l2Info: Qt.vector4d(win.slotPalettes[2].mode || 0, win.slotPalettes[2].variation || 0, 0, 0)
    property color l2Head: win.slotPalettes[2].head
    property color l2Body: win.slotPalettes[2].body
    property color l2Tail: win.slotPalettes[2].tail
    property color l2A: win.slotPalettes[2].colorA
    property color l2B: win.slotPalettes[2].colorB
    property color l2C: win.slotPalettes[2].colorC
    property color l2D: win.slotPalettes[2].colorD
    property vector4d l3Info: Qt.vector4d(win.slotPalettes[3].mode || 0, win.slotPalettes[3].variation || 0, 0, 0)
    property color l3Head: win.slotPalettes[3].head
    property color l3Body: win.slotPalettes[3].body
    property color l3Tail: win.slotPalettes[3].tail
    property color l3A: win.slotPalettes[3].colorA
    property color l3B: win.slotPalettes[3].colorB
    property color l3C: win.slotPalettes[3].colorC
    property color l3D: win.slotPalettes[3].colorD
    property vector4d l4Info: Qt.vector4d(win.slotPalettes[4].mode || 0, win.slotPalettes[4].variation || 0, 0, 0)
    property color l4Head: win.slotPalettes[4].head
    property color l4Body: win.slotPalettes[4].body
    property color l4Tail: win.slotPalettes[4].tail
    property color l4A: win.slotPalettes[4].colorA
    property color l4B: win.slotPalettes[4].colorB
    property color l4C: win.slotPalettes[4].colorC
    property color l4D: win.slotPalettes[4].colorD
    property vector4d l5Info: Qt.vector4d(win.slotPalettes[5].mode || 0, win.slotPalettes[5].variation || 0, 0, 0)
    property color l5Head: win.slotPalettes[5].head
    property color l5Body: win.slotPalettes[5].body
    property color l5Tail: win.slotPalettes[5].tail
    property color l5A: win.slotPalettes[5].colorA
    property color l5B: win.slotPalettes[5].colorB
    property color l5C: win.slotPalettes[5].colorC
    property color l5D: win.slotPalettes[5].colorD
    property vector2d cascade: Qt.vector2d(win.cascadeT, win.cascadeSeed)
    opacity: win.fade
    property var atlas: atlasImg

    fragmentShader: Qt.resolvedUrl("shaders/rain3d.frag.qsb")
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.AllButtons
    cursorShape: Qt.BlankCursor
    onClicked: win.dismiss()
    onDoubleClicked: win.dismiss()
    onWheel: win.dismiss()
    onPositionChanged: win.dismiss()
    onPressed: win.dismiss()
  }

  Shortcut {
    sequences: ["Esc", "Space", "Return", "Enter", "Tab", "Backspace"]
    onActivated: win.dismiss()
    context: Qt.ApplicationShortcut
  }

  Item {
    id: keySink
    anchors.fill: parent
    focus: true
    Keys.onPressed: function (event) {
      event.accepted = true
      win.dismiss()
    }
  }
}
