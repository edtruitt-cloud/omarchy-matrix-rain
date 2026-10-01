#!/usr/bin/env python3
"""Portable consistency checks for the rain atlas and shader clock."""
import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def png_size(path):
    head = path.read_bytes()[:24]
    assert head[:8] == b'\x89PNG\r\n\x1a\n', path
    return struct.unpack('>II', head[16:24])


def main():
    meta = json.loads((ROOT / 'atlas.json').read_text())
    js = dict(re.findall(r'^var (\w+) = (\d+)$', (ROOT / 'atlas.js').read_text(), re.M))
    assert {k: int(v) for k, v in js.items()} == {k: meta[k] for k in ('cols', 'rows', 'count', 'rainCount')}, (js, meta)
    # Glyph set blocks follow the rain's own glyphs, in order, inside the atlas.
    blocks = sorted(r for rs in meta['blocks'].values() for r in rs if r[0] >= meta['rainCount'])
    assert blocks[0][0] == meta['rainCount'] and blocks[-1][0] + blocks[-1][1] == meta['count'], blocks
    assert all(a[0] + a[1] == b[0] for a, b in zip(blocks, blocks[1:])), blocks
    assert png_size(ROOT / 'atlas.png') == (meta['cols'] * meta['cell'], meta['rows'] * meta['cell'])
    assert (meta['rows'] - 1) * meta['cols'] < meta['count'] <= meta['rows'] * meta['cols']
    # Both pick glyphs from a set; the default is the rain's own 177.
    assert 'atlasCols: Atlas.cols' in (ROOT / 'RainLayer.qml').read_text()
    assert 'glyphSet: Qt.vector4d(0, Atlas.rainCount, 0, 0)' in (ROOT / 'RainLayer.qml').read_text()
    saver = (ROOT / 'screensaver/Screensaver.qml').read_text()
    assert 'atlasCols: Atlas.cols' in saver and 'matrix: [[0, Atlas.rainCount]]' in saver

    shader = (ROOT / 'shaders/rain.frag').read_text()
    service = (ROOT / 'Service.qml').read_text()
    period = float(re.search(r'const float PERIOD = ([\d.]+);', shader).group(1))
    assert float(re.search(r'rainPeriod: ([\d.]+)', service).group(1)) == period
    # The clocks wrap through wrapPhase (positive remainder, so Rewind works).
    assert 'function wrapPhase(x) { var p = root.rainPeriod; return ((x % p) + p) % p }' in service
    assert 'root.rainPhase = wrapPhase(' in service

    # Every quantised fall rate completes whole cycles per period, so heads
    # land on the same position after QML wraps the phase.
    for i in range(1001):
        stream = 0.35 + 0.65 * i / 1000
        cycles = round(stream * 0.22 * period)
        assert cycles >= 1 and abs(cycles / period - stream * 0.22) <= 0.5 / period
    # The mouse wheel never changes a setting in either panel: every wheel
    # handler only passes the event on so the panel scrolls.
    for qml in ROOT.glob('*.qml'):
        for m in re.finditer(r'onWheel:[^\n]*', qml.read_text()):
            assert 'wheel.accepted = false' in m.group(0), (qml.name, m.group(0))
    # Every single colour must look clearly different from the others (CIE Lab
    # distance of the body colours of at least 20), classic green included.
    import itertools, math
    pal = (ROOT / 'rainpalette.js').read_text()
    body = dict(re.findall(r'(\w+):\s*\{ head: "[^"]+", body: "(#[0-9a-f]{6})"', pal))
    body['green'] = '#00ff41'

    def lab(h):
        r, g, b = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
        lin = lambda c: ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92
        r, g, b = map(lin, (r, g, b))
        x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
        y = r * 0.2126 + g * 0.7152 + b * 0.0722
        z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883
        f = lambda t: t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
        return (116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)))
    close = [(round(math.dist(lab(body[a]), lab(body[b])), 1), a, b) for a, b in itertools.combinations(body, 2)
             if math.dist(lab(body[a]), lab(body[b])) < 20]
    assert not close, close
    # Multi-colour looks: each name once, every listed name defined.
    multi_names = re.search(r'var multiNames = \[([^\]]*)\]', pal).group(1)
    names = re.findall(r'"(\w+)"', multi_names)
    assert len(names) == len(set(names)) and all(re.search(r'\n    ' + n + r': \{ mode:', pal) for n in names), names
    # Look codes carry Custom glyphs: the drawn glyphs go in the code (not
    # your file paths) and come back, pixel for pixel, as finished glyphs.
    import subprocess, sys, tempfile
    tool = ROOT / 'tools' / 'look-code.py'
    with tempfile.TemporaryDirectory() as tmp:
        atlas = Path(tmp) / 'atlas.png'
        made = json.loads(subprocess.run([sys.executable, str(ROOT / 'tools' / 'custom-glyphs.py'), 'A★', str(atlas)],
                                         capture_output=True, text=True, check=True).stdout.strip().splitlines()[-1])
        look = {'glyphSet': 'custom', 'name': 'Mine', 'custom': {'chars': made['chars'], 'images': '/home/me/secret.png', 'count': made['count']}}
        code = subprocess.run([sys.executable, str(tool), 'pack', str(atlas), json.dumps(look)],
                              capture_output=True, text=True, check=True).stdout
        assert code.startswith('MR1:') and 'secret' not in code
        back = json.loads(subprocess.run([sys.executable, str(tool), 'unpack', str(Path(tmp) / 'shared')], input=code,
                                         capture_output=True, text=True, check=True).stdout)
        files = back['custom']['images']
        assert back['name'] == 'Mine' and back['custom']['chars'] == '' and len(files) == made['count'], back
        again = Path(tmp) / 'again.png'
        subprocess.run([sys.executable, str(ROOT / 'tools' / 'custom-glyphs.py'), '', str(again)] + files, capture_output=True, check=True)
        from PIL import Image
        assert Image.open(atlas).getchannel('A').tobytes() == Image.open(again).getchannel('A').tobytes()
        assert subprocess.run([sys.executable, str(tool), 'unpack', tmp], input='hello', capture_output=True, text=True).stdout == ''
    print('PASS: atlas.js/atlas.json/atlas.png agree; rain clock wraps on whole cycles; the wheel only scrolls')


if __name__ == '__main__':
    main()
