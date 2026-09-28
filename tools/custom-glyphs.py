#!/usr/bin/env python3
"""Draw your own glyphs for the rain's Custom glyph set.

  custom-glyphs.py TEXT OUT.png

Keeps up to 48 different visible characters from TEXT (every symbol is
allowed; only ones no installed font can draw are left out) and draws them in
the rain's tall style into OUT.png (16 per row, 128 px cells), cleaned up so
they read as rain:
  - one colour: colour glyphs (emoji) become a single-colour image, their
    light and dark detail kept as shading instead of a flat silhouette;
  - hairline strokes are thickened until they survive at small sizes;
  - stray specks are removed and edges smoothed.
Runs locally; nothing is sent anywhere. Prints one JSON line:
  {"chars": "...", "count": n, "rows": r, "removed": [{"ch": "x", "why": "..."}],
   "cleaned": [{"ch": "x", "what": "..."}]}
Needs python-pillow and fontconfig.
"""
import json
import os
import subprocess
import sys
import tempfile
import unicodedata

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageOps

CELL, COLS, SIZE, MARGIN = 128, 16, 112, 6
MAX = 48


def visible(ch):
    return unicodedata.category(ch)[0] not in "CZ"


def font_for(ch):
    """A font file that has this character (regular styles first)."""
    try:
        out = subprocess.run(["fc-list", ":charset=%x" % ord(ch), "file", "style"],
                             capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.TimeoutExpired):
        return None
    files = [line.split(":")[0] for line in out.splitlines() if line.strip()]
    files = [f for f in files if f.lower().endswith((".ttf", ".otf", ".ttc"))]
    if not files:
        return None
    files.sort(key=lambda f: ("Emoji" in f, "Regular" not in f, "Noto" not in f, len(f)))
    return files[0]


def one_colour(big):
    """Coverage for a glyph drawn in colour: its shape, with inner detail kept
    as brightness (dark outlines become gaps, light areas stay solid)."""
    alpha = big.getchannel("A")
    lum = ImageOps.autocontrast(big.convert("RGB").convert("L"), cutoff=2)
    detail = lum.point(lambda v: int(70 + 185 * (v / 255) ** 0.8))
    return ImageChops.multiply(alpha, detail)


def pixels(im):
    return im.get_flattened_data() if hasattr(im, "get_flattened_data") else im.getdata()


def stroke_share(mask):
    """How much ink survives a small erosion: low means hairline strokes."""
    ink = sum(1 for v in pixels(mask) if v > 110)
    if not ink:
        return 1.0
    kept = sum(1 for v in pixels(mask.filter(ImageFilter.MinFilter(5))) if v > 110)
    return kept / ink


def draw(ch, font_file):
    """The character scaled into the glyph area (keeping its shape) as one-
    colour coverage, cleaned up to read well. Returns (image, notes)."""
    # Colour emoji fonts only come in fixed sizes (109 px).
    font = None
    for size in (SIZE, 109):
        try:
            font = ImageFont.truetype(font_file, size, index=0)
            break
        except OSError:
            font = None
    if font is None:
        return None, []
    big = Image.new("RGBA", (CELL * 2, CELL * 2), (255, 255, 255, 0))
    ImageDraw.Draw(big).text((CELL, CELL), ch, font=font, anchor="mm", fill="white", embedded_color=True)
    box = big.getchannel("A").getbbox()
    if box is None:
        return None, []
    notes = []
    rgb = big.convert("RGB")
    coloured = any(r != g or g != b for r, g, b in pixels(rgb.crop(box).resize((24, 24)))
                   if (r, g, b) != (0, 0, 0))
    mask = one_colour(big) if coloured else big.getchannel("A")
    if coloured:
        notes.append("made one colour")
    ink = mask.crop(box)
    k = min(CELL * 0.78 / ink.width, (CELL - 2 * MARGIN) / ink.height)
    ink = ink.resize((max(1, round(ink.width * k)), max(1, round(ink.height * k))), Image.LANCZOS)
    cell = Image.new("L", (CELL, CELL), 0)
    cell.paste(ink, ((CELL - ink.width) // 2, (CELL - ink.height) // 2))
    # Hairlines vanish at rain sizes: thicken until the strokes hold up
    # (not colour glyphs: their inner shading would smear).
    for _ in range(0 if coloured else 3):
        if stroke_share(cell) >= 0.45:
            break
        cell = cell.filter(ImageFilter.MaxFilter(5))
        if "thickened" not in notes:
            notes.append("thickened")
    # Specks and ragged edges: a small median, then a soft, crisp edge.
    cleaned = cell.filter(ImageFilter.MedianFilter(3))
    if sum(1 for v in pixels(ImageChops.difference(cell, cleaned)) if v > 80) > 40:
        notes.append("cleaned up")
    cell = cleaned.filter(ImageFilter.GaussianBlur(0.7)).point(lambda v: 0 if v < 24 else min(255, int((v - 24) * 1.25)))
    out = Image.new("RGBA", (CELL, CELL), (255, 255, 255, 0))
    out.putalpha(cell)
    return out, notes


def main(argv):
    args = [a for a in argv[1:] if a != "--no-ai"]   # (old flag, ignored)
    if len(args) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    text, out_path = args
    removed, chars = [], []
    for ch in text:
        if not visible(ch) or ch in chars:
            continue
        if len(chars) >= MAX:
            removed.append({"ch": ch, "why": "more than %d symbols" % MAX})
            continue
        chars.append(ch)
    fonts = {}
    for ch in list(chars):
        f = font_for(ch)
        if not f:
            chars.remove(ch)
            removed.append({"ch": ch, "why": "no installed font can draw it"})
        else:
            fonts[ch] = f
    cells, cleaned = [], []
    for ch in chars:
        g, notes = draw(ch, fonts[ch])
        if g is None:
            removed.append({"ch": ch, "why": "draws as nothing"})
        else:
            cells.append((ch, g))
            if notes:
                cleaned.append({"ch": ch, "what": ", ".join(notes)})
    rows = max(1, -(-len(cells) // COLS))
    im = Image.new("RGBA", (COLS * CELL, rows * CELL), (255, 255, 255, 0))
    for i, (_, g) in enumerate(cells):
        im.alpha_composite(g, ((i % COLS) * CELL, (i // COLS) * CELL))
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    fd, tmp = tempfile.mkstemp(suffix=".png", dir=os.path.dirname(os.path.abspath(out_path)))
    os.close(fd)
    im.save(tmp)
    os.replace(tmp, out_path)
    print(json.dumps({"chars": "".join(c for c, _ in cells), "count": len(cells), "rows": rows,
                      "removed": removed, "cleaned": cleaned}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
