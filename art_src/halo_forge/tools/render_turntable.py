"""Customize-screen turntable (ui/customize.gd) from the Halo Forge model itself: N frames of one full
turn, frame 0 = front, turning clockwise seen from above, one fixed camera/scale for every frame (no jitter).
Framed on a 560 x 560 canvas with the feet on (280, 548) and the body 520 px tall.

Showcase look (brighter than the in-game sprite): lighter cel bands, a soft cool rim light on the silhouette,
rendered at SS x the size and scaled down, so the outlines come out thin and clean.

blender -b HaloForge_2D_Sprites.blend --python render_turntable.py -- <out dir> [frames=120] [--only 0,30] [--crop]
--crop-only: crop the N frames already in <out dir> without rendering.
--crop: after rendering, crops every frame to the union of their visible pixels (+ margin) and prints the new
FEET (the canvas point under the feet) for ui/customize.gd.
Never saves the .blend.
"""
import bpy, sys, os, math, numpy as np
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = argv[0]
N = int(argv[1]) if len(argv) > 1 and argv[1].isdigit() else 120
ONLY = [int(x) for x in argv[argv.index('--only') + 1].split(',')] if '--only' in argv else None
CROP = '--crop' in argv or '--crop-only' in argv
CROP_ONLY = '--crop-only' in argv
CANVAS, FEET_X, FEET_Y, BODY_H = 560, 280, 548, 520
SS = 1.5
DECIMATE = float(argv[argv.index('--decimate') + 1]) if '--decimate' in argv else 0.3
ELEV = math.radians(10)

s = bpy.context.scene
rig = bpy.data.objects['Gundam_Rig']; hf = bpy.data.objects[s.get('mech_body', 'HaloForge')]; rifle = bpy.data.objects['Rifle']
root = bpy.data.objects['SpriteRoot']; cam = bpy.data.objects['SpriteCamera']
act = bpy.data.actions['Hover_Idle']; rig.animation_data.action = act
if act.slots: rig.animation_data.action_slot = act.slots[0]
s.frame_set(1)

s.render.resolution_percentage = 100
s.render.film_transparent = True
s.render.image_settings.file_format = 'PNG'; s.render.image_settings.color_mode = 'RGBA'
s.view_layers[0].freestyle_settings.linesets[0].linestyle.thickness = 1.8
bpy.data.objects['Sprite_Key'].rotation_euler = (math.radians(50), math.radians(-30), math.radians(-35))


def showcase_material(mat):
    """Brighter albedo (midtones lifted, the gold nudged toward the design's yellow-gold), lighter cel bands,
    and a cool rim light added on top of the emission colour."""
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
    rim_ramp = nodes.new('ShaderNodeValToRGB')
    rim_ramp.color_ramp.elements[0].position = 0.55; rim_ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    rim_ramp.color_ramp.elements[1].position = 0.95; rim_ramp.color_ramp.elements[1].color = (0.32, 0.5, 0.75, 1)
    links.new(lw.outputs['Facing'], rim_ramp.inputs[0])
    add = nodes.new('ShaderNodeMixRGB'); add.blend_type = 'ADD'; add.inputs[0].default_value = 1.0
    links.new(src, add.inputs[1]); links.new(rim_ramp.outputs[0], add.inputs[2])
    links.new(add.outputs[0], emi.inputs['Color'])


for m in bpy.data.materials:
    if m.name.startswith('SPRITE_Cel') and m.use_nodes:
        showcase_material(m)

# Fewer polygons for the turntable only (the outline pass is the slow part; invisible at 560 px): the posed
# mesh is frozen once into a static, decimated copy under SpriteRoot, so each frame only turns an object.
if DECIMATE < 1.0:
    dg0 = bpy.context.evaluated_depsgraph_get()
    frozen = bpy.data.meshes.new_from_object(hf.evaluated_get(dg0), preserve_all_data_layers=True, depsgraph=dg0)
    still = bpy.data.objects.new('HaloForgeStill', frozen)
    s.collection.objects.link(still)
    still.matrix_world = hf.matrix_world.copy()
    mw = still.matrix_world.copy(); still.parent = root; still.matrix_world = mw
    dm = still.modifiers.new('TurntableDecimate', 'DECIMATE'); dm.ratio = DECIMATE
    bpy.context.view_layer.objects.active = still
    for o in bpy.context.selected_objects:
        o.select_set(False)
    still.select_set(True)
    bpy.ops.object.modifier_apply(modifier=dm.name)
    hf.hide_render = True
    # (decimation opens tiny mesh borders inside the plates: outline only silhouettes and contours)
    s.view_layers[0].freestyle_settings.linesets[0].select_border = False
    print('DECIMATED', len(hf.data.vertices), '->', len(still.data.vertices))

pivot = root.matrix_world.translation.copy()
cam.data.type = 'ORTHO'
fwd = Vector((0, math.cos(ELEV), -math.sin(ELEV)))          # looking at the mech's front (-Y side), a bit from above
cam.rotation_euler = fwd.to_track_quat('-Z', 'Y').to_euler()
R = cam.rotation_euler.to_matrix(); up = R @ Vector((0, 1, 0))


# Fixed scale/framing from the vertical extent over the whole turn (feet -> top of the head crest/rifle).
def world_pts():
    dg = bpy.context.evaluated_depsgraph_get(); pts = []
    for o in (hf, rifle):
        me = o.evaluated_get(dg).to_mesh()
        co = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get('co', co)
        m = np.array(o.matrix_world); pts.append(co.reshape(-1, 3)[::20] @ m[:3, :3].T + m[:3, 3])
        o.evaluated_get(dg).to_mesh_clear()
    return np.concatenate(pts)


P = world_pts(); upv = np.array(up)
lo = hi = None
for k in range(0, 360, 15):
    Rz = np.array(Matrix.Rotation(-math.radians(k), 3, 'Z'))
    q = (P - np.array(pivot)) @ Rz.T
    h = q @ upv
    lo = h.min() if lo is None else min(lo, h.min()); hi = h.max() if hi is None else max(hi, h.max())
# Wide enough for whatever sticks out sideways at any angle of the turn (the rifle), same scale.
px = (hi - lo) / BODY_H
rgt = np.array(R @ Vector((1, 0, 0)))
ext = 0.0
for k in range(0, 360, 5):
    Rz = np.array(Matrix.Rotation(-math.radians(k), 3, 'Z'))
    ext = max(ext, float(np.abs(((P - np.array(pivot)) @ Rz.T) @ rgt).max()))
CANVAS_W = max(CANVAS, 2 * int(math.ceil(ext / px + 12)))
FEET_X = CANVAS_W // 2
cam.data.ortho_scale = px * CANVAS_W
centre_h = lo + (FEET_Y - CANVAS / 2) * px
cam.location = pivot + up * centre_h - fwd * 6.0
s.camera = cam
s.render.resolution_x = int(CANVAS_W * SS); s.render.resolution_y = int(CANVAS * SS)
print('ORTHO', round(cam.data.ortho_scale, 4), 'CANVAS', CANVAS_W, CANVAS)


def load_px(path):
    im = bpy.data.images.load(path)
    w, h = im.size
    a = np.empty(w * h * 4, np.float32); im.pixels.foreach_get(a)
    bpy.data.images.remove(im)
    return a.reshape(h, w, 4)


def save_px(path, a):
    h, w = a.shape[:2]
    im = bpy.data.images.new('o', w, h, alpha=True)
    im.pixels.foreach_set(a.ravel()); im.filepath_raw = path; im.file_format = 'PNG'; im.save()
    bpy.data.images.remove(im)


os.makedirs(OUT, exist_ok=True)
tmp = os.path.join(OUT, '_big.png')
frames = ONLY if ONLY is not None else list(range(N))
for i in ([] if CROP_ONLY else frames):
    root.rotation_euler = (0, 0, -2 * math.pi * i / N)
    s.render.filepath = tmp
    bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(tmp)
    im.scale(CANVAS_W, CANVAS)
    im.filepath_raw = os.path.join(OUT, 'frame_%03d.png' % i); im.file_format = 'PNG'; im.save()
    bpy.data.images.remove(im)
    print('TURN', i)
root.rotation_euler = (0, 0, 0)
if os.path.exists(tmp):
    os.remove(tmp)

if CROP:
    x0, y0, x1, y1 = CANVAS_W, CANVAS, 0, 0
    for i in frames:
        a = load_px(os.path.join(OUT, 'frame_%03d.png' % i))[::-1]   # top-down rows
        ys, xs = np.nonzero(a[..., 3] > 0.01)
        if len(xs):
            x0, y0 = min(x0, xs.min()), min(y0, ys.min()); x1, y1 = max(x1, xs.max() + 1), max(y1, ys.max() + 1)
    m = 4
    x0, y0 = max(int(x0) - m, 0), max(int(y0) - m, 0)
    x1, y1 = min(int(x1) + m, CANVAS_W), min(int(y1) + m, CANVAS)
    for i in frames:
        p = os.path.join(OUT, 'frame_%03d.png' % i)
        a = load_px(p)[::-1][y0:y1, x0:x1]
        save_px(p, a[::-1].copy())
    print('CROP', x0, y0, x1, y1, 'FEET', FEET_X - x0, FEET_Y - y0, 'SIZE', x1 - x0, y1 - y0)
