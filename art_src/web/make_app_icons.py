"""App icons (web "Add to Home Screen" / PWA + the project icon): NIMBUS-07 itself, close up, built in code from
the mech's own 3D render (art_src/web/icon_mech.png from render_icon_mech.py) - no AI art.

Follows mobile game icon practice (one character, tight crop, one focal point, 2-3 colours, strong value
contrast, a hint of motion, no text, square art - iOS rounds the corners itself, must read at ~60 px):
  deep-navy backdrop -> cyan energy burst behind the head + diagonal speed streaks -> the mech, tilted a few
  degrees, with a cyan rim glow around its silhouette -> visor bloom -> corner vignette.

  blender -b art_src/halo_forge/HaloForge_2D_Sprites.blend --python art_src/web/render_icon_mech.py -- art_src/web/icon_mech.png --yaw 30 --elev -10 --head 3.4 --dy 0.2
  py -3 art_src/web/make_app_icons.py [render.png] [--preview out.png]
      -> assets/web/app_icon_{144,180,512}.png  (--preview: a sheet at 512 / 180 / 60 px instead)
"""
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "web")
S = 1024
NAVY_DEEP = (4, 8, 22)
NAVY = (14, 34, 78)
CYAN = (60, 210, 255)
TILT = -6.0               # degrees the mech leans (negative = top to the right)
MECH_SCALE = 1.55         # render width vs the icon
MECH_OFFSET = (-30, 175)  # px at 1024: put the head in the upper middle
BURST_AT = (0.52, 0.34)   # energy burst centre (fraction of the icon), behind the head


def radial(size, center, inner, outer, radius):
    im = Image.new("RGB", (size, size))
    px = im.load()
    cx, cy = center
    for y in range(size):
        for x in range(size):
            t = min(1.0, math.hypot(x - cx, y - cy) / radius)
            t = t * t * (3 - 2 * t)
            px[x, y] = tuple(int(inner[i] + (outer[i] - inner[i]) * t) for i in range(3))
    return im


def backdrop():
    bx, by = BURST_AT[0] * S, BURST_AT[1] * S
    im = radial(S, (bx, by), NAVY, NAVY_DEEP, S * 0.85).convert("RGBA")
    # Speed streaks: thin diagonal cyan lines (motion), brighter near the burst.
    streaks = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(streaks)
    rnd = random.Random(7)
    ang = math.radians(-32)
    dx, dy = math.cos(ang), math.sin(ang)
    for i in range(46):
        off = rnd.uniform(-S, S)
        length = rnd.uniform(S * 0.15, S * 0.55)
        along = rnd.uniform(-S * 0.4, S * 0.4)
        cx = S / 2 - dy * off + along * dx
        cy = S / 2 + dx * off + along * dy
        w = rnd.choice([2, 3, 3, 4, 6])
        a = rnd.randint(40, 120)
        d.line([(cx - dx * length / 2, cy - dy * length / 2), (cx + dx * length / 2, cy + dy * length / 2)],
            fill=CYAN + (a,), width=w)
    streaks = streaks.filter(ImageFilter.GaussianBlur(1.2))
    # Fade the streaks away from the burst so the corners stay calm.
    mask = radial(S, (bx, by), (255, 255, 255), (40, 40, 40), S * 0.75).convert("L")
    streaks.putalpha(ImageChops.multiply(streaks.getchannel("A"), mask))
    im.alpha_composite(streaks)
    # Energy burst: a soft cyan-white bloom + a ring behind the head.
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    for r, a in ((S * 0.42, 70), (S * 0.30, 110), (S * 0.18, 150)):
        g.ellipse([bx - r, by - r, bx + r, by + r], fill=CYAN + (a,))
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.07))
    im.alpha_composite(glow)
    ring = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    r = S * 0.36
    rd.ellipse([bx - r, by - r, bx + r, by + r], outline=(150, 235, 255, 210), width=int(S * 0.012))
    im.alpha_composite(ring.filter(ImageFilter.GaussianBlur(S * 0.012)))
    im.alpha_composite(ring)
    return im


def mech_layer(render_path):
    m = Image.open(render_path).convert("RGBA")
    k = S * MECH_SCALE / m.width
    m = m.resize((round(m.width * k), round(m.height * k)), Image.LANCZOS)
    m = m.rotate(-TILT, resample=Image.BICUBIC, expand=True)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    layer.alpha_composite(m, ((S - m.width) // 2 + MECH_OFFSET[0], (S - m.height) // 2 + MECH_OFFSET[1]))
    return layer


def rim_glow(layer):
    a = layer.getchannel("A")
    grown = a.filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.GaussianBlur(14))
    glow = Image.new("RGBA", (S, S), CYAN + (0,))
    glow.putalpha(grown.point(lambda v: int(v * 0.85)))
    return glow


def visor_bloom(layer):
    """Bloom on the mech's glowing blue-cyan bits (visor, lenses): bright pixels where B >> R."""
    r, g, b, a = layer.split()
    hot = ImageChops.subtract(b, r).point(lambda v: 255 if v > 95 else 0)
    bright = b.point(lambda v: 255 if v > 200 else 0)
    m = ImageChops.multiply(ImageChops.multiply(hot, bright), a.point(lambda v: 255 if v > 200 else 0))
    m = m.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(22))
    bloom = Image.new("RGBA", (S, S), (170, 240, 255, 0))
    bloom.putalpha(m.point(lambda v: min(255, int(v * 3.6))))
    return bloom


def vignette():
    v = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    a = radial(S, (S / 2, S * 0.45), (0, 0, 0), (170, 170, 170), S * 0.78).convert("L")
    v.putalpha(a)
    return v


def build(render_path):
    im = backdrop()
    layer = mech_layer(render_path)
    im.alpha_composite(rim_glow(layer))
    im.alpha_composite(layer)
    im.alpha_composite(visor_bloom(layer))
    im.alpha_composite(vignette())
    return im.convert("RGB")


def main():
    args = list(sys.argv[1:])
    preview = None
    if "--preview" in args:
        i = args.index("--preview")
        preview = args[i + 1]
        del args[i:i + 2]
    render = args[0] if args else os.path.join(ROOT, "art_src", "web", "icon_mech.png")
    icon = build(render)
    if preview:
        # As iOS shows it: rounded corners, at 512 / 180 / 60 px on a light home screen.
        sheet = Image.new("RGB", (512 + 180 + 60 + 80, 512 + 40), (235, 238, 245))
        x = 20
        for size in (512, 180, 60):
            sm = icon.resize((size, size), Image.LANCZOS)
            mask = Image.new("L", (size, size), 0)
            ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=int(size * 0.225), fill=255)
            sheet.paste(sm, (x, 20), mask)
            x += size + 20
        sheet.save(preview)
        print("PREVIEW", preview)
        return
    os.makedirs(OUT, exist_ok=True)
    for size in (144, 180, 512):
        icon.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, "app_icon_%d.png" % size))
    print("APP ICONS OK", OUT)


main()
