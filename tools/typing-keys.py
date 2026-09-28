#!/usr/bin/env python3
"""Add or remove the typing-ripple key binds in the running Hyprland.

  typing-keys.py on    bind the typing keys (with and without Shift)
  typing-keys.py off   remove the binds this script added

Each bind is non-consuming (the key still reaches your app as normal) and
only emits the Hyprland event `custom>>ertiv-matrix-rain:key`, the same for
every key: Matrix Rain learns that a key was pressed, never which one.
Binds are added at runtime with `hyprctl eval`, so nothing is written to your
Hyprland config; a config reload drops them (Matrix Rain adds them again).
Key combinations you already bind yourself are left alone. The combinations
added are listed in $XDG_RUNTIME_DIR/ertiv-matrix-rain-keys.json so `off`
removes exactly those.
"""
import json
import os
import subprocess
import sys

EVENT = "ertiv-matrix-rain:key"
KEYS = [chr(c) for c in range(ord("A"), ord("Z") + 1)] + [str(d) for d in range(10)] + [
    "space", "Return", "BackSpace", "Tab", "minus", "equal", "comma", "period", "slash",
    "semicolon", "apostrophe", "bracketleft", "bracketright", "backslash", "grave"]
MODS = [("", 0), ("SHIFT + ", 1)]
RECORD = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "ertiv-matrix-rain-keys.json")


def hyprctl(*args):
    return subprocess.run(["hyprctl", *args], capture_output=True, text=True, timeout=5).stdout


def lua_list(items):
    return "{" + ",".join(json.dumps(i) for i in items) + "}"


def remove():
    try:
        with open(RECORD) as f:
            combos = [c for c in json.load(f) if isinstance(c, str)]
    except (OSError, ValueError):
        combos = []
    if combos:
        hyprctl("eval", "for _, k in ipairs(" + lua_list(combos) + ") do hl.unbind(k) end")
    try:
        os.remove(RECORD)
    except OSError:
        pass


def add():
    remove()
    try:
        taken = {(b["modmask"], str(b["key"]).lower()) for b in json.loads(hyprctl("-j", "binds") or "[]")}
    except ValueError:
        taken = set()
    combos = [prefix + k for k in KEYS for prefix, mask in MODS if (mask, k.lower()) not in taken]
    code = ("for _, k in ipairs(" + lua_list(combos) + ") do hl.bind(k, hl.dsp.event(" + json.dumps(EVENT) +
            "), { non_consuming = true }) end")
    if hyprctl("eval", code).strip() != "ok":
        print("typing-keys: Hyprland did not accept the binds", file=sys.stderr)
        return 1
    with open(RECORD, "w") as f:
        json.dump(combos, f)
    return 0


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("on", "off"):
        print(__doc__, file=sys.stderr)
        return 2
    if sys.argv[1] == "on":
        return add()
    remove()
    return 0


if __name__ == "__main__":
    sys.exit(main())
