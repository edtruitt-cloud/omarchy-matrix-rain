#!/usr/bin/env python3
"""Matrix Rain look codes that carry Custom glyphs (symbols and pictures).

  look-code.py copy ATLAS.png LOOK_JSON   put the look's code on the clipboard
  look-code.py pack ATLAS.png LOOK_JSON   print the code
  look-code.py paste DIR                  read a code from the clipboard
  look-code.py unpack DIR < CODE          read a code from stdin

A code is "MR1:" + base64 of the look's JSON. When the look uses Custom
glyphs (look.custom), the drawn glyphs go in the code as one greyscale PNG
strip, so whoever pastes it gets the same symbols and pictures without
needing the same fonts or files. Your picture paths never go in a code.

Reading a code saves those glyphs as DIR/<id>/NN.glyph.png (finished glyphs
that custom-glyphs.py uses as they are) and prints the look as JSON, with
look.custom = {"chars": "", "images": [those files]}; nothing for a code
that isn't one.
"""
import base64
import hashlib
import io
import json
import os
import subprocess
import sys

from PIL import Image

COLS, CELL, MAX = 16, 256, 48
MAX_CODE = 4_000_000


def pack(atlas_path, look_json):
    look = json.loads(look_json)
    custom = look.pop("custom", None)
    if isinstance(custom, dict) and look.get("glyphSet") == "custom":
        count = max(0, min(MAX, int(custom.get("count") or 0)))
        if count and os.path.isfile(atlas_path):
            im = Image.open(atlas_path)
            alpha = im.convert("RGBA").getchannel("A")
            rows = -(-count // COLS)
            strip = Image.new("L", (min(count, COLS) * CELL, rows * CELL), 0)
            for i in range(count):
                box = ((i % COLS) * CELL, (i // COLS) * CELL)
                strip.paste(alpha.crop(box + (box[0] + CELL, box[1] + CELL)), box)
            buf = io.BytesIO()
            strip.save(buf, "PNG", optimize=True)
            look["custom"] = {"count": count, "cells": base64.b64encode(buf.getvalue()).decode("ascii")}
        elif isinstance(custom.get("chars"), str) and custom["chars"]:
            look["custom"] = {"chars": custom["chars"][:200]}
    data = json.dumps(look, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    return "MR1:" + base64.b64encode(data).decode("ascii")


def unpack(folder, code):
    code = code.strip()
    if not code.startswith("MR1:") or len(code) > MAX_CODE:
        return None
    body = "".join(code[4:].split())
    try:
        look = json.loads(base64.b64decode(body + "=" * (-len(body) % 4)).decode("utf-8"))
    except (ValueError, UnicodeDecodeError):
        return None
    if not isinstance(look, dict):
        return None
    custom = look.pop("custom", None)
    if isinstance(custom, dict) and isinstance(custom.get("cells"), str):
        files = save_cells(folder, custom["cells"], custom.get("count"))
        if files:
            look["custom"] = {"chars": "", "images": files}
    elif isinstance(custom, dict) and isinstance(custom.get("chars"), str):
        look["custom"] = {"chars": custom["chars"][:200], "images": []}
    return look


def save_cells(folder, cells_b64, count):
    try:
        raw = base64.b64decode(cells_b64)
        strip = Image.open(io.BytesIO(raw))
        if strip.width > COLS * CELL or strip.height > 3 * CELL:
            return []
        strip = strip.convert("L")
        count = max(0, min(MAX, int(count or 0)))
    except (ValueError, OSError, TypeError, Image.DecompressionBombError):
        return []
    out_dir = os.path.join(folder, hashlib.sha1(raw).hexdigest()[:12])
    os.makedirs(out_dir, exist_ok=True)
    files = []
    for i in range(count):
        x, y = (i % COLS) * CELL, (i // COLS) * CELL
        if x + CELL > strip.width or y + CELL > strip.height:
            break
        cell = Image.new("RGBA", (CELL, CELL), (255, 255, 255, 0))
        cell.putalpha(strip.crop((x, y, x + CELL, y + CELL)))
        path = os.path.join(out_dir, "%02d.glyph.png" % i)
        cell.save(path)
        files.append(path)
    return files


def main(argv):
    if len(argv) == 4 and argv[1] in ("pack", "copy"):
        code = pack(argv[2], argv[3])
        if argv[1] == "pack":
            sys.stdout.write(code)
            return 0
        try:
            subprocess.run(["wl-copy"], input=code.encode("ascii"), check=True, timeout=10)
        except (OSError, subprocess.SubprocessError):
            return 1
        print(json.dumps({"copied": len(code)}))
        return 0
    if len(argv) == 3 and argv[1] in ("unpack", "paste"):
        if argv[1] == "unpack":
            code = sys.stdin.read(MAX_CODE + 1)
        else:
            try:
                code = subprocess.run(["wl-paste", "--no-newline"], capture_output=True,
                                      timeout=10).stdout[:MAX_CODE + 1].decode("utf-8", "replace")
            except (OSError, subprocess.SubprocessError):
                code = ""
        look = unpack(argv[2], code)
        if look is not None:
            print(json.dumps(look, ensure_ascii=False))
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
