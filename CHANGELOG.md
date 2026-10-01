# Changelog

## Look codes carry Custom glyphs (2026-09-30)

- Copy code on a Custom look puts the drawn symbols and pictures in the
  code (a greyscale PNG strip, no file paths), and Paste code brings them
  back exactly, as finished glyphs saved under the state folder's shared/.
- Saved looks keep their own Custom symbols and pictures and redraw them
  when recalled.

## See-through windows per workspace (2026-09-29)

- Workspaces → See-through: how see-through each workspace's windows are,
  through runtime Hyprland window rules (not written to config, removed on
  unload). Windows Omarchy keeps opaque stay opaque.
- Panel order: Weather, Look, Colour, Reactions, Events, Workspaces,
  Fullscreen.

## Clearer pictures, letters up to 200 px (2026-09-29)

- Pictures as glyphs keep their detail: the subject is found by how its
  colours differ from the background, with its light and dark kept, and no
  hairline thickening. Pictures no longer there drop off the list.
- Letter size goes up to 200 px (was 100).
- Every rain slider has − and + buttons that step by exactly one unit (1 px,
  1 layer, or 1%).
- Small pictures are enlarged and sharpened when it measures crisper (an AI
  upscale with realesrgan-ncnn-vulkan if installed); custom glyphs are drawn
  at 256 px cells.

## Chain delay, pictures as glyphs (2026-09-29)

- Chained events come 5 seconds after the previous one (wallpaper and
  screensaver); a chained Glyph swap starts at once, and the chain carries on.
- Custom glyphs take pictures too, chosen with Add pictures… in the file
  picker (opens in Downloads; right-click a picture to remove it),
  turned into one-colour glyphs from their transparency or their drawing
  against the background, cleaned up like symbols.

## Get Sound Lab (2026-09-29)

- Reactions shows whether Sound Lab is installed and on, with Get Sound Lab
  (runs `omarchy plugin add`) or Turn on Sound Lab when it isn't.

## Heads per layer (2026-09-29)

- The Heads row follows Colour for: the rain, all depth layers ("Same as the
  rain"), or one layer ("Same as all layers"). Saved in looks and codes; the
  screensaver follows them too.
- Fixed: the screensaver drew Accent heads in the body colour.

## Five unusual colours, letters up to 100 px (2026-09-29)

- New singles: Eclipse (near-black, gold heads), Blacklight (indigo, neon
  yellow heads), Copper (trails age into verdigris), Ivory and Mustard, each
  at least 21 apart from every other colour.
- Letter size goes up to 100 px (was 28), in the wallpaper and screensaver.

## Rearrange saved looks (2026-09-28)

- Drag a saved look to move it; an accent bar shows where it lands. Click
  still loads it, right-click twice still deletes it. The order is saved.
- Saved looks (and look codes) include the Theme colour, which comes back when
  you load the look (not on workspace switches). Saving over a look's name
  keeps its place.

## Forest and eight more singles (2026-09-28)

- New gradient Forest: leaf green at the top, deeper green, bark brown, then
  grey-brown stone (some streams darker).
- New singles Amber, Chocolate, Wine, Hot Pink, Orchid, Navy, Teal and Pine,
  each at least 23 apart from every other colour (CIE Lab). "teal" is its own
  colour again instead of an old name for Cyan.

## Depth layers (2026-09-28)

- Depth layers can be 0 (off), and the slider always shows.
- Colour for → Depth layers always offers Layer 1 on its own, even with a
  single layer.
- Saved looks wrap onto more lines so their names show in full.

## Ready to share (2026-09-28)

- Typing ripples start off on new installs (they add key hooks).
- Public repository: https://github.com/edtruitt-cloud/omarchy-matrix-rain. README, release notes and marketplace draft
  describe the rain-only plugin; Sound Lab is an optional companion.
- Removed the synth-era docs and evidence, and an unused panel file.

## Hieroglyphs, Alchemy and Custom glyphs (2026-09-27)

- New glyph sets: Egyptian hieroglyphs and alchemical symbols (atlas blocks
  after the existing ones, which are unchanged).
- Custom: type your own symbols, any you like. Each is drawn as one colour
  (emoji keep their detail as shading), hairlines thickened and specks
  removed so it reads as rain; only symbols no font can draw are left out.
  Runs locally, nothing is sent anywhere.
- The glyph styles are two even rows in Look.

## Weather is just the presets (2026-09-27)

- Weather holds the preset buttons, your saved looks and the name / Save
  look / Copy code / Paste code row; every slider moved to Look. Changing
  them still deselects the preset.

## More, and more different, colours (2026-09-27)

- Singles: Frost is gone (it sat between Cobalt and Cyan; saved looks move to
  Cyan); Venom is a toxic lime instead of a second green; Cobalt is deeper and
  Cyan a truer aqua. New: Rose, Lavender, Mint, Moss, Rust and Noir. A test
  keeps every pair of single colours clearly apart (CIE Lab distance >= 20).
- Multi-colour: new Candy, Siren, Holly, Ice & Fire, Ink, Lava, Synthwave and
  Galaxy (16 in all).

## Gravity fills the screen evenly (2026-09-27)

- Gravity bunched the rain at the top and, through the trail wrap, the bottom
  (36% of it in the bottom fifth, 11% in the middle at 100%). It is now
  measured in time: streams still speed up as they fall and their trails
  stretch, but every fifth of the screen gets about 20%. Streams start
  moving at the top (up to 4x faster at the bottom at 100%) instead of
  from rest, which crushed the top rows. Fixed: zoomed-out depth layers
  drew a block of white glyphs at the top with Gravity on (rows above the
  screen fell outside the gravity curve).

## Switched-off events never happen (2026-09-27)

- With every event off, no random event happens (it used to pick from all).
- The idle wake-up surge only happens with Surge switched on.
- Switching an event off while it's running stops it (Glyph swap too).
- Right-click preview and IPC eventNow still start any event on request.
- Fixed: a chained Glyph swap stopped all later events (wallpaper and
  screensaver).
- The status IPC lists the last events and what started them (eventLog).
- Workspace rush no longer slides the rain sideways (that looked like Pan);
  it is a short rush down only.

## Panel layout (2026-09-27)

- Shape and light sliders (trail/speed variety, gravity, mirrored, weight,
  head glow, bloom, colour fringe, vignette) are weather settings now: every
  preset sets them to the plain look, and changing one deselects the preset.
- Look (glyphs) sits above Workspaces; Workspaces is one line of chips that
  step through saved looks only (presets there are dropped).
- Section headings fold their section (remembered); chip rows never wrap.

## Screensaver: colour per depth layer (2026-09-27)

- The screensaver uses the per-layer colours: its depth slices pass from the
  rain's colour (nearest) through Layer 1, Layer 2… to the last layer
  (farthest), blending in between, so colours travel as the slices rush
  forward. The distant haze takes the farthest layer's colour.
- Fixed: lists in state.json (layer colours, events, wallpaper colours) reach
  the screensaver as Qt sequences, which the old array checks ignored.

## Simpler panel (2026-09-27)

- Text in the rain (clock and messages) removed, from the wallpaper and the
  screensaver.
- The panel's explanation paragraphs are gone (only short status lines stay),
  and the panel is twice as wide (800 px).

## Only Theme changes the theme (2026-09-27)

- Rain colours never change the Omarchy theme; only Colour for → Theme does.
  Follow the rain is gone. On start, a Theme colour that didn't get applied
  (picked just before a shell restart) is applied.

## Fixed weather, glyph swap, typing ripples (2026-09-27)

- Weather presets are fixed: changing a Weather-section setting deselects the
  preset; picking it restores it exactly (presets saved with tweaks go back
  to their real values). Trail length, glyph flicker, CRT and the depth
  settings moved into the Weather section. Storm has three depth layers.
- Binary is now Glyph swap: another random glyph style for 10 seconds, on its
  own clock so other events can happen at the same time (wallpaper and
  screensaver).
- Typing ripples: each keypress sends a ring of lit letters through the rain,
  via pass-through Hyprland binds that only report that a key was pressed.

## Glyphs, light, text and more reactions (2026-09-27)

- Glyph sets (Katakana, Binary, Digits, Hex, Latin, Greek, Runes, Braille,
  Box lines), appended to the atlas after the original 177 glyphs, which are
  unchanged. Mirrored glyphs and glyph weight.
- Gravity, speed variety and trail variety.
- Head glow, bloom, colour fringe, vignette; head colour; own colour for the
  depth layers; Daylight and Wallpaper colours.
- Text in the rain: the clock and your messages.
- Mouse parting, workspace rush, idle drift, download pull.
- Drift and Cascade events (switched on in saved event lists), chained events.
- Saved looks and shareable look codes.
- Colour for each depth layer, and a Theme colour of its own (Colour for →
  Theme; Follow the rain goes back).
- A look per workspace (1–5): a weather preset or saved look, switched with
  a short dip; your own look returns elsewhere.

## Sound Lab split (2026-09-27)

- The synth is now its own plugin, Sound Lab (`ertiv.sound-lab`). Matrix Rain
  is the rain only; its panel is one column.
- Rain link: Matrix Rain serves `$XDG_RUNTIME_DIR/ertiv-matrix-rain-link.sock`.
  Sound Lab sends play state, tempo, LFO and kick beats (Beat flash, Tempo
  pull and the LFO's speed/density/size destinations use them); Matrix Rain
  sends each rain event, and the music reacts.
- Reactions shows whether Sound Lab is connected.
- Removed: `technoPlay`/`technoStop` IPC (use `omarchy-shell sound-lab play`).

## 1.0.0 — initial release candidate (unpublished)

- Digital rain with per-monitor fullscreen pause and integrated fall velocity.
- Generative stereo synth, per-track directions, 3:4 drums, sound snapshots,
  effects and local WAV recording.
- Session-only playback; no automatic changes to other wallpaper apps.
- Portable tests, reproducible assets and source-only optional screensaver.

### Rain improvements (2026-09-23)

- Extended 177-glyph atlas; grid size is generated into `atlas.js` instead of
  being hardcoded in QML.
- Rain phase wraps every 256 units on whole fall cycles, keeping shader float
  precision over long sessions without a visible jump.
- Fullscreen pause reads Quickshell's native Hyprland workspace state instead of
  starting Python and `hyprctl` on window events.
- Rain colour: classic green, Omarchy theme accent, presets or `#rrggbb`
  (panel and `setColor` IPC).
- `scripts/install-local` syncs a checkout to the installed plugin.
- Midpoint dials on the size, speed and density sliders (removed again on
  2026-09-26).

### Screensaver catches up (2026-09-27)

- All colour looks (multi-colour, gradients, rainbow, variation), trail
  length, glyph flicker and CRT; the lit events happen during it (--event
  previews one).

### Depth quality, Do Not Disturb (2026-09-27)

- Layers behind the front draw together into one reduced-resolution buffer
  (Depth quality: Sharp / Balanced / Fast). Storm with 5 layers at 4K went
  from ~43% to ~24% GPU (Balanced); layers near the front stay sharp.
- Notification bursts are skipped while Omarchy's Do Not Disturb is on.
- benchmark-rain.py measures Classic, Storm per quality, and Storm without depth.

### Dive conveyor; the wheel only scrolls (2026-09-27)

- Rain layers sit at depths, scaled by camera zoom, with one hidden layer
  behind. Dive flies them forward as one tight pack at one speed; a layer that
  passes the screen fades back in directly behind the last one; the camera
  then eases to a stop and the pack settles into its resting slots.
- The mouse wheel never changes a slider or knob in either panel.
- Dive ends by coasting forward only (layers in front fly on through the
  screen into the back slots); rejoining layers fade in. Events: frequency
  chips on one line, no Try one button, right-click an event to see it.

### More events, Fire back, wind removed (2026-09-27)

- New events: Surge, Binary (0s and 1s), Dive (camera flies forward through
  the depth layers) and Pan (camera slides past them with parallax).
- Fire is back as a gradient. Wind and gusts removed.

### Wind physics and rain events (2026-09-27)

- Wind and Gusts drive a light spring-damper wind whose gusts travel down the
  screen, bending and swaying the rain (replaces the fixed wind/waves).
- Events: Déjà vu, Rewind, Bullet time, Scramble, Blackout and Glitch happen
  now and then (chosen set and rate); déjà vu's old rate carries over.
- Glow and lightning removed. CRT is part of the presets; Classic uses 100%.

### Fewer, more distinct colours; effects (2026-09-27)

- Removed look-alike colours (Amber, Rose, Teal, Toxic; Cyberpunk, Candy,
  Fire, Dusk); Glitch is now mostly green with the odd red or white stream.
  Saved choices move to the closest remaining look.
- Effects: glow, wind slant, waves, CRT scanlines/vignette and lightning,
  each with a setting; all are no-ops at 0 / off.

### Storm depth, Ocean gradient (2026-09-27)

- Storm's depth layers at 20% visibility.
- Ocean is a gradient: white at the very top, blues darkening downwards, with
  a few darker streams (per-look colour variation). Gradients keep their exact
  colours; a white or grey colour never leads a theme.

### Whole-look weather and distinct colours (2026-09-27)

- Weather presets set size, speed, density, trail, flicker and depth, with
  your values for Drizzle, Storm and Terminal and a film-matched Classic.
  Tweaks cover every one of them; older tweaks are cleared once.
- Single colours reworked into 15 distinct head/body/tail looks (several shift
  hue along the trail) replacing near-duplicate shades; old names migrate.

### Many more colours and up to 5 depth layers (2026-09-27)

- 19 more single colours and 12 multi-colour looks (per-stream mixes,
  rainbow, gradients) with swatch chips; each builds its own Omarchy theme
  (multi-colour: border gradient, terminal families, split-toned wallpaper).
- Depth layers: 1–5 extra layers behind the main rain.

### Rain panel: amounts instead of switches (2026-09-27)

- Wider rain column (380 px) with one-line sliders and section headings.
- Every toggle-plus-bar became a single 0–100% amount (0% = off): depth,
  beat flash; tempo, notification burst and CPU became amounts too. Déjà vu
  and fullscreen are chip choices. Old switches migrate.
- The "Set Omarchy theme" switch is gone: the rain colour always sets it.
- New: trail length, glyph flicker and depth size. Beat flash 25% stronger.

### Weather presets, depth layer and reactions (2026-09-27)

- Weather presets (Drizzle, Classic, Storm, Terminal) that remember your
  slider tweaks; earlier settings become Classic.
- Depth layer: a smaller, slower, dimmer rain layer behind (seeded shader).
- Reactions: beat flash timed to the audible kick, speed following tempo,
  notification bursts (session-bus watch, no content read), CPU-load speed,
  and an optional déjà vu replay. All have settings in the rain panel.

### Slider fixes and −/+ buttons (2026-09-27)

- Sliders no longer keep following the pointer after the mouse button is
  released outside the panel (plugin-local MatrixSlider, adapted from
  Omarchy's PanelSlider).
- − / + fine-tuning buttons beside Tempo and every volume: always exactly
  1 BPM or 1% (into the boost); the full synth's BPM buttons also step by 1.
- Ambient's bass and Juno 15% louder at base; the engine's Juno and drone
  caps raised from 1.0 to 1.5 so presets and the volume boost are not cut off.

### Per-mood volumes and tempo, volume boost (2026-09-26)

- Volumes and tempo are remembered per mood; earlier volumes become every
  mood's starting point. Tempo slider (BPM) in the Background view.
- Each volume has a separate boost bar, up to 120%, once the main bar is full.

### A volume for every part (2026-09-26)

- Kick, Hat, Clap, Shaker, Bass, Juno and Drone each have a saved volume
  (row sliders in the full synth, Levels in the Background view), kept out
  of moods, saved sounds and variations. Replaces the Drums/Bass/Drone
  sliders; the drum slider's half-level rescale is undone.
- Shaker and clap raised to about 4 and 5 dB under the hat (they were
  inaudible); shaker filter opened from 6.5 to 4 kHz.

### Percussion rows, drone volume, linear rain sliders (2026-09-26)

- Clap and Shaker rows in the full synth (editable, mutable, each with its
  own Forward / Ping-pong playhead) and a Fill switch; Drone volume in Levels.
- Removed the rain sliders' midpoint dials; the sliders are linear again.

### Background percussion and bass volume (2026-09-26)

- Quiet clap on beats 2 and 4, shaker on the "and"s, and a shaker fill every
  8 bars, under the kick/hat beat.
- Drum volume rescaled: 100% now plays at the old 50% (saved levels keep
  their loudness). Bass volume slider. Saved sounds store the mood's own
  levels, not the volume sliders.

### Steady drums and drum volume (2026-09-26)

- Every mood now uses kick on beats 1 and 3, hat on 2 and 4 (the Ambient
  beat); the busier per-style patterns clashed with the music.
- Drum volume slider (Background view and full synth), saved.
  It replaces the Drums on/off switch (off migrates to 0%).
- Acid bassline no longer jumps to the high G in the middle of the bar.

### Background music view (2026-09-25)

- The synth opens in a simple view: Play, volume, five moods with short
  descriptions, a saved Drums switch and Keep it changing (Evolve). The full
  synth is unchanged behind "Full synth →".

### Screensaver follows the rain settings (2026-09-25)

- The screensaver reads the saved rain colour, letter size, fall speed and
  density at launch; colours come from `rainpalette.js`, shared with the
  wallpaper. `install-local` rebuilds the screensaver binary when needed.

### Rain colour sets the Omarchy theme (2026-09-24)

- `tools/rain-theme.py` builds a Matrix Rain theme recoloured from the Matrix
  theme (or a built-in palette) and applies it; Green restores Matrix.
- "Set Omarchy theme" toggle, debounced, never triggered by the Theme colour.

### Synth improvements (2026-09-23)

- Audio queue cut from ~420 ms to ~125–155 ms (8 KiB player pipe); step
  display now follows the audible step instead of the rendered one.
- LFO and chorus phases run continuously, so rate changes no longer jump.
  Cutoff, resonance, drive, Juno filter, LFO depths and layer levels ramp
  across each block (tested: about a third of the zipper energy).
- Six named sound slots in `sounds.json` with overwrite confirmation, undo,
  rename and migration of the old single snapshot. State reads allow 64 KiB,
  and unreadable state/sound files are backed up as `*.bad`, not replaced.

### Pre-publication improvements

- Graceful audio teardown and per-block WAV header flushing; verified Stop,
  disable and reload inside the live Omarchy shell.
- Freeze inactive shader uniforms and window updates; stop the clock when all
  outputs are paused/fullscreen.
- Actionable player, PipeWire and recording errors near the transport controls.
- Responsive tabs, step grids and effects; light/dark surfaces and contrast.
- Cache block-constant synthesis calculations and filter coefficients; unroll
  the ladder update without changing the tested PCM output.
