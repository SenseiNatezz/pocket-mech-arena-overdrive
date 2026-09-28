extends CanvasLayer
## On-screen twin-stick controls. Shown while the last-used device is a touch screen (phones and
## tablets start with them visible). `-- --touch` forces them on for desktop testing.
## Hidden while the game is paused (menus take over); hiding releases any held stick/button.

## PORTRAIT layout (Layout.portrait): the sticks stay in the bottom corners and every ability button
## moves into two rows above the right stick (right thumb), clear of the HUD status card at the top.
## [node, left, top, right, bottom] offsets, all anchored to the BOTTOM-RIGHT corner.
const PORTRAIT_RIGHT := [
	["AimStick", -290, -300, -50, -60],
	["Boost", -170, -440, -50, -320],
	["Beam", -290, -420, -194, -324],
	["AltFire", -410, -420, -314, -324],
	["Overdrive", -150, -560, -50, -460],
	["Repair", -254, -552, -170, -468],
	["Cone", -358, -552, -274, -468],
	["Nova", -462, -552, -378, -468],
]

var _forced := OS.get_cmdline_user_args().has("--touch")
var _wanted := false
## Landscape anchors + offsets of every control (as authored in the scene), to restore on rotation.
var _landscape := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wanted = _forced or Controls.touch_active
	Controls.device_changed.connect(_on_device_changed)
	for c: Control in $Root.get_children():
		_landscape[c.name] = [c.anchor_left, c.anchor_top, c.anchor_right, c.anchor_bottom,
			c.offset_left, c.offset_top, c.offset_right, c.offset_bottom]
	Layout.changed.connect(_apply_layout)
	_apply_layout(Layout.portrait)


func _apply_layout(portrait: bool) -> void:
	for n: String in _landscape:
		var v: Array = _landscape[n]
		var c := $Root.get_node(n) as Control
		c.anchor_left = v[0]
		c.anchor_top = v[1]
		c.anchor_right = v[2]
		c.anchor_bottom = v[3]
		c.offset_left = v[4]
		c.offset_top = v[5]
		c.offset_right = v[6]
		c.offset_bottom = v[7]
	if not portrait:
		return
	for p: Array in PORTRAIT_RIGHT:
		var c := $Root.get_node(String(p[0])) as Control
		c.anchor_left = 1.0
		c.anchor_right = 1.0
		c.anchor_top = 1.0
		c.anchor_bottom = 1.0
		c.offset_left = p[1]
		c.offset_top = p[2]
		c.offset_right = p[3]
		c.offset_bottom = p[4]


func _on_device_changed(device: Controls.Device) -> void:
	_wanted = _forced or device == Controls.Device.TOUCH


func _process(_delta: float) -> void:
	var show := _wanted and not get_tree().paused
	if visible != show:
		visible = show
