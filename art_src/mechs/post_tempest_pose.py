"""TEMPEST pose fix (blender -b art_src/mechs/tempest/tempest_2D_Sprites.blend --python art_src/mechs/post_tempest_pose.py).

The shared sprite rig's boost pose pitches the pelvis forward and swings the legs back; on NIMBUS-07's short,
bulky legs that reads fine, but TEMPEST's long thin legs ended up almost flat behind the body, so from the
straight-down sheet camera they looked like two legs floating off the back. This edits TEMPEST's own copy of
the Actions (never the template): in every boosting key the thighs swing down under the hips and the knees bend,
so the feet tuck in just behind the body. Bank poses get a smaller tuck so the legs stop splaying sideways.

Each key is weighted by how far the pelvis is pitched forward at that frame (the boost lean), so idle-like keys
inside Dash_Forward stay as they were. Run once on a freshly built .blend (it saves the file); re-running
would add the offsets again, so the script refuses if it has already run.
"""
import bpy, math
from mathutils import Quaternion

# (action, thigh offset deg, shin offset deg, foot offset deg, weight by pelvis lean?, counter-roll share)
# Counter-roll: the bank poses roll the pelvis sideways; the thighs roll back by this share of it, so the legs
# hang under the body instead of swinging out to one side.
EDITS = [
    ("Boost_Loop", -62.0, 40.0, -10.0, True, 0.0),
    ("Dash_Forward", -62.0, 40.0, -10.0, True, 0.0),
    ("Bank_Left", -18.0, 22.0, 0.0, False, 0.85),
    ("Bank_Right", -18.0, 22.0, 0.0, False, 0.85),
]
BOOST_PITCH = 0.225          # Pelvis rotation_quaternion.x at full boost lean
MARK = "tempest_pose_fix"
ROLL_SIGN = -1.0    # measured: this sign rolls the legs back under the body (the other way splays them further)

rig = bpy.data.objects["Gundam_Rig"]
if rig.get(MARK):
    raise SystemExit("POST TEMPEST POSE: already applied to this .blend - rebuild it first")


def channel_curves(action):
    out = []
    for layer in action.layers:
        for strip in layer.strips:
            for cb in strip.channelbags:
                out += list(cb.fcurves)
    return out


def quat_curves(curves, bone):
    path = 'pose.bones["%s"].rotation_quaternion' % bone
    found = {fc.array_index: fc for fc in curves if fc.data_path == path}
    return [found[i] for i in range(4)] if len(found) == 4 else None


for name, d_thigh, d_shin, d_foot, by_lean, counter_roll in EDITS:
    act = bpy.data.actions[name]
    curves = channel_curves(act)
    pelvis = quat_curves(curves, "Pelvis")
    edited = 0
    for side in ("R", "L"):
        for bone, deg in (("Thigh." + side, d_thigh), ("Shin." + side, d_shin), ("Foot." + side, d_foot)):
            if deg == 0.0:
                continue
            qc = quat_curves(curves, bone)
            if qc is None:
                print("POST TEMPEST POSE: no rotation keys for", name, bone)
                continue
            for k in range(len(qc[0].keyframe_points)):
                frame = qc[0].keyframe_points[k].co[0]
                w = 1.0
                if by_lean and pelvis:
                    w = max(0.0, min(1.0, pelvis[1].evaluate(frame) / BOOST_PITCH))
                if w <= 0.001:
                    continue
                q = Quaternion([qc[i].keyframe_points[k].co[1] for i in range(4)])
                q = q @ Quaternion((1.0, 0.0, 0.0), math.radians(deg * w))
                if counter_roll > 0.0 and pelvis and bone.startswith("Thigh"):
                    pq = Quaternion([pelvis[i].evaluate(frame) for i in range(4)])
                    roll = 2.0 * math.atan2(pq.z, pq.w)
                    q = q @ Quaternion((0.0, 0.0, 1.0), -roll * counter_roll * ROLL_SIGN)
                for i in range(4):
                    kp = qc[i].keyframe_points[k]
                    kp.co[1] = q[i]
                    kp.handle_left_type = kp.handle_right_type = 'AUTO_CLAMPED'
                edited += 1
            for fc in qc:
                fc.update()
    print("POST TEMPEST POSE:", name, "keys edited", edited)

rig[MARK] = True
bpy.ops.wm.save_mainfile()
print("POST SAVED")
