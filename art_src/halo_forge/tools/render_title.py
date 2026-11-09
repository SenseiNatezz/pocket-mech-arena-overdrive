"""Title-screen hero art for ui/title_scene.gd: the Halo Forge model itself (no AI art), cel material +
Freestyle outline, rifle in the right fist, with the Customize turntable's brighter showcase look (lighter
bands, lifted albedo, cool rim light; render_turntable.py showcase_material).
Writes assets/hq/title_mech.png cropped to the visible pixels and TARGET_H tall, and prints the visor
points as fractions of that image (title_scene.gd EYES).

blender -b HaloForge_2D_Sprites.blend --python render_title.py -- <project dir> [--preview <png>]
    [--pose Aim_Rifle:25] [--yaw 35] [--elev -8]
  pose  Action:frame to pose the mech in (default Aim_Rifle:25, rifle levelled)
  yaw   degrees the mech is turned; + turns its front toward screen-right (toward the menu)
  elev  camera elevation in degrees; negative = from below (heroic low angle)
Never saves the .blend.
"""
import bpy, sys, os, math, numpy as np
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view

argv = sys.argv[sys.argv.index('--') + 1:]
PROJECT = argv[0]


def opt(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


PREVIEW = opt('--preview', None)
POSE = opt('--pose', 'Aim_Rifle:25')
YAW = float(opt('--yaw', '35'))
ELEV = math.radians(float(opt('--elev', '-8')))
TARGET_H = 1100
RES = 1800

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

s = bpy.context.scene
rig = bpy.data.objects['Gundam_Rig']; hf = bpy.data.objects['HaloForge']; rifle = bpy.data.objects['Rifle']
act_name, frame = POSE.split(':')
act = bpy.data.actions[act_name]
rig.animation_data.action = act
if act.slots: rig.animation_data.action_slot = act.slots[0]
s.frame_set(int(frame))

cam = bpy.data.objects['SpriteCamera']; root = bpy.data.objects['SpriteRoot']
root.rotation_euler = (0, 0, math.radians(YAW))
bpy.context.view_layer.update()
fwd = Vector((0, math.cos(ELEV), -math.sin(ELEV)))
cam.data.type = 'ORTHO'
cam.rotation_euler = fwd.to_track_quat('-Z', 'Y').to_euler()
s.render.resolution_x = s.render.resolution_y = RES; s.render.resolution_percentage = 100
s.render.film_transparent = True
s.render.image_settings.file_format = 'PNG'; s.render.image_settings.color_mode = 'RGBA'
s.view_layers[0].freestyle_settings.linesets[0].linestyle.thickness = 3.0
bpy.data.objects['Sprite_Key'].rotation_euler = (math.radians(50), math.radians(-30), math.radians(-35))


def showcase_material(mat):
    nodes = mat.node_tree.nodes; links = mat.node_tree.links
    ramp = next((n for n in nodes if n.type == 'VALTORGB'), None)
    if ramp is None:
        return
    els = sorted(ramp.color_ramp.elements, key=lambda e: e.position)
    if len(els) >= 3:
        els[0].position = 0.0; els[0].color = (0.74, 0.78, 0.86, 1)
        els[1].position = 0.16; els[1].color = (0.92, 0.94, 0.98, 1)
        els[-1].position = 0.42; els[-1].color = (1, 1, 1, 1)
    mul = next((n for n in nodes if n.type == 'MIX_RGB' and n.blend_type == 'MULTIPLY'), None)
    if mul is not None and mul.inputs[1].is_linked:
        tex = mul.inputs[1].links[0].from_socket
        gamma = nodes.new('ShaderNodeGamma'); gamma.inputs['Gamma'].default_value = 0.8
        hue = nodes.new('ShaderNodeHueSaturation')
        hue.inputs['Hue'].default_value = 0.508; hue.inputs['Saturation'].default_value = 0.95
        hue.inputs['Value'].default_value = 1.04
        links.new(tex, gamma.inputs['Color']); links.new(gamma.outputs[0], hue.inputs['Color'])
        links.new(hue.outputs[0], mul.inputs[1])
    emi = next((n for n in nodes if n.type == 'EMISSION'), None)
    if emi is None or not emi.inputs['Color'].is_linked:
        return
    src = emi.inputs['Color'].links[0].from_socket
    lw = nodes.new('ShaderNodeLayerWeight'); lw.inputs['Blend'].default_value = 0.35
    rim = nodes.new('ShaderNodeValToRGB')
    rim.color_ramp.elements[0].position = 0.5; rim.color_ramp.elements[0].color = (0, 0, 0, 1)
    rim.color_ramp.elements[1].position = 0.95; rim.color_ramp.elements[1].color = (0.36, 0.56, 0.85, 1)
    links.new(lw.outputs['Facing'], rim.inputs[0])
    add = nodes.new('ShaderNodeMixRGB'); add.blend_type = 'ADD'; add.inputs[0].default_value = 1.0
    links.new(src, add.inputs[1]); links.new(rim.outputs[0], add.inputs[2])
    links.new(add.outputs[0], emi.inputs['Color'])


for m in bpy.data.materials:
    if m.name.startswith('SPRITE_Cel') and m.use_nodes:
        showcase_material(m)

# Frame the posed mech: fit its projected extent (with a margin) in the square render.
dg = bpy.context.evaluated_depsgraph_get()
pts = []
for o in (hf, rifle):
    me = o.evaluated_get(dg).to_mesh()
    co = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get('co', co)
    m = np.array(o.matrix_world); pts.append(co.reshape(-1, 3)[::10] @ m[:3, :3].T + m[:3, 3])
    o.evaluated_get(dg).to_mesh_clear()
P = np.concatenate(pts)
R3 = np.array(cam.rotation_euler.to_matrix())
right = R3[:, 0]; up = R3[:, 1]
u = P @ right; v = P @ up
cu, cv = (u.min() + u.max()) / 2, (v.min() + v.max()) / 2
cam.data.ortho_scale = max(u.max() - u.min(), v.max() - v.min()) * 1.12
cam.location = Vector(right * cu + up * cv) - fwd * 8.0
s.camera = cam

raw = os.path.join(PROJECT, 'art_src', 'halo_forge', 'title_raw.png')
s.render.filepath = raw
bpy.ops.render.render(write_still=True)

# Visor: the front-most skin of the head (in the mech's own frame, -Y = forward), left / right halves.
ev = hf.evaluated_get(dg); me = ev.to_mesh()
gi = hf.vertex_groups['Head'].index
idx = [v.index for v in hf.data.vertices if any(g.group == gi for g in v.groups)]
co = np.array([tuple(hf.matrix_world @ me.vertices[i].co) for i in idx])
ev.to_mesh_clear()
pivot = np.array(root.matrix_world.translation)
inv = np.array(Matrix.Rotation(-math.radians(YAW), 3, 'Z'))
loc = (co - pivot) @ inv.T
zc = np.percentile(loc[:, 2], 45)
sel = np.abs(loc[:, 2] - zc) < 0.03
band_l, band_w = loc[sel], co[sel]
front = band_l[:, 1] < np.percentile(band_l[:, 1], 6)
fl, fw = band_l[front], band_w[front]
cx = np.median(fl[:, 0])
eyes_w = [fw[fl[:, 0] > cx].mean(0), fw[fl[:, 0] <= cx].mean(0)]

img = bpy.data.images.load(raw)
w, h = img.size
px = np.empty(w * h * 4, np.float32); img.pixels.foreach_get(px); px = px.reshape(h, w, 4)[::-1]
ys, xs = np.nonzero(px[..., 3] > 0.02)
x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
crop = px[y0:y1, x0:x1].copy()
k = TARGET_H / crop.shape[0]
ow, oh = round(crop.shape[1] * k), TARGET_H
out = bpy.data.images.new('title_mech', crop.shape[1], crop.shape[0], alpha=True)
out.pixels.foreach_set(crop[::-1].ravel())
out.scale(ow, oh)
dst = os.path.join(PROJECT, 'assets', 'hq', 'title_mech.png') if not PREVIEW else PREVIEW
out.filepath_raw = dst; out.file_format = 'PNG'; out.save()
print('TITLE', dst, ow, oh)
for name, p in zip(('eye_l', 'eye_r'), sorted(eyes_w, key=lambda q: world_to_camera_view(s, cam, Vector(q)).x)):
    uvp = world_to_camera_view(s, cam, Vector(p))
    fx = (uvp.x * w - x0) / (x1 - x0); fy = ((1 - uvp.y) * h - y0) / (y1 - y0)
    print('%s = Vector2(%.3f, %.3f)' % (name, fx, fy))
