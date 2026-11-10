"""Title lobby card art: small crops of the real arena maps (assets/hq/env_*_topdown.png, 3312 x 2480) so the
menu never has to load the full maps. Writes assets/hq/menu/arena_0..7.jpg (campaign card + arena list, in
Game.ARENAS order) and endless.jpg (the Volcanic Forge's furnace corner).

    py -3 art_src/menu/make_menu_thumbs.py
"""
import os
from PIL import Image, ImageEnhance, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "hq")
OUT = os.path.join(ROOT, "assets", "hq", "menu")
SIZE = (800, 340)

# Game.ARENAS order -> map art.
ARENAS = ["env_arctic_topdown", "env_jungle_topdown", "env_outpost_topdown", "env_skyway_topdown",
          "env_plaza_topdown", "env_forge_topdown", "env_desert_topdown", "env_dock_topdown"]
# Crop centre per map (fractions; default the middle): the Titan Graveyard card shows the fallen titan.
CENTRES = {"env_desert_topdown": (0.5, 0.3), "env_dock_topdown": (0.5, 0.42)}


def crop(im: Image.Image, cx: float, cy: float, w: int) -> Image.Image:
    """A SIZE-aspect box `w` pixels wide centred on (cx, cy) (fractions of the map), kept inside the map."""
    h = round(w * SIZE[1] / SIZE[0])
    x0 = min(max(round(cx * im.width - w / 2), 0), im.width - w)
    y0 = min(max(round(cy * im.height - h / 2), 0), im.height - h)
    return im.crop((x0, y0, x0 + w, y0 + h))


def finish(im: Image.Image, path: str) -> None:
    im = im.resize(SIZE, Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
    im = ImageEnhance.Contrast(im).enhance(1.08)
    im.save(path, quality=88, optimize=True)
    print("wrote", os.path.relpath(path, ROOT), im.size)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for i, name in enumerate(ARENAS):
        im = Image.open(os.path.join(SRC, name + ".png")).convert("RGB")
        cx, cy = CENTRES.get(name, (0.5, 0.5))
        finish(crop(im, cx, cy, 2300), os.path.join(OUT, "arena_%d.jpg" % i))
    forge = Image.open(os.path.join(SRC, "env_forge_topdown.png")).convert("RGB")
    finish(crop(forge, 0.78, 0.2, 1700), os.path.join(OUT, "endless.jpg"))


if __name__ == "__main__":
    main()
