"""App-icon hero render: a tight head-and-shoulders close-up of NIMBUS-07 (the player mech's own 3D model in
art_src/halo_forge/HaloForge_2D_Sprites.blend - no AI art), lit like the title screen (render_title.py's
showcase material: lifted albedo + cool rim) from a heroic low angle. Transparent PNG for make_app_icons.py.

blender -b art_src/halo_forge/HaloForge_2D_Sprites.blend --python art_src/web/render_icon_mech.py -- <out.png>
    [--pose Aim_Rifle:25] [--yaw 28] [--elev -12] [--top 0.40] [--res 1400] [--head 3.4 --dy 0.18]
  top   share of the mech's height (from the top of the head) that fills the frame
Never saves the .blend.
"""
import bpy, sys, os, math, numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(argv[0])


def opt(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


POSE = opt('--pose', 'Aim_Rifle:25')
YAW = float(opt('--yaw', '28'))
ELEV = math.radians(float(opt('--elev', '-12')))
TOP = float(opt('--top', '0.40'))
RES = int(opt('--res', '1400'))
## --head K: frame on the head instead, K head-bone lengths across (the face fills the icon); --dy shifts down.
HEAD = float(opt('--head', '0'))
DY = float(opt('--dy', '0.18'))

s = bpy.context.scene
rig = bpy.data.objects['Gundam_Rig']; hf = bpy.data.objects['HaloForge']; rifle = bpy.data.objects['Rifle']
act_name, frame = POSE.split(':')
act = bpy.data.actions[act_name]
rig.animation_data.action = act
if act.slots:
    rig.animation_data.action_slot = act.slots[0]
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
# A bolder ink line than the sprites: the icon is shown tiny.
s.view_layers[0].freestyle_settings.linesets[0].linestyle.thickness = 5.0
bpy.data.objects['Sprite_Key'].rotation_euler = (math.radians(50), math.radians(-30), math.radians(-35))

# (copied from art_src/halo_forge/tools/render_title.py, which renders on import)
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

# Frame the top TOP of the mech (head, visor, shoulder discs, chest) square in the render.
dg = bpy.context.evaluated_depsgraph_get()
me = hf.evaluated_get(dg).to_mesh()
co = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get('co', co)
m = np.array(hf.matrix_world); P = co.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]
hf.evaluated_get(dg).to_mesh_clear()
zmax, zmin = P[:, 2].max(), P[:, 2].min()
P = P[P[:, 2] > zmax - (zmax - zmin) * TOP]
R3 = np.array(cam.rotation_euler.to_matrix())
right = R3[:, 0]; up = R3[:, 1]
u = P @ right; v = P @ up
side = max(u.max() - u.min(), v.max() - v.min()) * 1.06
cu = (u.min() + u.max()) / 2
cv = v.max() - side / 2 + side * 0.03
if HEAD > 0.0:
    # Centre on the Head bone, K head-bone lengths across (the Head vertex group spills onto the collar).
    pb = rig.pose.bones['Head']
    hc = (rig.matrix_world @ pb.head + rig.matrix_world @ pb.tail) / 2
    blen = (pb.tail - pb.head).length * rig.matrix_world.to_scale()[0]
    hsize = blen
    side = hsize * HEAD
    cu = float(np.array(hc) @ right)
    cv = float(np.array(hc) @ up) - side * DY
cam.data.ortho_scale = side
cam.location = Vector(right * cu + up * cv) - fwd * 8.0
s.camera = cam
s.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print('ICON MECH', OUT)
