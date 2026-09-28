# Source and asset notices

Plugin code: MIT, matching the original local manifest. Maintainer must confirm
ownership/permission before marketplace submission.

`tests/validate_plugin.py` is from Tom Ballard's Build Omarchy Plugins,
commit `4f7a69a3d20cc67b013a3fe6f399c3124f5ebe46` (MIT; see
`LICENSES/toolkit-MIT.txt`). Toolkit: https://github.com/tcballard/build-omarchy-plugins.

`MatrixSlider.qml` is adapted from Omarchy's `shell/Ui/PanelSlider.qml`
(Omarchy is MIT-licensed per its Arch package; https://github.com/basecamp/omarchy),
changed so a drag ends when the mouse button is no longer held.

`atlas.png` is reproducibly rasterized from Noto Sans CJK JP Regular using
`scripts/build-atlas.py`. Font license: SIL OFL 1.1, preserved in
`LICENSES/Noto-OFL.txt`. No font binary is bundled. The original local atlas
had no recorded provenance; this release uses a newly generated atlas.

Shader binaries are Qt shader packs built from adjacent GLSL sources using
`scripts/build-shaders`. Optional screensaver C++ source builds locally with
Qt 6; its machine-specific executable is not distributed. Qt, Quickshell,
Omarchy, Python, and PipeWire are system dependencies, not vendored libraries.
