# 1.0.0 release notes

Matrix Rain on its own (the synth moved to the separate Sound Lab plugin on
2026-09-27). Tested on Omarchy 4.0.3-1 with Hyprland 0.56 and Qt 6, one
3840×2160 monitor at scale 2.

## What was checked

- `./tests/run`: plugin manifest/path validation (toolkit validator), atlas
  consistency (the original 177 rain glyphs unchanged), rain clock wrap, the
  mouse wheel never editing settings, every single colour at least 20 apart in
  CIE Lab, multi-colour list consistency, and the Omarchy theme builder.
- `python3 scripts/check-qml.py`: the real panel and service in an isolated
  offscreen shell with fictional state: presets, saved looks and share codes,
  workspace looks, colours per layer and for the theme, glyph sets (incl.
  Custom), events (only switched-on ones happen by themselves; chains; glyph
  swap alongside other events), reactions, Sound Lab link messages, typing
  ripples, gravity, folding sections, state save/load and migrations. It
  saves `preview.png`. It does not test real background windows or the GPU.
- GPU renders of the shader in a real Wayland window for new visual features
  (glyph sets, bloom, colour fringe, cascade, ripples, gravity evenness: each
  fifth of the screen gets 19–21% of the rain at 100% gravity).
- `omarchy plugin validate .` and the live shell: install via
  `./scripts/install-local`, reload, fullscreen pause.

## Performance

`python3 scripts/benchmark-rain.py` ran a real Wayland rain service for three
seconds per case (per-process counters; other desktop work was present):

| Scenario | CPU (one core) | GPU engine |
| --- | ---: | ---: |
| classic | 4.0% | 12% |
| storm 5 layers, sharp | 3.7% | 43% |
| storm 5 layers, balanced | 3.7% | 24% |
| storm 5 layers, fast | 4.7% | 22% |
| storm, depth off | 4.0% | 9% |

Paused: 0% CPU and GPU. Depth quality Balanced (the default) renders the far
layers at reduced resolution; Storm has three depth layers since these numbers
were taken with five.

## Not yet covered

1. Multi-monitor hardware (only one output here; per-monitor fullscreen logic
   is tested headless).
2. A public-Git install/update/remove check once the repository is public.
3. The live marketplace form and ID uniqueness, and the owner's checklist.
