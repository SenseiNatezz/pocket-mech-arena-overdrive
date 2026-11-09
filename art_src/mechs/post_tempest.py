"""TEMPEST post-build fix (art_src/mechs/make_mech.py tempest ... --post art_src/mechs/post_tempest.py).

The design is dark navy with electric-yellow seams that glow (concept: Mech Designs\\New 20 - concepts\\05_tempest.png).
Through the cel material (texture x light bands) the navy goes almost black on the arena floor, so on the built
SPRITE_Cel_Mech material:
* the texture colour is lifted (value x LIFT, a little more saturation) before the light bands
* yellow texels (min(R, G) well above B) add their own colour on top, unshaded - the seams and tesla coils glow
"""
import bpy

LIFT = 1.55
SAT = 1.12
GLOW = 0.85           # how much of the yellow's own colour is added unlit
MASK_FROM, MASK_TO = 0.18, 0.40   # min(R, G) - B ramp that marks a texel as glowing yellow

mat = bpy.data.materials['SPRITE_Cel_Mech']
nt = mat.node_tree; nodes = nt.nodes; links = nt.links
mul = next(n for n in nodes if n.type == 'MIX_RGB' and n.blend_type == 'MULTIPLY')
emi = next(n for n in nodes if n.type == 'EMISSION')
col = mul.inputs[1].links[0].from_socket

hsv = nodes.new('ShaderNodeHueSaturation')
hsv.inputs['Value'].default_value = LIFT; hsv.inputs['Saturation'].default_value = SAT
links.new(col, hsv.inputs['Color']); links.new(hsv.outputs['Color'], mul.inputs[1])

sep = nodes.new('ShaderNodeSeparateColor'); links.new(col, sep.inputs['Color'])
mn = nodes.new('ShaderNodeMath'); mn.operation = 'MINIMUM'
links.new(sep.outputs[0], mn.inputs[0]); links.new(sep.outputs[1], mn.inputs[1])
sub = nodes.new('ShaderNodeMath'); sub.operation = 'SUBTRACT'
links.new(mn.outputs[0], sub.inputs[0]); links.new(sep.outputs[2], sub.inputs[1])
rng = nodes.new('ShaderNodeMapRange'); rng.clamp = True
rng.inputs['From Min'].default_value = MASK_FROM; rng.inputs['From Max'].default_value = MASK_TO
links.new(sub.outputs[0], rng.inputs['Value'])
k = nodes.new('ShaderNodeMath'); k.operation = 'MULTIPLY'; k.inputs[1].default_value = GLOW
links.new(rng.outputs['Result'], k.inputs[0])
add = nodes.new('ShaderNodeMixRGB'); add.blend_type = 'ADD'
links.new(k.outputs[0], add.inputs[0]); links.new(mul.outputs[0], add.inputs[1]); links.new(col, add.inputs[2])
links.new(add.outputs[0], emi.inputs['Color'])
print('POST TEMPEST: lift', LIFT, 'glow', GLOW)
bpy.ops.wm.save_mainfile()
print('POST SAVED')
