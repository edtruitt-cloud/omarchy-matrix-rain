#!/usr/bin/env python3
"""Apply an Omarchy theme whose colours follow the Matrix Rain colour.

    rain-theme.py green      -> re-apply the Matrix base theme unchanged
    rain-theme.py '#ffb000'  -> build ~/.config/omarchy/themes/matrix-rain
                                (base theme hue-rotated to the rain colour)
                                and apply it
    rain-theme.py '#ffd24a,#ff7a1a,#ff3d7f,#8a3dff'
                             -> a multi-colour look: the first colour leads;
                                the others colour the window border gradient,
                                the terminal's cyan/blue/magenta families and
                                a gradient-mapped wallpaper
    --restart-shell          -> then restart the Omarchy shell so every
                                surface reloads with the new theme

Overlapping runs queue on a lock, and only the most recently requested
colour is applied (an older run exits once a newer request is waiting).

The base is the user's own ~/.config/omarchy/themes/matrix when present
(colors, lock colours, backgrounds, lock image), otherwise the built-in
palette below. The base theme itself is never modified. Recoloured images
are cached per colour in ~/.cache/ertiv.matrix-rain/theme/<hex>/.
Stdlib only, except Pillow for recolouring images (skipped if missing).
"""
from __future__ import annotations

import colorsys
import fcntl
import re
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
BASE_DIR = HOME / ".config/omarchy/themes/matrix"
OUT_SLUG = "matrix-rain"
OUT_DIR = HOME / ".config/omarchy/themes" / OUT_SLUG
CACHE = HOME / ".cache/ertiv.matrix-rain/theme"
STATE = HOME / ".local/state/ertiv.matrix-rain"
REQUEST = STATE / "theme-request"
LOCK = STATE / "theme.lock"
IMAGES = ("unlock.png", "preview.png", "preview-unlock.png")

# Matrix (1999) palette, used when the Matrix theme is not installed.
BUILTIN_COLORS = """mode = "dark"
accent = "#3CBF5C"
cursor = "#A4E0A8"
selection = "#143318"
muted = "#3A6840"
background = "#080C09"
dark_background = "#050705"
darker_background = "#020302"
lighter_background = "#121A13"
foreground = "#8BC98C"
dark_foreground = "#3A6840"
light_foreground = "#A8D4A9"
bright_foreground = "#C5E6C6"
selection_foreground = "#C5E6C6"
selection_background = "#143318"
hyprland_active_border = "rgba(3CBF5Cbb) rgba(1A5A2888) 45deg"
hyprland_inactive_border = "rgba(1A332088)"
red = "#A83A3A"
yellow = "#B8BA48"
orange = "#7AAA48"
green = "#2D9A48"
cyan = "#4BB56A"
blue = "#3D8F68"
magenta = "#5A7A58"
brown = "#2A3A28"
bright_red = "#D05050"
bright_yellow = "#D4D66A"
bright_green = "#5ED87A"
bright_cyan = "#6ECB88"
bright_blue = "#5AA080"
bright_magenta = "#7A927A"
color0 = "#080C09"
color1 = "#A83A3A"
color2 = "#2D9A48"
color3 = "#B8BA48"
color4 = "#3D8F68"
color5 = "#5A7A58"
color6 = "#4BB56A"
color7 = "#8BC98C"
color8 = "#3A6840"
color9 = "#D05050"
color10 = "#5ED87A"
color11 = "#D4D66A"
color12 = "#5AA080"
color13 = "#7A927A"
color14 = "#6ECB88"
color15 = "#C5E6C6"
"""
BUILTIN_LOCK = """text             = "#A8D4A9"
placeholder      = "#145A20"
text-error       = "#C4453C"
border           = "#2D9A48"
border-active    = "#3CBF5C"
border-error     = "#C4453C"
"""

HEX6 = re.compile(r"#([0-9A-Fa-f]{6})\b")
# Alarm colours keep their meaning whatever the rain colour.
KEEP_KEYS = {"red", "bright_red", "color1", "color9", "text-error", "border-error"}
RGBA = re.compile(r"rgba\(([0-9A-Fa-f]{6})([0-9A-Fa-f]{2})\)")


class Recolor:
    """Move the base theme's accent family onto the target colour.

    Colours near the accent's hue (the greens) and tinted neutrals rotate to
    the target hue, keeping their lightness. Distinct hues (the yellow, the
    brick red) stay as they are, so syntax colours stay distinguishable.
    """

    FAMILY = 50.0 / 360.0  # hue distance still counted as the accent family

    def __init__(self, base_accent: str, target: str) -> None:
        self.target = target
        self.base_hue, _, bs = colorsys.rgb_to_hls(*rgb(base_accent))
        th, _, ts = colorsys.rgb_to_hls(*rgb(target))
        self.shift = th - self.base_hue
        self.sat = min(1.0, ts / bs) if bs > 0 else 1.0

    def hex(self, value: str) -> str:
        h, l, s = colorsys.rgb_to_hls(*rgb(value))
        distance = abs((h - self.base_hue + 0.5) % 1.0 - 0.5)
        if distance > self.FAMILY and s > 0.15:
            return value.lstrip("#").upper()
        r, g, b = colorsys.hls_to_rgb((h + self.shift) % 1.0, l, min(1.0, s * self.sat))
        return "%02X%02X%02X" % (round(r * 255), round(g * 255), round(b * 255))

    def text(self, text: str) -> str:
        out = []
        for line in text.splitlines(keepends=True):
            key = line.split("=", 1)[0].strip()
            if key not in KEEP_KEYS and not line.lstrip().startswith("#"):
                line = RGBA.sub(lambda m: "rgba(%s%s)" % (self.hex(m.group(1)), m.group(2)), line)
                line = HEX6.sub(lambda m: "#" + self.hex(m.group(1)), line)
            out.append(line)
        return "".join(out)

    def image(self, src: Path, dest: Path, extras=()) -> bool:
        # Photos hold many hues, so rotating them scatters colour (yellow
        # walls turn magenta). Duotone instead: brightness through
        # black -> rain colour -> white, as the green original reads. A
        # multi-colour look maps brightness through all of its colours.
        try:
            from PIL import Image, ImageOps
        except ImportError:
            return False
        tint = "#" + self.target
        with Image.open(src) as im:
            if im.mode in ("P", "LA", "PA") or "transparency" in im.info:
                im = im.convert("RGBA")
            alpha = im.getchannel("A") if im.mode == "RGBA" else None
            grey = im.convert("L")
            if extras:
                # Split-tone: shadows lean to the look's last colour, midtones
                # to its lead colour, highlights to its second colour.
                def c(h, k=1.0):
                    return tuple(int(int(h[j:j + 2], 16) * k) for j in (0, 2, 4))
                stops = [(0, (0, 0, 0)), (70, c(extras[-1], 0.35)), (150, c(self.target)),
                         (215, c(extras[0])), (255, (255, 255, 255))]
                lut = [[], [], []]
                for v in range(256):
                    for (x0, c0), (x1, c1) in zip(stops, stops[1:]):
                        if x0 <= v <= x1:
                            f = (v - x0) / max(1, x1 - x0)
                            for ch in range(3):
                                lut[ch].append(round(c0[ch] + (c1[ch] - c0[ch]) * f))
                            break
                out = Image.merge("RGB", [grey.point(lut[ch]) for ch in range(3)])
            else:
                out = ImageOps.colorize(grey, black="#000000", mid=tint, white="#ffffff",
                                        blackpoint=0, midpoint=150, whitepoint=255)
            # A little grey back in keeps the original's muted, filmic look.
            out = Image.blend(out, grey.convert("RGB"), 0.25)
            if alpha is not None:
                out.putalpha(alpha)
            dest.parent.mkdir(parents=True, exist_ok=True)
            tmp = dest.with_name(dest.name + ".tmp" + dest.suffix)
            out.save(tmp, quality=92) if dest.suffix.lower() in (".jpg", ".jpeg") else out.save(tmp)
            tmp.replace(dest)
        return True


def rgb(value: str) -> tuple:
    v = value.lstrip("#")
    return tuple(int(v[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def accent_of(colors: str) -> str:
    m = re.search(r'^accent\s*=\s*"#([0-9A-Fa-f]{6})"', colors, re.M)
    return m.group(1) if m else "3CBF5C"


def theme_set(name: str) -> int:
    return subprocess.run(["omarchy", "theme", "set", name]).returncode


# Terminal colour families a multi-colour look's 2nd, 3rd and 4th colours take.
FAMILY_KEYS = (
    {"cyan", "bright_cyan", "color6", "color14"},
    {"blue", "bright_blue", "color4", "color12"},
    {"magenta", "bright_magenta", "color5", "color13"},
)


def combine(original: str, recoloured: str, base_accent: str, lead: str, extras) -> str:
    """Give a multi-colour look's extra colours to border and terminal families.

    Family lines are recoloured from the base theme's original values (the
    lead-coloured ones no longer sit in the base accent's hue family)."""
    lines = []
    for orig, line in zip(original.splitlines(keepends=True), recoloured.splitlines(keepends=True)):
        key = orig.split("=", 1)[0].strip()
        for n, keys in enumerate(FAMILY_KEYS):
            if key in keys and n < len(extras):
                line = HEX6.sub(lambda m: "#" + Recolor(base_accent, extras[n]).hex(m.group(1)), orig)
        lines.append(line)
    text = "".join(lines)
    # Window border: a gradient through the look's colours.
    border_cols = [Recolor(base_accent, c).hex(base_accent) for c in extras[:2]]
    return re.sub(r'^hyprland_active_border\s*=.*$',
                  lambda m: 'hyprland_active_border = "' + " ".join(
                      ["rgba(%s)" % (x + "cc") for x in [lead] + border_cols]) + ' 45deg"',
                  text, flags=re.M)



def build(target: str, extras=()) -> None:
    has_base = (BASE_DIR / "colors.toml").is_file()
    colors = (BASE_DIR / "colors.toml").read_text() if has_base else BUILTIN_COLORS
    lock = (BASE_DIR / "shell.lock.toml").read_text() if (BASE_DIR / "shell.lock.toml").is_file() else BUILTIN_LOCK
    rc = Recolor(accent_of(colors), target)
    extras = [e.lower() for e in extras]

    staging = OUT_DIR.with_name(OUT_SLUG + ".new")
    shutil.rmtree(staging, ignore_errors=True)
    staging.mkdir(parents=True)
    header = "# Generated by the Matrix Rain plugin from the rain colour %s.\n# Changing the rain colour rewrites this theme; edit the Matrix theme instead.\n" % ", ".join("#" + c.upper() for c in [target] + extras)
    text = rc.text(colors)
    if extras:
        text = combine(colors, text, accent_of(colors), rc.hex(accent_of(colors)), extras)
    (staging / "colors.toml").write_text(header + text)
    (staging / "shell.lock.toml").write_text(rc.text(lock))
    (staging / "keyboard.rgb").write_text(rc.hex(accent_of(colors)) + "\n")
    icons = BASE_DIR / "icons.theme"
    if icons.is_file():
        shutil.copyfile(icons, staging / "icons.theme")

    cache = CACHE / "-".join([target.lower()] + extras)
    sources = []
    if has_base:
        sources += [(p, Path("backgrounds") / p.name) for p in sorted((BASE_DIR / "backgrounds").glob("*")) if p.is_file()]
        sources += [(BASE_DIR / n, Path(n)) for n in IMAGES if (BASE_DIR / n).is_file()]
    for src, rel in sources:
        cached = cache / rel
        if not cached.exists() and not rc.image(src, cached, extras):
            continue  # no Pillow: theme without recoloured images
        dest = staging / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        try:
            dest.hardlink_to(cached)
        except OSError:
            shutil.copyfile(cached, dest)

    shutil.rmtree(OUT_DIR, ignore_errors=True)
    staging.rename(OUT_DIR)


def apply(spec: str) -> int:
    if spec == "green":
        if (BASE_DIR / "colors.toml").is_file():
            return theme_set("matrix")
        spec = "#3cbf5c"
    colours = [c[1:] for c in spec.split(",")]
    build(colours[0], colours[1:])
    return theme_set(OUT_SLUG)


def main(argv: list) -> int:
    args = [a for a in argv[1:] if a != "--restart-shell"]
    restart = len(args) != len(argv) - 1
    if len(args) != 1:
        print(__doc__, file=sys.stderr)
        return 2
    spec = args[0].strip().lower()
    if spec != "green" and not re.fullmatch(r"#[0-9a-f]{6}(,#[0-9a-f]{6}){0,3}", spec):
        print("rain-theme: expected green, #rrggbb or up to four comma-separated colours, got " + args[0], file=sys.stderr)
        return 2
    STATE.mkdir(parents=True, exist_ok=True)
    REQUEST.write_text(spec)
    with open(LOCK, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if REQUEST.read_text().strip() != spec:
            return 0  # a newer colour was requested while we waited
        code = apply(spec)
        if code == 0 and restart and REQUEST.read_text().strip() == spec:
            code = subprocess.run(["omarchy", "restart", "shell"]).returncode
        return code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
