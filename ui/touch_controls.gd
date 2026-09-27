extends CanvasLayer
## On-screen twin-stick controls. Shown while the last-used device is a touch screen (phones and
## tablets start with them visible). `-- --touch` forces them on for desktop testing.
## Hidden while the game is paused (menus take over); hiding releases any held stick/button.

var _forced := OS.get_cmdline_user_args().has("--touch")
var _wanted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wanted = _forced or Controls.touch_active
	Controls.device_changed.connect(_on_device_changed)


func _on_device_changed(device: Controls.Device) -> void:
	_wanted = _forced or device == Controls.Device.TOUCH


func _process(_delta: float) -> void:
	var show := _wanted and not get_tree().paused
	if visible != show:
		visible = show
