"""Dual Beam Pistols art, modelled from code (no AI art): a compact beam pistol in the Halo Forge's colours -
white armour slide with gold trim, gunmetal frame, a blue energy cell on top, a blue-ringed beam emitter
and an anti-beam blade under the barrel (after the Cherudim Gundam's GN Beam Pistol IIs, which parry
sabers with a coated under-barrel). Renders, top-down (forward = up), with a cel outline:
  <out>/pistol_raw.png   one pistol, 512 px  -> the in-hand art (assets/hq/weapons/beam_pistol.png)
  <out>/icon_raw.png     the pair, angled   -> the Armory icon (assets/hq/weapons/dual_pistols.png)
and prints the grip / muzzle pixel of the single render (for player/weapons/held_weapon.gd GUNS).

blender -b --factory-startup --python build_beam_pistol.py -- --out <dir>
"""
import bpy, bmesh, math, sys, os, argparse
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view

ap = argparse.ArgumentParser()
ap.add_argument('--out', required=True)
args = ap.parse_args(sys.argv[sys.argv.index('--') + 1:])
os.makedirs(args.out, exist_ok=True)

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
s = bpy.context.scene


def mat(name, col, rough=0.45, metal=0.0, emit=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*col, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = strength
    return m


WHITE = mat("white", (0.86, 0.87, 0.9), 0.35)
METAL = mat("metal", (0.07, 0.075, 0.09), 0.4, 0.55)
DARK = mat("dark", (0.025, 0.027, 0.035), 0.5, 0.3)
GOLD = mat("gold", (0.95, 0.62, 0.12), 0.3, 0.75)
BLUE = mat("energy", (0.1, 0.45, 1.0), 0.2, 0.0, (0.1, 0.5, 1.0), 2.2)


def box(name, size, loc, m, bevel=0.012, rot=(0, 0, 0), parent=None, taper=None):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]; v.co.y *= size[1]; v.co.z *= size[2]
        if taper and v.co.y > 0:  # narrow the front end
            v.co.x *= taper
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me)
    o.location = loc; o.rotation_euler = rot
    bpy.context.collection.objects.link(o)
    o.data.materials.append(m)
    if bevel > 0:
        md = o.modifiers.new("bev", "BEVEL"); md.width = bevel; md.segments = 2; md.limit_method = "ANGLE"
    if parent:
        o.parent = parent
    return o


def cyl(name, r, depth, loc, m, axis="Y", parent=None, verts=24):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r, radius2=r, depth=depth)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me)
    o.location = loc
    if axis == "Y":
        o.rotation_euler = (math.pi / 2, 0, 0)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(m)
    if parent:
        o.parent = parent
    return o


def wedge(name, pts, z0, z1, m, parent=None):
    """Extruded 2D outline (x, y) between heights z0..z1."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bot = [bm.verts.new((x, y, z0)) for x, y in pts]
    top = [bm.verts.new((x, y, z1)) for x, y in pts]
    bm.faces.new(bot[::-1]); bm.faces.new(top)
    n = len(pts)
    for i in range(n):
        bm.faces.new([bot[i], bot[(i + 1) % n], top[(i + 1) % n], top[i]])
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(m)
    if parent:
        o.parent = parent
    return o


def pistol(name):
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    P = root
    # Slide (white armour) narrowing toward the muzzle, top rib with vents, gold trim along both edges.
    box("slide", (0.24, 0.62, 0.14), (0, 0.02, 0.12), WHITE, 0.02, parent=P, taper=0.86)
    box("rib", (0.08, 0.44, 0.03), (0, 0.02, 0.2), METAL, 0.006, parent=P)
    for i in range(4):
        box("vent%d" % i, (0.05, 0.022, 0.01), (0, 0.17 - i * 0.055, 0.217), DARK, 0.0, parent=P)
    for sx in (-1, 1):
        box("trim", (0.024, 0.48, 0.02), (sx * 0.095, 0.02, 0.19), GOLD, 0.004, parent=P)
        box("sidepanel", (0.012, 0.26, 0.06), (sx * 0.121, 0.08, 0.12), METAL, 0.003, parent=P)
        box("sideglow", (0.014, 0.16, 0.014), (sx * 0.124, 0.08, 0.12), BLUE, 0.0, parent=P)
    # Lower frame (gunmetal), a little wider at the back.
    box("frame", (0.2, 0.5, 0.08), (0, -0.04, 0.02), METAL, 0.012, parent=P)
    # Beam emitter: dark shroud, glowing ring, lens.
    cyl("shroud", 0.082, 0.15, (0, 0.4, 0.12), METAL, parent=P)
    cyl("ring", 0.088, 0.03, (0, 0.455, 0.12), BLUE, parent=P)
    cyl("muzzlecap", 0.07, 0.02, (0, 0.48, 0.12), DARK, parent=P)
    cyl("lens", 0.055, 0.012, (0, 0.493, 0.12), BLUE, parent=P)
    # Anti-beam blade under the barrel, poking out past the muzzle to a point, with a gold edge.
    wedge("blade", [(-0.045, 0.15), (0.045, 0.15), (0.04, 0.56), (0.0, 0.72), (-0.04, 0.56)], -0.015, 0.035, METAL, parent=P)
    wedge("bladeedge", [(-0.014, 0.53), (0.014, 0.53), (0.0, 0.71)], 0.035, 0.045, GOLD, parent=P)
    # Energy cell on top at the back (blue glow tube with dark caps), rear sight.
    cyl("cell", 0.045, 0.17, (0, -0.2, 0.22), BLUE, parent=P)
    cyl("cap1", 0.052, 0.025, (0, -0.11, 0.22), DARK, parent=P)
    cyl("cap2", 0.052, 0.025, (0, -0.29, 0.22), DARK, parent=P)
    box("sight", (0.1, 0.03, 0.05), (0, -0.3, 0.215), DARK, 0.004, parent=P)
    # Grip (raked back) with a white panel, trigger guard.
    box("grip", (0.16, 0.16, 0.26), (0, -0.24, -0.1), METAL, 0.02, rot=(math.radians(-14), 0, 0), parent=P)
    box("guard", (0.04, 0.16, 0.03), (0, -0.08, -0.06), METAL, 0.006, parent=P)
    return root


# Light: key sun from the top-left of the image, soft fill; grey world.
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.2
sun.rotation_euler = (math.radians(35), math.radians(-28), math.radians(-35))
bpy.context.collection.objects.link(sun)
fill = bpy.data.objects.new("fill", bpy.data.lights.new("fill", "SUN"))
fill.data.energy = 0.9
fill.rotation_euler = (math.radians(-40), math.radians(30), 0)
bpy.context.collection.objects.link(fill)
s.world = bpy.data.worlds.new("w")
s.world.use_nodes = True
s.world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.37, 0.42, 1)
s.world.node_tree.nodes["Background"].inputs[1].default_value = 0.8

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
bpy.context.collection.objects.link(cam)
s.camera = cam
cam.data.type = "ORTHO"
cam.location = (0, 0.18, 5)
cam.rotation_euler = (0, 0, 0)

for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        s.render.engine = eng
        break
    except TypeError:
        pass
s.render.film_transparent = True
s.render.image_settings.file_format = "PNG"
s.render.image_settings.color_mode = "RGBA"
s.render.resolution_percentage = 100
s.view_settings.view_transform = "Standard"
s.render.use_freestyle = True
s.render.line_thickness_mode = "ABSOLUTE"
s.render.line_thickness = 1.6
ls = s.view_layers[0].freestyle_settings.linesets[0] if s.view_layers[0].freestyle_settings.linesets else \
    s.view_layers[0].freestyle_settings.linesets.new("lines")
ls.linestyle.color = (0.03, 0.035, 0.05)
ls.select_by_visibility = True
ls.select_crease = True
ls.select_silhouette = True
ls.select_border = True

# 1) One pistol, straight down, rolled a little so a side face shows (like the other weapon art).
p = pistol("pistol")
p.rotation_euler = (0, math.radians(14), 0)
bpy.context.view_layer.update()
cam.data.ortho_scale = 1.2
s.render.resolution_x = s.render.resolution_y = 512
s.render.filepath = os.path.join(args.out, "pistol_raw.png")
bpy.ops.render.render(write_still=True)
for label, pt in (("grip", (0, -0.24, 0.05)), ("muzzle", (0, 0.5, 0.12)), ("blade_tip", (0, 0.72, 0.02))):
    w = p.matrix_world @ Vector(pt)
    c = world_to_camera_view(s, cam, w)
    print("POINT", label, round(c.x * 512, 1), round((1 - c.y) * 512, 1))

# 2) The pair for the Armory icon: angled out, mirrored roll.
q = pistol("pistol2")
p.location = (-0.2, 0, 0); p.rotation_euler = (0, math.radians(16), math.radians(10))
q.location = (0.2, 0, 0); q.rotation_euler = (0, math.radians(-16), math.radians(-10))
cam.location = (0, 0.16, 5)
cam.data.ortho_scale = 1.3
s.render.resolution_x = s.render.resolution_y = 512
s.render.filepath = os.path.join(args.out, "icon_raw.png")
bpy.ops.render.render(write_still=True)
print("DONE")
