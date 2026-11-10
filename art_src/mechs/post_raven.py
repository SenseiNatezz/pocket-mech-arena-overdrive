"""RAVEN CLAW post-build fix (art_src/mechs/make_mech.py raven ... --post art_src/mechs/post_raven.py).

The design is charcoal gunmetal with red energy lights (the user's sheet: Mech Designs\\Tripo uploads\\1 RAVEN CLAW
front.png). Through the cel material (texture x light bands) the charcoal goes purple-black on the arena floor and the
red lights vanish, so on the built SPRITE_Cel_Mech material (same recipe as post_tempest.py):
* the texture colour is lifted (value x LIFT) and its purple cast pulled back (saturation x SAT) before the light bands
* red texels (R well above max(G, B)) add their own colour on top, unshaded - the core, visor and wing seams glow
Re-running it on an already-fixed .blend only updates the numbers (the nodes are labelled).
"""
import bpy

LIFT = 2.4
SAT = 0.75
GLOW = 1.8            # how much of the red's own colour is added unlit
MASK_FROM, MASK_TO = 0.07, 0.24   # R - max(G, B) ramp that marks a texel as glowing red

mat = bpy.data.materials['SPRITE_Cel_Mech']
nt = mat.node_tree; nodes = nt.nodes; links = nt.links
if any(n.label == 'RAVEN_LIFT' for n in nodes):
    hsv = next(n for n in nodes if n.label == 'RAVEN_LIFT')
    hsv.inputs['Value'].default_value = LIFT; hsv.inputs['Saturation'].default_value = SAT
    rng = next(n for n in nodes if n.label == 'RAVEN_MASK')
    rng.inputs['From Min'].default_value = MASK_FROM; rng.inputs['From Max'].default_value = MASK_TO
    next(n for n in nodes if n.label == 'RAVEN_GLOW').inputs[1].default_value = GLOW
    print('POST RAVEN: updated lift', LIFT, 'sat', SAT, 'glow', GLOW)
    bpy.ops.wm.save_mainfile()
    print('POST SAVED')
else:
    mul = next(n for n in nodes if n.type == 'MIX_RGB' and n.blend_type == 'MULTIPLY')
    emi = next(n for n in nodes if n.type == 'EMISSION')
    col = mul.inputs[1].links[0].from_socket

    hsv = nodes.new('ShaderNodeHueSaturation'); hsv.label = 'RAVEN_LIFT'
    hsv.inputs['Value'].default_value = LIFT; hsv.inputs['Saturation'].default_value = SAT
    links.new(col, hsv.inputs['Color']); links.new(hsv.outputs['Color'], mul.inputs[1])

    sep = nodes.new('ShaderNodeSeparateColor'); links.new(col, sep.inputs['Color'])
    mx = nodes.new('ShaderNodeMath'); mx.operation = 'MAXIMUM'
    links.new(sep.outputs[1], mx.inputs[0]); links.new(sep.outputs[2], mx.inputs[1])
    sub = nodes.new('ShaderNodeMath'); sub.operation = 'SUBTRACT'
    links.new(sep.outputs[0], sub.inputs[0]); links.new(mx.outputs[0], sub.inputs[1])
    rng = nodes.new('ShaderNodeMapRange'); rng.clamp = True; rng.label = 'RAVEN_MASK'
    rng.inputs['From Min'].default_value = MASK_FROM; rng.inputs['From Max'].default_value = MASK_TO
    links.new(sub.outputs[0], rng.inputs['Value'])
    k = nodes.new('ShaderNodeMath'); k.operation = 'MULTIPLY'; k.inputs[1].default_value = GLOW; k.label = 'RAVEN_GLOW'
    links.new(rng.outputs['Result'], k.inputs[0])
    add = nodes.new('ShaderNodeMixRGB'); add.blend_type = 'ADD'
    links.new(k.outputs[0], add.inputs[0]); links.new(mul.outputs[0], add.inputs[1]); links.new(col, add.inputs[2])
    links.new(add.outputs[0], emi.inputs['Color'])
    print('POST RAVEN: lift', LIFT, 'sat', SAT, 'glow', GLOW)
    bpy.ops.wm.save_mainfile()
    print('POST SAVED')
