extends SceneTree
## Turns the raw Higgsfield renders (assets/hq/raw, ~1024 px) into game-ready textures in assets/hq:
## optionally drops faint halo pixels, trims empty transparent borders and downsizes (Lanczos) so the
## largest side matches the target, keeping the aspect ratio.
##   godot --headless --path . --script res://tools/process_hq_assets.gd

const RAW := "res://assets/hq/raw/"
## Outpost set (user's Higgsfield assets, background already removed): assets/hq/raw/outpost -> assets/hq/outpost
const OUT := "res://assets/hq/"
## file -> [largest side in px, alpha cutoff (0 = keep soft edges)]
const ASSETS := {
	"scrap_hound.png": [160, 0.0],
	"scrap_gunner.png": [200, 0.3],
	"warden.png": [384, 0.0],
	"repair_pad.png": [224, 0.0],
	"rubble.png": [192, 0.0],
	"scorch.png": [192, 0.0],
	"barricade.png": [256, 0.35],
	"crate.png": [128, 0.35],
	"barrel.png": [112, 0.35],
	"showcase_mech.png": [600, 0.3],
	"outpost/hangar.png": [600, 0.3],
	"outpost/dome.png": [560, 0.3],
	"outpost/radar.png": [520, 0.3],
	"outpost/silos.png": [560, 0.3],
	"outpost/turret.png": [420, 0.3],
	"outpost/crystals.png": [420, 0.3],
	"outpost/wall.png": [700, 0.3],
	"outpost/crater.png": [360, 0.0],
	"beam/beam_body.png": [896, 0.0],
	"beam/beam_muzzle_flash.png": [320, 0.0],
	"beam/beam_impact.png": [320, 0.0],
	# Energy-weapon robots (enemies + bosses); low cutoff keeps the blades' glow.
	"enemies2/blade_striker.png": [200, 0.15],
	"enemies2/aegis_guardian.png": [240, 0.15],
	"enemies2/lancer.png": [230, 0.2],
	"enemies2/ronin.png": [400, 0.15],
	"enemies2/seraph.png": [440, 0.15],
	"enemies2/sword_funnel.png": [140, 0.1],
	# Heavy Tank (replaced the Mortar Crab) + Gun Range target drone.
	"enemies3/heavy_tank.png": [260, 0.2],
	"enemies3/target_drone.png": [120, 0.2],
	# Armory weapons (card art + in-game swing sprites; all point up).
	"weapons/beam_rifle.png": [256, 0.1],
	"weapons/sniper.png": [256, 0.1],
	"weapons/gatling.png": [256, 0.1],
	"weapons/beam_saber.png": [256, 0.1],
	"weapons/dual_sabers.png": [256, 0.1],
	"weapons/katana.png": [256, 0.1],
	"weapons/spear.png": [256, 0.1],
	"weapons/axe.png": [256, 0.1],
	"weapons/scythe.png": [256, 0.1],
	"weapons/greatsword.png": [256, 0.1],
	"weapons/rocket_launcher.png": [256, 0.1],
	"weapons/rocket.png": [96, 0.15],
}


## Optional user arg: only process paths starting with it (e.g. `-- enemies2/`).
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var only: String = args[0] if not args.is_empty() else ""
	for d in ["enemies2", "enemies3", "weapons"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + d))
	for f: String in ASSETS:
		if not f.begins_with(only):
			continue
		var path := ProjectSettings.globalize_path(RAW + f)
		if not FileAccess.file_exists(path):
			print("missing ", f)
			continue
		var img := Image.load_from_file(path)
		img.convert(Image.FORMAT_RGBA8)
		var cutoff: float = ASSETS[f][1]
		if cutoff > 0.0:
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a < cutoff:
						img.set_pixel(x, y, Color(c, 0.0))
		var used := img.get_used_rect()
		var out := img.get_region(used)
		var target: int = ASSETS[f][0]
		var k := float(target) / maxi(used.size.x, used.size.y)
		out.resize(maxi(roundi(used.size.x * k), 1), maxi(roundi(used.size.y * k), 1), Image.INTERPOLATE_LANCZOS)
		out.save_png(ProjectSettings.globalize_path(OUT + f))
		print("%s: used %s -> %s" % [f, used, out.get_size()])
	quit()
