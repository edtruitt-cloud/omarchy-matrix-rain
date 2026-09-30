import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "rainpalette.js" as Palette

Item {
  id: panel

  property var widget: null
  property QtObject bar: null

  readonly property var service: widget ? widget.service : null
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color accent: bar && bar.accent ? bar.accent : Color.accent
  readonly property real letterSize: service ? service.letterSize : 16
  readonly property real speed: service ? service.speed : 0.15
  readonly property real density: service ? service.density : 0.75
  readonly property bool isOn: !!service && service.enabled && !service.manualPaused

  implicitWidth: Style.space(780)
  implicitHeight: rainCol.implicitHeight + Style.space(24)

  function luminance(c) {
    function linear(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
  }
  readonly property color selectionTextColor: luminance(panel.accent) > 0.179 ? "#000000" : "#ffffff"

  component FieldLabel: Column {
    width: parent ? parent.width : 200
    spacing: 2
    property string title
    property string hint
    property string value: ""
    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      textFormat: Text.PlainText
      text: title + (value !== "" ? "  ·  " + value : "")
      color: panel.fg
      font.family: panel.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }
    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      visible: hint.length > 0
      textFormat: Text.PlainText
      text: "(" + hint + ")"
      color: panel.fg
      opacity: 0.8
      font.family: panel.fontFamily
      font.pixelSize: Style.font.body
    }
  }

  component Chip: Rectangle {
    id: chip
    property string chipId
    property string label
    property bool on: false
    property var onTap
    property var onRightTap
    // Optional colour squares shown before the label.
    property var swatch: []
    // A line of chips sets this so they share its width (0 = natural width).
    property real fixedWidth: 0
    readonly property real swatchWidth: swatch.length ? swatch.length * 7 + 5 : 0
    width: fixedWidth > 0 ? fixedWidth : panel.chipWidth(label, swatch.length)
    height: 24
    radius: 3
    color: on ? panel.accent : Qt.rgba(panel.fg.r, panel.fg.g, panel.fg.b, 0.12)
    border.width: 1
    border.color: on ? panel.accent : Qt.rgba(panel.fg.r, panel.fg.g, panel.fg.b, 0.22)
    Row {
      anchors.centerIn: parent
      spacing: 6
      Row {
        visible: chip.swatch.length > 0
        spacing: 1
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
          model: chip.swatch
          Rectangle { required property var modelData; width: 6; height: 10; radius: 1; color: modelData }
        }
      }
      Text {
        text: chip.label
        width: Math.min(implicitWidth, Math.max(8, chip.width - 12 - chip.swatchWidth))
        elide: Text.ElideRight
        color: chip.on ? panel.selectionTextColor : panel.fg
        font.pixelSize: 10
        font.bold: true
        font.family: panel.fontFamily
      }
    }
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: mouse => {
        if (mouse.button === Qt.RightButton) { if (onRightTap) onRightTap(chipId) }
        else if (onTap) onTap(chipId)
      }
    }
  }

  // Grey explanation under a group of settings.
  component Note: Text {
    width: parent ? parent.width : 300
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    color: panel.fg
    opacity: 0.65
    font.family: panel.fontFamily
    font.pixelSize: Style.font.body
  }

  function chipWidth(label, swatches) { return Math.max(44, String(label).length * 8 + 14 + (swatches ? swatches * 7 + 6 : 0)) }

  // One line of chips, optionally after a name. It never wraps: when the
  // chips don't fit at their own width they share the line equally (long
  // labels end in …).
  component ChipRow: Row {
    id: cr
    property string title
    property bool indent: title !== ""
    property var options: []
    property var labels: ({})
    property string current: ""
    property var pick
    property var rightPick
    property var labelOf: function(id) { return cr.labels[id] || (id.charAt(0).toUpperCase() + id.slice(1)) }
    property var isOn: function(id) { return cr.current === id }
    property var swatchOf: function(id) { return [] }
    property bool fill: false   // share the line even when the chips would fit
    width: parent ? parent.width : 300
    spacing: 4
    readonly property real titleWidth: indent ? Style.space(118) : 0
    readonly property real room: width - titleWidth - Math.max(0, options.length - 1) * spacing
    readonly property real natural: {
      var t = 0
      for (var i = 0; i < options.length; i++) t += panel.chipWidth(labelOf(options[i]), swatchOf(options[i]).length)
      return t
    }
    readonly property real share: options.length && (fill || natural > room) ? Math.floor(room / options.length) : 0
    Text {
      visible: cr.indent
      width: cr.titleWidth - cr.spacing; height: 24
      verticalAlignment: Text.AlignVCenter
      text: cr.title
      elide: Text.ElideRight
      color: panel.fg
      font.family: panel.fontFamily
      font.pixelSize: Style.font.body
    }
    Repeater {
      model: cr.options
      Chip {
        required property var modelData
        chipId: String(modelData)
        label: cr.labelOf(modelData)
        swatch: cr.swatchOf(modelData)
        fixedWidth: cr.share
        on: cr.isOn(modelData)
        onTap: function(id) { if (cr.pick) cr.pick(id) }
        onRightTap: function(id) { if (cr.rightPick) cr.rightPick(id) }
      }
    }
  }

  // Many chips as even lines (never a ragged last line): as few lines as
  // `perLine` allows, the chips spread evenly over them.
  component ChipGrid: Column {
    id: cg
    property var options: []
    property int perLine: 8
    property var labelOf
    property var isOn
    property var swatchOf: function(id) { return [] }
    property var pick
    property var rightPick
    width: parent ? parent.width : 300
    spacing: 4
    readonly property int lines: Math.max(1, Math.ceil(options.length / Math.max(1, perLine)))
    readonly property int each: Math.ceil(options.length / lines)
    Repeater {
      model: cg.lines
      ChipRow {
        required property int index
        options: cg.options.slice(index * cg.each, (index + 1) * cg.each)
        fill: cg.lines > 1
        labelOf: cg.labelOf
        isOn: cg.isOn
        swatchOf: cg.swatchOf
        pick: cg.pick
        rightPick: cg.rightPick
      }
    }
  }

  // Which layers a colour chip paints: the rain, or the depth layers behind.
  property string paintTarget: "front"
  property string confirmDelete: ""

  // The chosen target, falling back to the rain when its layer is gone.
  readonly property string target: {
    var t = panel.paintTarget
    if (!service) return "front"
    if (t === "desktop" || t === "front") return t
    if (!service.depthOn) return "front"
    if (t.indexOf("layer") === 0 && (service.depthLayers < 1 || Number(t.slice(5)) > service.depthLayers)) return "back"
    return t
  }
  function colorOn(name) {
    if (!service) return false
    var t = panel.target
    if (t === "desktop") return service.themeColor === name
    if (t === "back") return service.backColor === name
    if (t.indexOf("layer") === 0) return (service.layerColors[Number(t.slice(5)) - 1] || "") === name
    return service.rainColor === name
  }
  function paintColor(name) {
    if (!service) return
    var t = panel.target
    if (t === "desktop") service.applyThemeColor(name)
    else if (t === "back") service.setRainOption("backColor", name)
    else if (t.indexOf("layer") === 0) service.setLayerColor(Number(t.slice(5)), name)
    else service.applyRainColor(name)
  }

  function folded(name) { return !!service && service.collapsedSections.indexOf(name) >= 0 }

  // Section heading; click it to fold the section away (remembered).
  component Section: Text {
    id: sec
    property string name
    text: (panel.folded(name) ? "▸ " : "▾ ") + name
    color: panel.accent
    font.family: panel.fontFamily
    font.pixelSize: Style.font.body
    font.bold: true
    font.letterSpacing: 1.5
    topPadding: Style.space(6)
    width: parent ? parent.width : 300
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: if (service) service.toggleSection(sec.name)
    }
  }
  // The settings under a Section heading.
  component SectionBody: Column {
    property string name
    width: parent ? parent.width : 300
    spacing: Style.space(6)
    visible: !panel.folded(name)
  }

  // One line per setting: name, bar, value. `off` labels 0 when 0 means off.
  component SliderRow: Row {
    id: sr
    property string title
    property string hint: ""
    property real value
    property real minimum: 0
    property real maximum: 1
    property real step: 0.01
    property bool integer: false
    property var format: function(v) { return Math.round(v * 100) + "%" }
    property bool zeroIsOff: false
    signal moved(real v)
    signal released(real v)
    width: parent ? parent.width : 300
    spacing: Style.space(8)
    Text {
      id: srTitle
      width: Style.space(118); height: Style.space(24)
      verticalAlignment: Text.AlignVCenter
      text: sr.title
      elide: Text.ElideRight
      color: panel.fg
      font.family: panel.fontFamily
      font.pixelSize: Style.font.body
    }
    MatrixSlider {
      bar: panel.bar
      width: sr.width - srTitle.width - srValue.width - 2 * sr.spacing
      height: Style.space(24)
      minimum: sr.minimum; maximum: sr.maximum; step: sr.step; integer: sr.integer
      value: sr.value
      onMoved: function(v) { sr.moved(v) }
      onReleased: function(v) { sr.released(v) }
    }
    Text {
      id: srValue
      width: Style.space(62); height: Style.space(24)
      verticalAlignment: Text.AlignVCenter
      horizontalAlignment: Text.AlignRight
      text: sr.zeroIsOff && sr.value <= 0.001 ? "off" : sr.format(sr.value)
      color: panel.fg
      opacity: 0.8
      font.family: panel.fontFamily
      font.pixelSize: Style.font.body
    }
  }

    Column {
      id: rainCol
      width: parent.width - Style.space(24)
      x: Style.space(12); y: Style.space(12)
      spacing: Style.space(6)

      Row {
        width: parent.width
        spacing: Style.space(10)
        Text {
          text: "Matrix Rain"
          color: fg
          font.family: fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }
        Button {
          foreground: panel.fg
          fontFamily: panel.fontFamily
          iconText: panel.isOn ? "󰏤" : "󰐊"
          text: panel.isOn ? "Pause rain" : "Resume rain"
          bordered: true
          onClicked: if (service) service.applyToggle()
        }
      }

      Text {
        visible: !!service && service.enabled && service.manualPaused
        width: parent.width
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        text: "The rain is paused. Press Resume rain to start it again."
        color: panel.accent
        font.family: panel.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Section { name: "WEATHER" }
      SectionBody {
        name: "WEATHER"
        ChipRow {
          options: service ? service.weatherNames : []
          current: service ? service.rainPreset : ""
          pick: function(id) { if (service) service.applyRainPreset(id) }
        }
        // Your saved looks, lit like a preset when the rain matches one. These
        // wrap onto more lines (full names). Drag one to move it; a bar shows
        // where it will land.
        Flow {
          id: looksFlow
          visible: !!service && service.savedLooks.length > 0
          width: parent.width
          spacing: 4
          property int dragFrom: -1
          property int dropAt: -1
          property point dragPoint: Qt.point(0, 0)
          // The look under a point in this Flow (-1 = none).
          function indexAt(x, y) {
            for (var i = 0; i < children.length; i++) {
              var c = children[i]
              if (c.lookIndex !== undefined && x >= c.x - 2 && x <= c.x + c.width + 2 && y >= c.y && y <= c.y + c.height)
                return c.lookIndex
            }
            return -1
          }
          Repeater {
            model: service ? service.savedLooks.map(function(l) { return l.name }) : []
            Chip {
              id: lookChip
              required property string modelData
              required property int index
              readonly property int lookIndex: index
              chipId: modelData
              label: panel.confirmDelete === modelData ? "Delete?" : modelData
              on: panel.confirmDelete === modelData || (!!service && service.lookIs(modelData))
              opacity: looksFlow.dragFrom === index ? 0.35 : 1
              // Where it will land: a bar on the side it goes to.
              Rectangle {
                visible: looksFlow.dragFrom >= 0 && looksFlow.dropAt === lookChip.index && looksFlow.dropAt !== looksFlow.dragFrom
                width: 3; radius: 1
                height: parent.height + 4
                y: -2
                x: looksFlow.dropAt > looksFlow.dragFrom ? parent.width + 1 : -4
                color: panel.accent
              }
              MouseArea {
                anchors.fill: parent
                z: 2
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                preventStealing: true
                property point start
                cursorShape: looksFlow.dragFrom === lookChip.index ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                onPressed: mouse => { start = Qt.point(mouse.x, mouse.y) }
                onPositionChanged: mouse => {
                  if (!(mouse.buttons & Qt.LeftButton)) return
                  var p = mapToItem(looksFlow, mouse.x, mouse.y)
                  if (looksFlow.dragFrom < 0 && Math.abs(mouse.x - start.x) + Math.abs(mouse.y - start.y) > 8) {
                    panel.confirmDelete = ""
                    looksFlow.dragFrom = lookChip.index
                  }
                  if (looksFlow.dragFrom >= 0) {
                    looksFlow.dragPoint = p
                    var at = looksFlow.indexAt(p.x, p.y)
                    if (at >= 0) looksFlow.dropAt = at
                  }
                }
                onReleased: mouse => {
                  if (looksFlow.dragFrom >= 0) {
                    if (service && looksFlow.dropAt >= 0) service.moveLook(looksFlow.dragFrom, looksFlow.dropAt)
                    looksFlow.dragFrom = -1; looksFlow.dropAt = -1
                    return
                  }
                  var id = lookChip.modelData
                  if (mouse.button === Qt.RightButton) {
                    if (panel.confirmDelete === id) { panel.confirmDelete = ""; if (service) service.deleteLook(id) }
                    else panel.confirmDelete = id
                  } else {
                    panel.confirmDelete = ""
                    if (service) service.recallLook(id)
                  }
                }
                onCanceled: { looksFlow.dragFrom = -1; looksFlow.dropAt = -1 }
              }
            }
          }
        }
        Row {
          width: parent.width
          spacing: 4
          TextField {
            id: lookName
            width: parent.width - saveLook.width - copyLook.width - pasteLook.width - 3 * parent.spacing
            height: 24
            verticalPadding: 2
            foreground: panel.fg
            accent: panel.accent
            placeholderText: "Name this look"
            maximumLength: 24
            onAccepted: { if (service) service.saveLook(text); text = "" }
          }
          Chip { id: saveLook; chipId: "save"; label: "Save look"; onTap: function() { if (service) service.saveLook(lookName.text); lookName.text = "" } }
          Chip { id: copyLook; chipId: "copy"; label: "Copy code"; onTap: function() { if (service) service.copyLookCode(lookName.text || "Shared look") } }
          Chip { id: pasteLook; chipId: "paste"; label: "Paste code"; onTap: function() { if (service) service.pasteLookCode() } }
        }
        Note {
          visible: !!service && service.shareStatus !== ""
          text: service ? service.shareStatus : ""
        }
      }

      Section { name: "LOOK" }
      SectionBody {
        name: "LOOK"
        ChipGrid {
          options: service ? service.glyphSetNames : []
          perLine: 7
          labelOf: function(id) { return ({ box: "Box" })[id] || (id.charAt(0).toUpperCase() + id.slice(1)) }
          isOn: function(id) { return !!service && service.glyphSet === id }
          pick: function(id) { if (service) service.setRainOption("glyphSet", id) }
        }
        // Custom: your own symbols, drawn in one colour and cleaned up.
        Row {
          visible: !!service && service.glyphSet === "custom"
          width: parent.width
          spacing: 4
          TextField {
            id: customField
            width: parent.width - customUse.width - parent.spacing
            height: 24
            verticalPadding: 2
            foreground: panel.fg
            accent: panel.accent
            text: service ? service.customChars : ""
            placeholderText: "Type or paste your symbols: ★☯⚡♠…"
            maximumLength: 200
            onAccepted: if (service) service.setCustomGlyphs(text)
          }
          Chip {
            id: customUse
            chipId: "use"
            label: service && service.customBusy ? "Drawing…" : "Use symbols"
            on: !!service && service.customBusy
            onTap: function() { if (service) service.setCustomGlyphs(customField.text) }
          }
        }
        Note {
          visible: !!service && service.glyphSet === "custom" && service.customStatus !== ""
          text: service ? service.customStatus : ""
        }
        SliderRow {
          title: "Letter size"
          minimum: 4; maximum: 100; step: 1; integer: true
          value: panel.letterSize
          format: function(v) { return Math.round(v) + " px" }
          onMoved: v => { if (service) service.letterSize = v }
          onReleased: v => { if (service) service.applyLetterSize(v) }
        }
        SliderRow {
          title: "Fall speed"
          minimum: 0.02; maximum: 1.0
          value: panel.speed
          format: function(v) { return v.toFixed(2) }
          onMoved: v => { if (service) service.speed = v }
          onReleased: v => { if (service) service.applySpeed(v) }
        }
        SliderRow {
          title: "Density"
          minimum: 0.5; maximum: 1.0
          value: panel.density
          onMoved: v => { if (service) service.density = v }
          onReleased: v => { if (service) service.applyDensity(v) }
        }
        SliderRow {
          title: "Trail length"
          minimum: 0.5; maximum: 2
          value: service ? service.trailScale : 1
          onMoved: v => { if (service) service.trailScale = v }
          onReleased: v => { if (service) service.setRainOption("trailScale", v) }
        }
        SliderRow {
          title: "Trail variety"
          minimum: 0; maximum: 3
          value: service ? service.trailVariety : 1
          onMoved: v => { if (service) service.trailVariety = v }
          onReleased: v => { if (service) service.setRainOption("trailVariety", v) }
        }
        SliderRow {
          title: "Speed variety"
          minimum: 0; maximum: 2
          value: service ? service.speedVariety : 1
          onMoved: v => { if (service) service.speedVariety = v }
          onReleased: v => { if (service) service.setRainOption("speedVariety", v) }
        }
        SliderRow {
          title: "Gravity"
          zeroIsOff: true
          value: service ? service.gravity : 0
          onMoved: v => { if (service) service.gravity = v }
          onReleased: v => { if (service) service.setRainOption("gravity", v) }
        }
        SliderRow {
          title: "Glyph flicker"
          zeroIsOff: true
          minimum: 0; maximum: 2
          value: service ? service.glyphFlicker : 1
          onMoved: v => { if (service) service.glyphFlicker = v }
          onReleased: v => { if (service) service.setRainOption("glyphFlicker", v) }
        }
        SliderRow {
          title: "Mirrored"
          zeroIsOff: true
          value: service ? service.mirrorAmount : 0
          onMoved: v => { if (service) service.mirrorAmount = v }
          onReleased: v => { if (service) service.setRainOption("mirrorAmount", v) }
        }
        SliderRow {
          title: "Glyph weight"
          zeroIsOff: true
          value: service ? service.glyphWeight : 0
          onMoved: v => { if (service) service.glyphWeight = v }
          onReleased: v => { if (service) service.setRainOption("glyphWeight", v) }
        }
        SliderRow {
          title: "Head glow"
          zeroIsOff: true
          value: service ? service.headGlow : 0
          onMoved: v => { if (service) service.headGlow = v }
          onReleased: v => { if (service) service.setRainOption("headGlow", v) }
        }
        SliderRow {
          title: "Bloom"
          zeroIsOff: true
          value: service ? service.bloomAmount : 0
          onMoved: v => { if (service) service.bloomAmount = v }
          onReleased: v => { if (service) service.setRainOption("bloomAmount", v) }
        }
        SliderRow {
          title: "Colour fringe"
          zeroIsOff: true
          value: service ? service.aberration : 0
          onMoved: v => { if (service) service.aberration = v }
          onReleased: v => { if (service) service.setRainOption("aberration", v) }
        }
        SliderRow {
          title: "Vignette"
          zeroIsOff: true
          value: service ? service.vignette : 0
          onMoved: v => { if (service) service.vignette = v }
          onReleased: v => { if (service) service.setRainOption("vignette", v) }
        }
        SliderRow {
          title: "CRT"
          zeroIsOff: true
          value: service ? service.crtAmount : 0
          onMoved: v => { if (service) service.crtAmount = v }
          onReleased: v => { if (service) service.setRainOption("crtAmount", v) }
        }
        SliderRow {
          title: "Depth layer"
          zeroIsOff: true
          minimum: 0; maximum: 0.9
          value: service ? service.depthLevel : 0.45
          onMoved: v => { if (service) service.depthLevel = v }
          onReleased: v => { if (service) service.setRainOption("depthLevel", v) }
        }
        SliderRow {
          title: "Depth layers"
          minimum: 0; maximum: 5; step: 1; integer: true
          value: service ? service.depthLayers : 1
          zeroIsOff: true
          format: function(v) { return Math.round(v) + (Math.round(v) === 1 ? " layer" : " layers") }
          onMoved: v => { if (service) service.depthLayers = v }
          onReleased: v => { if (service) service.setRainOption("depthLayers", v) }
        }
        SliderRow {
          title: "Depth size"
          visible: !!service && service.depthOn
          minimum: 0.4; maximum: 0.9
          value: service ? service.depthScale : 0.6
          onMoved: v => { if (service) service.depthScale = v }
          onReleased: v => { if (service) service.setRainOption("depthScale", v) }
        }
        ChipRow {
          visible: !!service && service.depthOn
          title: "Depth quality"
          options: ["sharp", "balanced", "fast"]
          current: service ? service.depthQuality : "balanced"
          pick: function(id) { if (service) service.setRainOption("depthQuality", id) }
        }
      }

      Section { name: "WORKSPACES" }
      SectionBody {
        name: "WORKSPACES"
        // One chip per workspace: tap steps to the next saved look, right-click back.
        ChipRow {
          fill: true
          options: [1, 2, 3, 4, 5]
          labelOf: function(ws) {
            var c = service ? (service.workspaceLooks[String(ws)] || "") : ""
            return ws + " · " + (c.indexOf("look:") === 0 ? c.slice(5) : "Your look")
          }
          isOn: function(ws) { return !!service && !!service.workspaceLooks[String(ws)] }
          pick: function(id) { if (service) service.cycleWorkspaceLook(Number(id), 1) }
          rightPick: function(id) { if (service) service.cycleWorkspaceLook(Number(id), -1) }
        }
      }

      Section { name: "COLOUR" }
      SectionBody {
        name: "COLOUR"
        ChipRow {
          title: "Colour for"
          options: service && service.depthOn ? ["front", "back", "desktop"] : ["front", "desktop"]
          labels: ({ front: "The rain", back: "Depth layers", desktop: "Theme" })
          current: panel.target.indexOf("layer") === 0 ? "back" : panel.target
          pick: function(id) { panel.paintTarget = id }
        }
        // Single layers, only while Depth layers is picked (and there are several).
        ChipRow {
          visible: !!service && service.depthOn
                   && (panel.target === "back" || panel.target.indexOf("layer") === 0)
          title: " "
          options: {
            var o = ["back"]
            for (var k = 1; service && k <= service.depthLayers; k++) o.push("layer" + k)
            return o
          }
          labels: ({ back: "All layers", layer1: "Layer 1", layer2: "Layer 2", layer3: "Layer 3", layer4: "Layer 4", layer5: "Layer 5" })
          current: panel.target
          pick: function(id) { panel.paintTarget = id }
        }
        // Heads follow Colour for: the rain, all depth layers, or one layer.
        ChipRow {
          visible: panel.target !== "desktop"
          title: "Heads"
          options: panel.target === "front" ? (service ? service.headModes : []) : [""].concat(service ? service.headModes : [])
          labels: ({ "": panel.target === "back" ? "Same as the rain" : "Same as all layers", look: "Look's own", body: "Body colour", accent: "Accent" })
          current: {
            if (!service) return "look"
            var t = panel.target
            if (t === "back") return service.backHeadColor
            if (t.indexOf("layer") === 0) return service.layerHeadColors[Number(t.slice(5)) - 1] || ""
            return service.headColor
          }
          pick: function(id) {
            if (!service) return
            var t = panel.target
            if (t === "back") service.setRainOption("backHeadColor", id)
            else if (t.indexOf("layer") === 0) service.setLayerHead(Number(t.slice(5)), id)
            else service.setRainOption("headColor", id)
          }
        }
        Chip {
          visible: panel.target !== "front" && panel.target !== "desktop"
          chipId: "same"
          label: panel.target === "back" ? "Same as the rain" : "Same as all depth layers"
          on: panel.colorOn("")
          onTap: function() { panel.paintColor("") }
        }
        ChipGrid {
          // The theme can't take Theme (itself) or Daylight (changes all day).
          options: (panel.target === "desktop" ? ["green", "wallpaper"] : ["green", "theme", "daylight", "wallpaper"]).concat(Palette.presetNames)
          perLine: 8
          labelOf: function(id) { return ({ hotpink: "Hot Pink" })[id] || (id.charAt(0).toUpperCase() + id.slice(1)) }
          swatchOf: function(id) {
            return id === "green" ? ["#e8ffe8", "#00ff41", "#005208"] : id === "theme" ? [panel.accent]
              : id === "daylight" ? [service ? Palette.daylight(service.dayHour) : "#7df9ff"]
              : id === "wallpaper" ? (service && service.wallpaperColors.length ? service.wallpaperColors : ["#888888"])
              : Palette.swatch(id)
          }
          isOn: function(id) { return panel.colorOn(id) }
          pick: function(id) { panel.paintColor(id) }
        }
        ChipGrid {
          options: Palette.multiNames
          perLine: 6
          labelOf: function(id) { return ({ icefire: "Ice & Fire" })[id] || (id.charAt(0).toUpperCase() + id.slice(1)) }
          swatchOf: function(id) { return Palette.swatch(id) }
          isOn: function(id) { return panel.colorOn(id) }
          pick: function(id) { panel.paintColor(id) }
        }
        Note {
          visible: !!service && service.themeStatus !== ""
          text: service ? service.themeStatus : ""
        }
      }

      Section { name: "REACTIONS" }
      SectionBody {
        name: "REACTIONS"
        SliderRow {
          title: "Beat flash"
          zeroIsOff: true
          value: service ? service.flashAmount : 0.6
          onMoved: v => { if (service) service.flashAmount = v }
          onReleased: v => { if (service) service.setRainOption("flashAmount", v) }
        }
        SliderRow {
          title: "Tempo pull"
          zeroIsOff: true
          value: service ? service.tempoPull : 0
          onMoved: v => { if (service) service.tempoPull = v }
          onReleased: v => { if (service) service.setRainOption("tempoPull", v) }
        }
        SliderRow {
          title: "Notify burst"
          zeroIsOff: true
          value: service ? service.burstAmount : 0.7
          onMoved: v => { if (service) service.burstAmount = v }
          onReleased: v => { if (service) service.setRainOption("burstAmount", v) }
        }
        SliderRow {
          title: "Typing"
          zeroIsOff: true
          value: service ? service.typingAmount : 0
          onMoved: v => { if (service) service.typingAmount = v }
          onReleased: v => { if (service) service.setRainOption("typingAmount", v) }
        }
        SliderRow {
          title: "Mouse"
          zeroIsOff: true
          value: service ? service.mouseAmount : 0.5
          onMoved: v => { if (service) service.mouseAmount = v }
          onReleased: v => { if (service) service.setRainOption("mouseAmount", v) }
        }
        SliderRow {
          title: "Workspace rush"
          zeroIsOff: true
          value: service ? service.workspaceRush : 0.5
          onMoved: v => { if (service) service.workspaceRush = v }
          onReleased: v => { if (service) service.setRainOption("workspaceRush", v) }
        }
        SliderRow {
          title: "Idle drift"
          zeroIsOff: true
          value: service ? service.idleDrift : 0.5
          onMoved: v => { if (service) service.idleDrift = v }
          onReleased: v => { if (service) service.setRainOption("idleDrift", v) }
        }
        SliderRow {
          title: "CPU pull"
          zeroIsOff: true
          value: service ? service.cpuPull : 0
          onMoved: v => { if (service) service.cpuPull = v }
          onReleased: v => { if (service) service.setRainOption("cpuPull", v) }
        }
        Row {
          width: parent.width
          spacing: 8
          Note {
            width: Math.min(implicitWidth, parent.width - (getSound.visible ? getSound.width + 8 : 0))
            anchors.verticalCenter: parent.verticalCenter
            text: !service ? "" : service.soundLabStatus !== "" ? service.soundLabStatus
              : service.soundLinked ? "Sound Lab connected" + (service.linkPlaying ? " · playing" : "")
              : service.soundLabState === "missing" ? "Sound Lab isn't installed"
              : service.soundLabState === "disabled" ? "Sound Lab is turned off" : "Sound Lab not running"
          }
          // Sound Lab is the companion synth: get it or turn it on from here.
          Chip {
            id: getSound
            visible: !!service && !service.soundLinked && (service.soundLabState === "missing" || service.soundLabState === "disabled")
            chipId: "getSoundLab"
            label: service && service.soundLabState === "disabled" ? "Turn on Sound Lab" : "Get Sound Lab"
            onTap: function() { if (service) service.getSoundLab() }
          }
        }
      }

      Section { name: "EVENTS" }
      SectionBody {
        name: "EVENTS"
        ChipGrid {
          options: service ? service.eventNames : []
          perLine: 6
          labelOf: function(id) {
            return ({ dejavu: "Déjà vu", rewind: "Rewind", bullet: "Bullet time", surge: "Surge",
                      scramble: "Scramble", binary: "Glyph swap", blackout: "Blackout", glitch: "Glitch",
                      dive: "Dive", pan: "Pan", drift: "Drift", cascade: "Cascade" })[id] || id
          }
          isOn: function(id) { return !!service && service.eventsOn.indexOf(id) >= 0 }
          pick: function(id) { if (service) service.toggleEvent(id) }
          rightPick: function(id) { if (service) service.startEvent(id) }
        }
        ChipRow {
          title: "How often"
          options: ["off", "rare", "sometimes", "often"]
          current: service ? service.eventRate : "off"
          pick: function(id) { if (service) service.setRainOption("eventRate", id) }
        }
        SliderRow {
          title: "Chain events"
          zeroIsOff: true
          value: service ? service.chainChance : 0
          onMoved: v => { if (service) service.chainChance = v }
          onReleased: v => { if (service) service.setRainOption("chainChance", v) }
        }
      }

      Section { name: "FULLSCREEN" }
      SectionBody {
        name: "FULLSCREEN"
        ChipRow {
          options: ["pause", "keep"]
          labels: ({ pause: "Pause rain", keep: "Keep falling" })
          current: service && service.pauseOnFullscreen ? "pause" : "keep"
          pick: function(id) { if (service) service.applySetPauseOnFullscreen(id === "pause") }
        }
      }
    }

}
