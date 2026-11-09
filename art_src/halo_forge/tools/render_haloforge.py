"""Renders the Halo Forge sprites exactly like Projects/gundam-arena-godot/tools/render_gundam.py made
gundam_sheet.png: straight-down ortho camera (scale 1.25) over SpriteRoot, mech front (-Y) pointing up,
256 px cells, the scene's cel material + Freestyle outline, same Actions and frame picks.

blender -b HaloForge_2D_Sprites.blend --python render_haloforge.py -- --out <dir> [--sheet <png>] [--only idle:0,aim:5] [--cell 256]
Never saves the .blend.
"""
import bpy, math, os, sys, argparse
import numpy as np
from mathutils import Vector

ap = argparse.ArgumentParser()
ap.add_argument('--out', required=True)
ap.add_argument('--sheet')
ap.add_argument('--only', default='')
ap.add_argument('--cell', type=int, default=256)
args = ap.parse_args(sys.argv[sys.argv.index('--') + 1:])

CELL = 256          # layout cell; --cell only changes the pixel size of preview stills
ORTHO = 1.25
ANIMS = [
    ("idle", "Hover_Idle", 8, True),
    ("boost", "Boost_Loop", 6, True),
    ("bank_left", "Bank_Left", 6, True),
    ("bank_right", "Bank_Right", 6, True),
    ("dash", "Dash_Forward", 6, False),
    ("fire", "Rifle_Fire", 4, True),
    ("aim", "Aim_Rifle", 6, False),
]
only = {}
for tok in filter(None, args.only.split(',')):
    n, i = tok.split(':'); only.setdefault(n, set()).add(int(i))

s = bpy.context.scene
s.render.resolution_x = s.render.resolution_y = args.cell
s.render.resolution_percentage = 100
s.render.film_transparent = True
s.render.image_settings.file_format = "PNG"
s.render.image_settings.color_mode = "RGBA"
cam = bpy.data.objects["SpriteCamera"]; root = bpy.data.objects["SpriteRoot"]; rig = bpy.data.objects["Gundam_Rig"]
center = root.matrix_world.translation.copy()
cam.data.type = "ORTHO"; cam.data.ortho_scale = ORTHO
cam.location = center + Vector((0, 0, 6)); cam.rotation_euler = (0, 0, math.pi)
s.camera = cam
os.makedirs(args.out, exist_ok=True)

rendered = {}
for name, action, count, loop in ANIMS:
    if only and name not in only: continue
    act = bpy.data.actions[action]
    rig.animation_data.action = act
    if hasattr(rig.animation_data, 'action_slot') and act.slots: rig.animation_data.action_slot = act.slots[0]
    start, end = act.frame_range; span = end - start
    files = []
    for i in range(count):
        if only and i not in only[name]: continue
        f = start + (span * i / count if loop else span * i / max(count - 1, 1))
        s.frame_set(int(round(f)))
        path = os.path.join(args.out, f"{name}_{i}.png")
        s.render.filepath = path
        bpy.ops.render.render(write_still=True)
        print("RENDERED", name, i, "frame", int(round(f)))
        files.append(path)
    rendered[name] = files

if args.sheet and not only:
    cols = max(c for _, _, c, _ in ANIMS)
    sheet = np.zeros((len(ANIMS) * CELL, cols * CELL, 4), dtype=np.float32)
    for r, (name, *_r) in enumerate(ANIMS):
        for c, path in enumerate(rendered[name]):
            img = bpy.data.images.load(path)
            px = np.empty(CELL * CELL * 4, dtype=np.float32); img.pixels.foreach_get(px)
            sheet[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL] = px.reshape(CELL, CELL, 4)[::-1]
            bpy.data.images.remove(img)
    out = bpy.data.images.new("halo_sheet", cols * CELL, len(ANIMS) * CELL, alpha=True)
    out.alpha_mode = "STRAIGHT"
    out.pixels.foreach_set(sheet[::-1].ravel())
    out.filepath_raw = args.sheet; out.file_format = "PNG"; out.save()
    print("SHEET", args.sheet, cols * CELL, len(ANIMS) * CELL)
