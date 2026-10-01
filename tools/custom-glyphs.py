#!/usr/bin/env python3
"""Draw your own glyphs for the rain's Custom glyph set.

  custom-glyphs.py TEXT OUT.png [IMAGE_OR_FOLDER ...]

Keeps up to 48 different visible characters from TEXT (every symbol is
allowed; only ones no installed font can draw are left out) and draws them in
the rain's tall style into OUT.png (16 per row, 128 px cells), cleaned up so
they read as rain:
  - one colour: colour glyphs (emoji) become a single-colour image, their
    light and dark detail kept as shading instead of a flat silhouette;
  - hairline strokes are thickened until they survive at small sizes;
  - stray specks are removed and edges smoothed.
Pictures work too (PNG, JPEG, WebP, GIF, BMP; SVG through ImageMagick): each
image file, or every image in a folder, becomes one more glyph the same way,
its shape taken from transparency or from the drawing against its background.
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

# Drawn at twice the rain atlas's resolution so big letter sizes stay crisp.
CELL, COLS, SIZE, MARGIN = 256, 16, 224, 12
F = CELL // 128   # filter sizes scale with the cell
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
    kept = sum(1 for v in pixels(mask.filter(ImageFilter.MinFilter(4 * F + 1))) if v > 110)
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
        cell = cell.filter(ImageFilter.MaxFilter(4 * F + 1))
        if "thickened" not in notes:
            notes.append("thickened")
    # Specks and ragged edges: a small median, then a soft, crisp edge.
    cleaned = cell.filter(ImageFilter.MedianFilter(2 * F + 1))
    if sum(1 for v in pixels(ImageChops.difference(cell, cleaned)) if v > 80) > 40 * F * F:
        notes.append("cleaned up")
    cell = cleaned.filter(ImageFilter.GaussianBlur(0.7 * F)).point(lambda v: 0 if v < 24 else min(255, int((v - 24) * 1.25)))
    out = Image.new("RGBA", (CELL, CELL), (255, 255, 255, 0))
    out.putalpha(cell)
    return out, notes


IMAGE_EXT = (".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".svg")


def image_files(paths):
    """Image files from files and folders (a folder's images in name order)."""
    out = []
    for raw in paths:
        path = os.path.expanduser(raw.strip())
        if os.path.isdir(path):
            out += [os.path.join(path, f) for f in sorted(os.listdir(path)) if f.lower().endswith(IMAGE_EXT)]
        elif path:
            out.append(path)
    return out


def load_image(path):
    if path.lower().endswith(".svg"):
        try:
            png = subprocess.run(["magick", "-background", "none", "-density", "300", path, "png:-"],
                                 capture_output=True, timeout=20).stdout
        except (OSError, subprocess.TimeoutExpired):
            return None
        import io
        return Image.open(io.BytesIO(png)) if png else None
    return Image.open(path)


def ai_upscale(im):
    """Real-ESRGAN (realesrgan-ncnn-vulkan, if installed): a 4x AI upscale for
    small pictures. None when it isn't there or fails."""
    import shutil
    tool = shutil.which("realesrgan-ncnn-vulkan")
    if not tool:
        return None
    with tempfile.TemporaryDirectory() as tmp:
        src, dst = os.path.join(tmp, "in.png"), os.path.join(tmp, "out.png")
        im.convert("RGBA").save(src)
        try:
            subprocess.run([tool, "-i", src, "-o", dst, "-s", "4"], capture_output=True, timeout=60)
            return Image.open(dst).convert("RGBA") if os.path.isfile(dst) else None
        except (OSError, subprocess.TimeoutExpired):
            return None


def edge_sharpness(mask):
    """How crisp the edges are: mean edge strength where there is ink."""
    edges = mask.filter(ImageFilter.FIND_EDGES)
    ink = [e for e, m in zip(pixels(edges), pixels(mask)) if m > 40]
    return sum(ink) / len(ink) if ink else 0.0


def specks(mask):
    """Stray bits: pixels a small median would remove."""
    return sum(1 for v in pixels(ImageChops.difference(mask, mask.filter(ImageFilter.MedianFilter(3)))) if v > 80)


def sharpen_if_better(mask, notes):
    """Sharpen, and keep it only if the edges get clearly crisper without
    much more noise."""
    cand = mask.filter(ImageFilter.UnsharpMask(radius=2 * F, percent=140, threshold=3))
    before, after = edge_sharpness(mask), edge_sharpness(cand)
    if after > before * 1.12 and specks(cand) <= specks(mask) * 1.3 + 30 * F * F:
        notes.append("sharpened")
        return cand
    return mask


def picture(path, notes=None):
    """An image as glyph coverage: transparency if it has any, otherwise the
    drawing's contrast against its background (the edges' colour)."""
    try:
        im = load_image(path)
        if im is None:
            return None
        im.seek(0)
        im = im.convert("RGBA")
    except (OSError, ValueError, EOFError):
        return None
    im.thumbnail((CELL * 4, CELL * 4))
    notes = [] if notes is None else notes
    # Small pictures are enlarged before anything else (AI upscaler if
    # installed, else a smooth resample), so detail is judged at glyph size.
    if max(im.size) < CELL * 2:
        up = ai_upscale(im)
        if up is not None:
            im = up
            notes.append("AI upscaled")
        else:
            k = CELL * 2 / max(im.size)
            im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
            notes.append("enlarged")
    alpha = im.getchannel("A")
    lum = im.convert("RGB").convert("L")
    if alpha.getextrema()[0] < 250:
        detail = ImageOps.autocontrast(lum, cutoff=2).point(lambda v: int(150 + 105 * (v / 255)))
        mask = ImageChops.multiply(alpha, detail)
        if not any(pixels(mask.point(lambda v: 255 if v > 60 else 0))):
            mask = alpha  # dark shapes on transparency: use the shape itself
    else:
        # No transparency: the subject is whatever differs from the
        # background (the colour around the edges), with its own light and
        # dark detail kept on top.
        rgb = im.convert("RGB")
        w, h = rgb.size
        edge = [rgb.getpixel((x, y)) for x in range(0, w, max(1, w // 24)) for y in (0, h - 1)]
        edge += [rgb.getpixel((x, y)) for y in range(0, h, max(1, h // 24)) for x in (0, w - 1)]
        bg = tuple(sorted(c[i] for c in edge)[len(edge) // 2] for i in range(3))
        diff = ImageChops.difference(rgb, Image.new("RGB", rgb.size, bg)).convert("L")
        diff = ImageOps.autocontrast(diff, cutoff=1).point(lambda v: 0 if v < 40 else min(255, int((v - 40) * 1.5)))
        bright_bg = sum(bg) / 3 > 128
        shade = ImageOps.autocontrast(ImageOps.invert(lum) if bright_bg else lum, cutoff=2)
        mask = ImageChops.multiply(diff, shade.point(lambda v: int(120 + 135 * (v / 255))))
    return mask


def draw_mask(mask, notes=None):
    """A picture's coverage fitted into the glyph cell and cleaned up (specks,
    edges). No thickening: pictures aren't hairline symbols."""
    box = mask.point(lambda v: 255 if v > 40 else 0).getbbox()
    if box is None:
        return None, []
    notes = ["made one colour"] + (notes or [])
    ink = mask.crop(box)
    k = min(CELL * 0.78 / ink.width, (CELL - 2 * MARGIN) / ink.height)
    ink = ink.resize((max(1, round(ink.width * k)), max(1, round(ink.height * k))), Image.LANCZOS)
    cell = Image.new("L", (CELL, CELL), 0)
    cell.paste(ink, ((CELL - ink.width) // 2, (CELL - ink.height) // 2))
    cleaned = cell.filter(ImageFilter.MedianFilter(2 * F + 1))
    if sum(1 for v in pixels(ImageChops.difference(cell, cleaned)) if v > 80) > 40 * F * F:
        notes.append("cleaned up")
    cleaned = sharpen_if_better(cleaned, notes)
    out = Image.new("RGBA", (CELL, CELL), (255, 255, 255, 0))
    out.putalpha(cleaned)
    return out, notes


def finished_glyph(path):
    """A glyph from a shared look code (NN.glyph.png, one drawn cell): used
    as it is, so it looks the same as it did for whoever shared it."""
    if not path.endswith(".glyph.png"):
        return None
    try:
        im = Image.open(path)
        if im.size != (CELL, CELL):
            return None
        return im.convert("RGBA")
    except (OSError, ValueError):
        return None


def main(argv):
    args = [a for a in argv[1:] if a != "--no-ai"]   # (old flag, ignored)
    if len(args) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    text, out_path, image_args = args[0], args[1], args[2:]
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
    # Pictures, after the symbols (the same 48 limit in all).
    missing = []
    for path in image_files(image_args):
        name = "🖼" + os.path.basename(path)
        if len(cells) >= MAX:
            removed.append({"ch": name, "why": "more than %d glyphs" % MAX})
            continue
        if not os.path.isfile(path):
            removed.append({"ch": name, "why": "file not found"})
            missing.append(path)
            continue
        g = finished_glyph(path)
        if g is not None:
            cells.append((name, g))
            continue
        pic_notes = []
        mask = picture(path, pic_notes)
        g, notes = draw_mask(mask, pic_notes) if mask is not None else (None, [])
        if g is None:
            removed.append({"ch": name, "why": "not an image it can read, or empty"})
        else:
            cells.append((name, g))
            cleaned.append({"ch": name, "what": ", ".join(notes)})
    rows = max(1, -(-len(cells) // COLS))
    im = Image.new("RGBA", (COLS * CELL, rows * CELL), (255, 255, 255, 0))
    for i, (_, g) in enumerate(cells):
        im.alpha_composite(g, ((i % COLS) * CELL, (i // COLS) * CELL))
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    fd, tmp = tempfile.mkstemp(suffix=".png", dir=os.path.dirname(os.path.abspath(out_path)))
    os.close(fd)
    im.save(tmp)
    os.replace(tmp, out_path)
    print(json.dumps({"chars": "".join(c for c, _ in cells if not c.startswith("🖼")), "count": len(cells), "rows": rows,
                      "images": sum(1 for c, _ in cells if c.startswith("🖼")), "missing": missing,
                      "removed": removed, "cleaned": cleaned}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
