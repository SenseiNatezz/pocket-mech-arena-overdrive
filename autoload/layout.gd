extends Node
## Layout (autoload): landscape <-> portrait.
## Whenever the window (or phone browser) is taller than it is wide, the game switches its base canvas
## from 1280x720 to 720x1280 (with "expand", an iPhone in portrait gets a ~720 x 1560 logical screen at
## the same pixel scale as landscape), and emits `changed(portrait)` so screens can rearrange themselves.
## Rotating the phone mid-game just re-lays everything out. `Layout.portrait` is readable any time.
## Debug: `-- --portrait` / `-- --landscape` force one (desktop testing).

signal changed(portrait: bool)

const LANDSCAPE := Vector2i(1280, 720)
const PORTRAIT := Vector2i(720, 1280)

var portrait := false
var _forced := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.has("--portrait"):
		_forced = "portrait"
	elif args.has("--landscape"):
		_forced = "landscape"
	get_tree().root.size_changed.connect(_update)
	_update()


func _update() -> void:
	var win := get_tree().root.size
	var p := win.y > win.x
	if _forced != "":
		p = _forced == "portrait"
	var want := PORTRAIT if p else LANDSCAPE
	if get_tree().root.content_scale_size != want:
		get_tree().root.content_scale_size = want
	if p != portrait:
		portrait = p
		changed.emit(p)
