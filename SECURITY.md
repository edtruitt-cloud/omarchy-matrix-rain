# Execution and data

Omarchy plugins run unsandboxed as your desktop user. Local static validation
is not a security audit or marketplace approval.

Matrix Rain executes Python for the theme builder, bounded Hyprland queries,
`hyprctl` for read-only monitor/workspace state, `dbus-monitor` (only when
Notify burst is on; only the fact that a notification was sent is used), and
Bash/coreutils for atomic state writes. QML control arguments are passed
separately, not interpolated as shell code. State reads are capped and short
subprocesses time out after 5 seconds.

The Sound Lab link is a local Unix socket in `$XDG_RUNTIME_DIR` (user-only).
Matrix Rain reads JSON lines from it (play state, tempo, LFO, beats; values
are clamped, anything else is ignored) and sends only rain event names and
lengths.

It writes only its state directory and, when you pick a colour, its own
Omarchy theme.
It does not use the network, collect telemetry, install dependencies, change
other wallpaper services, or change lock/idle policy. The separately built
screensaver opens a Qt window only when manually launched.

For sensitive findings, avoid posting private data or exploit details publicly.
Ask for a private reporting channel through the repository maintainer. A public
repository and maintainer contact still need to be established before release.

Typing ripples (Reactions → Typing, above 0%) add pass-through Hyprland key
binds at runtime (`hyprctl eval`, never written to config) that emit one fixed
event per keypress. The event carries no key identity; Matrix Rain uses only
the fact that a key was pressed. At 0%, or when the plugin unloads, the binds
recorded in `$XDG_RUNTIME_DIR/ertiv-matrix-rain-keys.json` are removed.

Custom glyphs run `tools/custom-glyphs.py` only when you press Use symbols. It
reads installed fonts (fontconfig) and draws the symbols to the state folder;
nothing is sent anywhere.
