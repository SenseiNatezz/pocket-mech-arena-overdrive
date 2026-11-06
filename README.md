# Pocket Mech Arena

Twin-stick, top-down mech shooter made in Godot 4.7 (GL Compatibility). Plays in landscape or portrait.

**Play in your browser:** https://senseinatezz.github.io/pocket-mech-arena-overdrive/
**Windows download:** see [Releases](https://github.com/SenseiNatezz/pocket-mech-arena-overdrive/releases)

## How to play
Six levels on painted top-down maps: Frozen Outpost, Jungle Megafactory, Alien Outpost, Skyway
Junction, Ruined Plaza and the Volcanic Forge. Survive 5 waves of robots on each, then a boss drops in
(Warden, Ronin, Seraph, Warden Mk-II, Shogun, and VULCAN the Forge Titan). Heat and Overdrive build up from the damage you deal. Die during a
boss fight and RETRY BOSS puts you straight back into it.

**New Game:** pick a difficulty (Easy / Normal / Hard / Extreme: more, tougher, faster enemies and
beefier bosses), then your starting weapon on the Loadout screen.

**Enemies:** Scrap Hound, Scrap Gunner, Blade Striker (energy-katana dash), Aegis Guardian (frontal
shield: flank it), Lancer (laser-locked rail sniper) and the armored Heavy Tank. The Volcanic Forge
adds its own: the Magma Crawler (drips lava, lunges, bursts into a lava pool), the Anvil (hammer
leap-slam) and the Slagspitter (lobs molten globs; its furnace tank is weak from behind).

**Leveling up:** defeated enemies drop XP shards. Each level-up pauses the game and offers 3 upgrades
(4 with the VX-7 Standard) from 23: Target Lock, Triple Shot, Defense Shield, Piercing Rounds, Rapid
Fire, Power Core, Armor Plating, Thrusters, Orbit Blades, Explosive Rounds, Salvage Repair, Heat Sink,
Scavenger, Critical Targeting, Bit Drones, Micro-Missile Pod, Arc Emitter, Impulse Burst, Reactive
Armor, Cryo Rounds, Redline, Reactor Overcharge and Thermal Amplifier. Two upgrades you've invested in
unlock a gold COMBO card (9 combos, e.g. Cluster Missiles, Storm Bits, Shatter, Executioner). Under the
cards: REROLL (2 per run, +1 per NEXT ARENA), BANISH (1 per run: that upgrade never shows up again) and
SKIP (+20 HP instead); the Hangar sells more rerolls and banishes. Max level 20; leveling slows down
after level 5, 10 and 15. Upgrades carry over when you press NEXT ARENA.

**Hangar chassis:** VX-7 Standard (4 upgrade cards per level-up), VX-5 Striker (fast; boosting slices
robots and kills recharge the boost), VX-9 Bulwark (heavy; boost rams robots, and SIEGE MODE braces it
when you stand still: +30% damage, -30% damage taken).

**Settings:** difficulty, screen shake, volumes, radio voice, camera zoom (Far / Normal / Close),
fullscreen (also F11 / Alt+Enter), CONTROLS (rebind every keyboard / mouse action), and on touch
screens Auto-Fire (fires at the auto-aim target by itself) and the touch layout: Simple (FIRE, BOOST,
ALT FIRE, BEAM and one smart HEAT button; Repair and Overdrive trigger on their own) or Full.

**Weapons (Armory):** 12 weapons, unlocked by the total number of waves you've beaten in any mode:
Beam Rifle (start), Beam Saber (3), Sniper Beam (5), Dual Beam Sabers (8), Beam Katana (10),
Gatling Cannon (13), Beam Spear (15), Rocket Launcher (18), Energy Axe (20), Beam Scythe (25) and
Physical Greatsword (30). The Energy Sword unlocks by defeating VULCAN in the Volcanic Forge (or after
40 waves): a 4-hit combo whose finisher, CRESCENT NOVA, spins and launches a piercing crescent wave.
Melee weapons have combos with a finisher on the last hit.

**Weapon Range (main menu):** every weapon unlocked, spawn any enemy or boss, and you can't be
destroyed. Switch weapons with 1-9, 0, -, = / mouse wheel / Tab or the weapon bar.

**Tutorial:** new pilots are offered a 2-minute guided training mission before their first run (also under Settings > Tutorial).

**Endless Mode (main menu):** endless waves on a random open map. Each wave is bigger and tougher, a
Warden boss arrives every 5 waves, and your best wave is saved. Six extra robots join the later waves:
Hornet drones, the Coil serpent, the mine-laying Widow, the flamethrower Cinder, the shield-commander
Bastion and the armored Tidebreaker crab (all spawnable in the Weapon Range too).

| Action | Keyboard / Mouse (rebindable) | Gamepad | Touch |
|---|---|---|---|
| Move | WASD / Arrows | Left stick | Left thumb stick (360°) |
| Aim | Mouse | Right stick | Automatic: locks onto the nearest enemy (drag on FIRE to aim by hand) |
| Fire | Left mouse | RT | Automatic with Auto-Fire (or hold the big FIRE button) |
| Scatter shot | Right mouse | LT | ALT FIRE |
| Boost (dash, crosses pits) | Space | LB | BOOST |
| Heat Nova (40 heat) | E | Y | HEAT (Simple layout: Nova when robots are close) / NOVA |
| Magma Cone (30 heat) | Q | RB | HEAT (Simple layout: Cone otherwise) / CONE |
| Self-repair | F | B | Automatic below 35% HP (Simple) / REPAIR |
| Overdrive | Shift | R3 | Automatic when full (Simple) / OVERDRIVE |
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
- `godot --headless --path . -- --gun-range --touch --attach=res://tools/touch_test.gd --temp-save` checks the touch controls (auto-aim, FIRE button, move stick)
- `godot --headless --path . -- --arena=6 --no-intro --attach=res://tools/forge_test.gd --temp-save` checks the Volcanic Forge robots and the VULCAN boss
- `godot --headless --path . -- --gun-range --attach=res://tools/energy_sword_test.gd --temp-save` checks the Energy Sword (unlock, held art, combo + CRESCENT NOVA)
