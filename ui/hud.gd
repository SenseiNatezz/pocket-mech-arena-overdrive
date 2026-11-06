extends CanvasLayer
## In-game HUD + menus. Everything here is built in code:
##   top-left   HP (+ shield pips), heat (with Cone/Nova cost ticks), overdrive, repair kits, boost
##              cooldown dial, beam cooldown, pilot level + XP bar + equipped weapon
##   top-center objective, wave/zone banners (upper third, on a dark strip), boss health bar
##   boss card  letterbox + the boss's name and epithet whenever a boss arrives (see _show_boss_card)
##   top-right  arena name (or endless wave), time, kills
##   panels     pause (resume / restart / screen shake / main menu + upgrades owned), game over,
##              victory, and the level-up menu (ui/level_up_menu.gd)
## Talks to the arena through its signals (objective_changed, banner, boss_started, ...).

const LEVEL_UP_MENU := preload("res://ui/level_up_menu.gd")

var mech: Mech
var arena: Node
## Setting a new boss (arena boss_started, Endless boss waves, gun range spawns) shows its name card.
var boss: Node:
	set = _set_boss
var level_menu: CanvasLayer
var _bars: Control
var _objective: Label
var _banner: Label
var _banner_box: PanelContainer
var _banner_style: StyleBoxFlat
var _banner_tw: Tween
var _card: Control
var _card_name := ""
var _help: Label
var _pause_panel: Control
var _over_panel: Control
var _retry_boss_btn: Button
var _win_panel: Control
var _win_stats: Label
var _over_stats: Label
var _pause_upgrades: Label
var _next_btn: Button
var _shake_btn: Button
var _t := 0.0
var _hp_shown := 1.0
var _ended := false
var _unlock_toast: PanelContainer
var _toast_tw: Tween
var _radio_box: PanelContainer
var _radio_text: Label
const BLACKOUT := preload("res://ui/blackout.gdshader")
var _blackout: ColorRect
var _blackout_k := 0.0
var _radio_tw: Tween


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# BLACKOUT twist: darkness over the arena (under every HUD element), a pool of light around the mech.
	_blackout = ColorRect.new()
	_blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blackout.material = ShaderMaterial.new()
	(_blackout.material as ShaderMaterial).shader = BLACKOUT
	_blackout.visible = false
	root.add_child(_blackout)
	_bars = Control.new()
	_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(_draw_bars)
	root.add_child(_bars)

	_objective = _label(18, Color(0.85, 0.95, 1.0))
	_objective.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective.position = Vector2(-300, 14)
	_objective.size = Vector2(600, 30)
	root.add_child(_objective)
	Layout.changed.connect(_on_layout)
	_on_layout(Layout.portrait)

	# Wave / zone banners: upper third, clear of the objective line and boss bar, on a dark strip with a
	# coloured underline so they read over the arena and the mech (see show_banner / _place_banner).
	_banner_box = PanelContainer.new()
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_style = StyleBoxFlat.new()
	_banner_style.bg_color = Color(0.01, 0.02, 0.05, 0.66)
	_banner_style.border_width_bottom = 3
	_banner_style.set_corner_radius_all(4)
	_banner_style.content_margin_left = 30
	_banner_style.content_margin_right = 30
	_banner_style.content_margin_top = 0
	_banner_style.content_margin_bottom = 2
	_banner_box.add_theme_stylebox_override("panel", _banner_style)
	_banner_box.modulate.a = 0.0
	_banner = _label(46, Color.WHITE)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_banner.add_theme_constant_override("outline_size", 12)
	_banner_box.add_child(_banner)
	root.add_child(_banner_box)

	_pause_panel = _panel("PAUSED", [["RESUME", _resume], ["RESTART ARENA", _restart], ["SCREEN SHAKE: ON", _toggle_shake],
		["MAIN MENU", _to_menu]], true)
	_shake_btn = _pause_panel.find_child("Btn2", true, false) as Button
	_over_panel = _panel("MECH DESTROYED", [["RETRY", _restart], ["MAIN MENU", _to_menu], ["RETRY BOSS", _retry_boss]])
	# RETRY BOSS (only shown after dying in a campaign boss fight) sits above RETRY.
	_retry_boss_btn = _over_panel.find_child("Btn2", true, false) as Button
	_retry_boss_btn.get_parent().move_child(_retry_boss_btn, (_over_panel.find_child("Btn0", true, false) as Button).get_index())
	_win_panel = _panel("ARENA CLEARED", [["NEXT ARENA", _next], ["PLAY AGAIN", _restart], ["MAIN MENU", _to_menu]])
	_next_btn = _win_panel.find_child("Btn0", true, false) as Button
	_win_stats = _stats_label(_win_panel)
	_over_stats = _stats_label(_over_panel)
	_pause_upgrades = _stats_label(_pause_panel)
	_pause_upgrades.add_theme_font_size_override("font_size", 14)
	for p in [_pause_panel, _over_panel, _win_panel]:
		root.add_child(p)
		p.hide()
	_unlock_toast = _make_unlock_toast()
	root.add_child(_unlock_toast)
	Game.weapon_unlocked.connect(_on_weapon_unlocked)
	_radio_box = _make_radio_box()
	root.add_child(_radio_box)
	Radio.line_started.connect(_on_radio_line)
	level_menu = LEVEL_UP_MENU.new()
	add_child(level_menu)
	_hook_scene.call_deferred()


## Radio subtitles (autoload/radio.gd): "HALCYON  <line>" in a dark strip low on the screen (above the
## touch controls in portrait), fading out when the line ends.
func _make_radio_box() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.08, 0.78)
	sb.border_color = Color(0.35, 0.8, 1.0, 0.6)
	sb.border_width_left = 3
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	sb.content_margin_left = 12
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.modulate.a = 0.0
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var who := Label.new()
	who.text = "HALCYON"
	who.add_theme_font_size_override("font_size", 14)
	who.add_theme_color_override("font_color", Color(0.35, 0.8, 1.0))
	who.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(who)
	# (every callout fits on one line, so no wrapping - wrapped labels in containers size badly)
	_radio_text = Label.new()
	_radio_text.add_theme_font_size_override("font_size", 16)
	h.add_child(_radio_text)
	return p


func _on_radio_line(text: String, duration: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	_radio_text.text = text
	_radio_box.reset_size()
	var w := _radio_box.get_combined_minimum_size().x
	_radio_box.size = _radio_box.get_combined_minimum_size()
	var y := vp.y - (600.0 if Layout.portrait else 110.0)
	_radio_box.position = Vector2(roundf((vp.x - w) / 2.0), y)
	if _radio_tw:
		_radio_tw.kill()
	_radio_tw = create_tween()
	_radio_tw.tween_property(_radio_box, "modulate:a", 1.0, 0.15)
	_radio_tw.tween_interval(duration)
	_radio_tw.tween_property(_radio_box, "modulate:a", 0.0, 0.4)


## Wrapped info text right under a panel's title.
func _stats_label(panel: Control) -> Label:
	var l := _label(18, Color(0.8, 0.9, 1.0))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(380, 0)
	panel.get_node("Box/VBox").add_child(l)
	panel.get_node("Box/VBox").move_child(l, 1)
	return l


func _hook_scene() -> void:
	mech = get_tree().get_first_node_in_group("player") as Mech
	if mech:
		mech.died.connect(func() -> void: get_tree().create_timer(1.6).timeout.connect(_show_game_over))
	arena = get_tree().get_first_node_in_group("arena")
	if Game.is_endless():
		(_pause_panel.find_child("Btn1", true, false) as Button).text = "RESTART RUN"
		(_over_panel.find_child("Btn0", true, false) as Button).text = "NEW RUN"
	if arena:
		arena.objective_changed.connect(func(t: String) -> void: _objective.text = t)
		arena.banner.connect(show_banner)
		arena.boss_started.connect(func(b: Node) -> void: boss = b)
		arena.arena_cleared.connect(_show_victory)
		if arena.get("intro_texture") and not Game.start_at_boss and not OS.get_cmdline_user_args().has("--no-intro"):
			_show_intro_card(arena.intro_texture, arena.arena_name.to_upper(), arena.intro_subtitle)
		else:
			show_banner(arena.arena_name.to_upper(), Color(0.5, 0.9, 1.0))


## Cinematic intro card (the arena's key art) that fades out after a few seconds.
func _show_intro_card(tex: Texture2D, title: String, subtitle: String) -> void:
	var card := Control.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	move_child(card, 0)
	var art := TextureRect.new()
	art.texture = tex
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0.03, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(shade)
	var t := _label(64, Color(0.9, 0.95, 1.0))
	t.text = title
	t.set_anchors_preset(Control.PRESET_CENTER)
	t.position = Vector2(-600, -70)
	t.size = Vector2(1200, 90)
	card.add_child(t)
	var s := _label(20, Color(0.55, 0.95, 1.0))
	s.text = subtitle
	s.set_anchors_preset(Control.PRESET_CENTER)
	s.position = Vector2(-600, 20)
	s.size = Vector2(1200, 40)
	card.add_child(s)
	art.pivot_offset = get_viewport().get_visible_rect().size / 2
	var tw := card.create_tween()
	tw.tween_property(art, "scale", Vector2(1.08, 1.08), 3.2)
	tw.parallel().tween_property(card, "modulate:a", 0.0, 0.8).set_delay(2.4)
	tw.tween_callback(card.queue_free)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel(title: String, buttons: Array, with_help := false) -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.05, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := PanelContainer.new()
	box.name = "Box"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.13, 0.95)
	sb.border_color = Color(0.35, 0.8, 1.0, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(28)
	box.add_theme_stylebox_override("panel", sb)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	shade.add_child(box)
	var v := VBoxContainer.new()
	v.name = "VBox"
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(380, 0)
	box.add_child(v)
	v.add_child(_label(34, Color(0.6, 0.9, 1.0)))
	(v.get_child(0) as Label).text = title
	for i in buttons.size():
		var b := MenuButtonFactory.make(buttons[i][0])
		b.name = "Btn%d" % i
		b.pressed.connect(buttons[i][1])
		v.add_child(b)
	if with_help:
		_help = _label(13, Color(1, 1, 1, 0.6))
		v.add_child(_help)
		_refresh_help()
		Controls.bindings_changed.connect(_refresh_help)
	return shade


## Pause-menu controls help. Keyboard / mouse keys are rebindable, so they come from Controls.
func _refresh_help() -> void:
	if _help == null:
		return
	var k := func(action: StringName) -> String: return Controls.key_name(action)
	var move: String = k.call(&"move_up") + k.call(&"move_left") + k.call(&"move_down") + k.call(&"move_right")
	if move.length() != 4:
		move = "%s/%s/%s/%s" % [k.call(&"move_up"), k.call(&"move_left"), k.call(&"move_down"), k.call(&"move_right")]
	_help.text = "KB/Mouse: %s move, mouse aim, %s fire, %s scatter, %s boost,\n%s nova, %s cone, %s repair, %s overdrive, %s use, %s beam\n" % [
		move, k.call(&"fire_primary"), k.call(&"fire_secondary"), k.call(&"boost"), k.call(&"heat_attack_1"),
		k.call(&"heat_attack_2"), k.call(&"self_repair"), k.call(&"overdrive"), k.call(&"use"), k.call(&"beam")] \
		+ "Gamepad: sticks move/aim, RT fire, LT scatter, LB boost,\nY nova, RB cone, B repair, R3 overdrive, A use, X beam"


func show_banner(text: String, color := Color.WHITE) -> void:
	# The boss name card is already showing this name.
	if is_instance_valid(_card) and text == _card_name:
		return
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_style.border_color = Color(color, 0.85)
	if _banner_tw:
		_banner_tw.kill()
	var fit := _place_banner()
	_banner_box.scale = Vector2.ONE * fit * 1.3
	_banner_tw = create_tween()
	_banner_tw.set_parallel()
	_banner_tw.tween_property(_banner_box, "modulate:a", 1.0, 0.15)
	_banner_tw.tween_property(_banner_box, "scale", Vector2.ONE * fit, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tw.chain().tween_property(_banner_box, "modulate:a", 0.0, 0.5).set_delay(1.6)


## Sizes the banner strip to its text and centres it in the upper third: just under the status card in
## landscape, under the boss bar in portrait. Returns the scale that fits it on screen (long banners on a
## narrow portrait screen shrink).
func _place_banner() -> float:
	_banner.add_theme_font_size_override("font_size", 38 if Layout.portrait else 46)
	_banner_box.reset_size()
	var sz := _banner_box.get_combined_minimum_size()
	_banner_box.size = sz
	var vp := _screen_size()
	_banner_box.position = Vector2(roundf((vp.x - sz.x) / 2.0), 178.0 if Layout.portrait else 128.0)
	_banner_box.pivot_offset = sz / 2.0
	return minf(1.0, (vp.x - 24.0) / maxf(sz.x, 1.0))


# --- boss name card ------------------------------------------------------------------------------------

## Subtitle under each boss's name ("WARDEN - CRYO UNIT" -> "SIEGE WALKER  -  CRYO UNIT"; Endless
## "RONIN MK-II" uses RONIN's).
const BOSS_EPITHETS := {
	"WARDEN": "Siege Walker",
	"RONIN": "Masterless Blade",
	"SHOGUN": "Warlord of the Ruins",
	"SERAPH": "Herald of Six Blades",
	"VULCAN": "The Forge Titan",
}
const BOSS_CARD_TIME := 2.3


func _set_boss(b: Node) -> void:
	var fresh := b != boss and is_instance_valid(b)
	boss = b
	if fresh and is_node_ready() and b.get("boss_name") != null:
		_show_boss_card(b)


## [big name, subtitle] for a boss name.
static func boss_title(full: String) -> PackedStringArray:
	var big := full
	var tags: Array[String] = []
	var dash := full.find(" - ")
	if dash >= 0:
		big = full.substr(0, dash)
		tags.append(full.substr(dash + 3))
	var mk := big.find(" MK-")
	var epithet: String = BOSS_EPITHETS.get(big.substr(0, mk) if mk >= 0 else big, "")
	if epithet != "":
		tags.push_front(epithet)
	return PackedStringArray([big, "  -  ".join(tags).to_upper()])


## Cinematic boss card: letterbox bars slide in, the name slams in (lower third in landscape, under the
## boss bar in portrait) with its epithet above and an accent rule below, then it all fades after
## ~BOSS_CARD_TIME s. Sits under the banners / panels / radio strip and pauses with the game.
func _show_boss_card(b: Node) -> void:
	if is_instance_valid(_card):
		_card.queue_free()
	var full := String(b.get("boss_name"))
	var accent: Color = b.get("accent") if b.get("accent") is Color else Color(1.0, 0.3, 0.25)
	var title := boss_title(full)
	_card_name = full
	# The arena's own "<BOSS NAME>" banner would only repeat the card.
	if _banner.text == full:
		if _banner_tw:
			_banner_tw.kill()
		_banner_box.modulate.a = 0.0
	var vp := _screen_size()
	var card := Control.new()
	card.name = "BossCard"
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.process_mode = Node.PROCESS_MODE_PAUSABLE
	_bars.get_parent().add_child(card)
	_bars.get_parent().move_child(card, _bars.get_index() + 1)
	_card = card
	var bar_h := roundf(vp.y * (0.055 if Layout.portrait else 0.075))
	var bars: Array[ColorRect] = []
	for top: bool in [true, false]:
		var r := ColorRect.new()
		r.color = Color(0, 0, 0, 0.9)
		r.size = Vector2(vp.x, bar_h)
		r.position = Vector2(0, -bar_h if top else vp.y)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(r)
		bars.append(r)
	var name_y := 262.0 if Layout.portrait else roundf(vp.y * 0.68)
	var name_l := _label(52 if Layout.portrait else 66, Color.WHITE)
	name_l.text = title[0]
	name_l.add_theme_color_override("font_outline_color", Color(accent.darkened(0.75), 0.95))
	name_l.add_theme_constant_override("outline_size", 14)
	name_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	name_l.add_theme_constant_override("shadow_offset_y", 5)
	name_l.size = Vector2(vp.x, 90)
	name_l.position = Vector2(0, name_y - 45)
	name_l.pivot_offset = name_l.size / 2
	card.add_child(name_l)
	var sub := _label(18 if Layout.portrait else 20, accent.lightened(0.45))
	var spaced := FontVariation.new()
	spaced.base_font = ThemeDB.fallback_font
	spaced.spacing_glyph = 4
	sub.add_theme_font_override("font", spaced)
	sub.text = title[1]
	sub.size = Vector2(vp.x, 30)
	sub.position = Vector2(0, name_y - 82)
	card.add_child(sub)
	var rule_w := minf(vp.x - 80.0, 620.0)
	var rule := ColorRect.new()
	rule.color = accent
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.size = Vector2(0, 3)
	rule.position = Vector2(vp.x / 2.0, name_y + 44)
	card.add_child(rule)
	name_l.modulate.a = 0.0
	name_l.scale = Vector2(1.6, 1.6)
	sub.modulate.a = 0.0
	var tw := card.create_tween()
	tw.set_parallel()
	tw.tween_property(bars[0], "position:y", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(bars[1], "position:y", vp.y - bar_h, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(name_l, "modulate:a", 1.0, 0.16).set_delay(0.12)
	tw.tween_property(name_l, "scale", Vector2.ONE, 0.3).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(Sfx.play.bind(&"slam", -10.0, 0.0)).set_delay(0.14)
	tw.tween_property(rule, "size:x", rule_w, 0.4).set_delay(0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(rule, "position:x", (vp.x - rule_w) / 2.0, 0.4).set_delay(0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(sub, "modulate:a", 1.0, 0.35).set_delay(0.32)
	tw.tween_property(sub, "position:y", name_y - 76, 0.35).set_delay(0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var out := BOSS_CARD_TIME - 0.45
	tw.tween_property(card, "modulate:a", 0.0, 0.45).set_delay(out)
	tw.tween_property(bars[0], "position:y", -bar_h, 0.45).set_delay(out).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(bars[1], "position:y", vp.y, 0.45).set_delay(out).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(card.queue_free)


## Mid-run "NEW WEAPON UNLOCKED" card (top right) with the weapon's art. The results screen still
## lists the unlock again at the end of the arena.
func _make_unlock_toast() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.1, 0.88)
	sb.border_color = Color(1.0, 0.85, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p.position = Vector2(-450, 70)
	p.custom_minimum_size = Vector2(430, 96)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.modulate.a = 0.0
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(40, 76)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	var head := _label(15, Color(1.0, 0.85, 0.3))
	head.text = "NEW WEAPON UNLOCKED"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(head)
	var name_l := _label(24, Color.WHITE)
	name_l.name = "Name"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(name_l)
	var hint := _label(13, Color(0.7, 0.85, 1.0))
	hint.text = "Equip it in the Armory"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(hint)
	return p


func _on_weapon_unlocked(names: Array[String]) -> void:
	var icon := ""
	for w in Game.WEAPONS:
		if w["name"] == names[-1]:
			icon = w["icon"]
	(_unlock_toast.find_child("Name", true, false) as Label).text = ", ".join(names).to_upper()
	(_unlock_toast.find_child("Icon", true, false) as TextureRect).texture = load("res://assets/hq/weapons/%s.png" % icon) if icon != "" else null
	Sfx.play(&"levelup", -6.0, 0.0)
	if _toast_tw:
		_toast_tw.kill()
	# (`position` is in parent coordinates, so slide in to 450 px left of the right edge; in portrait
	# it sits below the status card + boss bar)
	var x := (_unlock_toast.get_parent() as Control).size.x - 450.0
	_unlock_toast.position = Vector2(x + 40.0, 170.0 if Layout.portrait else 70.0)
	_toast_tw = create_tween()
	_toast_tw.set_parallel()
	_toast_tw.tween_property(_unlock_toast, "modulate:a", 1.0, 0.2)
	_toast_tw.tween_property(_unlock_toast, "position:x", x, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tw.chain().tween_property(_unlock_toast, "modulate:a", 0.0, 0.6).set_delay(4.0)


# --- menus ---------------------------------------------------------------------------------------------

## Polled (not event-based) so the on-screen PAUSE button, which uses Input.action_press, works too.
func _check_pause() -> void:
	if Input.is_action_just_pressed("pause") and not _ended and not Controls.ignore_real_input and not Upgrades.choosing:
		if get_tree().paused:
			_resume()
		else:
			_pause()


func _pause() -> void:
	get_tree().paused = true
	_shake_btn.text = "SCREEN SHAKE: %s" % ("ON" if Game.screen_shake else "OFF")
	_pause_upgrades.text = _upgrade_summary()
	_pause_panel.show()
	(_pause_panel.find_child("Btn0", true, false) as Button).grab_focus()


## "Pilot level 6: Homing Missiles 2, Triple Shot 1, ..." for the pause menu.
func _upgrade_summary() -> String:
	var parts: Array[String] = []
	for id: StringName in Upgrades.CATALOG:
		if Upgrades.level_of(id) > 0:
			parts.append("%s %d" % [Upgrades.display_name(id), Upgrades.level_of(id)])
	for id: StringName in Upgrades.COMBOS:
		if Upgrades.level_of(id) > 0:
			parts.append("COMBO %s" % Upgrades.display_name(id).to_upper())
	var weapon_name: String = Game.weapon_info(mech.weapon if mech else Game.weapon)["name"]
	return "Level %d  -  %s\n%s" % [Upgrades.level, weapon_name,
		"Upgrades: " + ", ".join(parts) if not parts.is_empty() else "No upgrades yet - defeat enemies to level up"]


## Unlock announcement for results screens ("" when nothing new).
## Banks this run's Hangar scrap and says how much it was (results screens).
func _scrap_text() -> String:
	if not Game.scrap_enabled and Game.run_scrap <= 0.0:
		return ""
	var got := Game.bank_scrap()
	return "\n+%d SCRAP   (Hangar: %d)" % [got, Game.scrap]


func _unlock_text() -> String:
	if Game.new_unlocks.is_empty():
		return ""
	var t := "\nNEW WEAPON UNLOCKED: %s\n(equip it in the Armory)" % ", ".join(Game.new_unlocks).to_upper()
	Game.new_unlocks.clear()
	return t


func _resume() -> void:
	_pause_panel.hide()
	get_tree().paused = false


func _toggle_shake() -> void:
	Game.set_screen_shake(not Game.screen_shake)
	_shake_btn.text = "SCREEN SHAKE: %s" % ("ON" if Game.screen_shake else "OFF")


func _restart() -> void:
	if arena:
		Game.restart_arena()
	else:
		Game.to_test_range()


func _retry_boss() -> void:
	Game.retry_boss()


func _to_menu() -> void:
	Game.to_menu()


func _next() -> void:
	Game.next_arena()


func _show_game_over() -> void:
	if _ended:
		return
	if Upgrades.choosing:
		await level_menu.closed
	_ended = true
	_pause_panel.hide()
	if Game.is_endless():
		var best := Game.endless_best
		_over_stats.text = "Survived %d wave%s   (Best %d%s)\nLevel %d    Time %s    Kills %d%s" % [
			Game.endless_wave, "" if Game.endless_wave == 1 else "s", best,
			"  NEW RECORD!" if Game.endless_wave > Game.endless_best_at_start else "", Upgrades.level,
			_fmt_time(Game.run_time), Game.kills, _unlock_text() + _scrap_text()]
	else:
		_over_stats.text = "Level %d    Time %s    Kills %d%s" % [Upgrades.level, _fmt_time(Game.run_time), Game.kills,
			_scrap_text()]
	_retry_boss_btn.visible = Game.can_retry_boss()
	var retry := _over_panel.find_child("Btn0", true, false) as Button
	if not Game.is_endless():
		retry.text = "RETRY LEVEL" if _retry_boss_btn.visible else "RETRY"
	_over_panel.show()
	(_retry_boss_btn if _retry_boss_btn.visible else retry).grab_focus()
	get_tree().paused = true


func _show_victory() -> void:
	if _ended:
		return
	if Upgrades.choosing:
		await level_menu.closed
	_ended = true
	_win_stats.text = "Level %d    Time %s    Kills %d%s" % [Upgrades.level, _fmt_time(Game.run_time), Game.kills,
		_unlock_text() + _scrap_text()]
	_next_btn.visible = Game.has_next_arena()
	_win_panel.show()
	(_win_panel.find_child("Btn0" if _next_btn.visible else "Btn1", true, false) as Button).grab_focus()
	Sfx.play(&"levelup", -2.0, 0.0)
	get_tree().paused = true


func _fmt_time(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


# --- bars ----------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_check_pause()
	_t += delta
	if mech:
		_hp_shown = lerpf(_hp_shown, mech.hp / mech.max_hp, 1.0 - exp(-6.0 * delta))
	_bars.queue_redraw()
	_update_blackout(delta)


## BLACKOUT twist: fade the darkness in / out and keep the light pool on the mech.
func _update_blackout(delta: float) -> void:
	var want := 1.0 if Game.is_endless() and Game.endless_twist == &"blackout" and mech and not mech.dead else 0.0
	_blackout_k = move_toward(_blackout_k, want, delta * 0.8)
	_blackout.visible = _blackout_k > 0.0
	if not _blackout.visible:
		return
	var vp := _bars.size
	var mat := _blackout.material as ShaderMaterial
	mat.set_shader_parameter("center", _bars.get_viewport().get_canvas_transform() * mech.global_position)
	mat.set_shader_parameter("rect_size", vp)
	mat.set_shader_parameter("radius", minf(vp.x, vp.y) * 0.42)
	mat.set_shader_parameter("strength", _blackout_k)
	mat.set_shader_parameter("t", _t)


func _draw_bars() -> void:
	var c := _bars
	var font := ThemeDB.fallback_font
	var vp := c.size
	_draw_enemy_arrows(c, font, vp)
	if mech:
		var hp_frac := mech.hp / mech.max_hp
		# Low-HP warning vignette.
		if hp_frac < 0.3 and not mech.dead:
			var a := (0.3 - hp_frac) / 0.3 * (0.35 + 0.2 * sin(_t * 6.0))
			for i in 6:
				c.draw_rect(Rect2(Vector2.ZERO, vp).grow(-i * 8), Color(1, 0.05, 0.05, a * (1.0 - i / 6.0) * 0.5), false, 8.0)
		_draw_status(c, font)
	# Boss bar.
	var boss_alive: bool = is_instance_valid(boss) and not boss.dead
	# The objective line would just repeat "Destroy the <boss>" under the boss bar.
	_objective.visible = not boss_alive
	if boss_alive:
		var bar := boss_bar_rect()
		var col: Color = boss.get("accent")
		_text(font, Vector2(bar.position.x, bar.position.y - 7), "%s  -  PHASE %d" % [boss.get("boss_name"), boss.get("phase")], 15, col.lightened(0.3))
		c.draw_rect(bar.grow(3), Color(0, 0, 0, 0.7))
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(boss.hp / boss.max_hp, 0.0, 1.0), bar.size.y)), col)
		for k in [0.66, 0.33]:
			c.draw_line(bar.position + Vector2(bar.size.x * k, 0), bar.position + Vector2(bar.size.x * k, bar.size.y), Color(1, 1, 1, 0.7), 2.0)
		c.draw_rect(bar, Color(1, 1, 1, 0.6), false, 1.5)
	# Run info (top-right, below the touch buttons' row when they're visible).
	var place: String = arena.arena_name.to_upper() if arena else ({Game.GUN_RANGE: "WEAPON RANGE", Game.TUTORIAL: "TUTORIAL"}.get(get_tree().current_scene.scene_file_path, "TEST RANGE"))
	if Game.is_endless():
		place = "ENDLESS  WAVE %d  (BEST %d)" % [maxi(Game.endless_wave + 1, 1), Game.endless_best]
	var info := "%s   %s   KILLS %d" % [place, _fmt_time(Game.run_time), Game.kills]
	var iy := 134.0 if Controls.device == Controls.Device.TOUCH and not Layout.portrait else 28.0
	c.draw_string_outline(font, Vector2(vp.x - 420, iy), info, HORIZONTAL_ALIGNMENT_RIGHT, 400, 14, 5, Color(0, 0, 0, 0.8))
	c.draw_string(font, Vector2(vp.x - 420, iy), info, HORIZONTAL_ALIGNMENT_RIGHT, 400, 14, Color(0.8, 0.9, 1.0))
	# Difficulty tag under it (not in the ranges, where enemies don't scale).
	if arena:
		var d: Dictionary = Game.DIFFICULTIES[Game.difficulty]
		var tag := String(d["name"]).to_upper()
		c.draw_string_outline(font, Vector2(vp.x - 420, iy + 18), tag, HORIZONTAL_ALIGNMENT_RIGHT, 400, 13, 5, Color(0, 0, 0, 0.8))
		c.draw_string(font, Vector2(vp.x - 420, iy + 18), tag, HORIZONTAL_ALIGNMENT_RIGHT, 400, 13, d["color"])
		# Endless twist badge.
		if Game.is_endless() and Game.TWISTS.has(Game.endless_twist):
			var tw: Dictionary = Game.TWISTS[Game.endless_twist]
			var txt := "TWIST: %s" % tw["name"]
			c.draw_string_outline(font, Vector2(vp.x - 420, iy + 36), txt, HORIZONTAL_ALIGNMENT_RIGHT, 400, 13, 5, Color(0, 0, 0, 0.8))
			c.draw_string(font, Vector2(vp.x - 420, iy + 36), txt, HORIZONTAL_ALIGNMENT_RIGHT, 400, 13,
				Color(tw["color"], 0.75 + 0.25 * sin(_t * 3.0)))


func _text(font: Font, pos: Vector2, s: String, size: int, col: Color) -> void:
	_bars.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.8))
	_bars.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


# --- status panel ---------------------------------------------------------------------------------------

## Compact pilot card (top-left):
##   [LV badge, ring = XP]  HP bar (shield diamonds inside, number on the right)
##                          HEAT bar (Cone / Nova cost ticks light up when affordable)
##                          OVERDRIVE bar (pulses + READY when full)
##   weapon name            repair kits, boost dial, beam dial  (desktop / gamepad only - on touch
##                                                               screens the buttons show these)
func _draw_status(c: Control, font: Font) -> void:
	var touch := Controls.device == Controls.Device.TOUCH
	var o := Vector2(12, 10)
	var size := Vector2(360, 96 if touch else 104)
	var cut := 12.0
	var frame := PackedVector2Array([o, o + Vector2(size.x - cut, 0), o + Vector2(size.x, cut), o + size,
		o + Vector2(cut, size.y), o + Vector2(0, size.y - cut)])
	c.draw_colored_polygon(frame, Color(0.02, 0.05, 0.11, 0.74))
	var edge := frame.duplicate()
	edge.append(frame[0])
	c.draw_polyline(edge, Color(0.35, 0.75, 1.0, 0.45), 1.5, true)
	c.draw_line(o + Vector2(10, 3), o + Vector2(size.x - cut - 6, 3), Color(0.35, 0.75, 1.0, 0.25), 2.0)

	# Level badge: the ring fills with XP toward the next level.
	var bc := o + Vector2(44, 44)
	var xp_col := Color(0.35, 1.0, 0.8)
	c.draw_circle(bc, 30.0, Color(0.01, 0.03, 0.07, 0.95))
	c.draw_arc(bc, 35.0, 0.0, TAU, 48, Color(xp_col, 0.15), 5.0, true)
	var xf := Upgrades.xp_fraction()
	if xf > 0.0:
		c.draw_arc(bc, 35.0, -PI / 2, -PI / 2 + TAU * xf, 48, xp_col.lerp(Color.WHITE, 0.15 + 0.15 * sin(_t * 4.0)), 5.0, true)
	c.draw_arc(bc, 30.0, 0.0, TAU, 48, Color(xp_col, 0.5), 1.5, true)
	c.draw_string(font, bc + Vector2(-30, -9), "LV", HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color(xp_col, 0.8))
	var lv := str(Upgrades.level)
	c.draw_string_outline(font, bc + Vector2(-30, 17), lv, HORIZONTAL_ALIGNMENT_CENTER, 60, 26, 4, Color(0, 0, 0, 0.8))
	c.draw_string(font, bc + Vector2(-30, 17), lv, HORIZONTAL_ALIGNMENT_CENTER, 60, 26, Color.WHITE)

	var x0 := o.x + 90.0
	var bw := size.x - 104.0
	# HP (lagging red chunk shows recent damage; shield charges sit inside the bar).
	var hp_frac := clampf(mech.hp / mech.max_hp, 0.0, 1.0)
	var bar := Rect2(x0, o.y + 12, bw, 20)
	c.draw_rect(bar, Color(0, 0, 0, 0.65))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_hp_shown, 0.0, 1.0), bar.size.y)), Color(1.0, 0.35, 0.3))
	var hp_col := Color(0.35, 1.0, 0.5) if hp_frac > 0.3 else Color(1.0, 0.4, 0.3).lerp(Color.WHITE, 0.25 + 0.25 * sin(_t * 8.0))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp_frac, bar.size.y)), hp_col)
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp_frac, 5)), Color(1, 1, 1, 0.18))
	for i in range(1, 10):
		var sx := bar.position.x + bar.size.x * i / 10.0
		c.draw_line(Vector2(sx, bar.position.y), Vector2(sx, bar.end.y), Color(0, 0, 0, 0.3), 1.0)
	if mech.shield_charges > 0:
		var sc := Color(0.55, 0.9, 1.0, 0.8 + 0.2 * sin(_t * 5.0))
		c.draw_rect(bar.grow(2), sc, false, 2.0)
		for i in mech.shield_charges:
			var p := bar.position + Vector2(12 + i * 14, 10)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(5, 0), p + Vector2(0, 6),
				p + Vector2(-5, 0)]), Color(0.9, 0.97, 1.0))
	c.draw_rect(bar, Color(1, 1, 1, 0.45), false, 1.5)
	var hp_txt := "%d / %d" % [ceili(mech.hp), roundi(mech.max_hp)]
	c.draw_string_outline(font, Vector2(bar.position.x, bar.end.y - 5), hp_txt, HORIZONTAL_ALIGNMENT_RIGHT, bar.size.x - 6,
		13, 4, Color(0, 0, 0, 0.85))
	c.draw_string(font, Vector2(bar.position.x, bar.end.y - 5), hp_txt, HORIZONTAL_ALIGNMENT_RIGHT, bar.size.x - 6, 13,
		Color.WHITE)

	# Heat, with the Cone / Nova costs marked.
	bar = Rect2(x0, o.y + 38, bw, 13)
	c.draw_rect(bar, Color(0, 0, 0, 0.65))
	var heat_frac := mech.heat / mech.heat_max
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * heat_frac, bar.size.y)),
		Color(1.0, 0.45, 0.1).lerp(Color(1, 0.85, 0.3), heat_frac))
	for m in [[mech.cone_cost, "CONE"], [mech.nova_cost, "NOVA"]]:
		var mx: float = bar.position.x + bar.size.x * m[0] / mech.heat_max
		var ok: bool = mech.heat >= m[0]
		c.draw_line(Vector2(mx, bar.position.y - 2), Vector2(mx, bar.end.y + 2), Color(1, 1, 1, 0.95 if ok else 0.35), 2.0)
		if ok:
			c.draw_colored_polygon(PackedVector2Array([Vector2(mx - 4, bar.position.y - 6), Vector2(mx + 4, bar.position.y - 6),
				Vector2(mx, bar.position.y - 1)]), Color(1.0, 0.85, 0.4))
	c.draw_rect(bar, Color(1, 1, 1, 0.35), false, 1.0)
	_bar_label(font, bar, "HEAT", Color(1.0, 0.8, 0.55))

	# Overdrive.
	bar = Rect2(x0, o.y + 56, bw, 13)
	var od_active := mech.overdrive_left > 0.0
	var od_ready := mech.overdrive_meter >= 100.0 and not od_active
	c.draw_rect(bar, Color(0, 0, 0, 0.65))
	var od_frac := mech.overdrive_left / mech.overdrive_time if od_active else mech.overdrive_meter / 100.0
	var od_col := Color(1.0, 0.85, 0.25)
	if od_ready:
		od_col = od_col.lerp(Color.WHITE, 0.5 + 0.5 * sin(_t * 10.0))
		c.draw_rect(bar.grow(2), Color(1.0, 0.85, 0.3, 0.4 + 0.3 * sin(_t * 10.0)), false, 2.0)
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * od_frac, bar.size.y)), od_col)
	c.draw_rect(bar, Color(1, 1, 1, 0.35), false, 1.0)
	_bar_label(font, bar, "OVERDRIVE", Color(1.0, 0.92, 0.6))
	var od_txt := "READY" if od_ready else ("%.1fs" % mech.overdrive_left if od_active else "")
	if od_txt != "":
		c.draw_string_outline(font, Vector2(bar.position.x, bar.end.y - 1), od_txt, HORIZONTAL_ALIGNMENT_RIGHT, bar.size.x - 4,
			10, 3, Color(0, 0, 0, 0.9))
		c.draw_string(font, Vector2(bar.position.x, bar.end.y - 1), od_txt, HORIZONTAL_ALIGNMENT_RIGHT, bar.size.x - 4, 10,
			Color.WHITE)

	# Bottom row: equipped weapon (+ kits / boost / beam on keyboard & gamepad).
	var row_y := o.y + size.y - 13
	var wname := String(Game.weapon_info(mech.weapon)["name"]).to_upper()
	_text(font, Vector2(x0, row_y), wname, 11, Color(0.75, 0.85, 1.0))
	if touch:
		return
	var cy := row_y - 9
	var right := x0 + bw
	# Beam Cannon dial.
	var bf := mech.beam.ready_fraction() if mech.beam else 1.0
	_dial(Vector2(right - 9, cy), bf, Color(0.45, 0.85, 1.0), "BEAM", font)
	# Boost dial.
	_dial(Vector2(right - 41, cy), mech.boost_ready_fraction(), Color(0.4, 0.95, 1.0), "BOOST", font)
	# Repair kits.
	for i in mech.repair_charges_max:
		var r := Rect2(right - 72 - (mech.repair_charges_max - 1 - i) * 16 - 6, cy - 6, 12, 12)
		var have := i < mech.repair_charges
		c.draw_rect(r, Color(0.35, 1.0, 0.5) if have else Color(1, 1, 1, 0.08))
		c.draw_rect(r, Color(1, 1, 1, 0.45), false, 1.0)
		if have:
			c.draw_rect(Rect2(r.position + Vector2(5, 2), Vector2(2, 8)), Color(0.05, 0.3, 0.1))
			c.draw_rect(Rect2(r.position + Vector2(2, 5), Vector2(8, 2)), Color(0.05, 0.3, 0.1))


## Small label drawn inside the left end of a thin bar.
func _bar_label(font: Font, bar: Rect2, s: String, col: Color) -> void:
	_bars.draw_string_outline(font, Vector2(bar.position.x + 4, bar.end.y - 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3,
		Color(0, 0, 0, 0.9))
	_bars.draw_string(font, Vector2(bar.position.x + 4, bar.end.y - 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)


## Cooldown dial (fills clockwise; bright when ready) with a tiny caption underneath.
func _dial(p: Vector2, frac: float, col: Color, caption: String, font: Font) -> void:
	var ready := frac >= 1.0
	_bars.draw_circle(p, 8.0, Color(0, 0, 0, 0.6))
	_bars.draw_arc(p, 8.0, -PI / 2, -PI / 2 + TAU * clampf(frac, 0.0, 1.0), 24,
		col.lerp(Color.WHITE, 0.3 + 0.2 * sin(_t * 6.0)) if ready else Color(1.0, 0.6, 0.2), 3.0, true)
	if ready:
		_bars.draw_circle(p, 3.0, col)
	_bars.draw_string(font, p + Vector2(-20, 17), caption, HORIZONTAL_ALIGNMENT_CENTER, 40, 8, Color(col, 0.75))


## Off-screen enemy arrows: every robot outside the view gets a small arrow at the screen edge, pointing
## at it, in its signature colour (bosses: bigger, in their accent colour, with a ring). When only a
## few robots are left, the arrows grow, pulse and show the distance, so the last stragglers of a wave
## are quick to find.
const ARROW_COLORS := {
	&"Chaser": Color(1.0, 0.55, 0.3), &"Shooter": Color(1.0, 0.4, 0.3), &"HeavyTank": Color(1.0, 0.6, 0.2),
	&"BladeStriker": Color(1.0, 0.35, 0.85), &"AegisGuardian": Color(0.35, 0.9, 1.0), &"Lancer": Color(0.5, 1.0, 0.7),
	&"Hornet": Color(0.45, 0.65, 1.0), &"Coil": Color(1.0, 0.4, 0.9), &"Widow": Color(0.65, 1.0, 0.2),
	&"Cinder": Color(0.55, 0.8, 1.0), &"Bastion": Color(0.3, 1.0, 0.6), &"Tidebreaker": Color(1.0, 0.55, 0.35),
	&"MagmaCrawler": Color(1.0, 0.45, 0.15), &"Anvil": Color(0.8, 0.82, 0.88), &"Slagspitter": Color(1.0, 0.8, 0.25),
}
const ARROW_MARGIN := 30.0
## Screen area of the status card (top-left); arrows slide past it.
const STATUS_CARD := Rect2(0, 0, 390, 126)
## At or below this many robots left, arrows switch to "straggler" mode (bigger, pulsing, distance).
const ARROW_FEW := 3


func _draw_enemy_arrows(c: Control, font: Font, vp: Vector2) -> void:
	if not mech or mech.dead:
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	var alive := 0
	for e in enemies:
		if e is Enemy and not e.dead:
			alive += 1
	var few := alive <= ARROW_FEW
	var xf := c.get_viewport().get_canvas_transform()
	var center := vp / 2.0
	var half := center - Vector2.ONE * ARROW_MARGIN
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	for e in enemies:
		if not (e is Enemy) or e.dead:
			continue
		var p: Vector2 = xf * e.global_position
		var r: float = e.hit_radius * xf.get_scale().x
		if Rect2(Vector2.ZERO, vp).grow(-r * 0.5).has_point(p):
			continue  # on screen
		var dir := (p - center).normalized()
		# Where the ray from the screen centre leaves the (inset) screen rectangle.
		var t := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
		var at := center + dir * t
		# Keep clear of the status card (top-left): slide along the edge past it.
		if STATUS_CARD.has_point(at):
			if at.x <= ARROW_MARGIN + 1.0:
				at.y = STATUS_CARD.end.y + 12.0
			else:
				at.x = STATUS_CARD.end.x + 12.0
		var is_boss := e is WardenBoss
		var col: Color = e.get("accent") if is_boss else ARROW_COLORS.get(e.get_script().get_global_name(), Color(1.0, 0.4, 0.35))
		var size := 24.0 if is_boss else (19.0 if few else 14.0)
		var alpha := 0.65 + 0.35 * pulse if few or is_boss else 0.75
		if few:
			size += 3.0 * pulse
		var side := dir.orthogonal()
		var tip := at + dir * size
		var tri := PackedVector2Array([tip, at - dir * size * 0.5 + side * size * 0.75, at - dir * size * 0.2,
			at - dir * size * 0.5 - side * size * 0.75])
		var outline := tri.duplicate()
		outline.append(tip)
		# Dark backing so it reads on bright maps (snow, sand) too.
		c.draw_circle(at + dir * size * 0.2, size * 1.05, Color(0.02, 0.03, 0.08, 0.45 * alpha))
		c.draw_colored_polygon(tri, Color(col, alpha))
		c.draw_polyline(outline, Color(0, 0, 0, 0.7 * alpha), 2.0, true)
		if is_boss:
			c.draw_arc(at, size * 1.35, 0.0, TAU, 24, Color(col, 0.4 + 0.3 * pulse), 2.0, true)
		if few or is_boss:
			var m := "%dm" % roundi(mech.global_position.distance_to(e.global_position) / 10.0)
			var tp := at - dir * (size + 20.0) + Vector2(-24, 6)
			c.draw_string_outline(font, tp, m, HORIZONTAL_ALIGNMENT_CENTER, 48, 15, 5, Color(0, 0, 0, 0.85))
			c.draw_string(font, tp, m, HORIZONTAL_ALIGNMENT_CENTER, 48, 15, Color(col.lightened(0.4), 1.0))


## Portrait: the objective line drops below the status card (the top row is full there).
func _on_layout(portrait: bool) -> void:
	_objective.position.y = 122.0 if portrait else 14.0
	if _banner_box and _banner_box.modulate.a > 0.0:
		_place_banner.call_deferred()


## Boss health bar: centred right under the top edge, between the status card (left) and the run info
## (right; on touch screens the ability buttons). The name + phase sit just above it.
## Portrait: full width, just under the status card + run info.
func boss_bar_rect() -> Rect2:
	var vp := _bars.size
	if Layout.portrait:
		return Rect2(20.0, 140.0, vp.x - 40.0, 14.0)
	var right_reserve := 460.0 if Controls.device == Controls.Device.TOUCH else 360.0
	var half := minf(vp.x / 2.0 - 405.0, vp.x / 2.0 - right_reserve)
	var w := clampf(half * 2.0, 300.0, 640.0)
	return Rect2(vp.x / 2.0 - w / 2.0, 30.0, w, 14.0)


## HUD canvas size (falls back to the viewport before the first layout pass).
func _screen_size() -> Vector2:
	return _bars.size if _bars.size.x > 0.0 else get_viewport().get_visible_rect().size
