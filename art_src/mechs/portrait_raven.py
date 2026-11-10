"""RAVEN CLAW Hangar portrait in the design's own dark charcoal (the user asked for it to match the sheet, 11-09).

post_raven.py lifts the charcoal so the top-down sprite stays readable on the arena floor, but that lift also
turns the 3/4 portrait silver. Run this BEFORE the turntable renderer in the same Blender session: it puts the
lift back to neutral in memory only (the .blend is never saved), keeping the red-light glow.

  blender -b art_src/mechs/raven/raven_2D_Sprites.blend --python art_src/mechs/portrait_raven.py \
      --python art_src/halo_forge/tools/render_turntable.py -- <ABSOLUTE path to art_src/mechs/raven/turntable> 120 --only 15
  (the out dir must be absolute: a relative one lands under C:\ because Blender resolves it from the drive root)
  then copy art_src/mechs/raven/turntable/frame_015.png to assets/sprites/mechs/raven/portrait.png

make_mech.py's own portrait step renders WITH the lift, so re-run this after any make_mech.py raven run.
"""
import bpy

VALUE, SAT = 1.0, 1.0      # neutral: the texture's own charcoal

nodes = bpy.data.materials['SPRITE_Cel_Mech'].node_tree.nodes
lift = next((n for n in nodes if n.label == 'RAVEN_LIFT'), None)
if lift is None:
    print('PORTRAIT RAVEN: no RAVEN_LIFT node (post_raven.py not applied) - rendering as is')
else:
    lift.inputs['Value'].default_value = VALUE
    lift.inputs['Saturation'].default_value = SAT
    print('PORTRAIT RAVEN: lift set to', VALUE, 'for this render only')
