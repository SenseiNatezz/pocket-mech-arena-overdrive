extends Node
## Hangar touch-scroll test (ui/touch_scroll.gd), with real touch events (emulated to mouse like a phone):
##   godot --headless --path . -- --temp-save --scrap=40000 --menu-page=7 --attach=res://tools/hangar_scroll_test.gd
## 1. a 160 px swipe that STARTS on the ARROWHEAD card scrolls the page and does not buy / select it
## 2. a fling keeps the page moving after the finger lifts
## 3. a plain tap on the card (back at the top) still buys and selects it
## -> "HANGAR SCROLL TEST OK (0 failed)"

var _fails := 0


func _ready() -> void:
	if not get_parent().has_method("_refresh_lobby"):
		queue_free()
		return
	await get_tree().create_timer(1.5).timeout
	var page: HangarPage = get_tree().root.find_children("*", "HangarPage", true, false)[0]
	var scroll: ScrollContainer = page.get("_scroll")
	var card: Control = (page.get("_chassis_btns") as Dictionary)[&"striker"]
	var bar := scroll.get_v_scroll_bar()
	var scrap0 := Game.scrap
	_check("page is long enough to scroll (%d px)" % (bar.max_value - bar.page), bar.max_value - bar.page > 400.0)

	# 1. Swipe up 160 page px (8 steps of 20), starting on the card. Steps are converted to screen px: the
	# headless window is tiny, so 1 screen px is many page px.
	var center := card.get_global_rect().get_center()
	var step := get_viewport().get_screen_transform().basis_xform(Vector2(0, -20))
	await _touch(_screen(center), true)
	for i in 8:
		await _drag(_screen(center) + step * (i + 1), step)
	await _touch(_screen(center) + step * 8, false)
	var after_swipe := bar.value
	_check("a 160 px swipe on a card scrolls the page by the same amount (%d px)" % after_swipe,
		absf(after_swipe - 160.0) < 30.0)
	_check("the swipe did not buy or select the card", Game.chassis == &"standard" and Game.scrap == scrap0)

	# 2. Fling: the page keeps going a little after the finger lifts.
	await get_tree().create_timer(0.5).timeout
	_check("the fling carried on after release (%d -> %d px)" % [after_swipe, bar.value], bar.value > after_swipe + 20.0)

	# 3. Back to the top, then a still tap on the card buys it.
	bar.value = 0
	await get_tree().process_frame
	var at := _screen(card.get_global_rect().get_center())
	await _touch(at, true)
	await _touch(at, false)
	await get_tree().process_frame
	_check("a tap still buys + selects the card", Game.chassis == &"striker" and Game.scrap == scrap0 - 2500)

	print("HANGAR SCROLL TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails else 0)


func _screen(p: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * p


func _touch(p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = p
	e.pressed = down
	Input.parse_input_event(e)
	await get_tree().process_frame
	await get_tree().process_frame


func _drag(p: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = p
	e.relative = rel
	Input.parse_input_event(e)
	await get_tree().process_frame


func _check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1
