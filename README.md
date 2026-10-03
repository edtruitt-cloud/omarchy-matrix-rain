# Matrix Rain

Digital rain wallpaper for Omarchy / Quickshell, with weather presets, colour
looks (one of which can recolour your Omarchy theme), depth layers, reactions and rain events.
Click **ア** in the bar for the settings; right-click it to pause.

Matrix Rain works on its own. It can also pair with **Sound Lab**
(`ertiv.sound-lab`), an optional companion synth plugin that isn't published
yet; when both run they talk to each other, see [Sound Lab link](#sound-lab-link).

## Requirements and installation

Requires Omarchy 4 Quattro with Quickshell, Qt 6 and Hyprland. Local validation
uses Omarchy 4.0.3-1; see [release notes](docs/RELEASE.md) for what was tested.
Python 3, Bash and GNU coreutils are required. Optional: `python-pillow` for
Custom glyphs and ImageMagick for the Wallpaper colour (both on a standard
Omarchy install), `dbus-monitor` for Notify burst. No pip packages,
accounts, network services or API keys are used.

Install from the public repository:

```bash
omarchy plugin add https://github.com/edtruitt-cloud/omarchy-matrix-rain.git --enable
omarchy bar put ertiv.matrix-rain --section right
```

Use Setup > Plugins to enable the plugin, and the bar settings to place its
widget if needed. It draws a background layer on each monitor. Disable any
other animated wallpaper yourself if they overlap.

```bash
omarchy plugin update ertiv.matrix-rain
omarchy plugin remove ertiv.matrix-rain
```

Removal unloads the wallpaper. Settings in `~/.local/state/ertiv.matrix-rain/`
are deliberately retained. Delete those folders manually only if you no longer
want their contents. The plugin does not edit your Hyprland or idle settings.

## Development

Run `./tests/run` for portable validation, and
`omarchy plugin validate .` on Omarchy. Run `python3 scripts/check-qml.py` for
an isolated headless panel check and preview (requires installed Omarchy/Qt).
It accepts `--width`, `--height`, `--theme light`, `--scale 1.5` and
`--output` for layout tests.
`python3 scripts/check-live.py` performs a reversible live-shell test with a
temporary plugin and a brief fullscreen test window. It restores
focus and its own configuration entries, retaining recovery files in `build/live`.
`python3 scripts/benchmark-rain.py` briefly runs a real Wayland rain service and
reads its CPU/GPU counters (results in `docs/evidence/rain-performance.json`).
Rebuild shader packs with `./scripts/build-shaders` (`qt6-shadertools`).
Rebuild the atlas with `python3 scripts/build-atlas.py` (`python-pillow` and
`noto-fonts-cjk`, development only); it also writes `atlas.js`, which the rain
and screensaver read for the grid size. `./scripts/install-local` copies this
checkout over the installed plugin (backing it up to `build/`) and reloads it. See [third-party notices](THIRD_PARTY.md).

Report reproducible bugs through the public repository's Issues once published.
Include Omarchy version, error text, and reproduction steps; omit private state.
See [SECURITY.md](SECURITY.md) for execution and data boundaries.

## Panel and theme

The panel (800 px wide) holds every rain setting in one scrolling column; click a section heading to fold it away. Rows of chips never wrap: they share the line instead. **Theme** follows your Omarchy
accent (brightened for the black background); classic green is the default.
Rain colours never change the desktop theme. Only **Colour for → Theme** does,
a moment after you pick a colour there: Green re-applies the Matrix theme, and any
other colour applies **Matrix Rain**, a copy of the Matrix theme recoloured to
match (accent, borders, terminal greens, lock screen, backgrounds duotoned).
Alarm reds and the yellow keep their colour. The Matrix theme itself is never
edited, and without it a built-in Matrix palette is used. After applying the theme the Omarchy shell restarts so the
bar, panels, lock screen and wallpaper all reload with it (terminals restart too,
as `omarchy theme set` always does). Clicking several colours quickly applies
only the last one. Problems are written to `~/.local/state/ertiv.matrix-rain/theme.log`. Recoloured images are cached in `~/.cache/ertiv.matrix-rain/`.

Pause freezes the image without continuing shader updates. Fullscreen pause
applies to each output; the animation clock stops when no output needs it.

Settings persist in `~/.local/state/ertiv.matrix-rain/state.json`. If it
cannot be read, it is kept as `state.json.bad` rather than overwritten.

## Weather, look and reactions

The rain panel uses one-line sliders; for every effect, 0% means off. In both
panels the mouse wheel only scrolls; it never changes a setting.

- **Weather** presets are fixed and set everything in the Weather section:
  letter size, fall speed, density, trail length, glyph flicker, CRT and the
  depth settings. Changing any of those makes it your own mix (no preset is
  lit); tap a preset to get it back exactly:
  - *Drizzle*: 22 px, slow (0.10), sparse (50%), short trails, slow flicker,
    one soft depth layer.
  - *Classic*: as close to the film as it gets: 16 px, a dense sheet (85%) with
    long fading trails (135%), busy glyphs, a faint hint of depth, full CRT.
  - *Storm*: 14 px, fast (0.60), full density, longest trails, fastest flicker,
    three depth layers at 20%.
  - *Terminal*: 6 px at full speed, 85% density, one faint layer.
- **Look**: *Trail length* (50–200%), *Glyph flicker* (how fast characters
  change; 0% freezes them), *CRT* (scanlines and darker corners), *Depth layer* (visibility of the rain behind),
  *Depth layers* (1–5 extra layers, 2–6 in total; farther ones are smaller,
  slower on screen and dimmer; one more waits hidden for Dive) and *Depth size* (the farthest layer's letter size). Each
  layer draws the rain again; *Depth quality* (Sharp, Balanced, Fast) draws the
  layers behind the front together at reduced resolution. Measured at 4K on
  this machine: Storm with 5 layers uses about 43% of the GPU's graphics engine
  on Sharp, 24% on Balanced (default) and 22% on Fast; Classic about 12%.
- **Colour**: 33 single looks and 17 multi-colour looks, each clearly
  different (the test suite checks every pair of single colours). Single looks
  have their own head, body and tail, some shifting hue along the trail:
  Green, Theme, Daylight, Wallpaper, Gold, Amber, *Ember* (yellow to orange
  to red), Blood, Rust, Chocolate, Wine, Rose, Hot Pink, *Plasma* (magenta to
  blue), Orchid, Lavender, Violet, Cobalt, Navy, Cyan, Teal, Mint, Pine,
  *Venom* (toxic lime), Moss, Mustard, *Copper* (trails age into verdigris),
  Sepia, Ivory, Ghost, *Noir* (charcoal with white heads), *Eclipse* (near-black
  with gold heads, like sparks) and *Blacklight* (indigo with neon yellow heads). Multi-colour, per stream: *Rainbow* (hues drift across),
  *Neon*, *Vapor*, *Glitch* (mostly green with the odd red or white stream),
  *Candy* (red and white), *Siren* (red and blue), *Holly* (red and green),
  *Ice & Fire* (orange and blue), *Ink* (white and greys); gradients down the
  screen: *Fire*, *Lava* (dark at the top, glowing at the bottom), *Sunset*,
  *Synthwave* (cyan, pink, deep purple), *Aurora*, *Ocean* (white at the very
  top, blues darkening downwards), *Forest* (leaf green, deeper green, bark
  brown, grey-brown stone) and *Galaxy* (purple, magenta, blue, with
  dark streams). Picked for the Theme, a look recolours the Omarchy theme: its extra colours go
  to the window border gradient, the terminal's cyan/blue/magenta families and
  a split-toned wallpaper. As a rain colour, *Theme* follows your current theme. Removed or
  renamed colours move to the closest current look.
- **Reactions**: *Beat flash* brightens streams on each audible kick and *Tempo
  pull* moves fall speed toward the song's tempo while Sound Lab plays.
  *Notify burst* is a rush of brighter, faster rain whenever any app sends a
  notification (not while Do Not Disturb is on) (watched on the session bus with `dbus-monitor`; only the fact
  that one was sent is used, never its content). *CPU pull* speeds the rain
  with system load (read from `/proc/stat` every 2 seconds while visible).
- **Events** happen to the rain now and then (Off, Rare, Sometimes, Often; one
  of the lit events at random; tap an event to switch it, right-click to see
  it now): *Déjà vu* replays a
  moment three times, *Rewind* runs the rain backwards, *Bullet time* slows it
  nearly to a stop and back, *Surge* rushes it, *Scramble* churns every glyph,
  *Glyph swap* changes every glyph to another random style for 10 seconds
  (other events can still happen meanwhile; it's `binary` in IPC), *Blackout* fades it out and back,
  *Glitch* tears bands sideways and shifts their colour, *Dive* flies forward
  through the layers (they rush toward you as one tight pack; each one that
  passes the screen fades back in directly behind the last one while the dive
  goes on; then it coasts forward into its resting places, never moving back),
  and *Pan* slides past them with parallax.
  Dive and Pan look best with a few depth layers.
- **My looks**: *Save look* keeps the weather, glyphs, light and colours (including the Theme colour) under
  a name (up to 12); tap one to use it, drag it to move it, right-click twice to delete it. *Copy
  code* puts the current look on the clipboard as an `MR1:` code; *Paste code*
  adds a look from the clipboard. A Custom look's code carries the drawn
  symbols and pictures themselves (never your file paths), so whoever pastes
  it sees the same glyphs; they show up as *shared* picture chips. Saved
  looks remember their own Custom glyphs too.
- **Workspaces → See-through**: pick a workspace (1–5) and set how
  see-through its windows are (0% = off), so the rain shows through. Done
  with Hyprland window rules added at runtime (`hyprctl eval`), never written
  to your config and removed when the plugin unloads; windows Omarchy keeps
  opaque (picture-in-picture, Steam, …) stay opaque. Whole windows fade,
  text included.
- **Workspaces**: one chip per workspace (1–5). Tap it to step through your
  saved looks (right-click steps back); *Your look* keeps whatever you have.
  The rain dips and changes as you switch; the desktop theme is left alone.
- **Glyphs**: Matrix (the rain's own mix), Katakana, Binary, Digits, Hex,
  Latin, Greek, Runes, Braille, Box, Hieroglyphs, Alchemy or Custom. Custom
  takes your own symbols and pictures (up to 48 together), any you like.  *Add
  pictures…* opens the file picker (zenity) in Downloads to choose images
  (PNG, JPEG, WebP, GIF, BMP, SVG); right-click a picture's chip to remove it: `tools/custom-glyphs.py`
  draws each one an installed font can draw in the rain's tall style, as one
  colour (emoji keep their detail as shading), thickening hairline strokes
  and removing specks so it reads at rain sizes, into
  `~/.local/state/ertiv.matrix-rain/custom-glyphs.png`. Small pictures are enlarged and sharpened when that measures crisper
  (with `realesrgan-ncnn-vulkan` installed, they get an AI upscale first).
  Custom glyphs are drawn at twice the rain atlas's resolution. It runs locally.
  Needs `python-pillow`. The screensaver shows the rain's own glyphs for Custom. *Mirrored* flips a share of the
  glyphs, *Glyph weight* makes them bolder.
- **Motion**: *Gravity* speeds streams up as they fall; *Speed variety*
  (0–200%) and *Trail variety* (0–300%) spread stream speeds and trail lengths
  (100% is the original).
- **Light**: *Head glow*, *Bloom* (a soft halo), *Colour fringe* (red/blue
  edges) and *Vignette*. *Heads*: the look's own, white, the body colour or the
  theme accent, for the rain, all depth layers or one layer (it follows
  *Colour for*). *Colour for* chooses what the colour chips paint: *The rain*,
  *All depth layers*, one layer (*Layer 1* is just behind the rain; colours
  blend between layers and travel with them in a Dive), or *Theme*, the only
  way to change the Omarchy theme (Theme and Daylight aren't offered there).
- **More colours**: *Daylight* follows the time of day; *Wallpaper* takes the
  strongest colours of the current wallpaper (tap again to re-read it). Wallpaper
  can also be picked for the Theme.
- **Typing**: every keypress sends a ripple of lit letters through the rain.
  While it's above 0%, `tools/typing-keys.py` adds pass-through Hyprland binds
  for the typing keys (letters, digits, punctuation, with and without Shift;
  combinations you bind yourself are skipped) at runtime with `hyprctl eval`.
  They only emit `custom>>ertiv-matrix-rain:key`, the same for every key, so
  the rain learns that a key was pressed, never which one; keys still reach
  your apps. Nothing is written to your Hyprland config; 0% (or removing the
  plugin) takes the binds away. `omarchy-shell matrix-rain rippleTest` shows one.
- **More reactions**: *Mouse* parts the rain around the cursor on the desktop;
  *Workspace rush* sends a short rush through it when you switch workspace (it only ever falls down); *Idle drift* slows and dims it
  while you're away (Wayland idle, 1 minute) and sets off a surge when you come
  back. Downloads thicken it a little (from `/proc/net/dev`, always on).
- **More events**: *Drift* pulls some streams ahead and holds others back;
  *Cascade* lights every letter in an uneven wave. *Chain events* lets one
  event set off another, up to four in a row, 5 seconds apart (a chained
  *Glyph swap* starts at once).
- **Fullscreen**: *Pause rain* or *Keep falling* while a window is fullscreen.

## Optional screensaver

The source-only `screensaver/` companion provides a 3D walk through falling code.
It is separate from the shell plugin. Build and preview it manually:

```bash
./screensaver/build
./screensaver/launch --windowed --preview 8
```

It follows the rain settings saved by the plugin each time it starts: every
colour look (including multi-colour and Theme), letter size (glyph size), fall
speed (walking pace), density, trail length, glyph flicker and CRT. The lit
events happen during it too, at the chosen rate scaled for shorter sessions
(Dive rushes forward through the rain; Pan drifts sideways). With default
settings it looks as before. `./screensaver/launch --windowed --preview 8
--event dive` previews an event.

Requires a C++ compiler, pkg-config, Qt 6 development libraries, and OpenGL.
It does not configure idle timing, change your lock policy, or hide the cursor.
It is a visual effect, not a screen locker. Automatic idle integration is not
part of this release.

## Wallpaper IPC

```
omarchy-shell matrix-rain setLetterSize 16
omarchy-shell matrix-rain setSpeed 0.15
omarchy-shell matrix-rain setDensity 0.75
omarchy-shell matrix-rain setWeather storm        # drizzle, classic, storm, terminal
omarchy-shell matrix-rain dejaVuNow
omarchy-shell matrix-rain eventNow dive             # dejavu, rewind, bullet, surge, scramble, binary,
                                                   # blackout, glitch, dive, pan, random
omarchy-shell matrix-rain notifyTest              # show the notification burst
omarchy-shell matrix-rain setColor theme     # green, theme, amber, cyan, red, violet or #rrggbb
omarchy-shell matrix-rain toggle
omarchy-shell matrix-rain getLook                # print the current look's code (MR1:...)
omarchy-shell matrix-rain tryLook 'MR1:...'      # show a look without saving it
omarchy-shell matrix-rain addLook 'MR1:...'      # add a look to Saved looks and use it
```

## Sound Lab link

Matrix Rain serves a local socket at `$XDG_RUNTIME_DIR/ertiv-matrix-rain-link.sock`;
Sound Lab connects to it (either can start first). Sound Lab sends whether it
is playing, its tempo and LFO, and a beat on every audible kick: *Beat flash*,
*Tempo pull* and Sound Lab's LFO destinations *speed*, *density* and *size*
use them. When a rain event starts, Matrix Rain sends its name and length, and
Sound Lab's music reacts (set with **React to rain** in Sound Lab). Reactions
shows whether Sound Lab is connected. Nothing leaves your machine.
