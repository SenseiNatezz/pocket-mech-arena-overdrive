# Pocket Mech Arena - Uragun Version

Landscape twin-stick, top-down mech shooter made in Godot 4.7 (GL Compatibility).

**Play in your browser:** https://senseinatezz.github.io/pocket-mech-arena-uragun/
**Windows download:** see [Releases](https://github.com/SenseiNatezz/pocket-mech-arena-uragun/releases)

## How to play
Fight through 5 waves in each arena's encounter zone, then beat the boss behind the blast door.
Heat and Overdrive build up from the damage you deal.

| Action | Keyboard / Mouse | Gamepad | Touch |
|---|---|---|---|
| Move | WASD / Arrows | Left stick | Left thumb stick |
| Aim | Mouse | Right stick | Right thumb stick |
| Fire | Left mouse | RT | Push the right stick |
| Scatter shot | Right mouse | LT | ALT FIRE |
| Boost (dash, crosses pits) | Space | LB | BOOST |
| Heat Nova (40 heat) | E | Y | NOVA |
| Magma Cone (30 heat) | Q | RB | CONE |
| Self-repair | F | B | REPAIR |
| Overdrive | Shift | R3 | OVERDRIVE |
| Use (repair stations) | R | A | USE |
| Pause | Esc | Start | II |

## Project layout
- `autoload/` - Controls (input merging), Combat (pooled bullets/effects, damage), Sfx, Game (scene flow, settings)
- `player/` - the mech, its camera (aim lead + shake), boost ring, weapons
- `enemies/` - Scrap Hound (chaser), Sentry Drone (shooter), Mortar Crab (artillery), Warden (boss)
- `environment/` - arena builder, arena scenes, tiles, props (cover, crates, pits, doors...), hazards, encounter zones, parallax skyline
- `ui/` - HUD, menus, touch controls
- `tools/` - tileset generator, automated tests, autopilot, debug runner

Arena size: select an arena scene's root and change `size_in_screens` in the Inspector.
