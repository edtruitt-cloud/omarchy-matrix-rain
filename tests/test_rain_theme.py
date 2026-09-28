#!/usr/bin/env python3
"""rain-theme.py builds a recoloured theme without touching the base theme."""
import importlib.util, os, tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

with tempfile.TemporaryDirectory() as temp:
    os.environ['HOME'] = temp
    spec = importlib.util.spec_from_file_location('rain_theme', ROOT / 'tools/rain-theme.py')
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    m.theme_set = lambda name: (_ for _ in ()).throw(AssertionError('must not apply a theme in tests'))

    # Without the Matrix theme installed, the built-in palette is used.
    m.build('ffb000')
    out = (m.OUT_DIR / 'colors.toml').read_text()
    assert 'accent = "#BF963C"' in out, out
    assert 'red = "#A83A3A"' in out and 'yellow = "#B8BA48"' in out, 'alarm/yellow must keep their hue'
    assert 'rgba(BF963Cbb)' in out
    assert (m.OUT_DIR / 'keyboard.rgb').read_text().strip() == 'BF963C'

    # With a base theme: green rebuild is the identity; base is never modified.
    base = m.BASE_DIR; base.mkdir(parents=True)
    (base / 'colors.toml').write_text(m.BUILTIN_COLORS)
    (base / 'shell.lock.toml').write_text(m.BUILTIN_LOCK)
    try:
        from PIL import Image
        (base / 'backgrounds').mkdir()
        Image.new('RGB', (8, 8), (40, 190, 90)).save(base / 'backgrounds/a.png')
        Image.new('RGBA', (4, 4), (40, 190, 90, 128)).save(base / 'unlock.png')
    except ImportError:
        Image = None
    m.build('3cbf5c')
    body = lambda p: ''.join(l for l in p.read_text().splitlines(True) if not l.startswith('#'))
    assert body(m.OUT_DIR / 'colors.toml') == m.BUILTIN_COLORS
    m.build('00e5ff')
    assert (base / 'colors.toml').read_text() == m.BUILTIN_COLORS
    assert not m.OUT_DIR.with_name('matrix-rain.new').exists()
    if Image:
        r, g, b = Image.open(m.OUT_DIR / 'backgrounds/a.png').convert('RGB').getpixel((0, 0))
        assert b > r and g > r, (r, g, b)  # cyan duotone
        assert Image.open(m.OUT_DIR / 'unlock.png').mode == 'RGBA'
    assert m.main(['x', 'bogus']) == 2
    # Multi-colour look: extra colours reach the border gradient and the
    # terminal's cyan/blue/magenta families; alarms still keep their red.
    m.build('ffd24a', ['ff7a1a', 'ff3d7f', '8a3dff'])
    multi = (m.OUT_DIR / 'colors.toml').read_text()
    border = next(l for l in multi.splitlines() if l.startswith('hyprland_active_border'))
    assert border.count('rgba(') == 3, border
    single = m.Recolor('3CBF5C', 'ffd24a')
    cyan = next(l for l in multi.splitlines() if l.startswith('cyan ='))
    assert single.hex('4BB56A') not in cyan, 'cyan should take the second colour'
    assert 'red = "#A83A3A"' in multi
    assert m.main(['x', '#ffd24a,#ff7a1a,#ff3d7f,#8a3dff,#000000']) == 2, 'at most four colours'
    # Only the newest request applies; --restart-shell restarts after success.
    calls = []
    m.theme_set = lambda name: calls.append(('set', name)) or 0
    m.subprocess.run = lambda cmd, **kw: calls.append(tuple(cmd)) or type('R', (), {'returncode': 0})()
    assert m.main(['x', '#00e5ff', '--restart-shell']) == 0
    assert calls == [('set', 'matrix-rain'), ('omarchy', 'restart', 'shell')], calls
    calls.clear(); m.REQUEST.write_text('#ff2a2a')
    real_apply = m.apply
    m.apply = lambda spec: (m.REQUEST.write_text('#b46cff'), real_apply(spec))[1]
    assert m.main(['x', '#ff2a2a', '--restart-shell']) == 0
    assert ('omarchy', 'restart', 'shell') not in calls, 'superseded run must not restart the shell'
print('PASS: rain theme recolours the accent family, keeps alarms, green is identity, base untouched')
