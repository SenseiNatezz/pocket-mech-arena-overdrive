extends Node
## Boss fight probe (balance): logs the boss's HP / phase and the mech's HP every second, plus the damage
## taken by source, until the boss dies or 300 s pass.
##   godot --path . -- --arena=N --no-intro --autoplay --boss --attach=res://tools/boss_probe.gd --temp-save

var _t := 0.0
var _next := 0.0
var _by := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Combat.damage_dealt.connect(_on_dmg)


func _on_dmg(amount: float, source: Node, target: Node) -> void:
	if target and target.is_in_group("boss"):
		var k: String = "?" if source == null or not is_instance_valid(source) else String(source.name)
		_by[k] = _by.get(k, 0.0) + amount


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_t += delta
	var arena: Node = get_tree().current_scene
	var boss: Variant = arena.get("boss")
	var mech := get_tree().get_first_node_in_group("player") as Mech
	if _t >= _next:
		_next += 1.0
		if is_instance_valid(boss):
			print("  t=%3ds boss %5.0f/%5.0f ph=%d  mech %3.0f  lv=%d" % [int(_t), boss.hp, boss.max_hp, boss.phase, mech.hp if mech else -1.0, Upgrades.level])
	if (_t > 3.0 and boss != null and (not is_instance_valid(boss) or boss.dead)) or _t > 300.0 or (mech and mech.dead):
		print("PROBE END t=%.1f  dmg by source %s" % [_t, str(_by)])
		get_tree().quit()
