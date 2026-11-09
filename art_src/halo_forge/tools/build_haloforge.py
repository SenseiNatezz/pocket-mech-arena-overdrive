"""Builds the Halo Forge player mech inside HaloForge_2D_Sprites.blend (a copy of Gundam_2D_Sprites.blend).

blender -b HaloForge_2D_Sprites.blend --python build_haloforge.py -- <textured.glb> <rigged.glb>

* hides the old Gundam armour (kept in the file, render-disabled)
* imports the full-detail textured Tripo mesh
* uses the Tripo humanoid auto-rig (on its 20k retopo copy) only to find the joints and to split the
  mesh into rigid armour parts: every vertex goes 100% to one sprite-rig bone, so plates never bend
* moves the sprite rig's joints onto the new body (bone orientations, rolls and every Action untouched)
* poses both forearms forward like the old rifle-ready bind pose; the beam rifle moves with the right hand
* gives it the same cel material recipe as the old mech and saves the .blend
"""
import bpy, sys, math, bmesh, numpy as np
from mathutils import Vector, kdtree

argv = sys.argv[sys.argv.index('--') + 1:]
TEX_GLB, RIG_GLB = argv[0], argv[1]

scene = bpy.context.scene
rig = bpy.data.objects['Gundam_Rig']
assert not scene.get('halo_forge_built'), 'already built - start from a fresh copy'

# ---------------------------------------------------------------- hide the old armour
for o in bpy.data.objects:
    if o.name.startswith(('Armor_', 'Joint_')):
        o.hide_render = True; o.hide_set(True)

def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]

hf_objs = import_glb(TEX_GLB)
hf = next(o for o in hf_objs if o.type == 'MESH')
hf.name = 'HaloForge'; hf.data.name = 'HaloForge'
rg_objs = import_glb(RIG_GLB)
arm = next(o for o in rg_objs if o.type == 'ARMATURE')
low = max((o for o in rg_objs if o.type == 'MESH'), key=lambda o: len(o.vertex_groups))  # skip the Icosphere bone-shape helper
bpy.context.view_layer.update()

def world_verts(o):
    me = o.data; co = np.empty(len(me.vertices) * 3, np.float64); me.vertices.foreach_get('co', co)
    m = np.array(o.matrix_world); return co.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]

V = world_verts(hf); L = world_verts(low)
print('HF bounds', V.min(0).round(3), V.max(0).round(3))
print('LOW bounds', L.min(0).round(3), L.max(0).round(3))

# ---------------------------------------------------------------- Tripo joints (world, rest)
J = {}
for b in arm.data.bones:
    J[b.name.split(':')[-1]] = arm.matrix_world @ b.head_local
print('TRIPO BONES', sorted(J))
def j(n): return J[n].copy()
for n in sorted(J): print('JOINT', n, [round(x, 3) for x in J[n]])

assert j('LeftArm').x > j('RightArm').x, 'unexpected side convention (mech should face -Y)'

TRIPO_TO_OURS = {'Hips': 'Pelvis', 'Spine': 'Pelvis', 'Spine1': 'Chest', 'Spine2': 'Chest',
                 'Neck': 'Head', 'Head': 'Head', 'HeadTop_End': 'Head'}
for side, s in (('Left', 'L'), ('Right', 'R')):
    TRIPO_TO_OURS.update({f'{side}Shoulder': f'Shoulder.{s}', f'{side}Arm': f'UpperArm.{s}', f'{side}ForeArm': f'Forearm.{s}',
                          f'{side}Hand': f'Hand.{s}', f'{side}UpLeg': f'Thigh.{s}', f'{side}Leg': f'Shin.{s}',
                          f'{side}Foot': f'Foot.{s}', f'{side}ToeBase': f'Foot.{s}', f'{side}Toe_End': f'Foot.{s}'})

def ours(group):
    n = group.split(':')[-1]
    if n in TRIPO_TO_OURS: return TRIPO_TO_OURS[n]
    for side, s in (('Left', 'L'), ('Right', 'R')):
        if n.startswith(side + 'Hand'): return f'Hand.{s}'  # finger bones
    print('UNMAPPED GROUP', n); return 'Chest'

# ---------------------------------------------------------------- part per vertex from the low-poly skin weights
gnames = [g.name for g in low.vertex_groups]
OUR = sorted(set(ours(g) for g in gnames))
Wo = np.zeros((len(low.data.vertices), len(OUR)))
for v in low.data.vertices:
    for g in v.groups: Wo[v.index, OUR.index(ours(gnames[g.group]))] += g.weight
low_part = Wo.argmax(1)

kd = kdtree.KDTree(len(L))
for i, p in enumerate(L): kd.insert(p, i)
kd.balance()
part = np.empty(len(V), np.int32)
for i, p in enumerate(V):
    votes = np.zeros(len(OUR))
    for (_, idx, d) in kd.find_n(p, 6): votes[low_part[idx]] += 1.0 / (d + 1e-4)
    part[i] = votes.argmax()

# loose shells (ring discs, small plates) move as one piece: majority vote per connected island
bm = bmesh.new(); bm.from_mesh(hf.data); bm.verts.ensure_lookup_table()
seen = np.zeros(len(V), bool); islands = 0
for start in range(len(V)):
    if seen[start]: continue
    stack = [start]; seen[start] = True; comp = []
    while stack:
        k = stack.pop(); comp.append(k)
        bv = bm.verts[k]
        for e in bv.link_edges:
            o2 = e.other_vert(bv).index
            if not seen[o2]: seen[o2] = True; stack.append(o2)
    if len(comp) < 0.08 * len(V):
        c = np.array(comp); part[c] = np.bincount(part[c], minlength=len(OUR)).argmax(); islands += 1
bm.free()
print('islands voted', islands)
for k, n in enumerate(OUR): print('PART', n, int((part == k).sum()))

# ---------------------------------------------------------------- refit the sprite rig's joints (rig-local space)
HEAD_FROM = {'Pelvis': 'Hips', 'Chest': 'Spine1', 'Head': 'Neck'}
for side, s in (('Left', 'L'), ('Right', 'R')):
    HEAD_FROM.update({f'Shoulder.{s}': f'{side}Shoulder', f'UpperArm.{s}': f'{side}Arm', f'Forearm.{s}': f'{side}ForeArm',
                      f'Hand.{s}': f'{side}Hand', f'Thigh.{s}': f'{side}UpLeg', f'Shin.{s}': f'{side}Leg', f'Foot.{s}': f'{side}Foot'})
FOLLOW = {'Backpack': 'Chest', 'Thruster_R': 'Chest', 'Thruster_L': 'Chest', 'Rifle': 'Hand.R', 'Weapon_Muzzle': 'Hand.R'}

RW = rig.matrix_world.copy(); RWi = RW.inverted(); R3 = RW.to_3x3(); R3i = R3.inverted()
OLD_PELVIS = rig.data.bones['Pelvis'].head_local.copy()
new_head = {b: RWi @ j(t) for b, t in HEAD_FROM.items()}

# forearms: rotate the new forearm+hand verts about the elbow onto the old (rifle-ready) forearm direction
for s, side in (('R', 'Right'), ('L', 'Left')):
    ob = rig.data.bones[f'Forearm.{s}']
    want = (ob.tail_local - ob.head_local).normalized()
    elbow = RWi @ j(f'{side}ForeArm'); wrist = RWi @ j(f'{side}Hand')
    cur = (wrist - elbow).normalized()
    R = cur.rotation_difference(want).to_matrix()
    print('forearm', s, 'pre-rotate deg', round(math.degrees(cur.angle(want)), 1))
    sel = np.isin(part, [OUR.index(f'Forearm.{s}'), OUR.index(f'Hand.{s}')])
    ew = np.array(RW @ elbow); Rw = np.array(R3 @ R @ R3i)
    V[sel] = (V[sel] - ew) @ Rw.T + ew
    new_head[f'Hand.{s}'] = elbow + R @ (wrist - elbow)

delta = {}
for b in rig.data.bones:
    if b.name in new_head: delta[b.name] = new_head[b.name] - b.head_local
for b, src in FOLLOW.items(): delta[b] = delta[src].copy()

for o in bpy.context.selected_objects: o.select_set(False)
bpy.context.view_layer.objects.active = rig; rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for eb in rig.data.edit_bones: eb.use_connect = False
for eb in rig.data.edit_bones:
    if eb.name in delta:
        m = eb.matrix.copy(); ln = eb.length
        m.translation = m.translation + delta[eb.name]
        eb.matrix = m; eb.length = ln
bpy.ops.object.mode_set(mode='OBJECT')
for n, d in delta.items(): print('MOVED', n, [round(x, 3) for x in d])

# the rifle is skinned to the Rifle bone, so its rest verts move with the bone
rifle = bpy.data.objects['Rifle']
dl = rifle.matrix_world.inverted().to_3x3() @ (R3 @ delta['Hand.R'])
for v in rifle.data.vertices: v.co += dl

# ---------------------------------------------------------------- rigid weights on the full-detail mesh
mi = np.array(hf.matrix_world.inverted())
loc = V @ mi[:3, :3].T + mi[:3, 3]
hf.data.vertices.foreach_set('co', loc.astype(np.float32).ravel()); hf.data.update()
for k, n in enumerate(OUR):
    vg = hf.vertex_groups.new(name=n); idx = np.nonzero(part == k)[0].tolist()
    if idx: vg.add(idx, 1.0, 'REPLACE')
mw = hf.matrix_world.copy(); hf.parent = rig; hf.matrix_world = mw
hf.modifiers.new('Armature', 'ARMATURE').object = rig

for o in rg_objs: bpy.data.objects.remove(o, do_unlink=True)

# put the new pelvis where the old one was (x/y only, feet stay on the ground) so the sprite centre is unchanged;
# moving the rig object carries the new mesh, the rifle and every bone with it
old_pelvis = RW @ OLD_PELVIS
new_pelvis = RW @ new_head['Pelvis']
shift = Vector((old_pelvis.x - new_pelvis.x, old_pelvis.y - new_pelvis.y, 0))
rig.location = rig.location + rig.parent.matrix_world.to_3x3().inverted() @ shift
print('CENTRE SHIFT', [round(x, 3) for x in shift])

# ---------------------------------------------------------------- cel material (same recipe as setup_sprites.py)
src = hf.data.materials[0]; src.use_fake_user = True
mat = src.copy(); mat.name = 'SPRITE_Cel_HaloForge'
nodes = mat.node_tree.nodes; links = mat.node_tree.links
out = next(n for n in nodes if n.type == 'OUTPUT_MATERIAL'); pr = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
col = pr.inputs['Base Color'].links[0].from_socket
dif = nodes.new('ShaderNodeBsdfDiffuse'); dif.inputs['Color'].default_value = (1, 1, 1, 1)
if pr.inputs['Normal'].is_linked: links.new(pr.inputs['Normal'].links[0].from_socket, dif.inputs['Normal'])
rgb = nodes.new('ShaderNodeShaderToRGB'); links.new(dif.outputs[0], rgb.inputs[0])
ramp = nodes.new('ShaderNodeValToRGB'); ramp.name = 'CelBands'; ramp.color_ramp.interpolation = 'CONSTANT'
e = ramp.color_ramp.elements; e[0].position = 0.0; e[0].color = (0.48, 0.53, 0.64, 1); e[1].position = 0.62; e[1].color = (1, 1, 1, 1)
e.new(0.28).color = (0.74, 0.79, 0.9, 1)
links.new(rgb.outputs['Color'], ramp.inputs[0])
mul = nodes.new('ShaderNodeMixRGB'); mul.blend_type = 'MULTIPLY'; mul.inputs[0].default_value = 1
links.new(ramp.outputs[0], mul.inputs[2]); links.new(col, mul.inputs[1])
emi = nodes.new('ShaderNodeEmission'); links.new(mul.outputs[0], emi.inputs[0]); links.new(emi.outputs[0], out.inputs['Surface'])
hf.data.materials[0] = mat

for img in bpy.data.images:
    if img.source == 'FILE' and img.packed_file is None and img.has_data: img.pack()
scene['halo_forge_built'] = True
bpy.ops.wm.save_mainfile()
print('HALO_FORGE_SAVED')
