#!/usr/bin/env python3
"""Check the actual candidate in an isolated offscreen shell; capture its panel."""
import argparse, os, shutil, subprocess, tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--width',type=int,default=800)
parser.add_argument('--height',type=int,default=900)
parser.add_argument('--theme',choices=['dark','light'],default='dark')
parser.add_argument('--scale',default='1')
parser.add_argument('--output',type=Path,default=root/'preview.png')
args=parser.parse_args()
args.output.parent.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='matrix-qml-') as tmp:
    tmp=Path(tmp)
    for name in ('Commons','Ui','services'):
        (tmp/name).symlink_to(Path('/usr/share/omarchy/shell')/name)
    shutil.copytree(root,tmp/'Synth',ignore=shutil.ignore_patterns('.git','build','dist','__pycache__'))
    # Offscreen Qt has no layer-shell backend: exclude monitor windows only.
    service=tmp/'Synth/Service.qml'
    code=service.read_text()
    a=code.index('  Variants {'); b=code.index('  IpcHandler {',a)
    service.write_text(code[:a]+code[b:])
    (tmp/'home').mkdir(); (tmp/'runtime').mkdir(mode=0o700); (tmp/'bin').mkdir()
    stub=tmp/'bin/hyprctl'
    stub.write_text('#!/bin/sh\nprintf "[]\\n"\n');stub.chmod(0o755)
    (tmp/'shell.qml').write_text('''import QtQuick
import Quickshell
import qs.Commons
import "Synth" as Synth
ShellRoot {
  Synth.Service { id: svc; manifest: ({__sourceDir: Qt.resolvedUrl("Synth").toString().replace("file://", "")}) }
  Synth.RainLayer { id: rainFixture; visible: false; width: 64; height: 64 }
  QtObject { id: bridge; property var service: svc }
  FloatingWindow {
    id: window
    property var validateLayout: null
    implicitWidth: Number(Quickshell.env("MATRIX_WIDTH")); implicitHeight: Number(Quickshell.env("MATRIX_HEIGHT")); color: Color.background
    Component.onCompleted: {
      Color.background = Quickshell.env("MATRIX_THEME") === "light" ? "#f5f5f5" : "#101315"
      Color.foreground = Quickshell.env("MATRIX_THEME") === "light" ? "#20252b" : "#cacccc"
      Color.accent = Quickshell.env("MATRIX_THEME") === "light" ? "#17643b" : "#9fe6b5"
    }
    Synth.Panel { id: panel; anchors.fill: parent; widget: bridge }
    Timer {
      interval: 50; repeat: true; running: true
      onTriggered: {
        if (!svc._stateLoaded) return
        stop()
        svc.applyStateText("{not json"); if(!svc._stateCorrupt) throw new Error("Corrupt state flag")
        svc._stateCorrupt=false
        svc.applyLetterSize(1000); if(svc.letterSize!==28) throw new Error("Clamp failed")
        svc.applyLetterSize(16)
        svc.pauseOnFullscreen=true; svc.fullscreenOverride={A:true}
        if (svc.screenCanAnimate("A") || !svc.screenCanAnimate("B")) throw new Error("Per-monitor fullscreen gating")
        svc.manualPaused=true
        if (svc.screenCanAnimate("A") || svc.screenCanAnimate("B")) throw new Error("Pause gating")
        svc.manualPaused=false; svc.enabled=false
        if (svc.screenCanAnimate("B")) throw new Error("Disabled gating")
        svc.enabled=true; svc.fullscreenOverride=null
        rainFixture.time=12
        var shader=null
        for(var n=0;n<rainFixture.children.length;n++) if(rainFixture.children[n].objectName==="rainShader") shader=rainFixture.children[n]
        if(!shader || shader.time!==12) throw new Error("Active shader binding")
        rainFixture.running=false; rainFixture.time=99
        if(shader.time!==12) throw new Error("Inactive shader was updated")
        rainFixture.running=true
        if(shader.time!==99) throw new Error("Shader did not resume")
        if(shader.glyphSet.x!==0 || shader.glyphSet.y!==177 || shader.atlasRows!==24) throw new Error("Atlas metadata not read from atlas.js")
        // Never touch the real desktop theme from the harness.
        svc.themeFollowsRain=false
        if(svc.applyRainColor("bogus") || svc.rainColor!=="green") throw new Error("Invalid rain colour accepted")
        if(svc.themeSpecFor(svc.rainColor)!=="green") throw new Error("Green theme spec")
        svc.applyRainColor("gold"); if(svc.themeSpecFor(svc.rainColor)!=="#ffd84a") throw new Error("Preset theme spec")
        svc.applyRainColor("theme"); if(svc.themeSpecFor(svc.rainColor)!=="") throw new Error("Theme colour must not set the theme")
        svc.applyRainColor("green")
        if(!svc.applyRainColor("#FF0000") || svc.rainColor!=="#ff0000" || svc.rainPalette.body.r!==1 || svc.rainPalette.body.g!==0) throw new Error("Custom rain colour")
        svc.applyRainColor("theme"); if(Math.max(svc.rainPalette.body.r,svc.rainPalette.body.g,svc.rainPalette.body.b)<0.99) throw new Error("Theme colour not brightened")
        svc.applyRainColor("green"); if(Math.abs(svc.rainPalette.body.b-0.255)>0.01) throw new Error("Classic green changed")
        if (svc.validRainColor("sunset") !== "sunset" || svc.validRainColor("cobalt") !== "cobalt") throw new Error("New colours accepted")
        svc.applyRainColor("sunset")
        if (svc.rainPalette.mode !== 2 || svc.themeSpecFor(svc.rainColor).split(",").length !== 4) throw new Error("Multi-colour palette/theme spec")
        svc.applyRainColor("neon"); if (svc.rainPalette.mode !== 1) throw new Error("Per-stream mode")
        svc.applyRainColor("rainbow"); if (svc.rainPalette.mode !== 3) throw new Error("Rainbow mode")
        svc.applyRainColor("cyan"); if (svc.rainPalette.mode !== 0 || svc.themeSpecFor(svc.rainColor) !== "#00f0e0") throw new Error("Single new colour")
        if (svc.validRainColor("toxic") !== "venom" || svc.validRainColor("teal") !== "cyan" || svc.validRainColor("fire") !== "fire" || svc.validRainColor("candy") !== "candy") throw new Error("Removed colours move to their closest look")
        svc.applyRainColor("ember"); if (svc.themeSpecFor(svc.rainColor).split(",").length !== 3 || Math.abs(svc.rainPalette.head.b - 0.627) > 0.01) throw new Error("Ember trail colours reach the theme")
        if (svc.validRainColor("orange") !== "ember" || svc.validRainColor("sky") !== "cyan" || svc.validRainColor("frost") !== "cyan" || svc.validRainColor("mint") !== "mint") throw new Error("Old colour names migrate")
        svc.applyRainColor("ocean")
        if (svc.rainPalette.mode !== 2 || svc.rainPalette.variation !== 0.4 || svc.rainPalette.colorA.r !== 1 || svc.rainPalette.colorD.b > 0.5) throw new Error("Ocean: white top, dark blue bottom, variation")
        if (svc.themeSpecFor(svc.rainColor).split(",")[0] === "#ffffff") throw new Error("White must not lead a theme")
        svc.applyRainColor("green"); if (svc.rainPalette.mode !== 0) throw new Error("Green mode")
        // --- Matrix Rain weather presets, depth and reactions
        // Weather presets are fixed: picking one sets its values; changing one
        // of those settings deselects it; picking it again restores it exactly.
        svc.applyRainPreset("storm")
        if (svc.letterSize !== 14 || svc.speed !== 0.6 || svc.density !== 1 || svc.trailScale !== 2 || svc.glyphFlicker !== 2 || svc.depthLayers !== 3 || svc.depthLevel !== 0.2) throw new Error("Storm preset sets the whole look (3 layers)")
        if (svc.rainPreset !== "storm") throw new Error("Storm selected")
        svc.applySpeed(0.5); if (svc.rainPreset !== "") throw new Error("A change deselects the preset")
        svc.applyRainPreset("storm"); if (svc.speed !== 0.6 || svc.rainPreset !== "storm") throw new Error("Presets never keep changes")
        svc.setRainOption("crtAmount", 0.5); if (svc.rainPreset !== "") throw new Error("CRT is a weather setting")
        svc.applyRainPreset("storm"); svc.setRainOption("mirrorAmount", 0.3); if (svc.rainPreset !== "") throw new Error("Shape and light are weather settings now")
        svc.applyRainPreset("storm"); if (svc.mirrorAmount !== 0 || svc.speedVariety !== 1) throw new Error("Presets use the plain shape")
        svc.setRainOption("glyphSet", "runes"); if (svc.rainPreset !== "storm") throw new Error("Glyphs leave the weather alone"); svc.setRainOption("glyphSet", "matrix")
        svc.setRainOption("mirrorAmount", 0)
        svc.applyRainPreset("drizzle")
        if (svc.letterSize !== 22 || svc.speed !== 0.1 || svc.density !== 0.5 || svc.trailScale !== 0.6 || svc.glyphFlicker !== 0.4 || svc.depthLevel !== 0.4 || svc.depthLayers !== 1 || svc.depthScale !== 0.4) throw new Error("Drizzle preset")
        // Saved with tweaks (weather version 2): the preset goes back to its real values.
        svc.applyStateText(JSON.stringify({rainPreset: "classic", weatherVersion: 2, letterSize: 10}))
        if (svc.letterSize !== 16 || svc.rainPreset !== "classic") throw new Error("Tweaked presets go back to their real values")
        svc.applyStateText(JSON.stringify({rainPreset: "classic", weatherVersion: 3, letterSize: 10}))
        if (svc.letterSize !== 10 || svc.rainPreset !== "") throw new Error("Your own mix loads as it is")
        svc.applyRainPreset("terminal"); if (svc.letterSize !== 6 || svc.speed !== 1) throw new Error("Terminal preset")
        if (svc.applyRainPreset("hail")) throw new Error("Unknown preset")
        svc.applyRainPreset("classic")
        if (svc.setRainOption("bogus", 1) || svc.setRainOption("eventRate", "never")) throw new Error("Invalid rain option")
        svc.setRainOption("depthLevel", 5); if (svc.depthLevel !== 0.9) throw new Error("Depth clamp")
        svc.setRainOption("depthLevel", 0.45)
        // CPU load: 50% busy between samples speeds rain by 30%.
        svc.setRainOption("cpuPull", 0.6)
        svc.readCpu("cpu  100 0 100 800 0 0 0 0 0 0"); svc.readCpu("cpu  150 0 150 900 0 0 0 0 0 0")
        if (Math.abs(svc.cpuLoad - 0.5) > 1e-9 || Math.abs(svc.reactiveSpeed - svc.rainSpeed * 1.3) > 1e-9) throw new Error("CPU reaction")
        svc.setRainOption("cpuPull", 0); if (svc.cpuLoad !== 0 || Math.abs(svc.reactiveSpeed - svc.rainSpeed) > 1e-9) throw new Error("CPU off")
        // Sound Lab link: beats flash only while it plays; its state, tempo
        // and LFO arrive as JSON lines; rain events go out to it.
        function beatRunning() { for (var c = 0; c < svc.resources.length; c++) { var r = svc.resources[c]; if (r.property === "beatFlash" && r.running) return true } return svc.beatFlash > 0 }
        if (svc.soundLinked || svc.lfoDest !== "") throw new Error("No Sound Lab in the harness")
        svc.readLink('{"t":"beat"}'); if (beatRunning()) throw new Error("No flash while Sound Lab is stopped")
        svc.readLink('{"t":"state","playing":true,"bpm":150,"lfo":{"rate":0.5,"depth":0.4,"dest":"speed"}}')
        if (!svc.linkPlaying || svc.linkBpm !== 150 || svc.linkLfoDest !== "speed" || svc.linkLfoDepth !== 0.4) throw new Error("Link state")
        svc.readLink('{"t":"beat"}'); if (!beatRunning()) throw new Error("Flash on a Sound Lab beat")
        svc.readLink('not json'); svc.readLink('{"t":"state","bpm":9999}'); if (svc.linkBpm !== 180) throw new Error("Link tempo clamp")
        svc.setRainOption("tempoPull", 1); if (Math.abs(svc.reactiveSpeed - svc.rainSpeed * (1 + svc.cpuPull * svc.cpuLoad) * (1 + 0.8 * svc.burst) * 180 / 122) > 1e-9) throw new Error("Tempo pull follows Sound Lab")
        svc.setRainOption("tempoPull", 0)
        svc.readLink('{"t":"state","playing":false}'); if (svc.linkPlaying) throw new Error("Link stop")
        svc.setRainOption("burstAmount", 0); svc.burstLevel = 0; svc.triggerBurst(); if (svc.burstLevel !== 0) throw new Error("Burst while off")
        svc.setRainOption("burstAmount", 0.7)
        svc.readDnd('{"version":3,"dnd":true}'); svc.burstLevel = 0; svc.triggerBurst(); if (svc.burstLevel !== 0) throw new Error("No burst during Do Not Disturb")
        svc.readDnd('{"version":3,"dnd":false}'); if (svc.doNotDisturb) throw new Error("DND off")
        svc.readDnd('not json'); if (svc.doNotDisturb) throw new Error("Bad DND file means DND off")
        if (svc.setRainOption("depthQuality", "ultra") || !svc.setRainOption("depthQuality", "fast") || svc.depthResolution !== 0.5) throw new Error("Depth quality")
        svc.setRainOption("depthQuality", "balanced")
        // Déjà vu replays a 0.4 s loop three times, then carries on.
        svc.rainPhase = 10; var rate = svc.reactiveSpeed
        svc.startDejaVu(); svc.advanceRain(0.1); var p1 = svc.rainPhase
        svc.advanceRain(0.4); if (Math.abs(svc.rainPhase - p1) > 1e-6) throw new Error("Déjà vu replays the same moment")
        svc.advanceRain(0.8); if (svc.activeEvent !== "" || Math.abs(svc.rainPhase - (10 + 0.4 * rate)) > 1e-6) throw new Error("Déjà vu ends and resumes")
        var st = JSON.parse(svc.statePayload())
        if (st.depthLevel !== svc.depthLevel || st.rainPreset !== svc.rainPreset || st.burstAmount !== 0.7 || st.eventRate !== "off" || st.trailScale !== svc.trailScale || st.weatherVersion !== 3 || st.depthOn !== undefined) throw new Error("Rain settings saved")
        // Old on/off switches become amounts (0% = off).
        svc.applyStateText(JSON.stringify({depthOn:false, musicReact:false, followTempo:true, notifyBurst:false, cpuReact:true, dejaVu:false, dejaVuRate:"often"}))
        if (svc.depthLevel !== 0 || svc.flashAmount !== 0 || svc.tempoPull !== 1 || svc.burstAmount !== 0 || svc.cpuPull !== 0.6 || svc.eventRate !== "off") throw new Error("Switch migration")
        svc.applyStateText(JSON.stringify({dejaVuRate:"often"})); if (svc.eventRate !== "often" || svc.eventsOn.join() !== "dejavu") throw new Error("Déjà vu rate becomes the event rate")
        svc.eventsOn = svc.eventNames.slice(); svc.setRainOption("eventRate", "off")
        svc.applyStateText(JSON.stringify({depthLevel:0.45, depthScale:0.6, flashAmount:0.6, tempoPull:0, burstAmount:0.7, cpuPull:0, eventRate:"off"}))
        if (!svc.depthOn || svc.setRainOption("trailScale", 9) !== true || svc.trailScale !== 2) throw new Error("Amount ranges")
        svc.setRainOption("trailScale", 1); svc.setRainOption("glyphFlicker", 1)
        svc.setRainOption("depthLayers", 9); if (svc.depthLayers !== 5) throw new Error("Depth layers clamp")
        svc.setRainOption("depthLayers", 2.6); if (svc.depthLayers !== 3) throw new Error("Depth layers are whole")
        // Depth slots: evenly spaced, the farthest drawn at depthScale.
        svc.layerSlots = []
        if (Math.abs(svc.layerDist(1) - 4/3) > 1e-9 || Math.abs(svc.distanceZoom(svc.layerDist(3)) - svc.depthScale) > 1e-9 || svc.distanceZoom(1) !== 1) throw new Error("Depth distances and sizes")
        svc.setRainOption("depthLayers", 1)
        if (svc.setRainOption("depthOn", true)) throw new Error("Old switch option accepted")
        svc.setRainOption("crtAmount", 0.3)
        var fx = JSON.parse(svc.statePayload())
        if (fx.windAmount !== undefined || fx.crtAmount !== 0.3 || fx.eventRate !== "off" || fx.eventsOn.length !== svc.eventNames.length || fx.glowAmount !== undefined || fx.lightningRate !== undefined) throw new Error("Effects saved")
        svc.setRainOption("crtAmount", 0)
        // Events: each runs, changes the rain as described, and ends.
        svc.rainPhase = 20; rate = svc.reactiveSpeed
        svc.startEvent("rewind"); svc.advanceRain(0.5); if (!(svc.rainPhase < 20)) throw new Error("Rewind runs backwards")
        for (var wi = 0; wi < 20; wi++) svc.advanceRain(0.1); if (svc.activeEvent !== "") throw new Error("Rewind ends")
        var before = svc.rainPhase; svc.startEvent("bullet"); svc.advanceRain(1.5)
        if (!(svc.rainPhase - before < 1.5 * rate * 0.2)) throw new Error("Bullet time nearly stops the rain")
        for (wi = 0; wi < 20; wi++) svc.advanceRain(0.1)
        svc.startEvent("blackout"); svc.advanceRain(0.8); if (svc.rainFade !== 0) throw new Error("Blackout fades out")
        for (wi = 0; wi < 20; wi++) svc.advanceRain(0.1); if (svc.rainFade !== 1) throw new Error("Blackout comes back")
        svc.startEvent("scramble"); svc.advanceRain(0.1); if (svc.scrambleBoost <= 0) throw new Error("Scramble churns glyphs")
        for (wi = 0; wi < 10; wi++) svc.advanceRain(0.1); if (svc.scrambleBoost !== 0) throw new Error("Scramble ends")
        svc.startEvent("glitch"); for (wi = 0; wi < 10; wi++) svc.advanceRain(0.1); if (svc.glitchLevel !== 0 || svc.activeEvent !== "") throw new Error("Glitch ends")
        if (svc.startEvent("hail")) throw new Error("Unknown event")
        svc.eventsOn = ["scramble"]; svc.startEvent(""); if (svc.activeEvent !== "scramble") throw new Error("Random event picks from those switched on")
        for (wi = 0; wi < 10; wi++) svc.advanceRain(0.1)
        svc.toggleEvent("rewind"); if (svc.eventsOn.join() !== "scramble,rewind") throw new Error("Toggle event")
        // Surge rushes the rain; Glyph swap (Binary) changes the glyph set for 10 s alongside other events.
        before = svc.rainPhase; svc.startEvent("surge"); svc.advanceRain(0.8)
        if (!(svc.rainPhase - before > 0.8 * rate * 2)) throw new Error("Surge rushes the rain")
        for (wi = 0; wi < 20; wi++) svc.advanceRain(0.1)
        svc.startEvent("binary"); svc.advanceRain(0.1)
        if (svc.swapSet === "" || svc.swapSet === svc.glyphSet || svc.activeEvent !== "" || svc.glyphRange.y === 177) throw new Error("Glyph swap picks another set")
        if (!svc.startEvent("scramble") || svc.activeEvent !== "scramble") throw new Error("Other events run during a glyph swap")
        for (wi = 0; wi < 105; wi++) svc.advanceRain(0.1); if (svc.swapSet !== "" || svc.glyphRange.y !== 177) throw new Error("Glyph swap ends after 10 s")
        // Typing ripples: a keypress adds one (while rendering); they age out; at most six.
        svc.setRainOption("typingAmount", 0.5); for (wi = 0; wi < 8; wi++) svc.keyRipple()
        if (svc.rendering && svc.ripples.length !== 6) throw new Error("Six ripples at most")
        for (wi = 0; wi < 20; wi++) svc.advanceRain(0.1); if (svc.ripples.length !== 0) throw new Error("Ripples fade")
        svc.setRainOption("typingAmount", 0); svc.keyRipple(); if (svc.ripples.length) throw new Error("Typing off")
        if (svc.typingWanted) throw new Error("No key hooks at 0%")
        if (JSON.parse(svc.statePayload()).typingAmount !== 0) throw new Error("Typing ripples start off")
        // Dive: the pack rushes forward at one speed; a layer that passes the
        // screen rejoins directly behind the last one; the camera stops and
        // the pack settles into the resting slots; it never goes dark.
        svc.setRainOption("depthLayers", 3); svc.setRainOption("depthLevel", 0.45)
        function restSet() { var a = []; for (var i = 0; i < svc.layerCount; i++) a.push(svc.layerDist(i).toFixed(4) + ":" + svc.distanceAlpha(svc.layerDist(i)).toFixed(4)); return a.sort().join() }
        var atRest = restSet()
        if (svc.layerCount !== 5 || svc.distanceAlpha(svc.layerDist(4)) > 1e-9 || Math.abs(svc.distanceAlpha(svc.layerDist(0)) - 1) > 1e-9) throw new Error("Rest: front, three depth layers, one hidden")
        var darkest = 1, sawPass = false, rejoinedBehind = 0, sameSpeed = true, movedBack = false
        svc.startEvent("dive")
        for (wi = 0; wi < 80 && svc.activeEvent !== ""; wi++) {
          var bef = [], befA = []
          for (var li = 0; li < svc.layerCount; li++) { bef.push(svc.layerDist(li)); befA.push(svc.layerAlpha(li)) }
          var inFlight = svc._eventT + 0.1 < svc.diveFlight
          svc.advanceRain(0.1)
          darkest = Math.min(darkest, svc.brightest())
          var moved = [], after = []
          for (li = 0; li < svc.layerCount; li++) after.push(svc.layerDist(li))
          for (li = 0; li < svc.layerCount; li++) {
            if (after[li] < 0.5 && svc.distanceZoom(after[li]) > 1.9) sawPass = true
            if (after[li] > bef[li] && inFlight) {
              var others = after.filter(function(x, k) { return k !== li })
              if (Math.abs(after[li] - (Math.max.apply(null, others) + svc.diveSpacing)) < 1e-9) rejoinedBehind++
            } else if (inFlight) moved.push(bef[li] - after[li])
          }
          if (moved.length > 1 && Math.max.apply(null, moved) - Math.min.apply(null, moved) > 1e-6) sameSpeed = false
          // Never backwards: a layer only moves closer; one that passed the
          // screen reappears behind the pack invisible and fades in.
          for (li = 0; li < svc.layerCount; li++)
            if (after[li] > bef[li] + 1e-9 && svc.layerAlpha(li) > 0.02) movedBack = true
        }
        if (movedBack) throw new Error("Dive never moves a visible layer backwards")
        if (svc.activeEvent !== "") throw new Error("Dive ends")
        if (darkest < 0.6) throw new Error("Dive never goes dark (" + darkest + ")")
        if (!sawPass || rejoinedBehind < 2) throw new Error("Passed layers rejoin directly behind the pack (" + rejoinedBehind + ")")
        if (!sameSpeed) throw new Error("The pack moves at one speed")
        if (restSet() !== atRest) throw new Error("After a dive the layers rest in the same slots")
        // Pan: nearer layers slide further (parallax), then back.
        svc.startEvent("pan"); svc.advanceRain(2.0)
        if (!(Math.abs(svc.layerPan(1, 1000)) > Math.abs(svc.layerPan(2, 1000)) + 50)) throw new Error("Pan parallax")
        for (wi = 0; wi < 30; wi++) svc.advanceRain(0.1); if (svc.pan !== 0) throw new Error("Pan ends")
        // Drift pulls streams apart and keeps its phase; Cascade sweeps and ends.
        var d0 = svc.driftPhase; svc.startEvent("drift"); for (wi = 0; wi < 40; wi++) svc.advanceRain(0.1)
        if (!(svc.driftPhase > d0 + 1) || svc.activeEvent !== "") throw new Error("Drift")
        svc.startEvent("cascade"); svc.advanceRain(1.0); var c1 = svc.cascadeT; svc.advanceRain(1.0)
        if (!(c1 > 0 && svc.cascadeT > c1)) throw new Error("Cascade sweeps")
        for (wi = 0; wi < 20; wi++) svc.advanceRain(0.1); if (svc.cascadeT !== 0) throw new Error("Cascade ends")
        // Chained events: with 100% another starts after one ends, at most three more.
        svc.setRainOption("chainChance", 1); svc.eventsOn = ["scramble"]; svc.startEvent("scramble")
        for (wi = 0; wi < 10; wi++) svc.advanceRain(0.1)
        if (svc._chainLeft !== 2) throw new Error("Chain counts down")
        svc.setRainOption("chainChance", 0); svc._chainLeft = 0
        // Glyph sets, head colour, back layers.
        if (svc.setRainOption("glyphSet", "wingdings") || !svc.setRainOption("glyphSet", "hex")) throw new Error("Glyph set option")
        if (svc.glyphRange.x !== 45 || svc.glyphRange.y !== 10 || svc.glyphRange.w !== 6) throw new Error("Hex = digits + A-F")
        svc.setRainOption("glyphSet", "katakana"); if (svc.glyphRange.y !== 45 || svc.glyphRange.z !== 64) throw new Error("Katakana ranges")
        svc.setRainOption("glyphSet", "hieroglyphs"); if (svc.glyphRange.x !== 328 || svc.glyphRange.y !== 24) throw new Error("Hieroglyphs")
        svc.setRainOption("glyphSet", "alchemy"); if (svc.glyphRange.x !== 352) throw new Error("Alchemy")
        // Custom: without checked symbols it draws the rain's own glyphs; a result sets it up.
        svc.setRainOption("glyphSet", "custom"); if (svc.customShown || svc.glyphRange.y !== 177) throw new Error("Empty custom falls back")
        svc.customResult('{"chars": "卐★", "count": 2, "rows": 1, "removed": [{"ch": "x", "why": "no installed font can draw it"}], "cleaned": [{"ch": "★", "what": "thickened"}]}')
        if (!svc.customShown || svc.glyphRange.x !== 0 || svc.glyphRange.y !== 2 || svc.customStatus.indexOf("★ thickened") < 0 || svc.customStatus.indexOf("left out x") < 0) throw new Error("Custom symbols in use")
        if (JSON.parse(svc.statePayload()).customChars !== "卐★") throw new Error("Custom saved")
        svc.customResult("garbage"); if (svc.customStatus.indexOf("Couldn't") !== 0 || svc.customCount !== 2) throw new Error("Bad result keeps the old symbols")
        svc.customCount = 0; svc.customChars = ""
        svc.setRainOption("glyphSet", "matrix")
        if (svc.setRainOption("headColor", "pink") || !svc.setRainOption("headColor", "white") || svc.headModeIndex !== 1) throw new Error("Head colour")
        svc.setRainOption("headColor", "look")
        // Colours per depth layer: slot k (distance 1 + k/n) wears layer k's colour,
        // the depth layers' colour, or the rain's; in between they blend.
        svc.setRainOption("depthLayers", 3); svc.setRainOption("depthLevel", 0.45); svc.layerSlots = []
        if (svc.layerPaletteAt(1.5) !== svc.rainPalette) throw new Error("Uncoloured layers use the rain")
        if (!svc.setRainOption("backColor", "cobalt") || svc.layerPaletteAt(1 + 1/3).body.b < 0.9 || svc.layerPaletteAt(1).body.g < 0.9) throw new Error("Depth layers colour")
        if (Math.abs(svc.layerPaletteAt(1 + 1/6).body.b - (svc.rainPalette.body.b + svc.backPalette.body.b) / 2) > 1e-6) throw new Error("Colours blend with depth")
        if (svc.setLayerColor(7, "ember") || svc.setLayerColor(2, "bogus") || !svc.setLayerColor(2, "ember")) throw new Error("Layer colour option")
        if (svc.layerPaletteAt(1 + 2/3).body.r < 0.9 || svc.layerPaletteAt(1 + 1/3).body.b < 0.9 || svc.layerPaletteAt(2).body.b < 0.9) throw new Error("Layer 2 is Ember, layers 1 and 3 Cobalt")
        if (JSON.parse(svc.statePayload()).layerColors[1] !== "ember" || svc.currentLook().layerColors[1] !== "ember") throw new Error("Layer colours saved")
        svc.setLayerColor(2, ""); svc.setRainOption("backColor", ""); svc.setRainOption("depthLayers", 1)
        // Only the Theme colour changes the theme; rain colours never do.
        svc.themeColor = ""; svc.applyRainColor("cyan"); if (svc.rainThemeSpec() !== "") throw new Error("Rain colours never set the theme")
        if (!svc.applyThemeColor("gold") || svc.rainThemeSpec() !== "#ffd84a") throw new Error("Theme colour")
        svc.applyRainColor("ember"); if (svc.rainThemeSpec() !== "#ffd84a") throw new Error("Rain colour leaves the theme alone")
        if (svc.applyThemeColor("daylight") || svc.applyThemeColor("theme") || svc.applyThemeColor("") || svc.themeColor !== "gold") throw new Error("Theme can't be Daylight, itself or empty")
        if (JSON.parse(svc.statePayload()).themeColor !== "gold") throw new Error("Theme colour saved")
        svc.themeFollowsRain = true
        var caught1 = svc.checkThemeCaughtUp("#ffd84a"), caught2 = svc.checkThemeCaughtUp("#000000")
        for (var c = 0; c < svc.resources.length; c++) if (svc.resources[c].interval === 1200) svc.resources[c].stop()
        svc.themeFollowsRain = false
        if (caught1 || !caught2) throw new Error("Theme catch-up")
        svc.themeColor = ""
        svc.applyRainColor("green")
        // Workspace rush: direction and a short sweep; idle drift; network.
        svc.workspaceSwitched(1); svc.workspaceSwitched(3); if (svc.wsDir !== -1 || svc.wsT !== 0) throw new Error("Workspace rush")
        svc.advanceRain(0.45); if (!(svc.wsKick > 0.3)) throw new Error("Workspace kick")
        if (svc.layerPan(1, 1000) !== 0) throw new Error("Workspace rush never slides sideways (only Pan does)")
        svc.advanceRain(1)
        if (svc.wsKick > 1e-6) throw new Error("Workspace kick ends")
        svc.idleSeconds = 600; if (Math.abs(svc.idleLevel - svc.idleDrift) > 1e-9) throw new Error("Idle level")
        svc.eventsOn = svc.eventNames.slice(); svc.wakeUp(); if (svc.idleSeconds !== 0 || svc.activeEvent !== "surge") throw new Error("Wake up surges")
        for (wi = 0; wi < 30; wi++) svc.advanceRain(0.1)
        svc._netPrev = null; svc.readNet("  lo: 99999 0\n eth0: 1000 0 0", 1000); svc.readNet("  lo: 9999999 0\n eth0: 20001000 0 0", 2000)
        if (svc._netPrev.rx !== 20001000) throw new Error("Network bytes")
        // Saved looks and share codes round-trip.
        svc.setRainOption("gravity", 0.4); svc.setRainOption("glyphSet", "runes")
        if (svc.saveLook("  Rune rain ") !== "Rune rain" || svc.savedLooks.length !== 1) throw new Error("Save look")
        svc.setRainOption("gravity", 0); svc.setRainOption("glyphSet", "matrix")
        if (!svc.recallLook("Rune rain") || svc.gravity !== 0.4 || svc.glyphSet !== "runes") throw new Error("Recall look")
        if (!svc.lookIs("Rune rain")) throw new Error("A recalled look is lit"); svc.setRainOption("gravity", 0.5); if (svc.lookIs("Rune rain")) throw new Error("A change unlights the look"); svc.setRainOption("gravity", 0.4)
        var code = svc.lookCode("Shared"); if (code.indexOf("MR1:") !== 0 || svc.readLookCode(code).glyphSet !== "runes") throw new Error("Look code")
        if (svc.readLookCode("MR1:!!!") || svc.readLookCode("hello")) throw new Error("Bad codes rejected")
        svc.setRainOption("gravity", 0); if (svc.importLook(code) !== "Shared" || svc.gravity !== 0.4 || svc.savedLooks.length !== 2) throw new Error("Import look")
        var saved2 = JSON.parse(svc.statePayload()); if (saved2.savedLooks.length !== 2 || saved2.glyphSet !== "runes" || saved2.eventsVersion !== 2) throw new Error("Looks saved")
        svc.applyStateText(JSON.stringify({eventsOn: ["dejavu"]})); if (svc.eventsOn.join() !== "dejavu,drift,cascade") throw new Error("New events join old lists")
        // Workspace looks: a saved look per workspace; your own look returns.
        svc.setRainOption("glyphSet", "matrix"); svc.applyRainPreset("classic")
        var mineSize = svc.letterSize
        if (svc.setWorkspaceLook(9, "look:Shared") || svc.setWorkspaceLook(2, "preset:storm") || svc.setWorkspaceLook(2, "look:Nope")) throw new Error("Bad workspace looks refused")
        if (svc.workspaceChoices().join() !== ",look:Rune rain,look:Shared") throw new Error("Workspaces offer only saved looks")
        svc.cycleWorkspaceLook(2, 1); if (svc.workspaceLooks["2"] !== "look:Rune rain") throw new Error("Cycle forward")
        svc.cycleWorkspaceLook(2, -1); svc.cycleWorkspaceLook(2, -1); if (svc.workspaceLooks["2"] !== "look:Shared") throw new Error("Cycle back wraps")
        svc.setWorkspaceLook(3, "look:Rune rain")
        svc.enabled = false   // not rendering: looks change at once instead of after a fade
        svc._lastWorkspace = 1; svc.workspaceSwitched(2)
        if (svc.glyphSet !== "runes" || svc.gravity !== 0.4 || !svc.workspaceBase) throw new Error("Workspace 2 uses Shared")
        svc.workspaceSwitched(3); if (svc.glyphSet !== "runes") throw new Error("Workspace 3 uses a saved look")
        svc.workspaceSwitched(4); if (svc.letterSize !== mineSize || svc.rainPreset !== "classic" || svc.glyphSet !== "matrix" || svc.workspaceBase) throw new Error("Your look comes back")
        svc.enabled = true
        if (svc.fromBase64(svc.toBase64("Rüne ✓ {x}")) !== "Rüne ✓ {x}") throw new Error("Base64 round trip")
        var wsSaved = JSON.parse(svc.statePayload()); if (wsSaved.workspaceLooks["2"] !== "look:Shared") throw new Error("Workspace looks saved")
        svc.deleteLook("Rune rain"); svc.deleteLook("Shared"); if (svc.savedLooks.length) throw new Error("Delete look")
        if (svc.workspaceLooks["3"] !== undefined) throw new Error("Deleting a look clears its workspace")
        if (svc.workspaceLooks["2"] !== undefined) throw new Error("Deleting a look clears workspace 2")
        svc.applyStateText(JSON.stringify({workspaceLooks: {"1": "preset:storm"}})); if (svc.workspaceLooks["1"] !== undefined) throw new Error("Old preset workspace choices dropped")
        svc.setRainOption("gravity", 0); svc.setRainOption("glyphSet", "matrix")
        // Events switched off never happen by themselves.
        svc.eventsOn = []
        if (svc.startEvent("") || svc.startEvent("", true) || svc.activeEvent !== "") throw new Error("No random event with every event off")
        svc.idleSeconds = 600; svc.wakeUp(); if (svc.activeEvent !== "") throw new Error("No wake-up surge with Surge off")
        svc.eventsOn = ["rewind", "surge"]; for (var ev = 0; ev < 40; ev++) { svc.startEvent(""); if (["", "rewind", "surge"].indexOf(svc.activeEvent) < 0) throw new Error("Random event not switched on: " + svc.activeEvent); svc.endEvent() }
        svc.startEvent("rewind"); svc.toggleEvent("rewind"); if (svc.activeEvent !== "") throw new Error("Switching an event off stops it")
        svc.eventsOn = ["binary"]; svc.startEvent("binary"); svc.toggleEvent("binary"); if (svc.swapSet !== "") throw new Error("Switching Glyph swap off stops it")
        svc.eventsOn = svc.eventNames.slice()
        // A chained glyph swap keeps the schedule going (it used to stop all events).
        svc.setRainOption("eventRate", "often"); svc.eventsOn = ["binary"]; svc.setRainOption("chainChance", 0)
        svc.startEvent("", true); if (!eventTimerRunning()) throw new Error("Schedule carries on after a chained glyph swap")
        function eventTimerRunning() { for (var c = 0; c < svc.resources.length; c++) { var r = svc.resources[c]; if (r.running && r.interval >= 60000) return true } return false }
        svc.setRainOption("eventRate", "off"); svc.swapSet = ""; svc.eventsOn = svc.eventNames.slice()
        svc.toggleSection("EVENTS"); if (svc.collapsedSections.join() !== "EVENTS" || JSON.parse(svc.statePayload()).collapsedSections[0] !== "EVENTS") throw new Error("Fold a section")
        // Events switched off never happen by themselves.
        svc.eventsOn = []
        if (svc.startEvent("") || svc.startEvent("", true) || svc.activeEvent !== "") throw new Error("No random event with every event off")
        svc.idleSeconds = 600; svc.wakeUp(); if (svc.activeEvent !== "") throw new Error("No wake-up surge with Surge off")
        svc.eventsOn = ["rewind", "surge"]; for (var ev = 0; ev < 40; ev++) { svc.startEvent(""); if (["", "rewind", "surge"].indexOf(svc.activeEvent) < 0) throw new Error("Random event not switched on: " + svc.activeEvent); svc.endEvent() }
        svc.startEvent("rewind"); svc.toggleEvent("rewind"); if (svc.activeEvent !== "") throw new Error("Switching an event off stops it")
        svc.eventsOn = ["binary"]; svc.startEvent("binary"); svc.toggleEvent("binary"); if (svc.swapSet !== "") throw new Error("Switching Glyph swap off stops it")
        svc.eventsOn = svc.eventNames.slice()
        svc.toggleSection("EVENTS"); if (svc.collapsedSections.length) throw new Error("Unfold a section")
        svc.eventsOn = svc.eventNames.slice()
        svc.applyRainPreset("classic"); if (svc.crtAmount !== 1) throw new Error("Classic runs on a full CRT")
        function walk(item) {
          if (item.children) for (var j=0;j<item.children.length;j++) walk(item.children[j])
        }
        window.validateLayout = walk
        console.log("MATRIX_QML_PASS")
        capture.start()
      }
    }
    Timer { id: capture; interval: 350; onTriggered: {
      window.validateLayout(panel)
      finish.start()
    } }
    Timer { id: finish; interval: 100; onTriggered: panel.grabToImage(result => {
      if (!result.saveToFile(Quickshell.env("MATRIX_PREVIEW"))) throw new Error("Capture failed")
      console.log("MATRIX_CAPTURE_PASS"); Qt.quit()
    }) }
  }
}
''')
    env=dict(os.environ,HOME=str(tmp/'home'),XDG_STATE_HOME=str(tmp/'home/.local/state'),
      XDG_CONFIG_HOME=str(tmp/'home/.config'),XDG_RUNTIME_DIR=str(tmp/'runtime'),
      QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',QT_QPA_PLATFORMTHEME='basic',
      PATH=str(tmp/'bin')+os.pathsep+os.environ['PATH'],MATRIX_PREVIEW=str(args.output.resolve()),MATRIX_WIDTH=str(args.width),MATRIX_HEIGHT=str(args.height),MATRIX_THEME=args.theme,QT_SCALE_FACTOR=args.scale)
    for key in ('HYPRLAND_INSTANCE_SIGNATURE',): env.pop(key,None)
    try:
        p=subprocess.run(['quickshell','-p',str(tmp),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=15)
    except subprocess.TimeoutExpired as error:
        out=error.stdout.decode() if isinstance(error.stdout,bytes) else error.stdout; print(out)
        raise
    print(p.stdout)
    assert p.returncode==0 and 'MATRIX_QML_PASS' in p.stdout and 'MATRIX_CAPTURE_PASS' in p.stdout
    assert 'TypeError:' not in p.stdout and 'ReferenceError:' not in p.stdout and 'Error:' not in p.stdout
