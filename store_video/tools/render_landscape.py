"""Odyssey Play Store promo video, LANDSCAPE 1920x1080, light theme.

    python store_video/tools/render_landscape.py <ffmpeg.exe> <scenes.json> <out.mp4>

Adapted from Snake Classic's renderer (snake-classic/snake_classic/
store_listings/play-store-video/tools/render_landscape.py): captions on the
left, the phone recording on the right, a progress bar, and intro and outro
cards. Restyled for Odyssey in light mode - paper background, ink type, lime
accents, the app's own Space Grotesk and Manrope.

Pillow draws every still (background, phone stage and mask, captions, cards)
as a PNG; one ffmpeg filter graph trims and joins the recordings, masks the
phone, fades the captions in and out, and lays the music under it.
"""

import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

D = Path(__file__).parent
ROOT = D.parents[1]
FONTS = ROOT / "assets" / "fonts"
MARK = ROOT / "assets" / "brand" / "mark" / "mark-ink-512.png"
MUSIC = ROOT / "store_video" / "music" / "mixkit-just-keep-walking-963.mp3"
FF, SCENES, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
W, H = 1920, 1080

PAPER = (242, 242, 239)
INK = (10, 11, 13)
INK2 = (88, 90, 94)
LIME = (214, 255, 61)
CARD = (255, 255, 255)

INTRO, OUTRO, FADE = 3.0, 4.5, 0.3

# The phone on the right. Recordings are 1080x2340.
PH = 980
PW = round(PH * 1080 / 2340 / 2) * 2
PX, PY = 1260, (H - PH) // 2
RADIUS = 44
CAP_X, CAP_W = 150, 960  # caption column on the left


def font(name, size):
    return ImageFont.truetype(str(FONTS / f"{name}.ttf"), size)


def display(size):
    return font("SpaceGrotesk-700", size)


def body(size, weight=500):
    return font(f"Manrope-{weight}", size)


def mono(size):
    return font("JetBrainsMono-700", size)


def wrap(draw, text, f, width):
    lines, cur = [], ""
    for word in text.split():
        trial = f"{cur} {word}".strip()
        if draw.textlength(trial, font=f) <= width:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    return lines + [cur]


def spaced(draw, xy, text, f, fill, spacing):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=f, fill=fill, anchor="lm")
        x += draw.textlength(ch, font=f) + spacing
    return x


def spaced_width(draw, text, f, spacing):
    return sum(draw.textlength(c, font=f) + spacing for c in text) - spacing


def chip(draw, x, y, label):
    """The eyebrow above each caption: ink pill, lime mono label."""
    f = mono(28)
    tw = spaced_width(draw, label, f, 5)
    h = 58
    draw.rounded_rectangle((x, y, x + tw + 48, y + h), radius=h // 2, fill=INK)
    spaced(draw, (x + 24, y + h / 2), label, f, LIME, 5)
    return y + h


def caption_png(i, label, title, sub):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ft, fs = display(92), body(42)
    tlines = wrap(d, title, ft, CAP_W)
    slines = wrap(d, sub, fs, CAP_W - 60)[:3]
    block = 58 + 44 + len(tlines) * 96 + 34 + len(slines) * 62
    y = (H - block) // 2
    y = chip(d, CAP_X, y, label) + 44
    for line in tlines:
        d.text((CAP_X - 4, y), line, font=ft, fill=INK)
        y += 96
    y += 34
    for line in slines:
        d.text((CAP_X, y), line, font=fs, fill=INK2)
        y += 62
    p = D / f"lcap{i}.png"
    img.save(p)
    return p


def background():
    """Paper with two soft lime glows - the store screenshots' light look."""
    img = Image.new("RGB", (W, H), PAPER)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((-420, -460, 640, 520), fill=(214, 255, 61, 70))
    gd.ellipse((1150, 380, 2300, 1500), fill=(214, 255, 61, 60))
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    img.paste(glow, (0, 0), glow)
    return img


def phone_assets():
    bg = background()
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (PX - 6, PY + 18, PX + PW + 6, PY + PH + 30), radius=RADIUS + 10, fill=(10, 11, 13, 60))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    bg.paste(shadow, (0, 0), shadow)
    ImageDraw.Draw(bg).rounded_rectangle(
        (PX - 10, PY - 10, PX + PW + 9, PY + PH + 9), radius=RADIUS + 10, fill=INK)
    bg.save(D / "lstage.png")
    mask = Image.new("L", (PW, PH), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, PW - 1, PH - 1), radius=RADIUS, fill=255)
    mask.save(D / "lmask.png")


def tile(size):
    """Odyssey's mark on a lime rounded tile, as on the store screenshots."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle((0, 0, size - 1, size - 1), radius=size * 0.29, fill=LIME)
    inner = round(size * 0.62)
    mark = Image.open(MARK).convert("RGBA").resize((inner, inner), Image.LANCZOS)
    img.alpha_composite(mark, ((size - inner) // 2, (size - inner) // 2))
    return img


def card(name, build):
    img = background()
    d = ImageDraw.Draw(img)
    build(img, d)
    p = D / f"{name}.png"
    img.save(p)
    return p


def highlight(d, x, y, text, f, pad=18):
    """Ink text on a lime highlight - the light-theme version of the lime
    accent word, which would not read as lime text on paper."""
    w = d.textlength(text, font=f)
    a, b = f.getmetrics()
    d.rounded_rectangle((x - pad, y + a * 0.18, x + w + pad, y + a + b * 0.35), radius=18, fill=LIME)
    d.text((x, y), text, font=f, fill=INK)


def intro(img, d):
    t = tile(220)
    img.paste(t, ((W - 220) // 2, 190), t)
    fw = display(84)
    word = "Odyssey"
    d.text(((W - d.textlength(word, font=fw)) / 2, 440), word, font=fw, fill=INK)
    fh = display(118)
    a, b = "Every trip, ", "one place."
    wa, wb = d.textlength(a, font=fh), d.textlength(b, font=fh)
    x0 = (W - wa - wb) / 2
    d.text((x0, 590), a, font=fh, fill=INK)
    highlight(d, x0 + wa, 590, b, fh)
    sub = "Trip planner and travel journal"
    fs = body(44)
    d.text(((W - d.textlength(sub, font=fs)) / 2, 790), sub, font=fs, fill=INK2)


def outro(img, d):
    t = tile(170)
    img.paste(t, (180, 170), t)
    d.text((385, 175), "Odyssey", font=display(96), fill=INK)
    d.text((390, 290), "Trip Planner & Journal", font=body(44, 600), fill=INK2)
    items = ["Plan every day of the trip", "Pack with a checklist",
             "Track spend in any currency", "Photos pinned to the map",
             "Works offline, no account needed"]
    fi = body(46, 700)
    y = 470
    for text in items:
        d.rounded_rectangle((190, y, 226, y + 36), radius=8, fill=INK)
        d.text((260, y + 18), text, font=fi, fill=INK, anchor="lm")
        y += 92
    bw, bh = 520, 150
    bx, by = 1150, 420
    d.rounded_rectangle((bx, by, bx + bw, by + bh), radius=bh // 2, fill=INK)
    fb = display(54)
    # No price or "download now" claims in store videos.
    label = "On Google Play"
    d.text((bx + (bw - d.textlength(label, font=fb)) / 2, by + bh / 2), label,
           font=fb, fill=LIME, anchor="lm")


def main():
    scenes = json.loads(Path(SCENES).read_text(encoding="utf-8"))["segments"]
    phone_assets()
    caps = [caption_png(i, s["chip"], s["title"], s["sub"]) for i, s in enumerate(scenes)]
    intro_p, outro_p = card("lintro", intro), card("loutro", outro)

    durs = [s["b"] - s["a"] for s in scenes]
    demo_len = sum(durs)
    total = INTRO + demo_len + OUTRO

    srcs = sorted({s["src"] for s in scenes})
    inputs, idx = [], {}
    for sp in srcs:
        idx[sp] = len(inputs) // 2
        inputs += ["-i", str(D / sp)]
    n_src = len(srcs)
    inputs += ["-loop", "1", "-i", str(D / "lstage.png")]
    inputs += ["-i", str(D / "lmask.png")]
    inputs += ["-loop", "1", "-t", str(INTRO), "-i", str(intro_p)]
    inputs += ["-loop", "1", "-t", str(OUTRO), "-i", str(outro_p)]
    cap0 = n_src + 4
    for p, du in zip(caps, durs):
        inputs += ["-loop", "1", "-t", f"{du:.3f}", "-i", str(p)]
    music_i = cap0 + len(scenes)
    inputs += ["-stream_loop", "-1", "-i", str(MUSIC)]

    fc = []
    uses = {sp: [i for i, s in enumerate(scenes) if s["src"] == sp] for sp in srcs}
    for sp, ids in uses.items():
        k = idx[sp]
        outs = "".join(f"[r{i}]" for i in ids)
        # fps first: screenrecord writes a variable frame rate.
        fc.append(f"[{k}:v]fps=30,split={len(ids)}{outs}" if len(ids) > 1 else f"[{k}:v]fps=30{outs}")
    for i, s in enumerate(scenes):
        fc.append(f"[r{i}]trim={s['a']}:{s['b']},setpts=PTS-STARTPTS[t{i}]")
    fc.append("".join(f"[t{i}]" for i in range(len(scenes))) + f"concat=n={len(scenes)}:v=1:a=0[rec]")
    fc.append(f"[rec]scale={PW}:{PH}:flags=lanczos,format=rgba[ph]")
    fc.append(f"[{n_src + 1}:v]format=gray[mk]")
    fc.append("[ph][mk]alphamerge[phr]")
    fc.append(f"[{n_src}:v]fps=30,trim=0:{demo_len:.3f},setpts=PTS-STARTPTS[stg]")
    fc.append(f"[stg][phr]overlay={PX}:{PY}:shortest=1[a0]")
    last, t = "a0", 0.0
    for i, du in enumerate(durs):
        fades = f"fade=in:st=0:d={FADE}:alpha=1,fade=out:st={du - FADE:.3f}:d={FADE}:alpha=1"
        fc.append(f"[{cap0 + i}:v]format=rgba,{fades},setpts=PTS-STARTPTS+{t:.3f}/TB[c{i}]")
        fc.append(f"[{last}][c{i}]overlay=0:0:eof_action=pass[b{i}]")
        last, t = f"b{i}", t + du
    fc.append(f"color=c=0x0A0B0D:s={W}x6:r=30:d={demo_len:.3f}[bar]")
    fc.append(f"[{last}][bar]overlay=x='-{W}+{W}*t/{demo_len:.3f}':y={H - 6}:shortest=1,"
              f"format=yuv420p,setsar=1[demo]")
    fc.append(f"[{n_src + 2}:v]fps=30,format=yuv420p,fade=in:st=0:d=0.35:color=white,"
              f"fade=out:st={INTRO - 0.35}:d=0.35:color=white,setsar=1[in]")
    fc.append(f"[{n_src + 3}:v]fps=30,format=yuv420p,fade=in:st=0:d=0.35:color=white,"
              f"fade=out:st={OUTRO - 0.6}:d=0.6:color=white,setsar=1[out]")
    fc.append("[in][demo][out]concat=n=3:v=1:a=0[v]")
    fc.append(f"[{music_i}:a]atrim=0:{total:.3f},asetpts=PTS-STARTPTS,volume=0.8,"
              f"afade=in:st=0:d=0.6,afade=out:st={total - 1.8:.3f}:d=1.8[aud]")

    cmd = [FF, "-hide_banner", "-loglevel", "error", "-y", *inputs, "-filter_complex", ";".join(fc),
           "-map", "[v]", "-map", "[aud]", "-t", f"{total:.2f}", "-c:v", "libx264", "-crf", "19",
           "-preset", "slow", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k",
           "-movflags", "+faststart", OUT]
    subprocess.run(cmd, check=True)
    print("done", round(total, 2))


if __name__ == "__main__":
    main()
