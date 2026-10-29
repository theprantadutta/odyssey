"""Builds the Play Store screenshot sets from raw device captures.

    python store_screenshots/composer/build.py

Reads   store_screenshots/raw/android_phone/*.png   (Galaxy A24, 1080x2340)
        store_screenshots/raw/android_tablet/*.png  (Galaxy Tab A9, 800x1340)
Writes  play_store_screenshots/             8 x 1080x1920  (phone)
        play_store_screenshots_tablet_7in/  8 x 1080x1920  (7-inch tablet)
        play_store_screenshots_tablet_10in/ 8 x 2160x3840  (10-inch tablet)

The look follows "Play Store Screenshots.dc.html" in the Odyssey Claude
Design project: backgrounds cycle ink -> lime -> paper, Space Grotesk
headlines, Manrope body, the raw capture in a dark frame bleeding off the
bottom. Slides 1 and 8 carry the logo; the six between each sell one thing.

Each slide is laid out once on a 1080x1920 CSS canvas. The 10-inch set is the
same page rendered at device scale 2, so the two tablet sets never drift.
"""

import html
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / 'store_screenshots' / 'raw'
WORK = ROOT / 'store_screenshots' / 'composer' / '_html'
CHROME = pathlib.Path(r'C:\Program Files\Google\Chrome\Application\chrome.exe')

INK, LIME, PAPER = '#0A0B0D', '#D6FF3D', '#F2F2EF'

# Copy is checked against what the app does. "No account needed" is guest
# mode; "any currency" is per-expense currency with conversion; "offline" is
# the local-first database.
SLIDES = [
    dict(
        file='01-every-trip-one-place', bg=INK, logo=True,
        headline='Every trip,<br><em>one place.</em>',
        body='Plan the days, pack the bag, track the spend and keep the '
             'photos. One journal for the whole journey.',
        shots=['home'],
    ),
    dict(
        file='02-your-next-trip-in-seconds', bg=LIME,
        eyebrow='START IN SECONDS',
        headline='Your next trip,<br>in seconds.',
        body='Name it, pick the dates and you are in. No account needed '
             'to start.',
        shots=['onboarding'],
    ),
    dict(
        file='03-plans-that-hold-up', bg=PAPER,
        eyebrow='DAY BY DAY',
        headline='Plans that<br>hold up.',
        body='A timeline for every day of the trip. Tick things off as you '
             'go and watch the days fill in.',
        shots=['plan'],
    ),
    dict(
        file='04-packed-verified', bg=INK,
        eyebrow='NOTHING FORGOTTEN',
        headline='Packed.<br><em>Verified.</em>',
        body='Lists by category, one progress bar. Tick items as they go in '
             'the bag and know exactly what is left.',
        shots=['packing'],
    ),
    dict(
        file='05-any-currency-one-budget', bg=LIME,
        eyebrow='ANY CURRENCY',
        headline='Know where<br>it went.',
        body='Log spend in the currency you paid in and see it in yours. '
             'Categories total themselves.',
        shots=['spend'],
    ),
    dict(
        file='06-every-place-pinned', bg=PAPER,
        eyebrow='ON THE MAP',
        headline='Every place,<br>pinned.',
        body='Plans and photos land on the map, so a trip is something you '
             'can wander back through.',
        shots=['tripmap', 'memories'],
    ),
    dict(
        file='07-your-travel-wallet', bg=INK,
        eyebrow='TRAVEL WALLET',
        headline='Tickets,<br><em>close at hand.</em>',
        body='Boarding passes, bookings and passport scans kept with the '
             'trip, and there when the signal is not.',
        shots=['documents'],
    ),
    dict(
        file='08-everything-in-one-trip', bg=LIME, logo=True,
        headline='Everything,<br>in one trip.',
        chips=['Itinerary', 'Packing', 'Budget', 'Documents', 'Memories',
               'Map', 'Works offline'],
        shots=['overview'],
    ),
]

# Raw capture size (width, height) per device.
RAW_SIZE = {'android_phone': (1080, 2340), 'android_tablet': (800, 1340)}

# Raw pixels to cut from the top of a capture, so a trip tab opens on its
# stats row instead of repeating the same cover photo on five slides.
CROP = {
    'android_phone': {name: 800 for name in
                      ['plan', 'packing', 'spend', 'documents', 'memories',
                       'tripmap']},
    'android_tablet': {name: 230 for name in
                       ['plan', 'packing', 'spend', 'documents', 'memories',
                        'tripmap']},
}


def palette(bg):
    dark = bg == INK
    return dict(
        ink='#F2F2EF' if dark else INK,
        body='rgba(242,242,239,.62)' if dark else 'rgba(10,11,13,.6)',
        eyebrow=LIME if dark else 'rgba(10,11,13,.5)',
        accent=LIME if dark else INK,
        frame='rgba(255,255,255,.14)' if dark else INK,
        dark=dark,
    )


def logo(bg):
    tile, glyph = (LIME, INK) if bg == INK else (INK, LIME)
    word = '#F2F2EF' if bg == INK else INK
    return f'''
      <div class="logo">
        <div class="tile" style="background:{tile}">
          <div class="pin" style="background:{glyph}">
            <div class="dot" style="background:{tile}"></div>
          </div>
        </div>
        <div class="word" style="color:{word}">Odyssey</div>
      </div>'''


def glow(bg, index):
    if bg == INK:
        corners = ['left:-220px;top:-260px', 'right:-240px;bottom:-240px',
                   'left:-200px;bottom:-260px']
        pos = corners[index % len(corners)]
        return (f'<div class="glow" style="{pos};background:radial-gradient('
                f'circle,rgba(214,255,61,.15),transparent 68%)"></div>')
    if bg == LIME:
        pos = ['right:-180px;top:-200px', 'left:-200px;bottom:-220px'][index % 2]
        return (f'<div class="glow" style="{pos};'
                f'background:rgba(10,11,13,.06)"></div>')
    return ''


def frames(slide, device, p, text_bottom):
    shots = slide['shots']
    tablet = device == 'android_tablet'
    src = lambda name: (RAW / device / f'{name}.png').as_uri()

    def shown_height(name, inner_width):
        # What is left of the capture once its top is cut, at this width.
        raw_w, raw_h = RAW_SIZE[device]
        return int(inner_width * (raw_h - CROP[device].get(name, 0)) / raw_w)

    def img(name):
        # A negative top margin in % is relative to the width, which is what
        # the capture is scaled to - so the cut is resolution-independent.
        cut = CROP[device].get(name, 0) / RAW_SIZE[device][0] * 100
        return f'<img src="{src(name)}" style="margin-top:-{cut:.3f}%">'

    if len(shots) == 1:
        width = 920 if tablet else 700
        border = 14 if tablet else 10
        radius = 46 if tablet else 56
        top = max(text_bottom + 70, 760)
        height = shown_height(shots[0], width - 2 * border) + 2 * border
        return f'''
      <div class="frame" style="left:{(1080 - width) // 2}px;top:{top}px;
           width:{width}px;height:{height}px;border:{border}px solid {p['frame']};
           border-radius:{radius}px">
        {img(shots[0])}
      </div>'''

    # Two devices, staggered.
    width = 470 if tablet else 482
    border = 9
    radius = 34 if tablet else 44
    top = max(text_bottom + 60, 700)
    out = []
    for i, name in enumerate(shots):
        height = shown_height(name, width - 2 * border) + 2 * border
        side = 'left:44px' if i == 0 else 'right:44px'
        out.append(f'''
      <div class="frame" style="{side};top:{top + i * 130}px;width:{width}px;
           height:{height}px;border:{border}px solid {INK};
           border-radius:{radius}px">
        {img(name)}
      </div>''')
    return ''.join(out)


def page(slide, index, device):
    p = palette(slide['bg'])
    parts = []
    y = 110
    if slide.get('logo'):
        parts.append(logo(slide['bg']))
        y += 76 + 52
    if slide.get('eyebrow'):
        parts.append(f'<div class="eyebrow" style="color:{p["eyebrow"]}">'
                     f'{html.escape(slide["eyebrow"])}</div>')
        y += 18 + 34
    headline = slide['headline'].replace(
        '<em>', f'<em style="color:{p["accent"] if p["dark"] else INK}">')
    parts.append(f'<div class="headline" style="color:{p["ink"]}">'
                 f'{headline}</div>')
    y += 2 * 96
    if slide.get('body'):
        parts.append(f'<div class="body" style="color:{p["body"]}">'
                     f'{html.escape(slide["body"])}</div>')
        y += 32 + 3 * 54
    if slide.get('chips'):
        chips = ''.join(
            f'<div class="chip{" on" if i == 0 else ""}">{html.escape(c)}</div>'
            for i, c in enumerate(slide['chips']))
        parts.append(f'<div class="chips">{chips}</div>')
        y += 36 + 2 * 74

    return f'''<!doctype html>
<html><head><meta charset="utf-8">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=Manrope:wght@500;600;700;800&display=block" rel="stylesheet">
<style>
  html,body{{margin:0;padding:0}}
  body{{width:1080px;height:1920px;overflow:hidden;position:relative;
       background:{slide['bg']};-webkit-font-smoothing:antialiased}}
  .glow{{position:absolute;width:780px;height:780px;border-radius:50%}}
  .text{{position:absolute;left:84px;top:110px;right:84px}}
  .logo{{display:flex;align-items:center;gap:20px;margin-bottom:52px}}
  .tile{{width:76px;height:76px;border-radius:22px;display:flex;
        align-items:center;justify-content:center}}
  .pin{{width:38px;height:38px;border-radius:11px 11px 11px 2px;
       transform:rotate(45deg);display:flex;align-items:center;
       justify-content:center}}
  .dot{{width:12px;height:12px;border-radius:50%}}
  .word{{font:700 42px 'Space Grotesk',sans-serif;letter-spacing:-.04em}}
  .eyebrow{{font:700 15px ui-monospace,Menlo,Consolas,monospace;
           letter-spacing:.2em;margin-bottom:34px}}
  .headline{{font:700 100px/.96 'Space Grotesk',sans-serif;
            letter-spacing:-.045em}}
  .headline em{{font-style:normal}}
  .body{{margin-top:32px;max-width:780px;
        font:500 36px/1.5 Manrope,sans-serif}}
  .chips{{display:flex;flex-wrap:wrap;gap:14px;margin-top:36px;
         max-width:880px}}
  .chip{{padding:15px 26px;border-radius:999px;background:rgba(10,11,13,.08);
        font:700 27px Manrope,sans-serif;color:{INK}}}
  .chip.on{{background:{INK};color:{LIME}}}
  .frame{{position:absolute;box-sizing:border-box;overflow:hidden;
         background:{INK}}}
  .frame img{{display:block;width:100%}}
</style></head>
<body>
  {glow(slide['bg'], index)}
  <div class="text">{''.join(parts)}</div>
  {frames(slide, device, p, y)}
</body></html>'''


def render(html_path, out_path, scale):
    out_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        str(CHROME), '--headless=new', '--disable-gpu', '--hide-scrollbars',
        '--window-size=1080,1920', f'--force-device-scale-factor={scale}',
        '--virtual-time-budget=10000', '--default-background-color=00000000',
        f'--screenshot={out_path}', html_path.as_uri(),
    ], check=True, capture_output=True)


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    sets = [
        ('android_phone', ROOT / 'play_store_screenshots', 1),
        ('android_tablet', ROOT / 'play_store_screenshots_tablet_7in', 1),
        ('android_tablet', ROOT / 'play_store_screenshots_tablet_10in', 2),
    ]
    only = set(sys.argv[1:])
    for device, out_dir, scale in sets:
        if only and out_dir.name not in only:
            continue
        for i, slide in enumerate(SLIDES):
            src = WORK / f'{device}-{slide["file"]}.html'
            src.write_text(page(slide, i, device), encoding='utf-8')
            out = out_dir / f'{slide["file"]}.png'
            render(src, out, scale)
            print(out.relative_to(ROOT))


if __name__ == '__main__':
    main()
