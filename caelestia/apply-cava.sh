#!/bin/bash
# Called as caelestia postHook after every scheme change.
python3 << 'PYEOF'
import json, os, shutil, subprocess, tomllib
from pathlib import Path

raw = os.environ.get('SCHEME_COLOURS', '')
if not raw:
    from caelestia.utils.scheme import get_scheme
    colours = get_scheme().colours
else:
    colours = json.loads(raw)

# ── cava (monochrome gradient) ────────────────────────────────────────────────
on_bg   = colours.get('onBackground',     '323232')
on_sv   = colours.get('onSurfaceVariant', '5f5f5f')
outline = colours.get('outline',          '7b7b7b')
ov      = colours.get('outlineVariant',   'b2b2b2')

cava_config = f"""[general]
framerate = 60

[input]
method = pulse
source = auto

[output]
method = ncurses
style = stereo

[color]
gradient = 1
gradient_count = 4
gradient_color_1 = '#{on_bg}'
gradient_color_2 = '#{on_sv}'
gradient_color_3 = '#{outline}'
gradient_color_4 = '#{ov}'

[smoothing]
noise_reduction = 85
monstercat = 1
waves = 0
gravity = 120

[eq]
1 = 0.8
2 = 0.9
3 = 1.0
4 = 1.1
5 = 1.2
"""
Path(os.path.expanduser('~/.config/cava/config')).write_text(cava_config)
subprocess.run(['killall', '-USR2', 'cava'], stderr=subprocess.DEVNULL)

# ── terminal colors (foot + kitty) ────────────────────────────────────────────
bg     = colours.get('background',        '181212')
fg     = colours.get('onBackground',      'ece0df')
cursor = colours.get('primary',           'ffb2b7')
terms  = [colours.get(f'term{i}', '')    for i in range(16)]

foot_palette = '\n'.join(f'regular{i}={terms[i]}' for i in range(8) if terms[i]) \
             + '\n' + \
               '\n'.join(f'bright{i}={terms[i+8]}' for i in range(8) if terms[i+8])

Path(os.path.expanduser('~/.config/foot')).mkdir(exist_ok=True)
Path(os.path.expanduser('~/.config/foot/foot.ini')).write_text(f"""shell=fish
title=foot
font=JetBrains Mono Nerd Font:size=12
letter-spacing=0
dpi-aware=no
pad=25x25
bold-text-in-bright=no
gamma-correct-blending=no

[scrollback]
lines=10000

[cursor]
style=beam
beam-thickness=1.5
color={bg}{cursor}

[colors]
alpha=0.78
background={bg}
foreground={fg}
{foot_palette}

[key-bindings]
scrollback-up-page=Page_Up
scrollback-down-page=Page_Down
search-start=Control+Shift+f

[search-bindings]
cancel=Escape
find-prev=Shift+F3
find-next=F3 Control+G
""")

kitty_palette = '\n'.join(f'color{i} #{terms[i]}' for i in range(16) if terms[i])
Path(os.path.expanduser('~/.config/kitty')).mkdir(exist_ok=True)
Path(os.path.expanduser('~/.config/kitty/kitty.conf')).write_text(f"""background #{bg}
foreground #{fg}
cursor #{cursor}
selection_background #{colours.get('primaryContainer', '522126')}
selection_foreground #{colours.get('onPrimaryContainer', 'ffdadb')}

{kitty_palette}

background_opacity 0.78
font_family JetBrains Mono Nerd Font
font_size 12.0
cursor_shape beam
cursor_beam_thickness 1.5
scrollback_lines 10000
""")
subprocess.run(['pkill', '-USR1', '-x', 'kitty'], stderr=subprocess.DEVNULL)

# ── Bibata accent cursor ──────────────────────────────────────────────────────
accent  = colours.get('primary',      '000000')
outline_c = colours.get('onPrimary',  'ffffff')
detail  = colours.get('primaryContainer', '000000')

theme_name = f'Bibata-Accent-{accent}'
icons_base = Path(os.path.expanduser('~/.local/share/icons'))
out_dir    = icons_base / theme_name
cur_dir    = out_dir / 'cursors'

# Remove stale accent themes except current
for old in icons_base.glob('Bibata-Accent-*'):
    if old.name != theme_name:
        shutil.rmtree(old, ignore_errors=True)

if cur_dir.exists() and any(cur_dir.iterdir()):
    # Already built for this color — just apply
    subprocess.run(['hyprctl', 'setcursor', theme_name, '28'], stderr=subprocess.DEVNULL)
    subprocess.run(['gsettings', 'set', 'org.gnome.desktop.interface', 'cursor-theme', theme_name],
                   stderr=subprocess.DEVNULL)
    raise SystemExit(0)

src_svg  = Path(os.path.expanduser('~/.cache/bibata-accent-src/svg'))
toml_cfg = Path(os.path.expanduser('~/.cache/bibata-accent-src/x.build.toml'))
work_dir = Path('/tmp/bibata-accent-build')

shutil.rmtree(work_dir, ignore_errors=True)
(work_dir / 'svg').mkdir(parents=True)
(work_dir / 'png').mkdir()
cur_dir.mkdir(parents=True, exist_ok=True)

# Recolor SVGs
for svg in src_svg.glob('*.svg'):
    text = svg.read_text()
    text = text.replace('#00FF00', f'#{accent}')
    text = text.replace('#0000FF', f'#{outline_c}')
    text = text.replace('#FF0000', f'#{detail}')
    (work_dir / 'svg' / svg.name).write_text(text)

# Render SVG → PNG at multiple sizes
SIZES = [24, 28, 32, 40, 48, 64]
for svg in (work_dir / 'svg').glob('*.svg'):
    for size in SIZES:
        subprocess.run([
            'rsvg-convert', '-w', str(size), '-h', str(size),
            str(svg), '-o', str(work_dir / 'png' / f'{svg.stem}_{size:03d}.png')
        ], stderr=subprocess.DEVNULL)

# Build XCursor files
with open(toml_cfg, 'rb') as f:
    cfg = tomllib.load(f)

fallback  = cfg['cursors']['fallback_settings']
ANIMATED  = {'left_ptr_watch', 'wait'}  # copy from Classic, skip rebuild

for name, cur in cfg['cursors'].items():
    if name == 'fallback_settings':
        continue

    x11_name = cur.get('x11_name', name)
    symlinks  = cur.get('x11_symlinks', [])
    png_pat   = cur.get('png', f'{name}.png')
    xhot_256  = cur.get('x_hotspot', fallback['x_hotspot'])
    yhot_256  = cur.get('y_hotspot', fallback['y_hotspot'])

    if x11_name in ANIMATED or '*' in png_pat:
        # Copy animated cursor from existing Classic theme
        src = Path(f'/usr/share/icons/Bibata-Modern-Classic/cursors/{x11_name}')
        if src.exists():
            shutil.copy2(src, cur_dir / x11_name)
    else:
        stem = png_pat.replace('.png', '')
        lines = []
        for size in SIZES:
            png = work_dir / 'png' / f'{stem}_{size:03d}.png'
            if not png.exists():
                continue
            xhot = max(0, round(xhot_256 * size / 256))
            yhot = max(0, round(yhot_256 * size / 256))
            lines.append(f'{size} {xhot} {yhot} {png}')
        if not lines:
            continue
        cfg_file = work_dir / f'{x11_name}.cursor'
        cfg_file.write_text('\n'.join(lines) + '\n')
        subprocess.run(['xcursorgen', str(cfg_file), str(cur_dir / x11_name)],
                       stderr=subprocess.DEVNULL)

    for sym in symlinks:
        link = cur_dir / sym
        if not link.exists():
            try: link.symlink_to(x11_name)
            except: pass

# Write theme metadata
(out_dir / 'index.theme').write_text(
    f'[Icon Theme]\nName={theme_name}\nComment=Dynamic accent cursor\n'
)

# Apply cursor — new theme name forces Hyprland to reload from disk
subprocess.run(['hyprctl', 'setcursor', theme_name, '28'], stderr=subprocess.DEVNULL)
subprocess.run(['gsettings', 'set', 'org.gnome.desktop.interface', 'cursor-theme', theme_name],
               stderr=subprocess.DEVNULL)

print(f'Cursor rebuilt with accent #{accent}')
PYEOF
