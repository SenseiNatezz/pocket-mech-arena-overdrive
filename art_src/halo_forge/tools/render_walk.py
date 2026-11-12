"""Renders a mech's TWO-LAYER sprites: the legs and the upper body apart, so the legs can face the way the
mech moves while the upper body turns to the aim on top (player/mech.gd, Game.chassis_walk_art).

  blender -b <mech>_2D_Sprites.blend --python render_walk.py -- --name <sheet> --out <frames dir>
          --dst <assets/sprites/walk> --tables <art_src/walk/<sheet>.json> [--hover] [--only legs,torso,walk]

Works on NIMBUS-07's HaloForge_2D_Sprites.blend and on every art_src/mechs/<sheet>/<sheet>_2D_Sprites.blend
(same rig; the body mesh is "HaloForge" or "MechBody"). Same camera / cell / look as render_haloforge.py.
Writes into --dst:
  <sheet>_legs.png         8 x 2 cells: row 0 = `walk` (8 frames), row 1 = `stand`, `slide` (the dash pose)
  <sheet>_torso.png        the sheet.png layout (idle 8, boost 6, bank_left 6, bank_right 6, dash 6, fire 4,
                           aim 6) with the legs + pelvis masked out, plus an 8th row: the upper body's own
                           `walk` cycle (8 frames, in step with the legs)
  <sheet>_torso_nogun.png  the same with the rifle hidden
and into --tables how far the hands and the rifle tip move in each walk frame from the first idle frame, in
sheet px (art_src/walk/make_tables.py turns those into assets/sprites/walk/walk_tables.gd for held_weapon.gd).

WALKING (default): legs stride on the ground; the chest counter-swings against the hips, rolls and nods with
each step and the arms swing (the look of URAGUN's mech: the whole upper body works with every step).
--hover: the mech floats instead (RAVEN CLAW). Its legs hang tucked under the hips and trail a little, kicking
gently; the upper body sways and rolls as it glides. Same layers, same files.

Frames are kept in --out; --only re-renders some parts and the sheets are put together from every frame there.
Nothing is saved to the .blend.
"""
import bpy, math, os, sys, json, argparse
import numpy as np
from mathutils import Vector, Matrix

ap = argparse.ArgumentParser()
ap.add_argument('--name', required=True)
ap.add_argument('--out', required=True)
ap.add_argument('--dst', required=True)
ap.add_argument('--tables', required=True)
ap.add_argument('--hover', action='store_true')
ap.add_argument('--only', default='legs,torso,walk', help='which parts to render: legs,torso,walk')
args = ap.parse_args(sys.argv[sys.argv.index('--') + 1:])
ONLY = set(args.only.split(','))

CELL = 256
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
LEG_GROUPS = {"Pelvis", "Thigh.L", "Thigh.R", "Shin.L", "Shin.R", "Foot.L", "Foot.R"}
WALK_FRAMES = 8
# Walking legs.
STRIDE = 25.0        # thigh swing, degrees each way
KNEE_BASE = 8.0
KNEE_LIFT = 38.0     # extra knee bend while the foot swings forward
HIP_YAW = 6.0
# Walking upper body.
CHEST_YAW = 10.0
CHEST_ROLL = 5.0
CHEST_LEAN = 5.0
CHEST_NOD = 3.5
ARM_SWING = 16.0
GUN_ARM_SWING = 6.0
HEAD_COUNTER = 7.0
# Hovering (--hover): (thigh forward, knee bend) of the tucked legs, how far they kick, and the upper body.
HOVER_LEGS = (-14.0, 62.0)
HOVER_KICK = 11.0
HOVER_IDLE = (-4.0, 30.0)
HOVER_DASH = (-34.0, 78.0)
HOVER_YAW = 5.0
HOVER_ROLL = 6.0
HOVER_LEAN = 9.0
HOVER_NOD = 2.0
HOVER_ARMS = 7.0

s = bpy.context.scene
s.render.resolution_x = s.render.resolution_y = CELL
s.render.resolution_percentage = 100
s.render.film_transparent = True
s.render.image_settings.file_format = "PNG"
s.render.image_settings.color_mode = "RGBA"
cam = bpy.data.objects["SpriteCamera"]; root = bpy.data.objects["SpriteRoot"]; rig = bpy.data.objects["Gundam_Rig"]
mesh = bpy.data.objects.get("HaloForge") or bpy.data.objects["MechBody"]
rifle = bpy.data.objects["Rifle"]
center = root.matrix_world.translation.copy()
cam.data.type = "ORTHO"; cam.data.ortho_scale = ORTHO
cam.location = center + Vector((0, 0, 6)); cam.rotation_euler = (0, 0, math.pi)
s.camera = cam
os.makedirs(args.out, exist_ok=True)
os.makedirs(args.dst, exist_ok=True)

# --- legs / torso split: a vertex group of everything skinned mostly to the pelvis and legs -------
leg_idx = {g.index for g in mesh.vertex_groups if g.name in LEG_GROUPS}
legs = []
for v in mesh.data.vertices:
    best_w = 0.0; best = -1
    for g in v.groups:
        if g.weight > best_w:
            best_w = g.weight; best = g.group
    if best in leg_idx:
        legs.append(v.index)
vg = mesh.vertex_groups.new(name="WALK_LEGS")
vg.add(legs, 1.0, 'REPLACE')
mask = mesh.modifiers.new("WalkMask", 'MASK')
mask.vertex_group = "WALK_LEGS"
print("LEGS VERTS", len(legs), "of", len(mesh.data.vertices))
hip = rig.matrix_world @ rig.data.bones["Pelvis"].head_local
print("HIP_PX", round((hip.x - center.x) * CELL / ORTHO, 2), round((hip.y - center.y) * CELL / ORTHO, 2))


def frame_path(name):
    return os.path.join(args.out, name + ".png")


def render(name):
    s.render.filepath = frame_path(name)
    bpy.ops.render.render(write_still=True)
    print("RENDERED", name)


def rot_about(pb, axis, deg):
    """Turns pose bone `pb` by `deg` about an armature-space axis through its own head."""
    bpy.context.view_layer.update()
    base = pb.matrix.copy()
    h = base.translation.copy()
    pb.matrix = Matrix.Translation(h) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-h) @ base
    bpy.context.view_layer.update()


def reset_pose():
    for pb in rig.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)


def pose_legs(left, right, yaw, toes=0.9):
    """left / right = (thigh forward deg, knee bend deg). Front of the mech is -Y, so forward = -X turn.
    toes: how much of the leg's pitch the foot takes back (0.9 = flat on the ground, less = toes hang)."""
    reset_pose()
    rot_about(rig.pose.bones["Pelvis"], 'Z', yaw)
    # The chest hangs off the pelvis; it is masked out of the legs render, so its turn does not matter.
    for side, (fwd, knee) in (("L", left), ("R", right)):
        rot_about(rig.pose.bones["Thigh." + side], 'X', -fwd)
        rot_about(rig.pose.bones["Shin." + side], 'X', knee)
        rot_about(rig.pose.bones["Foot." + side], 'X', (fwd - knee) * toes)


def walk_leg(phase):
    a = math.tau * phase
    return (STRIDE * math.sin(a), KNEE_BASE + KNEE_LIFT * max(0.0, math.cos(a)))


def hover_leg(phase):
    k = HOVER_KICK * math.sin(math.tau * phase)
    return (HOVER_LEGS[0] + k, HOVER_LEGS[1] - k)


def set_action(action):
    act = bpy.data.actions[action]
    rig.animation_data.action = act
    if hasattr(rig.animation_data, 'action_slot') and act.slots: rig.animation_data.action_slot = act.slots[0]
    return act


def px(bone):
    """Sheet pixel of a pose bone's head (the camera is turned half round: front of the mech is up)."""
    w = rig.matrix_world @ rig.pose.bones[bone].head
    k = CELL / ORTHO
    return (CELL / 2 - (w.x - center.x) * k, CELL / 2 + (w.y - center.y) * k)


def pose_walk_torso(base, phase):
    for pb in rig.pose.bones:
        pb.rotation_quaternion = base[pb.name][0]; pb.location = base[pb.name][1]
    a = math.tau * phase
    sn = math.sin(a)
    chest = rig.pose.bones["Chest"]
    if args.hover:
        rot_about(chest, 'Z', HOVER_YAW * sn)
        rot_about(chest, 'Y', HOVER_ROLL * math.sin(a + 0.9))
        rot_about(chest, 'X', HOVER_LEAN + HOVER_NOD * math.cos(a))
        rot_about(rig.pose.bones["Head"], 'Z', -HOVER_YAW * 0.7 * sn)
        rot_about(rig.pose.bones["UpperArm.L"], 'X', HOVER_ARMS * math.sin(a + 0.6))
        rot_about(rig.pose.bones["UpperArm.R"], 'X', -HOVER_ARMS * 0.5 * math.sin(a + 0.6))
    else:
        rot_about(chest, 'Z', CHEST_YAW * sn)
        rot_about(chest, 'Y', CHEST_ROLL * sn)
        rot_about(chest, 'X', CHEST_LEAN + CHEST_NOD * math.cos(2.0 * a))
        rot_about(rig.pose.bones["Head"], 'Z', -HEAD_COUNTER * sn)
        rot_about(rig.pose.bones["UpperArm.L"], 'X', ARM_SWING * sn)
        rot_about(rig.pose.bones["UpperArm.R"], 'X', -GUN_ARM_SWING * sn)
    bpy.context.view_layer.update()


def assemble(rows, cols, cells, dst):
    missing = [n for n in cells.values() if not os.path.exists(frame_path(n))]
    if missing:
        print("SHEET SKIPPED", os.path.basename(dst), "- frames missing:", len(missing))
        return
    sheet = np.zeros((rows * CELL, cols * CELL, 4), dtype=np.float32)
    for (r, c), name in cells.items():
        img = bpy.data.images.load(frame_path(name))
        px_ = np.empty(CELL * CELL * 4, dtype=np.float32); img.pixels.foreach_get(px_)
        sheet[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL] = px_.reshape(CELL, CELL, 4)[::-1]
        bpy.data.images.remove(img)
    out = bpy.data.images.new("sheet", cols * CELL, rows * CELL, alpha=True)
    out.alpha_mode = "STRAIGHT"
    out.pixels.foreach_set(sheet[::-1].ravel())
    out.filepath_raw = dst; out.file_format = "PNG"; out.save()
    bpy.data.images.remove(out)
    print("SHEET", dst)


# --- legs layer ---------------------------------------------------------------------------------
rig.animation_data.action = None
rifle.hide_render = True
leg_cells = {(0, i): "legs_walk_%d" % i for i in range(WALK_FRAMES)}
leg_cells[(1, 0)] = "legs_stand"
leg_cells[(1, 1)] = "legs_slide"
if 'legs' in ONLY:
    mask.invert_vertex_group = False
    for i in range(WALK_FRAMES):
        p = i / WALK_FRAMES
        if args.hover:
            pose_legs(hover_leg(p), hover_leg(p + 0.5), -2.0 * math.sin(math.tau * p), 0.35)
        else:
            pose_legs(walk_leg(p), walk_leg(p + 0.5), -HIP_YAW * math.sin(math.tau * p))
        render(leg_cells[(0, i)])
    if args.hover:
        pose_legs(HOVER_IDLE, HOVER_IDLE, 0.0, 0.35)
        render("legs_stand")
        pose_legs(HOVER_DASH, HOVER_DASH, 0.0, 0.35)
        render("legs_slide")
    else:
        pose_legs((0.0, 0.0), (0.0, 0.0), 0.0)
        render("legs_stand")
        pose_legs((32.0, 24.0), (-26.0, 32.0), -7.0)
        render("legs_slide")
assemble(2, WALK_FRAMES, leg_cells, os.path.join(args.dst, args.name + "_legs.png"))
reset_pose()

# --- torso layer (with / without the rifle) -----------------------------------------------------
mask.invert_vertex_group = True
cols = max(c for _, _, c, _ in ANIMS)
for tag, hide_rifle in (("", False), ("_nogun", True)):
    rifle.hide_render = hide_rifle
    cells = {}
    for r, (name, action, count, loop) in enumerate(ANIMS):
        act = set_action(action)
        start, end = act.frame_range; span = end - start
        for i in range(count):
            cells[(r, i)] = "torso%s_%s_%d" % (tag, name, i)
            if 'torso' in ONLY:
                f = start + (span * i / count if loop else span * i / max(count - 1, 1))
                s.frame_set(int(round(f)))
                render(cells[(r, i)])
    for i in range(WALK_FRAMES):
        cells[(len(ANIMS), i)] = "torso%s_walk_%d" % (tag, i)
    if 'walk' in ONLY:
        act = set_action("Hover_Idle")
        s.frame_set(int(act.frame_range[0]))
        bpy.context.view_layer.update()
        base = {pb.name: (pb.rotation_quaternion.copy(), pb.location.copy()) for pb in rig.pose.bones}
        idle = {b: px(b) for b in ("Hand.R", "Hand.L", "Weapon_Muzzle")}
        rig.animation_data.action = None
        delta = {"fist": [], "fist_left": [], "tip": []}
        for i in range(WALK_FRAMES):
            pose_walk_torso(base, i / WALK_FRAMES)
            for key, bone in (("fist", "Hand.R"), ("fist_left", "Hand.L"), ("tip", "Weapon_Muzzle")):
                p = px(bone)
                delta[key].append([round(p[0] - idle[bone][0], 1), round(p[1] - idle[bone][1], 1)])
            render(cells[(len(ANIMS), i)])
        if tag == "":
            os.makedirs(os.path.dirname(os.path.abspath(args.tables)), exist_ok=True)
            with open(args.tables, "w") as f:
                json.dump({"name": args.name, "hover": bool(args.hover), "delta": delta}, f, indent=1)
            print("TABLES", args.tables)
    assemble(len(ANIMS) + 1, cols, cells, os.path.join(args.dst, "%s_torso%s.png" % (args.name, tag)))
print("WALK DONE")
