class_name HeldWeapon
extends Node2D
## Guns drawn in the Gundam's gun hand: the Sniper Beam, Gatling Cannon and Rocket Launcher use their Higgsfield
## art (points up = forward) instead of the sprite's small rifle. A child of the mech's Body, which
## turns to the aim. While one is equipped the Muzzle / MuzzleFlash markers sit at its barrel tip, so
## shots, aim convergence and flashes come out of the big gun; switching away puts them back.

## id -> art, grip (Body space; the art's back end sits here), on-screen length, muzzle (fraction up the art)
const GUNS := {
	&"gatling": {"tex": "gatling", "grip": Vector2(33, 4), "length": 108.0, "muzzle": 0.97},
	&"rockets": {"tex": "rocket_launcher", "grip": Vector2(33, 8), "length": 100.0, "muzzle": 0.98},
	&"sniper": {"tex": "sniper", "grip": Vector2(28, -2), "length": 124.0, "muzzle": 0.98},
}

var mech: Mech
var _id := &""
var _tex: Texture2D
var _default_muzzle := Vector2.ZERO
var _default_flash := Vector2.ZERO
var _kick := 0.0
var _rumble := 0.0


func setup(m: Mech) -> void:
	mech = m
	_default_muzzle = m.muzzle.position
	_default_flash = m.muzzle_flash.position


## Called every frame by the mech with its current weapon.
func sync(id: StringName, delta: float, firing: bool) -> void:
	if id != _id:
		_id = id
		if GUNS.has(id):
			var g: Dictionary = GUNS[id]
			_tex = load("res://assets/hq/weapons/%s.png" % g["tex"])
			var tip: Vector2 = g["grip"] + Vector2(0, -g["length"] * g["muzzle"])
			mech.muzzle.position = tip
			mech.muzzle_flash.position = tip + Vector2(0, -6)
		else:
			_tex = null
			mech.muzzle.position = _default_muzzle
			mech.muzzle_flash.position = _default_flash
	visible = _tex != null
	_kick = move_toward(_kick, 0.0, delta * 9.0)
	_rumble = _rumble + delta * 60.0 if firing and id == &"gatling" else 0.0
	if visible:
		queue_redraw()


## Recoil: the gun jolts back toward the mech (1 = full rocket kick).
func kick(amount := 1.0) -> void:
	_kick = maxf(_kick, amount)


func _draw() -> void:
	if _tex == null:
		return
	var g: Dictionary = GUNS[_id]
	var size := _tex.get_size()
	var s: float = g["length"] / size.y
	var shake := Vector2(sin(_rumble) * 0.8, cos(_rumble * 1.3) * 0.5) if _rumble > 0.0 else Vector2.ZERO
	var pos: Vector2 = g["grip"] + Vector2(0, _kick * 7.0) + shake
	draw_set_transform(pos + Vector2(3, 5), 0.0, Vector2(s, s))
	draw_texture(_tex, Vector2(-size.x / 2, -size.y), Color(0, 0, 0, 0.3))
	draw_set_transform(pos, 0.0, Vector2(s, s))
	draw_texture(_tex, Vector2(-size.x / 2, -size.y))
	draw_set_transform(Vector2.ZERO)
