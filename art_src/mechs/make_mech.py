"""Multi-mech pipeline: a Tripo model (textured GLB + humanoid-rigged GLB) -> a playable mech sheet.

py -3 art_src/mechs/make_mech.py <sheet> --tex "<textured.glb>" --rig "<rigged.glb>" [--rebuild] [--turntable]
                                          [--skip-build] [--sheet-dir <res-relative dir>] [--head-z 0.809]

  1. copies the read-only template Desktop\\Gundam Game\\Gundam_2D_Sprites.blend (sprite rig, Actions, camera,
     cel lights) to art_src/mechs/<sheet>/<sheet>_2D_Sprites.blend - only the first time, or with --rebuild
  2. build_mech.py: the Tripo mesh split into rigid parts on the sprite rig (same as NIMBUS-07's build)
  3. art_src/halo_forge/tools/render_haloforge.py: the 7 x 8 sheet of 256 px cells -> assets/sprites/mechs/<sheet>/sheet.png
  4. tools/make_mech_frames.gd: sheet_nogun.png, frames.tres, frames_nogun.tres, fists.tres (hand / rifle-tip
     points per frame, read by player/weapons/held_weapon.gd)
  5. a Hangar card portrait (portrait.png: a 3/4 front view from the turntable camera) and, with --turntable, the
     120-frame Customize turntable (turntable/frame_NNN.png)
  6. godot --import, so the new PNGs load
Game.chassis_frames(id) loads res://assets/sprites/mechs/<sheet>/frames.tres (falls back to the shipped
assets/sprites/gundam_frames.tres while a sheet doesn't exist). NIMBUS-07 itself stays on the shipped sheet.
"""
import argparse, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.abspath(os.path.join(HERE, '..', '..'))
TEMPLATE = os.path.abspath(os.path.join(PROJECT, '..', 'Gundam_2D_Sprites.blend'))
BLENDER = os.environ.get('BLENDER', r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe')
GODOT = os.environ.get('GODOT', r'C:\Users\Nate\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe')
RENDER_SHEET = os.path.join(PROJECT, 'art_src', 'halo_forge', 'tools', 'render_haloforge.py')
RENDER_TURNTABLE = os.path.join(PROJECT, 'art_src', 'halo_forge', 'tools', 'render_turntable.py')
PORTRAIT_FRAME = 15   # of 120: 45 degrees round from the front


def run(cmd, label):
    print('==', label)
    r = subprocess.run(cmd, capture_output=True, text=True, errors='replace')
    out = (r.stdout or '') + (r.stderr or '')
    for line in out.splitlines():
        if any(k in line for k in ('Error', 'ERROR', 'Traceback', 'SAVED', 'SHEET', 'OK', 'POINT', 'FEET', 'PART ', 'FIT', 'UNMAPPED', 'HALO', 'POST')):
            print('  ', line)
    if r.returncode != 0:
        print(out[-3000:])
        sys.exit('%s failed (%d)' % (label, r.returncode))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sheet')
    ap.add_argument('--tex')
    ap.add_argument('--rig')
    ap.add_argument('--rebuild', action='store_true')
    ap.add_argument('--skip-build', action='store_true')
    ap.add_argument('--turntable', action='store_true')
    ap.add_argument('--sheet-dir', default=None, help='res-relative output dir (default assets/sprites/mechs/<sheet>)')
    ap.add_argument('--post', default=None, help='a Blender script run on the built .blend right after the build '
                    '(per-design fixes, e.g. art_src/mechs/post_solstice.py)')
    ap.add_argument('--head-z', default=None, help="scale the model so Tripo's Head joint sits at this height "
                    "(NIMBUS-07: 0.809) - for designs whose halo / backpack shrank the body")
    a = ap.parse_args()
    work = os.path.join(HERE, a.sheet)
    os.makedirs(work, exist_ok=True)
    blend = os.path.join(work, a.sheet + '_2D_Sprites.blend')
    rel = a.sheet_dir or 'assets/sprites/mechs/' + a.sheet
    out = os.path.join(PROJECT, *rel.split('/'))
    os.makedirs(out, exist_ok=True)
    if not a.skip_build and (a.rebuild or not os.path.exists(blend)):
        if not (a.tex and a.rig):
            sys.exit('--tex and --rig are needed to build')
        shutil.copyfile(TEMPLATE, blend)
        run([BLENDER, '-b', blend, '--python', os.path.join(HERE, 'build_mech.py'), '--', a.tex, a.rig]
            + (['--head-z', a.head_z] if a.head_z else []), 'build')
        if a.post:
            run([BLENDER, '-b', blend, '--python', os.path.abspath(a.post)], 'post')
    run([BLENDER, '-b', blend, '--python', RENDER_SHEET, '--', '--out', os.path.join(work, 'raw'),
         '--sheet', os.path.join(out, 'sheet.png')], 'render sheet')
    if a.sheet_dir:
        # (a custom dir: make_mech_frames.gd reads assets/sprites/mechs/<name>/, so point it there)
        name = rel.split('/')[-1]
    else:
        name = a.sheet
    run([GODOT, '--headless', '--path', PROJECT, '--script', 'res://tools/make_mech_frames.gd', '--', '--sheet=' + name],
        'frames')
    tt = os.path.join(work, 'turntable')
    run([BLENDER, '-b', blend, '--python', RENDER_TURNTABLE, '--', tt, '120', '--only', str(PORTRAIT_FRAME)], 'portrait')
    shutil.copyfile(os.path.join(tt, 'frame_%03d.png' % PORTRAIT_FRAME), os.path.join(out, 'portrait.png'))
    if a.turntable:
        run([BLENDER, '-b', blend, '--python', RENDER_TURNTABLE, '--', os.path.join(out, 'turntable'), '120', '--crop'],
            'turntable')
    run([GODOT, '--headless', '--path', PROJECT, '--import'], 'import')
    print('MECH READY:', out)


if __name__ == '__main__':
    main()
