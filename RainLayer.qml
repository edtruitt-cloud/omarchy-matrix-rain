import QtQuick
import "atlas.js" as Atlas

// Per-monitor rain surface. Fills the background PanelWindow at the
// compositor's native pixel size (3840x2160 today; follows the output if
// the iMac is later switched to 5K).
Item {
  id: layer

  property real time: 0
  property real letterSize: 16
  property real speed: 0.15
  property real density: 0.75
  property bool running: true
  property color headColor: Qt.rgba(0.91, 1.00, 0.91, 1)
  property color bodyColor: Qt.rgba(0.00, 1.00, 0.255, 1)
  property color tailColor: Qt.rgba(0.00, 0.32, 0.03, 1)
  property real seed: 0
  property real flash: 0
  property real trailScale: 1
  property real glyphFlicker: 1
  // Multi-colour looks (rainpalette.js full()): mode 0 = single colour.
  property real colorMode: 0
  property color colorA: bodyColor
  property color colorB: bodyColor
  property color colorC: bodyColor
  property color colorD: bodyColor
  property real colorVariation: 0
  property real crt: 0
  // Camera events (Service.qml): zoom about the centre, sideways slide.
  property real zoom: 1
  property real panX: 0
  property real binary: 0
  property real glitch: 0
  property real glitchSeed: 0
  // Glyph set: (start, count, start2, count2) in the atlas; default = the
  // rain's own glyphs.
  property vector4d glyphSet: Qt.vector4d(0, Atlas.rainCount, 0, 0)
  property real mirror: 0
  property real weight: 0
  property real gravity: 0
  property real speedVariety: 1
  property real trailVariety: 1
  property real drift: 0
  property real headGlow: 0
  property real bloom: 0
  property real aberration: 0
  property real vignette: 0
  // Cursor (x, y) in this layer's pixels, strength, radius.
  property vector4d mouse: Qt.vector4d(0, 0, 0, 1)
  property vector2d cascade: Qt.vector2d(0, 0)
  property real headMode: 0
  // Custom glyph set: your own symbols (tools/custom-glyphs.py), rows of 16.
  property url customSource: ""
  property real customRows: 0
  property vector4d rip0: Qt.vector4d(0, 0, 9, 0)
  property vector4d rip1: Qt.vector4d(0, 0, 9, 0)
  property vector4d rip2: Qt.vector4d(0, 0, 9, 0)
  property vector4d rip3: Qt.vector4d(0, 0, 9, 0)
  property vector4d rip4: Qt.vector4d(0, 0, 9, 0)
  property vector4d rip5: Qt.vector4d(0, 0, 9, 0)
  property color headFixed: "#ffffff"
  // Off for layers drawn over another layer (the window is black anyway).
  property bool showBackground: true

  Image {
    id: customImg
    source: layer.customSource
    visible: false
    mipmap: true
    smooth: true
    cache: false
  }

  Image {
    id: atlasImg
    source: Qt.resolvedUrl("atlas.png")
    visible: false
    mipmap: true
    smooth: true
  }

  ShaderEffect {
    id: fx
    objectName: "rainShader"
    anchors.fill: parent
    visible: atlasImg.status === Image.Ready
    blending: true
    supportsAtlasTextures: false

    property real time: 0
    property real cellSize: 16
    property real speed: 1
    property real density: 0.75
    property real iWidth: width
    property real iHeight: height
    property real atlasCols: Atlas.cols
    property real atlasRows: Atlas.rows
    property vector4d glyphSet: layer.glyphSet
    property var atlas: atlasImg
    property color headColor: layer.headColor
    property color bodyColor: layer.bodyColor
    property color tailColor: layer.tailColor
    property real seed: layer.seed
    property real flash: 0
    property real trailScale: layer.trailScale
    property real glyphFlicker: layer.glyphFlicker
    property real colorMode: layer.colorMode
    property color colorA: layer.colorA
    property color colorB: layer.colorB
    property color colorC: layer.colorC
    property color colorD: layer.colorD
    property real colorVariation: layer.colorVariation
    property real crt: layer.crt
    property real zoom: layer.zoom
    property real panX: layer.panX
    property real binary: layer.binary
    property real glitch: layer.glitch
    property real glitchSeed: layer.glitchSeed
    property real mirror: layer.mirror
    property real weight: layer.weight
    property real gravity: layer.gravity
    property real speedVariety: layer.speedVariety
    property real trailVariety: layer.trailVariety
    property real drift: layer.drift
    property real headGlow: layer.headGlow
    property real bloom: layer.bloom
    property real aberration: layer.aberration
    property real vignette: layer.vignette
    property vector4d mouse: layer.mouse
    property vector2d cascade: layer.cascade
    property real headMode: layer.headMode
    property var customAtlas: customImg.status === Image.Ready ? customImg : atlasImg
    property real customRows: customImg.status === Image.Ready ? layer.customRows : 0
    property vector4d rip0: layer.rip0
    property vector4d rip1: layer.rip1
    property vector4d rip2: layer.rip2
    property vector4d rip3: layer.rip3
    property vector4d rip4: layer.rip4
    property vector4d rip5: layer.rip5
    property color headFixed: layer.headFixed

    fragmentShader: Qt.resolvedUrl("shaders/rain.frag.qsb")
  }

  // Freeze shader inputs as well as the window update loop on inactive outputs.
  Binding { target: fx; property: "time"; value: layer.time; when: layer.running; restoreMode: Binding.RestoreNone }
  Binding { target: fx; property: "cellSize"; value: layer.letterSize; when: layer.running; restoreMode: Binding.RestoreNone }
  Binding { target: fx; property: "speed"; value: layer.speed; when: layer.running; restoreMode: Binding.RestoreNone }
  Binding { target: fx; property: "density"; value: layer.density; when: layer.running; restoreMode: Binding.RestoreNone }
  Binding { target: fx; property: "flash"; value: layer.flash; when: layer.running; restoreMode: Binding.RestoreNone }

  Rectangle {
    anchors.fill: parent
    visible: layer.showBackground
    color: "#000000"
    z: -1
  }
}
