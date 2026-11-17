extends Node
## Preview capture of SALVAGE COMBAT + LIMB DAMAGE (autoload/salvage.gd). Attach it in an arena:
##   -- --arena=1 --no-intro --temp-save --attach=res://tools/salvage_shots.gd --salvage-shot=C:/x/salvage.png
## (add --salvage-zoom to frame the mech up close). Three pieces already bolted on, the legs broken and the
## arms damaged (sparks), then two robots next to the mech are torn apart so their pieces bounce out, one is
## picked up (the HUD feed line + LEGS REPAIRED); the shot is taken with the other still lying there.

const CHASER := preload("res://enemies/chaser.tscn")

var _path := ""
var _zoom := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--salvage-shot="):
			_path = a.trim_prefix("--salvage-shot=")
		if a == "--salvage-zoom":
			_zoom = true
	_run.call_deferred()


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _run() -> void:
	var mech: Mech = null
	for i in 40:
		await _wait(0.25)
		mech = get_tree().get_first_node_in_group("player") as Mech
		if mech and i > 6:
			break
	Game.scrap_enabled = true
	mech.grant_invuln(30.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy:
			(e as Enemy).queue_free()
	Salvage.collect(Salvage.PIECES[&"Hornet"])
	Salvage.collect(Salvage.PIECES[&"Shooter"])
	Salvage.collect(Salvage.PIECES[&"Widow"])
	Salvage.integrity[&"legs"] = 0.0
	Salvage.integrity[&"arms"] = 0.25
	Salvage.limb_broken.emit(&"legs")
	await _wait(0.8)
	var at := mech.global_position
	Salvage.drop(&"Anvil", at + Vector2(90, 40), true)
	Salvage.drop(&"Chaser", at + Vector2(-30, 30), true)
	if _zoom:
		var cam := get_viewport().get_camera_2d()
		if cam:
			cam.zoom *= 1.8
	await _wait(0.9)
	await RenderingServer.frame_post_draw
	if _path != "":
		get_viewport().get_texture().get_image().save_png(_path)
		print("screenshot saved: ", _path)
	get_tree().quit()
