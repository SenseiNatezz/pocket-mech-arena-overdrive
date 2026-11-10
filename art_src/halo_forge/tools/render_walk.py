"""Renders NIMBUS-07's WALKING sprites: the mech split into two layers so it can walk on the ground
(legs face the way it moves, the upper body turns to the aim on top - player/mech.gd).

  blender -b HaloForge_2D_Sprites.blend --python render_walk.py -- --out <dir> --dst <assets/sprites/walk> [--only walk]

Same camera / cell / look as render_haloforge.py. Writes into --dst:
  nimbus_legs.png         8 x 2 cells: row 0 = walk cycle (8), row 1 = stand, dash slide
  nimbus_torso.png        the gundam_sheet.png layout (idle 8, boost 6, bank_left 6, bank_right 6, dash 6,
                          fire 4, aim 6) with the legs + pelvis masked out, so fists stay where
                          held_weapon.gd's tables put them, plus an 8th row: `walk` (8 frames, in step with
                          the legs' walk cycle) - the upper body leaning, rolling and counter-swinging its
                          shoulders and arms with every step. The script prints that row's fist / rifle tip
                          tables (WALK TABLES) for held_weapon.gd.
  nimbus_torso_nogun.png  the same with the rifle hidden
The legs are posed by hand here (no Action); nothing is saved to the .blend.
"""
import bpy, math, os, sys, argparse
import numpy as np
from mathutils import Vector, Matrix

ap = argparse.ArgumentParser()
ap.add_argument('--out', required=True)
ap.add_argument('--dst', required=True)
ap.add_argument('--only', default='legs,torso,walk', help='which parts to render: legs,torso,walk')
args = ap.parse_args(sys.argv[sys.argv.index('--') + 1:])

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
STRIDE = 20.0        # thigh swing, degrees each way
KNEE_BASE = 8.0
KNEE_LIFT = 34.0     # extra knee bend while the foot swings forward
HIP_YAW = 5.0

s = bpy.context.scene
s.render.resolution_x = s.render.resolution_y = CELL
s.render.resolution_percentage = 100
s.render.film_transparent = True
s.render.image_settings.file_format = "PNG"
s.render.image_settings.color_mode = "RGBA"
cam = bpy.data.objects["SpriteCamera"]; root = bpy.data.objects["SpriteRoot"]; rig = bpy.data.objects["Gundam_Rig"]
mesh = bpy.data.objects["HaloForge"]; rifle = bpy.data.objects["Rifle"]
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


def render(name):
    path = os.path.join(args.out, name + ".png")
    s.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("RENDERED", name)
    return path


def rot_about(pb, axis, deg):
    """Turns pose bone `pb` by `deg` about an armature-space axis through its own head."""
    bpy.context.view_layer.update()
    base = pb.matrix.copy()
    h = base.translation.copy()
    pb.matrix = Matrix.Translation(h) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-h) @ base
    bpy.context.view_layer.update()


def pose_legs(left, right, yaw):
    """left / right = (thigh forward deg, knee bend deg). Front of the mech is -Y, so forward = -X turn."""
    for pb in rig.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
    rot_about(rig.pose.bones["Pelvis"], 'Z', yaw)
    # The chest hangs off the pelvis; it is masked out of the legs render, so its turn does not matter.
    for side, (fwd, knee) in (("L", left), ("R", right)):
        rot_about(rig.pose.bones["Thigh." + side], 'X', -fwd)
        rot_about(rig.pose.bones["Shin." + side], 'X', knee)
        rot_about(rig.pose.bones["Foot." + side], 'X', (fwd - knee) * 0.9)


def walk_leg(phase):
    a = math.tau * phase
    return (STRIDE * math.sin(a), KNEE_BASE + KNEE_LIFT * max(0.0, math.cos(a)))


def assemble(rows, cols, cells, dst):
    sheet = np.zeros((rows * CELL, cols * CELL, 4), dtype=np.float32)
    for (r, c), path in cells.items():
        img = bpy.data.images.load(path)
        px = np.empty(CELL * CELL * 4, dtype=np.float32); img.pixels.foreach_get(px)
        sheet[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL] = px.reshape(CELL, CELL, 4)[::-1]
        bpy.data.images.remove(img)
    out = bpy.data.images.new("sheet", cols * CELL, rows * CELL, alpha=True)
    out.alpha_mode = "STRAIGHT"
    out.pixels.foreach_set(sheet[::-1].ravel())
    out.filepath_raw = dst; out.file_format = "PNG"; out.save()
    bpy.data.images.remove(out)
    print("SHEET", dst)


# --- legs layer ---------------------------------------------------------------------------------
ONLY = set(args.only.split(','))
rig.animation_data.action = None
rifle.hide_render = True
if 'legs' in ONLY:
    mask.invert_vertex_group = False
    cells = {}
    for i in range(WALK_FRAMES):
        p = i / WALK_FRAMES
        pose_legs(walk_leg(p), walk_leg(p + 0.5), -HIP_YAW * math.sin(math.tau * p))
        cells[(0, i)] = render("legs_walk_%d" % i)
    pose_legs((0.0, 0.0), (0.0, 0.0), 0.0)
    cells[(1, 0)] = render("legs_stand")
    pose_legs((27.0, 22.0), (-22.0, 30.0), -6.0)
    cells[(1, 1)] = render("legs_slide")
    assemble(2, WALK_FRAMES, cells, os.path.join(args.dst, "nimbus_legs.png"))
for pb in rig.pose.bones:
    pb.rotation_quaternion = (1, 0, 0, 0)

# --- torso layer (with / without the rifle) -----------------------------------------------------
# The walk row: on top of the first idle frame, the chest counter-swings against the hips, rolls and nods
# with each step, the free (left) arm swings against its leg and the gun arm a little the other way.
CHEST_YAW = 10.0
CHEST_ROLL = 5.0
CHEST_LEAN = 5.0
CHEST_NOD = 3.5
ARM_SWING = 16.0
GUN_ARM_SWING = 6.0
HEAD_COUNTER = 7.0
# held_weapon.gd's measured idle frame 0 (the walk tables are that plus how far the hand bones move).
IDLE_FIST = (179.8, 106.9)
IDLE_TIP = (197.4, 15.0)


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
    rot_about(chest, 'Z', CHEST_YAW * sn)
    rot_about(chest, 'Y', CHEST_ROLL * sn)
    rot_about(chest, 'X', CHEST_LEAN + CHEST_NOD * math.cos(2.0 * a))
    rot_about(rig.pose.bones["Head"], 'Z', -HEAD_COUNTER * sn)
    rot_about(rig.pose.bones["UpperArm.L"], 'X', ARM_SWING * sn)
    rot_about(rig.pose.bones["UpperArm.R"], 'X', -GUN_ARM_SWING * sn)
    bpy.context.view_layer.update()


mask.invert_vertex_group = True
cols = max(c for _, _, c, _ in ANIMS)
for tag, hide_rifle in (("", False), ("_nogun", True)):
    rifle.hide_render = hide_rifle
    cells = {}
    if 'torso' in ONLY:
        for r, (name, action, count, loop) in enumerate(ANIMS):
            act = set_action(action)
            start, end = act.frame_range; span = end - start
            for i in range(count):
                f = start + (span * i / count if loop else span * i / max(count - 1, 1))
                s.frame_set(int(round(f)))
                cells[(r, i)] = render("torso%s_%s_%d" % (tag, name, i))
    if 'walk' in ONLY:
        act = set_action("Hover_Idle")
        s.frame_set(int(act.frame_range[0]))
        bpy.context.view_layer.update()
        base = {pb.name: (pb.rotation_quaternion.copy(), pb.location.copy()) for pb in rig.pose.bones}
        idle = {b: px(b) for b in ("Hand.R", "Hand.L", "Weapon_Muzzle")}
        rig.animation_data.action = None
        fist, fist_l, tip = [], [], []
        for i in range(WALK_FRAMES):
            pose_walk_torso(base, i / WALK_FRAMES)
            d = {b: (px(b)[0] - idle[b][0], px(b)[1] - idle[b][1]) for b in idle}
            fist.append((IDLE_FIST[0] + d["Hand.R"][0], IDLE_FIST[1] + d["Hand.R"][1]))
            fist_l.append((CELL - IDLE_FIST[0] + d["Hand.L"][0], IDLE_FIST[1] + d["Hand.L"][1]))
            tip.append((IDLE_TIP[0] + d["Weapon_Muzzle"][0], IDLE_TIP[1] + d["Weapon_Muzzle"][1]))
            cells[(len(ANIMS), i)] = render("torso%s_walk_%d" % (tag, i))
        if tag == "":
            fmt = lambda pts: "[" + ", ".join("Vector2(%.1f, %.1f)" % p for p in pts) + "]"
            print("WALK TABLES")
            print("WALK_FIST " + fmt(fist))
            print("WALK_FIST_LEFT " + fmt(fist_l))
            print("WALK_TIP " + fmt(tip))
    if 'torso' in ONLY and 'walk' in ONLY:
        assemble(len(ANIMS) + 1, cols, cells, os.path.join(args.dst, "nimbus_torso%s.png" % tag))
print("WALK DONE")
