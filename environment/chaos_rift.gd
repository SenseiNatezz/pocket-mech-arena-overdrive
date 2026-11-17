class_name ChaosRift
extends Node
## A CHAOS RIFT sector (Game.active_curse; Hades' Chaos Gates): added by ScenicArena when the pilot came in
## through the purple route door. The sector's first Game.CHAOS_CURSE_WAVES waves play under the CURSE
## (Game.CHAOS_CURSES, read through Game.twist_value); once that many waves are cleared - or the waves run out
## first - it lifts and ui/chaos_boon.gd deals three CHAOS BLESSINGS, one of them kept for the rest of the run.
## While the curse holds, a purple plate under the HUD status card names it and counts the waves down.

var arena: ScenicArena
var curse := &""
var _cleared := 0
var _lifted := false
var _plate: CursePlate


func _ready() -> void:
	curse = Game.active_curse()
	if curse == &"" or arena == null or arena.zone == null:
		queue_free()
		return
	arena.zone.started.connect(_announce)
	arena.zone.wave_cleared.connect(func(i: int, _n: int) -> void:
		_cleared = i
		if i >= Game.CHAOS_CURSE_WAVES:
			lift())
	arena.zone.cleared.connect(lift)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_plate = CursePlate.new()
	_plate.rift = self
	layer.add_child(_plate)


func info() -> Dictionary:
	return Game.CHAOS_CURSES.get(curse, {})


## Waves still to clear before the curse lifts.
func waves_left() -> int:
	return maxi(Game.CHAOS_CURSE_WAVES - _cleared, 0)


## After HOSTILES INBOUND: the curse's banner and what it does (a rift sector has no twist or deal to announce).
func _announce() -> void:
	get_tree().create_timer(1.6, false).timeout.connect(func() -> void:
		if _lifted:
			return
		arena.banner.emit(String(info()["name"]), Game.CHAOS_COLOR)
		arena.objective_changed.emit("%s  It lifts after wave %d." % [info()["desc"], Game.CHAOS_CURSE_WAVES]))


## The curse is over: banner, then the blessing pick (it waits for any level-up pick to close first).
func lift() -> void:
	if _lifted:
		return
	_lifted = true
	Game.chaos_lifted = true
	if _plate:
		_plate.queue_free()
	var mech := get_tree().get_first_node_in_group("player") as Mech
	if mech == null or mech.dead:
		return
	arena.banner.emit("CURSE LIFTED", Game.CHAOS_COLOR)
	Sfx.play(&"shield", -6.0)
	var pick := ChaosBoon.new()
	arena.add_child(pick)
	pick.open()
	pick.chosen.connect(func(id: StringName, rarity: int) -> void:
		var r: Dictionary = Game.CHAOS_RARITY[rarity]
		arena.banner.emit("%s  -  %s" % [String(Game.CHAOS_BLESSINGS[id]["name"]), String(r["name"])], r["color"]))


## The curse plate: under the status card (and the evolution strip), a dark violet tab with the curse's name and
## how many waves it has left, its edge pulsing.
class CursePlate:
	extends Control
	var rift: ChaosRift
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if rift == null or get_tree().get_nodes_in_group("player").is_empty():
			return
		var mech := get_tree().get_first_node_in_group("player") as Mech
		if mech == null or mech.dead:
			return
		var touch := Controls.device == Controls.Device.TOUCH
		var y := 10.0 + (78.0 if touch else 86.0) + 28.0
		var name_s := String(rift.info().get("name", ""))
		var left := rift.waves_left()
		var sub := "lifts after wave %d  -  %d to go" % [Game.CHAOS_CURSE_WAVES, left] if left > 0 else "lifting..."
		var f_name := UiFont.XBOLD
		var f_sub := UiFont.BODY
		var w := maxf(f_name.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x,
			f_sub.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x) + 64.0
		var r := Rect2(12.0, y, w, 44.0)
		var col := Game.CHAOS_COLOR
		var pulse := 0.5 + 0.5 * sin(_t * 3.2)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.07, 0.02, 0.13, 0.86)
		bg.border_color = Color(col, 0.55 + 0.4 * pulse)
		bg.set_border_width_all(2)
		bg.border_width_left = 5
		bg.set_corner_radius_all(6)
		bg.shadow_color = Color(col, 0.18 + 0.15 * pulse)
		bg.shadow_size = 6
		draw_style_box(bg, r)
		draw_string_outline(f_name, Vector2(r.position.x + 16.0, r.position.y + 20.0), name_s, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 16, 4, Color(0, 0, 0, 0.8))
		draw_string(f_name, Vector2(r.position.x + 16.0, r.position.y + 20.0), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			col.lightened(0.35))
		draw_string(f_sub, Vector2(r.position.x + 16.0, r.position.y + 37.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.88, 0.82, 1.0, 0.9))
		# One pip per wave of the curse, lit while it still holds.
		for i in Game.CHAOS_CURSE_WAVES:
			var c := Vector2(r.end.x - 12.0 - i * 11.0, r.position.y + 14.0)
			var on := i < left
			draw_circle(c, 3.6, Color(col.lightened(0.3), 0.95) if on else Color(col, 0.25))
