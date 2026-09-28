extends Node
## Combat (autoload): pooled projectiles + pooled effects (sparks, rings, debris, damage numbers),
## area damage, explosions, telegraphed artillery strikes and screen shake requests.
## Everything spawns into a "Combat" container inside the current scene (created on demand).
##
## Damage contract:
##   "damageable" group   -> take_damage(amount, from_pos, source), `hit_radius`, optional knock(impulse)
##   "destructibles" group -> take_hit(amount, from_pos)   (cover, crates, barrels: hit by both sides)

signal damage_dealt(amount: float, source: Node, target: Node)
signal enemy_killed(enemy: Node)
signal shake_requested(strength: float)

const BULLET := preload("res://player/weapons/bullet.tscn")
const GLOW := preload("res://assets/fx/glow.tres")
const RING := preload("res://assets/fx/ring.tres")
const STRIKE := preload("res://environment/hazards/artillery_strike.gd")

var _container: Node2D
var _pool: Array[Bullet] = []
var _cursor := 0
var _fx: Array[Sprite2D] = []
var _labels: Array[Label] = []
var _bursts: Array[CPUParticles2D] = []
var _add := CanvasItemMaterial.new()
var _burst_ramp := Gradient.new()


func _ready() -> void:
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_burst_ramp.set_color(0, Color(1, 1, 1, 1))
	_burst_ramp.set_color(1, Color(1, 1, 1, 0))


func _world() -> Node2D:
	if not is_instance_valid(_container) or not _container.is_inside_tree():
		_container = Node2D.new()
		_container.name = "Combat"
		_container.z_index = 5
		get_tree().current_scene.add_child(_container)
		_pool.clear()
		_fx.clear()
		_labels.clear()
		_merged.clear()
		_bursts.clear()
		_cursor = 0
		for i in 120:
			_grow()
		for i in 40:
			_new_fx()
		for i in 12:
			_new_burst()
	return _container


## Container for world-level effects (so scenes can parent things like artillery strikes).
func world() -> Node2D:
	return _world()


# --- projectiles -----------------------------------------------------------------------------------

func _grow() -> Bullet:
	var b: Bullet = BULLET.instantiate()
	_container.add_child(b)
	b.deactivate()
	_pool.append(b)
	return b


## Fires a pooled bullet. `player_owned` picks the collision layers (player shots vs enemy shots).
## Returns it so callers can add upgrade traits (pierce, homing, explosive).
func fire(pos: Vector2, vel: Vector2, damage: float, player_owned: bool, source: Node, color := Color(0.4, 0.8, 1.0),
		size := 1.0, lifetime := 1.2) -> Bullet:
	_world()
	var b: Bullet = null
	for i in _pool.size():
		var idx := (_cursor + i) % _pool.size()
		if not _pool[idx].active:
			b = _pool[idx]
			_cursor = idx + 1
			break
	if b == null:
		b = _grow()
	b.launch(pos, vel, damage, player_owned, source, color, size, lifetime)
	return b


func clear_enemy_bullets() -> void:
	for b in _pool:
		if b.active and not b.player_owned:
			spark(b.global_position, Color(1, 0.5, 0.6), 0.6)
			b.deactivate()


## Destroys enemy bullets inside a circle / cone (Beam Sword parries). Returns how many.
func deflect_bullets(center: Vector2, radius: float, cone_dir := Vector2.ZERO, cone_half_angle := PI) -> int:
	var n := 0
	for b in _pool:
		if not b.active or b.player_owned:
			continue
		var off := b.global_position - center
		if off.length() <= radius and (cone_dir == Vector2.ZERO or absf(cone_dir.angle_to(off)) <= cone_half_angle):
			spark(b.global_position, Color(1, 0.9, 0.6), 0.7)
			b.deactivate()
			n += 1
	return n


# --- targeting -------------------------------------------------------------------------------------

## Closest living enemy within `radius` (optionally only inside a cone around `dir`), or null.
func nearest_enemy(from: Vector2, radius: float, dir := Vector2.ZERO, half_angle := PI) -> Node2D:
	var best: Node2D = null
	var best_d := radius
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or e.get("dead") == true:
			continue
		var off: Vector2 = e.global_position - from
		var d := off.length()
		if d < best_d and (dir == Vector2.ZERO or d < 1.0 or absf(dir.angle_to(off)) <= half_angle):
			best_d = d
			best = e
	return best


## Living enemies (damageable, not the player) inside a circle / cone.
func enemies_in_area(center: Vector2, radius: float, cone_dir := Vector2.ZERO, cone_half_angle := PI) -> Array[Node]:
	var out: Array[Node] = []
	for n in get_tree().get_nodes_in_group("damageable"):
		if is_instance_valid(n) and not n.is_in_group("player") and n.get("dead") != true \
				and _in_area(n, center, radius, cone_dir, cone_half_angle):
			out.append(n)
	return out


## Hits destructible props (cover, crates, barrels) inside a circle / cone.
func damage_destructibles(center: Vector2, radius: float, damage: float, cone_dir := Vector2.ZERO,
		cone_half_angle := PI) -> void:
	for n in get_tree().get_nodes_in_group("destructibles"):
		if is_instance_valid(n) and _in_area(n, center, radius, cone_dir, cone_half_angle):
			n.take_hit(damage, center)


## Explosive Rounds / missile impact: a small blast that only hurts enemies (lighter FX and sound
## than a full explosion, since these can happen many times a second).
func small_blast(pos: Vector2, radius: float, damage: float, source: Node) -> void:
	for n in enemies_in_area(pos, radius):
		n.take_damage(damage, pos, source)
	shockwave(pos, radius, Color(1.0, 0.6, 0.25), 0.25)
	spark(pos, Color(1.0, 0.75, 0.35), radius / 45.0)
	burst(pos, Color(1.0, 0.55, 0.2), radius * 3.0, 0.9)
	Sfx.play(&"explode", -16.0, 0.15)


# --- damage ----------------------------------------------------------------------------------------

## Damages every damageable in the radius (optionally only inside a cone). Returns hits.
## Destructibles (cover, crates, barrels) in range are always hit too.
func area_damage(center: Vector2, radius: float, damage: float, source: Node, hurts_player := false,
		cone_dir := Vector2.ZERO, cone_half_angle := PI, knockback := 0.0) -> int:
	var hits := 0
	for n in get_tree().get_nodes_in_group("damageable"):
		if not is_instance_valid(n) or n == source:
			continue
		var is_player: bool = n.is_in_group("player")
		if is_player != hurts_player:
			continue
		if _in_area(n, center, radius, cone_dir, cone_half_angle):
			n.take_damage(damage, center, source)
			if knockback > 0.0 and n.has_method("knock"):
				n.knock((n.global_position - center).normalized() * knockback)
			hits += 1
	for n in get_tree().get_nodes_in_group("destructibles"):
		if is_instance_valid(n) and n != source and _in_area(n, center, radius, cone_dir, cone_half_angle):
			n.take_hit(damage, center)
	return hits


func _in_area(n: Node, center: Vector2, radius: float, cone_dir: Vector2, cone_half_angle: float) -> bool:
	var off: Vector2 = n.global_position - center
	var r: float = n.get("hit_radius") if n.get("hit_radius") != null else 20.0
	if off.length() > radius + r:
		return false
	return cone_dir == Vector2.ZERO or off.length() < 1.0 or absf(cone_dir.angle_to(off)) <= cone_half_angle


func report_damage(amount: float, source: Node, target: Node) -> void:
	damage_dealt.emit(amount, source, target)


func report_kill(enemy: Node) -> void:
	enemy_killed.emit(enemy)


## Explosion: `hurts` = "player", "enemies" or "all" (barrels hurt everyone).
func explode(pos: Vector2, radius: float, damage: float, source: Node, hurts := "all", color := Color(1.0, 0.55, 0.2),
		knockback := 380.0) -> void:
	if hurts == "all" or hurts == "player":
		area_damage(pos, radius, damage, source, true, Vector2.ZERO, PI, knockback)
	if hurts == "all" or hurts == "enemies":
		area_damage(pos, radius, damage, source, false, Vector2.ZERO, PI, knockback)
	explosion_fx(pos, radius, color)


func explosion_fx(pos: Vector2, radius: float, color := Color(1.0, 0.55, 0.2)) -> void:
	shockwave(pos, radius, color, 0.4)
	shockwave(pos, radius * 0.55, Color(1, 0.95, 0.8), 0.22)
	spark(pos, color, radius / 40.0)
	burst(pos, color, radius * 3.0, 1.4)
	burst(pos, Color(0.35, 0.33, 0.33), radius * 2.0, 1.8)
	Sfx.play(&"explode", -3.0)
	shake(clampf(radius / 260.0, 0.15, 0.6))


## Telegraphed artillery: a red circle for `delay` seconds, then an explosion. If `from` is given, a
## shell visibly arcs from there to the target.
func artillery(pos: Vector2, radius: float, damage: float, source: Node, delay := 1.0, hurts := "player",
		from := Vector2.INF) -> void:
	var s: Node2D = STRIKE.new()
	s.setup(pos, radius, damage, source, delay, hurts, from)
	_world().add_child(s)


func shake(strength: float) -> void:
	if Game.screen_shake:
		shake_requested.emit(strength)


# --- pooled effects --------------------------------------------------------------------------------

func _new_fx() -> Sprite2D:
	var s := Sprite2D.new()
	s.material = _add
	s.visible = false
	_container.add_child(s)
	_fx.append(s)
	return s


func _fx_sprite() -> Sprite2D:
	_world()
	for s in _fx:
		if not s.visible:
			return s
	return _new_fx()


func spark(pos: Vector2, color: Color, size := 1.0) -> void:
	var s := _fx_sprite()
	s.texture = GLOW
	s.modulate = color
	s.position = pos
	s.scale = Vector2.ONE * 0.25 * size
	s.visible = true
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "scale", Vector2.ONE * 0.8 * size, 0.12)
	tw.tween_property(s, "modulate:a", 0.0, 0.14)
	tw.chain().tween_callback(s.hide)


## Expanding shockwave ring (heat attacks, explosions).
func shockwave(pos: Vector2, radius: float, color: Color, duration := 0.35) -> void:
	var s := _fx_sprite()
	s.texture = RING
	s.modulate = color
	s.position = pos
	s.scale = Vector2.ONE * 0.2
	s.visible = true
	var target := radius / 64.0  # ring texture is 128 px wide
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "scale", Vector2.ONE * target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, duration)
	tw.chain().tween_callback(s.hide)


func _new_burst() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 18
	p.lifetime = 0.55
	p.explosiveness = 0.95
	p.direction = Vector2.RIGHT
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.damping_min = 250.0
	p.damping_max = 500.0
	p.color_ramp = _burst_ramp
	p.z_index = 1
	_container.add_child(p)
	_bursts.append(p)
	return p


## Burst of square debris/ember particles.
func burst(pos: Vector2, color: Color, speed := 260.0, size := 1.0) -> void:
	_world()
	var p: CPUParticles2D = null
	for b in _bursts:
		if not b.emitting:
			p = b
			break
	if p == null:
		p = _new_burst()
	p.position = pos
	p.color = color
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.scale_amount_min = 2.0 * size
	p.scale_amount_max = 5.0 * size
	p.restart()
	p.emitting = true


## Floating damage / heal number. Pass `target` (the thing that was hit) and rapid hits on it MERGE
## into one number that keeps counting up and follows it, instead of stacking a new label per hit -
## so crowded fights (Extreme, Triple Shot, Gatling, Orbit Blades...) stay readable. Bigger totals are
## drawn bigger. At most MAX_NUMBERS show at once; past that, small unkeyed numbers are skipped.
func damage_number(pos: Vector2, amount: float, color := Color(1, 0.85, 0.6), target: Object = null) -> void:
	_world()
	var key := ""
	if target != null:
		key = "%d:%s" % [target.get_instance_id(), color.to_html()]
		var e: Dictionary = _merged.get(key, {})
		if not e.is_empty() and is_instance_valid(e["label"]) and e["label"].visible:
			e["total"] += amount
			_show_number(e["label"], e["total"], color, true)
			return
	var shown := 0
	for x in _labels:
		if x.visible:
			shown += 1
	if shown >= MAX_NUMBERS and target == null:
		return
	var l: Label = null
	for x in _labels:
		if not x.visible:
			l = x
			break
	if l == null:
		if shown >= MAX_NUMBERS:
			return
		l = Label.new()
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(NUMBER_W, 34)
		l.z_index = 20
		_container.add_child(l)
		_labels.append(l)
	l.set_meta("rise", 0.0)
	l.set_meta("jitter", randf_range(-10.0, 10.0))
	l.set_meta("anchor", pos)
	l.set_meta("target", weakref(target) if target else null)
	if key != "":
		_merged[key] = {"label": l, "total": amount}
		l.set_meta("key", key)
	else:
		l.set_meta("key", "")
	_show_number(l, amount, color, false)


const MAX_NUMBERS := 28
const NUMBER_W := 120.0
var _merged := {}


## (Re)starts a number's pop + hold + fade. Merged hits restart the hold so it stays while you keep hitting.
func _show_number(l: Label, total: float, color: Color, bump: bool) -> void:
	l.text = str(roundi(total))
	var fs := 20 + int(clampf(total / 60.0, 0.0, 1.0) * 14.0)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color if total < 150.0 else color.lerp(Color(1.0, 0.65, 0.2), 0.6))
	l.pivot_offset = Vector2(NUMBER_W / 2, 17)
	l.modulate.a = 1.0
	l.visible = true
	_place_number(l)
	var old: Tween = l.get_meta("tween") if l.has_meta("tween") else null
	if old:
		old.kill()
	var tw := l.create_tween()
	l.set_meta("tween", tw)
	l.scale = Vector2.ONE * (1.35 if bump else 1.2)
	tw.tween_property(l, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(v: float) -> void: l.set_meta("rise", v), l.get_meta("rise"), 26.0, 0.55) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(0.25)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void:
		l.hide()
		_merged.erase(l.get_meta("key")))


## Keeps numbers above whatever they belong to (targets move while their total counts up).
func _place_number(l: Label) -> void:
	var anchor: Vector2 = l.get_meta("anchor")
	var ref: WeakRef = l.get_meta("target")
	var t: Object = ref.get_ref() if ref else null
	var lift := 34.0
	if t is Node2D and (t as Node2D).is_inside_tree():
		anchor = (t as Node2D).global_position
		l.set_meta("anchor", anchor)
		var r = t.get("hit_radius")
		if r != null:
			lift = 18.0 + float(r)
	l.position = anchor + Vector2(-NUMBER_W / 2 + l.get_meta("jitter"), -lift - 17.0 - l.get_meta("rise"))


func _process(_delta: float) -> void:
	for l in _labels:
		if is_instance_valid(l) and l.visible:
			_place_number(l)
