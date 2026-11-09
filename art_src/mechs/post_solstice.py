"""SOLSTICE post-build fix (art_src/mechs/make_mech.py solstice ... --post art_src/mechs/post_solstice.py).

Runs on the built solstice_2D_Sprites.blend after build_mech.py:
* the sun halo (gold ring + 8 blade fins behind the back) is found by mesh island: mostly gold texture, behind the
  back, out on the ring (not the body inside it). Tripo's auto-rig skinned most of it to the left upper arm, so it
  would swing with that arm - every halo vertex goes rigidly to Chest instead
* the halo shrinks to HALO_SCALE about its centre (built with --head-z 0.92 the body is bigger than the first
  pass; the halo shouldn't swallow it) and leans back TILT degrees about its lower edge: the sheet camera looks
  straight down, and an upright disc is only a thin gold bar from above - leaned back it reads as a sun wheel
* readability on pale floors (Frozen Outpost ice): the white armour texels get a cool grey-blue shade (gold and blue
  untouched) and this mech's Freestyle outline is thicker
Lengths below are measured at the first build's scale (--head-z 0.809, Head bone at REF_HEAD) and scaled by k.
"""
import bpy, bmesh, math, numpy as np

TILT = 35.0           # degrees the halo leans back (top goes behind the mech)
HALO_SCALE = 0.82     # halo size about its centre
REF_HEAD = 0.792      # sprite rig Head bone height when the lengths below were measured
RING_Z = 0.752        # halo centre height (rig-local)
RING_R = 0.18         # ring radius (the fins reach ~0.40): the lean pivots on the ring's bottom
MIN_R = 0.12          # islands nearer the halo centre than this are the body inside the ring
MIN_GOLD = 0.35       # share of gold texels an island needs
BEHIND_Y = 0.03       # island centre must be behind the back (+y = behind, the mech faces -y)
WHITE_SHADE = (0.80, 0.84, 0.93)   # multiplies near-white texels
WHITE_FROM, WHITE_TO = 0.55, 0.80  # min(R, G, B) ramp that marks a texel as white armour
OUTLINE = 1.7         # Freestyle line thickness (px; the template's is 1.15)

hf = bpy.data.objects['MechBody']; rig = bpy.data.objects['Gundam_Rig']
k = rig.data.bones['Head'].head_local.z / REF_HEAD
RING_Z, RING_R, MIN_R, BEHIND_Y, LOW_Z = RING_Z * k, RING_R * k, MIN_R * k, BEHIND_Y * k, 0.5 * k
print('HALO scale k', round(k, 3))
me = hf.data
n = len(me.vertices)
co = np.empty(n * 3); me.vertices.foreach_get('co', co); co = co.reshape(-1, 3)
M = np.array(hf.matrix_world); R = np.array(rig.matrix_world)
to_rig = np.linalg.inv(R) @ M; from_rig = np.linalg.inv(to_rig)
P = co @ to_rig[:3, :3].T + to_rig[:3, 3]

# islands
bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
isl = np.full(n, -1); k = 0
for s in range(n):
    if isl[s] >= 0: continue
    st = [s]; isl[s] = k
    while st:
        a = st.pop()
        for e in bm.verts[a].link_edges:
            o = e.other_vert(bm.verts[a]).index
            if isl[o] < 0: isl[o] = k; st.append(o)
    k += 1
bm.free()

# texture colour per vertex (base colour image, through the UVs)
uv = me.uv_layers.active.data
lu = np.empty(len(me.loops) * 2); uv.foreach_get('uv', lu); lu = lu.reshape(-1, 2)
lv = np.empty(len(me.loops), np.int64); me.loops.foreach_get('vertex_index', lv)
vuv = np.zeros((n, 2)); vuv[lv] = lu
src = bpy.data.materials.get('SPRITE_Cel_Mech') or me.materials[0]
img = next(nd.image for nd in src.node_tree.nodes if nd.type == 'TEX_IMAGE' and nd.image
           and 'basecolor' in nd.image.name.lower())
w, h = img.size; px = np.empty(w * h * 4, np.float32); img.pixels.foreach_get(px); px = px.reshape(h, w, 4)
col = px[np.clip((vuv[:, 1] % 1) * h, 0, h - 1).astype(int), np.clip((vuv[:, 0] % 1) * w, 0, w - 1).astype(int), :3]
gold = (col[:, 0] > 0.55) & (col[:, 1] > 0.40) & (col[:, 2] < 0.35) & (col[:, 0] - col[:, 2] > 0.3)

cnt = np.bincount(isl, minlength=k)
mean = lambda v: np.bincount(isl, weights=v, minlength=k) / cnt
cx, cy, cz, gf = mean(P[:, 0]), mean(P[:, 1]), mean(P[:, 2]), mean(gold.astype(float))
halo_isl = (cy > BEHIND_Y) & (np.hypot(cx, cz - RING_Z) > MIN_R) & (gf > MIN_GOLD) & (cz > LOW_Z)
halo = halo_isl[isl]
print('HALO islands', int(halo_isl.sum()), 'verts', int(halo.sum()))

# rigid to Chest
idx = np.nonzero(halo)[0].tolist()
for g in hf.vertex_groups:
    if g.name != 'Chest': g.remove(idx)
hf.vertex_groups['Chest'].add(idx, 1.0, 'REPLACE')

# shrink about the halo centre, then lean back about its lower edge (rig-local x axis)
H = P[halo]
centre = np.array([0.0, H[:, 1].mean(), RING_Z])
front = H[:, 1].min()
H = centre + (H - centre) * HALO_SCALE
H[:, 1] += front - H[:, 1].min()          # keep its front face where it was (against the back)
RING_R *= HALO_SCALE
pivot_z = RING_Z - RING_R
pivot_y = H[:, 1].min()
t = math.radians(TILT)
dy, dz = H[:, 1] - pivot_y, H[:, 2] - pivot_z
H[:, 1] = pivot_y + dy * math.cos(t) + dz * math.sin(t)
H[:, 2] = pivot_z - dy * math.sin(t) + dz * math.cos(t)
# nothing may come forward into the back
H[:, 1] += max(0.0, pivot_y - H[:, 1].min())
P[halo] = H
loc = P @ from_rig[:3, :3].T + from_rig[:3, 3]
me.vertices.foreach_set('co', loc.astype(np.float32).ravel()); me.update()
print('HALO TILT', TILT, 'pivot z', round(pivot_z, 3), 'y', round(pivot_y, 3), 'back to y', round(float(H[:, 1].max()), 3))

# white armour: a cool shade so it doesn't vanish on pale floors (before the light bands; gold / blue untouched)
nt = src.node_tree; nodes = nt.nodes; links = nt.links
mul = next(nd for nd in nodes if nd.type == 'MIX_RGB' and nd.blend_type == 'MULTIPLY')
tex = mul.inputs[1].links[0].from_socket
sep = nodes.new('ShaderNodeSeparateColor'); links.new(tex, sep.inputs['Color'])
m1 = nodes.new('ShaderNodeMath'); m1.operation = 'MINIMUM'
links.new(sep.outputs[0], m1.inputs[0]); links.new(sep.outputs[1], m1.inputs[1])
m2 = nodes.new('ShaderNodeMath'); m2.operation = 'MINIMUM'
links.new(m1.outputs[0], m2.inputs[0]); links.new(sep.outputs[2], m2.inputs[1])
rng = nodes.new('ShaderNodeMapRange'); rng.clamp = True
rng.inputs['From Min'].default_value = WHITE_FROM; rng.inputs['From Max'].default_value = WHITE_TO
links.new(m2.outputs[0], rng.inputs['Value'])
shade = nodes.new('ShaderNodeMixRGB'); shade.blend_type = 'MULTIPLY'
shade.inputs[2].default_value = (*WHITE_SHADE, 1.0)
links.new(rng.outputs['Result'], shade.inputs[0]); links.new(tex, shade.inputs[1])
links.new(shade.outputs[0], mul.inputs[1])
for vl in bpy.context.scene.view_layers:
    for ls in vl.freestyle_settings.linesets:
        ls.linestyle.thickness = OUTLINE
print('HALO white shade', WHITE_SHADE, 'outline', OUTLINE)
bpy.ops.wm.save_mainfile()
print('POST SAVED')
