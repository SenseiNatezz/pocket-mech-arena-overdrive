extends CanvasLayer
## On-screen touch controls. Shown while the last-used device is a touch screen (phones and tablets
## start with them visible). `-- --touch` forces them on for desktop testing.
## Hidden while the game is paused (menus take over); hiding releases any held stick/button.
##
##   left    floating MOVE stick (appears where your thumb lands, 360 degree movement)
##   right   big FIRE button (ui/fire_stick.gd): hold to fire with auto-aim, drag on it to aim by hand;
##           the ability buttons sit in two arcs around it (most used on the inner arc), like mobile
##           action games. The auto-aim target gets a lock-on marker (ui/auto_aim_marker.gd).
## The right-hand cluster is laid out in code for landscape and portrait (Layout.changed); everything
## else keeps the anchors/offsets authored in the scene.
## SIMPLE layout (Settings > Touch: Simple, the default): FIRE, BOOST, ALT FIRE, BEAM and one smart
## HEAT button (Nova when robots are close, else Cone - Mech._smart_heat); Self-repair and Overdrive
## trigger on their own (Mech, touch + simple). FULL layout: every ability gets its own button.
## With AUTO-FIRE (Settings, default on) the mech also fires at the auto-aim target by itself
## (Controls.auto_firing); FIRE is still there to aim by hand.

const MARKER := preload("res://ui/auto_aim_marker.gd")
const TOUCH_BUTTON := preload("res://ui/touch_button.gd")
## [node, ring (1 = inner, 2 = outer), angle in degrees around the FIRE button (180 = left, 270 = up), size]
const CLUSTER := [
	["Boost", 1, 180.0, 96.0],
	["AltFire", 1, 214.0, 84.0],
	["Beam", 1, 247.0, 84.0],
	["Nova", 1, 280.0, 84.0],
	["Cone", 2, 196.0, 84.0],
	["Repair", 2, 228.0, 84.0],
	["Overdrive", 2, 260.0, 96.0],
]
const SIMPLE_CLUSTER := [
	["Boost", 1, 180.0, 100.0],
	["AltFire", 1, 222.0, 86.0],
	["Beam", 1, 264.0, 86.0],
	["Heat", 2, 208.0, 100.0],
]
## Buttons only one of the two layouts shows.
const FULL_ONLY := ["Nova", "Cone", "Repair", "Overdrive"]
const SIMPLE_ONLY := ["Heat"]
## Per orientation: FIRE button centre (from the bottom-right corner), its size, inner/outer arc radius.
const LANDSCAPE_GEOM := {"center": Vector2(-165, -155), "fire": 170.0, "inner": 170.0, "outer": 285.0}
const PORTRAIT_GEOM := {"center": Vector2(-150, -160), "fire": 160.0, "inner": 165.0, "outer": 262.0}
## Portrait: the USE button sits a little lower so it clears the outer arc.
const PORTRAIT_USE := [-60.0, -170.0, 40.0, -70.0]

var _forced := OS.get_cmdline_user_args().has("--touch")
var _wanted := false
## Authored anchors + offsets of every control, restored before each layout pass.
var _authored := {}
## The layout last applied (Game.touch_simple can change in Settings).
var _simple := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wanted = _forced or Controls.touch_active
	Controls.device_changed.connect(_on_device_changed)
	# SIMPLE layout's smart HEAT button (its own action; the mech picks Nova or Cone).
	if not InputMap.has_action(&"heat_smart"):
		InputMap.add_action(&"heat_smart")
	var heat: Control = TOUCH_BUTTON.new()
	heat.name = "Heat"
	heat.set("action", &"heat_smart")
	heat.set("label", "HEAT")
	heat.set("accent", Color(1.0, 0.5, 0.15))
	heat.set("indicator", TOUCH_BUTTON.Indicator.HEAT_COST_CONE)
	$Root.add_child(heat)
	for c: Control in $Root.get_children():
		_authored[c.name] = [c.anchor_left, c.anchor_top, c.anchor_right, c.anchor_bottom,
			c.offset_left, c.offset_top, c.offset_right, c.offset_bottom]
	var marker := MARKER.new()
	marker.name = "AutoAimMarker"
	$Root.add_child(marker)
	$Root.move_child(marker, 0)
	Layout.changed.connect(_apply_layout)
	_apply_layout(Layout.portrait)


## Centre of a right-hand cluster control, as an offset from the bottom-right corner.
static func cluster_center(node_name: String, portrait: bool, simple := false) -> Vector2:
	var g: Dictionary = PORTRAIT_GEOM if portrait else LANDSCAPE_GEOM
	if node_name == "FireStick":
		return g["center"]
	for p: Array in (SIMPLE_CLUSTER if simple else CLUSTER):
		if p[0] == node_name:
			var r: float = g["inner"] if p[1] == 1 else g["outer"]
			return g["center"] + Vector2.from_angle(deg_to_rad(p[2])) * r
	return Vector2.ZERO


func _apply_layout(portrait: bool) -> void:
	for n: String in _authored:
		var v: Array = _authored[n]
		var c := $Root.get_node(n) as Control
		c.anchor_left = v[0]
		c.anchor_top = v[1]
		c.anchor_right = v[2]
		c.anchor_bottom = v[3]
		c.offset_left = v[4]
		c.offset_top = v[5]
		c.offset_right = v[6]
		c.offset_bottom = v[7]
	var g: Dictionary = PORTRAIT_GEOM if portrait else LANDSCAPE_GEOM
	_simple = Game.touch_simple
	_place_corner($Root/FireStick, g["center"], g["fire"])
	for p: Array in (SIMPLE_CLUSTER if _simple else CLUSTER):
		_place_corner($Root.get_node(String(p[0])), cluster_center(p[0], portrait, _simple), p[3])
	for n: String in FULL_ONLY:
		($Root.get_node(n) as Control).visible = not _simple
	for n: String in SIMPLE_ONLY:
		($Root.get_node(n) as Control).visible = _simple
	if portrait:
		var use := $Root/Use as Control
		use.offset_left = PORTRAIT_USE[0]
		use.offset_top = PORTRAIT_USE[1]
		use.offset_right = PORTRAIT_USE[2]
		use.offset_bottom = PORTRAIT_USE[3]


## Anchors `c` to the bottom-right corner, centred on `center` (an offset from that corner).
func _place_corner(c: Control, center: Vector2, size: float) -> void:
	c.anchor_left = 1.0
	c.anchor_right = 1.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = center.x - size / 2
	c.offset_right = center.x + size / 2
	c.offset_top = center.y - size / 2
	c.offset_bottom = center.y + size / 2


func _on_device_changed(device: Controls.Device) -> void:
	_wanted = _forced or device == Controls.Device.TOUCH


func _process(_delta: float) -> void:
	var show := _wanted and not get_tree().paused
	if visible != show:
		visible = show
	if _simple != Game.touch_simple:
		_apply_layout(Layout.portrait)
