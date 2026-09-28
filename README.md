# Pocket Mech Arena

Twin-stick, top-down mech shooter made in Godot 4.7 (GL Compatibility). Plays in landscape or portrait.

**Play in your browser:** https://senseinatezz.github.io/pocket-mech-arena-overdrive/
**Windows download:** see [Releases](https://github.com/SenseiNatezz/pocket-mech-arena-overdrive/releases)

## How to play
Five levels on painted top-down maps: Frozen Outpost, Jungle Megafactory, Alien Outpost, Skyway
Junction and Ruined Plaza. Survive 5 waves of robots on each, then a boss drops in (Warden, Ronin,
Seraph, Warden Mk-II, Shogun). Heat and Overdrive build up from the damage you deal. Die during a
boss fight and RETRY BOSS puts you straight back into it.

**New Game:** pick a difficulty (Easy / Normal / Hard / Extreme: more, tougher, faster enemies and
beefier bosses), then your starting weapon on the Loadout screen.

**Enemies:** Scrap Hound, Scrap Gunner, Blade Striker (energy-katana dash), Aegis Guardian (frontal
shield: flank it), Lancer (laser-locked rail sniper) and the armored Heavy Tank.

**Leveling up:** defeated enemies drop XP shards. Each level-up pauses the game and offers 3 upgrades
(Target Lock, Triple Shot, Defense Shield, Piercing Rounds, Rapid Fire, Power Core, Armor Plating,
Thrusters, Orbit Blades, Explosive Rounds, Salvage Repair, Heat Sink, Scavenger). Max level 20;
leveling slows down after level 5, 10 and 15. Upgrades carry over when you press NEXT ARENA.

**Weapons (Armory):** 11 weapons, unlocked by the total number of waves you've beaten in any mode:
Beam Rifle (start), Beam Saber (3), Sniper Beam (5), Dual Beam Sabers (8), Beam Katana (10),
Gatling Cannon (13), Beam Spear (15), Rocket Launcher (18), Energy Axe (20), Beam Scythe (25) and
Physical Greatsword (30). Melee weapons have combos with a finisher on the last hit.

**Weapon Range (main menu):** every weapon unlocked, spawn any enemy or boss, and you can't be
destroyed. Switch weapons with 1-9, 0, - / mouse wheel / Tab or the weapon bar.

**Tutorial:** new pilots are offered a 2-minute guided training mission before their first run (also under Settings > Tutorial).

**Endless Mode (main menu):** endless waves on a random open map. Each wave is bigger and tougher, a
Warden boss arrives every 5 waves, and your best wave is saved.

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
- `autoload/` - Controls (input merging), Combat (pooled bullets/effects, damage), Sfx, Game (scene flow, endless mode, weapon unlocks, settings), Upgrades (XP, levels, level-up upgrades)
- `player/` - the mech, its camera (aim lead + shake), boost ring, weapons (guns, beam cannon, melee kit)
- `enemies/` - Scrap Hound (chaser), Scrap Gunner (shooter), Blade Striker, Aegis Guardian, Lancer, Heavy Tank (tank); bosses: Warden, `bosses/` Ronin + Seraph
- `environment/` - arena builder, arena scenes, tiles, props (cover, crates, pits, doors...), hazards, encounter zones, parallax skyline
- `ui/` - HUD, menus (Armory, Gun Range panel), touch controls
- `tools/` - tileset generator, automated tests, autopilot, debug runner
- `assets/hq/raw/` - source art for the tools only. It has a `.gdignore`, so Godot never imports or exports it. Big painted maps and the Customize turntable import as lossy WebP (small download, works on every platform).

Arena size: select an arena scene's root and change `size_in_screens` in the Inspector.

## Tests
Run these from the project folder. `--temp-save` keeps tests away from your real save.
- `godot --headless --path . res://environment/test_range.tscn -- --smoke-test --temp-save` checks controls
- `godot --headless --path . res://environment/test_range.tscn -- --upgrade-test --temp-save` checks upgrades and weapons
- `godot --headless --path . -- --endless --endless-test --temp-save --no-intro` checks the Endless flow
- `godot --headless --path . -- --tutorial --tutorial-test --temp-save` plays through the tutorial
- `godot --headless --path . -- --arena=1 --arena-test --temp-save --no-intro` checks the arena flow
