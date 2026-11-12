class_name MechShadow
extends Node2D
## The mech's drop shadow: its own shape (the legs and upper-body sprites, this frame) drawn in soft black
## down-right of it, the way the sun falls on the maps (the robots' shadows lean the same way).
## `lift` 0 = on the ground (close and crisp), 1 = flying (further away, smaller, fainter and softer), so you
## can see the height; player/mech.gd eases it when the WALK / FLY switch flips.

const SHADER := preload("res://fx/soft_shadow.gdshader")
const GROUND := {"off": Vector2(8, 11), "scale": 1.0, "strength": 0.52, "blur": 1.6}
const AIR := {"off": Vector2(32, 46), "scale": 0.84, "strength": 0.34, "blur": 4.0}

var lift := 0.0
var sources: Array[AnimatedSprite2D] = []
var _mat := ShaderMaterial.new()


func _ready() -> void:
	_mat.shader = SHADER
	material = _mat


func _process(_delta: float) -> void:
	_mat.set_shader_parameter("strength", lerpf(GROUND.strength, AIR.strength, lift))
	_mat.set_shader_parameter("blur", lerpf(GROUND.blur, AIR.blur, lift))
	queue_redraw()


func _draw() -> void:
	var off: Vector2 = GROUND.off.lerp(AIR.off, lift)
	var sc: float = lerpf(GROUND.scale, AIR.scale, lift)
	var inv := get_global_transform().affine_inverse()
	for s in sources:
		if not is_instance_valid(s) or not s.is_visible_in_tree() or s.sprite_frames == null:
			continue
		var tex := s.sprite_frames.get_frame_texture(s.animation, s.frame)
		if tex == null:
			continue
		# The sprite's own transform (relative to this node), shrunk about the mech's centre and pushed away.
		var xf := Transform2D(0.0, Vector2(sc, sc), 0.0, off) * (inv * s.get_global_transform())
		draw_set_transform_matrix(xf)
		var size := tex.get_size()
		var at := s.offset - (size / 2.0 if s.centered else Vector2.ZERO)
		draw_texture_rect(tex, Rect2(at, size), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
