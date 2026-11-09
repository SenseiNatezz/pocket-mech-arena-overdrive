class_name GoldSalvager
extends Enemy
## GOLD SALVAGER: a harmless gold drone stuffed with scrap. During the waves of a real run the arena
## sends one every ~2-3 minutes (ScenicArena._salvager_tick); it pops up near the pilot and FLEES across
## the map for LIFETIME seconds (the ring under it runs down), then warps out. Shoot it down for a random
## prize, rolled in _award (weights in PRIZES - Cookie Clicker's Golden Cookie idea):
##   SCRAP FRENZY  every scrap gain x Game.FRENZY_MULT for Game.FRENZY_TIME s (Game.start_frenzy)
##   LUCKY         an instant scrap burst: LUCKY_SHARE of the run's scrap so far (at least LUCKY_MIN)
##   XP SURGE      a spray of XP shards worth XP_SURGE of a level
##   OVERDRIVE     the Overdrive meter fills up
##   JACKPOT       it bursts into JACKPOT_DRONES little gold drones (`mini`) that scatter; each one shot
##                 down pays a pile of scrap chips
## Prizes that can't land right now (XP at the level cap, Overdrive already full or running) pay LUCKY.
## It's an Enemy, so every weapon, upgrade and aim assist can hit it, but it deals no damage, isn't part of
## any wave, and a scripted wipe (a boss going down kills every robot) just makes it warp away.
## Game.salvager_spotted / salvager_caught / salvager_escaped tell the HUD and the Contracts.
## Drawn in code: a spinning gold hex body (the scrap nut look) with a rotor ring, a thruster flame and
## twinkles.

const GOLD := Color(1.0, 0.8, 0.28)
const LIGHT := Color(1.0, 0.95, 0.7)
const DARK := Color(0.42, 0.27, 0.05)
## (Was 11 s / 180 HP / 235 speed with a wide weave: in capture runs a player with pistols could not catch it.)
const LIFETIME := 14.0
const MINI_LIFETIME := 9.0
## [prize, weight]
const PRIZES := [[&"frenzy", 40.0], [&"lucky", 30.0], [&"xp", 15.0], [&"overdrive", 10.0], [&"jackpot", 5.0]]
const LUCKY_SHARE := 0.15
const LUCKY_MIN := 250.0
const XP_SURGE := 0.6
const JACKPOT_DRONES := 10
## Each JACKPOT drone pays this share of the run's scrap so far (at least JACKPOT_MIN).
const JACKPOT_SHARE := 0.025
const JACKPOT_MIN := 45.0

## A JACKPOT drone (small, quick to pop, pays `value` scrap).
var mini := false
var value := 0.0
## Tests / captures: the prize to pay instead of a roll.
var prize_override := &""
var _life := LIFETIME
var _goal := Vector2.ZERO
var _goal_t := 0.0
var _trail_t := 0.0


func _init() -> void:
	max_hp = 140.0
	move_speed = 215.0
	acceleration = 900.0
	contact_damage = 0.0
	hit_radius = 26.0


func _ready() -> void:
	if mini:
		hit_radius = 12.0
		move_speed = 205.0
	super._ready()
	add_to_group("salvagers")
	_life = MINI_LIFETIME if mini else LIFETIME
	_spawn_t = 0.25
	Combat.shockwave(global_position, hit_radius * 3.5, GOLD, 0.45)
	if not mini:
		Sfx.play(&"sparkle", -3.0, 0.0)
		Game.salvager_spotted.emit()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if dead:
		return
	_life -= delta
	_trail_t -= delta
	if _trail_t <= 0.0:
		_trail_t = 0.3 if mini else 0.12
		Combat.spark(global_position + Vector2(randf_range(-8.0, 8.0), 6.0), GOLD, 0.3 if mini else 0.45)
	if _life <= 0.0:
		_escape()


## Flee: head for an open spot far from the pilot (re-picked every second or so), weaving as it goes.
func _think(delta: float) -> void:
	_goal_t -= delta
	if _goal_t <= 0.0 or global_position.distance_to(_goal) < 50.0:
		_goal_t = randf_range(0.9, 1.6)
		_goal = _pick_goal()
	steer_to(_goal)
	desired_velocity = desired_velocity.rotated(sin(_t * 3.3) * 0.3)
	if desired_velocity.length() > 1.0:
		facing = desired_velocity.normalized()


## Somewhere on open floor (the arena's spawn points) away from the pilot, within a short dash.
func _pick_goal() -> Vector2:
	var away := global_position - target.global_position
	var arena := get_tree().get_first_node_in_group("arena")
	var zone: Variant = arena.get("zone") if arena else null
	var pts := PackedVector2Array()
	if zone is EncounterZone:
		pts = (zone as EncounterZone).spawn_points
	if pts.is_empty():
		return global_position + away.normalized().rotated(randf_range(-0.9, 0.9)) * 260.0
	var best := Vector2.INF
	var best_score := -INF
	for i in 16:
		var p := pts[randi() % pts.size()]
		var d := p.distance_to(global_position)
		if d < 120.0 or d > 650.0:
			continue
		var score := p.distance_to(target.global_position) - 0.6 * d + randf() * 80.0
		if score > best_score:
			best_score = score
			best = p
	return best if best != Vector2.INF else global_position + away.normalized() * 220.0


func die() -> void:
	if dead:
		return
	# Wiped out by a script (not shot down): it just warps away.
	if hp > 0.0:
		_escape()
		return
	_award(global_position)
	super.die()


## Rolls a prize from PRIZES.
static func roll_prize() -> StringName:
	var total := 0.0
	for p: Array in PRIZES:
		total += float(p[1])
	var r := randf() * total
	for p: Array in PRIZES:
		r -= float(p[1])
		if r <= 0.0:
			return p[0]
	return &"frenzy"


func _award(pos: Vector2) -> void:
	if mini:
		var got := Game.credit_scrap(value, &"gold")
		Game.drop_scrap(pos, got, 4)
		Combat.burst(pos, GOLD, 300.0, 0.8)
		Sfx.play(&"coin", -6.0, 0.1)
		return
	Combat.burst(pos, GOLD, 520.0, 1.6)
	Combat.shockwave(pos, 170.0, GOLD, 0.5)
	Combat.shake(0.35)
	Sfx.play(&"sparkle", 0.0, 0.0)
	var prize := prize_override if prize_override != &"" else roll_prize()
	var mech: Mech = target if is_instance_valid(target) and not target.dead else null
	if prize == &"xp" and Upgrades.is_max_level():
		prize = &"lucky"
	if prize == &"overdrive" and (mech == null or mech.overdrive_left > 0.0 or mech.overdrive_meter >= 100.0):
		prize = &"lucky"
	var amount := 0.0
	match prize:
		&"frenzy":
			Game.start_frenzy()
		&"lucky":
			amount = Game.credit_scrap(maxf(Game.run_scrap * LUCKY_SHARE, LUCKY_MIN * Game.diff("scrap")), &"gold")
			Game.drop_scrap(pos, amount, 12)
		&"xp":
			Upgrades.supply_xp(pos, XP_SURGE)
		&"overdrive":
			mech.add_overdrive(100.0)
		&"jackpot":
			_jackpot(pos)
	Game.salvager_caught.emit(prize, amount)


## JACKPOT: a ring of little gold drones that scatter (see `mini`).
func _jackpot(pos: Vector2) -> void:
	var each := maxf(Game.run_scrap * JACKPOT_SHARE, JACKPOT_MIN * Game.diff("scrap"))
	for i in JACKPOT_DRONES:
		var m: Enemy = get_script().new()
		m.set("mini", true)
		m.set("value", each)
		m.max_hp = 30.0 * sqrt(Game.diff("hp"))
		m.position = pos + Vector2.from_angle(TAU * i / JACKPOT_DRONES) * randf_range(30.0, 60.0)
		get_parent().add_child.call_deferred(m)


## Warps out (time's up, or wiped by a script): no prize.
func _escape() -> void:
	if dead:
		return
	dead = true
	Combat.shockwave(global_position, hit_radius * 3.0, GOLD, 0.35)
	Combat.burst(global_position, LIGHT, 200.0, 0.7)
	if not mini:
		Game.salvager_escaped.emit()
	queue_free()


func _draw() -> void:
	var r := hit_radius
	var blink := _life < 3.0 and fmod(_t * (10.0 if _life < 1.5 else 6.0), 1.0) < 0.35
	var a := 0.45 if blink else 1.0
	var c := Vector2(0, -r * 0.35 + sin(_t * 7.0) * (2.0 if mini else 3.0))
	# Ground shadow.
	draw_set_transform(Vector2(0, r * 0.75), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, r * 0.95, Color(0, 0, 0, 0.32 * a))
	draw_set_transform(Vector2.ZERO)
	# Glow.
	for i in 3:
		draw_circle(c, r * (2.0 - i * 0.35), Color(GOLD, (0.05 + 0.035 * i) * a))
	# Thruster flame, trailing its motion.
	var back := -velocity.normalized() if velocity.length() > 30.0 else Vector2.DOWN
	var flick := 0.8 + 0.4 * sin(_t * 40.0)
	var base := c + back * r * 0.75
	var side := back.orthogonal() * r * 0.32
	draw_colored_polygon(PackedVector2Array([base + side, base + back * r * 1.1 * flick, base - side]),
		Color(1.0, 0.6, 0.15, 0.75 * a))
	draw_colored_polygon(PackedVector2Array([base + side * 0.5, base + back * r * 0.65 * flick, base - side * 0.5]),
		Color(1.0, 0.95, 0.7, 0.9 * a))
	# Rotor ring with three pods.
	var spin := _t * (7.0 if mini else 5.0)
	draw_arc(c, r * 1.22, spin, spin + TAU * 0.78, 28, Color(LIGHT, 0.75 * a), 2.0, true)
	for i in 3:
		draw_circle(c + Vector2.from_angle(spin + i * TAU / 3.0) * r * 1.22, r * 0.16, tint(Color(LIGHT, a)))
	# Hex body (the scrap nut look) with a lit and a shaded facet.
	var hex := PackedVector2Array()
	for i in 6:
		hex.append(c + Vector2.from_angle(_t * 1.3 + i * TAU / 6.0) * r)
	draw_colored_polygon(hex, tint(Color(GOLD, a)))
	draw_colored_polygon(PackedVector2Array([c, hex[3], hex[4]]), Color(LIGHT, 0.55 * a))
	draw_colored_polygon(PackedVector2Array([c, hex[0], hex[1]]), Color(DARK, 0.45 * a))
	var ring := hex.duplicate()
	ring.append(hex[0])
	draw_polyline(ring, Color(DARK, a), 2.0, true)
	# Core: a pulsing gem.
	var pulse := 0.5 + 0.5 * sin(_t * 9.0)
	draw_circle(c, r * 0.42, Color(DARK, a))
	draw_circle(c, r * 0.3, Color(Color(1.0, 0.98, 0.8).lerp(GOLD, pulse * 0.6), a))
	if not mini:
		# Twinkles around it.
		for i in 3:
			var k := fmod(_t * 0.9 + i / 3.0, 1.0)
			_star(c + Vector2.from_angle(i * 2.1 + _t * 0.7) * r * (1.45 + 0.3 * k), (1.0 - absf(k - 0.5) * 2.0) * r * 0.34,
				Color(1.0, 1.0, 0.9, a))
		# Escape timer: a ring that runs down (gold -> red).
		var left := clampf(_life / LIFETIME, 0.0, 1.0)
		draw_arc(c, r * 1.6, -PI / 2.0, -PI / 2.0 + TAU * left, 32, Color(GOLD.lerp(Color(1.0, 0.3, 0.2), 1.0 - left), 0.85),
			3.0, true)
	draw_hp_bar(c.y - r * 2.0)


func _star(p: Vector2, s: float, col: Color) -> void:
	if s <= 0.5:
		return
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.25, -s * 0.25), p + Vector2(s, 0),
		p + Vector2(s * 0.25, s * 0.25), p + Vector2(0, s), p + Vector2(-s * 0.25, s * 0.25), p + Vector2(-s, 0),
		p + Vector2(-s * 0.25, -s * 0.25)]), col)
