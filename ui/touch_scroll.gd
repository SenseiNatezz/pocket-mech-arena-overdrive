class_name TouchScroll
extends Node
## Finger drag-scrolling for a ScrollContainer whose content is mostly buttons (the Hangar page): on a phone
## nearly every swipe starts on a card, and Godot's own ScrollContainer only drags from the gaps, so the page
## felt stuck. Add as a child of the ScrollContainer.
##
## Works on the mouse events Godot emulates from touch (InputEvent.DEVICE_ID_EMULATION), so a real mouse on PC
## is untouched (it keeps the wheel and the scroll bar). A press that moves more than DEADZONE px becomes a
## drag: the button under the finger gets a pointer-left + release far off-screen, so it never fires (a swipe
## can't BUY anything), every later finger move scrolls the page, and letting go flings it with momentum.
## A press that stays still is an ordinary tap.

const DEADZONE := 12.0
## Momentum decay per second after a fling (fraction of speed kept).
const FRICTION := 0.04
const MAX_FLING := 4500.0
const FAR := Vector2(-100000, -100000)
## Device id of the cancel events this node pushes itself (so it ignores them).
const OWN_DEVICE := 7731

var _scroll: ScrollContainer
var _down := false
var _dragging := false
var _start := Vector2.ZERO
var _speed := 0.0      # px/s of content, + = scrolling down the page
var _last_move_t := 0


func _ready() -> void:
	_scroll = get_parent() as ScrollContainer
	_follow = _scroll.follow_focus
	set_process(false)


## The ScrollContainer's own follow_focus (keyboard / gamepad focus scrolls into view). A tap also moves focus,
## and following it made the page jump under the finger, so it is off while the last input was touch.
var _follow := false


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_scroll.follow_focus = _follow
		return
	if event.device != InputEvent.DEVICE_ID_EMULATION or not _scroll.is_visible_in_tree():
		return
	_scroll.follow_focus = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not _scroll.get_global_rect().has_point(event.position):
				return
			_down = true
			_dragging = false
			_start = event.position
			_speed = 0.0
			set_process(false)
		elif _down:
			_down = false
			if _dragging:
				_dragging = false
				get_viewport().set_input_as_handled()
				# A finger that stopped before lifting doesn't fling.
				if Time.get_ticks_msec() - _last_move_t > 90:
					_speed = 0.0
				set_process(absf(_speed) > 30.0)
	elif event is InputEventMouseMotion and _down:
		if not _dragging and event.position.distance_to(_start) > DEADZONE:
			_dragging = true
			_cancel_press()
		if _dragging:
			get_viewport().set_input_as_handled()
			_move(-event.relative.y)
			var now := Time.get_ticks_msec()
			var dt := clampf((now - _last_move_t) / 1000.0, 1.0 / 120.0, 0.1)
			_speed = clampf(lerpf(_speed, -event.relative.y / dt, 0.5), -MAX_FLING, MAX_FLING)
			_last_move_t = now


func _process(delta: float) -> void:
	_speed *= pow(FRICTION, delta)
	if absf(_speed) < 30.0 or not _move(_speed * delta):
		set_process(false)


## Scrolls the content by `dy` px; false once it hits the top or bottom.
func _move(dy: float) -> bool:
	var bar := _scroll.get_v_scroll_bar()
	var before := bar.value
	bar.value = clampf(before + dy, bar.min_value, bar.max_value - bar.page)
	return not is_equal_approx(bar.value, before)


## The press already went to the button (or card) under the finger: tell it the pointer left and was released
## out there, so it un-presses without emitting `pressed`, and the viewport lets go of it.
func _cancel_press() -> void:
	var mm := InputEventMouseMotion.new()
	mm.device = OWN_DEVICE
	mm.position = FAR
	mm.global_position = FAR
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(mm, true)
	var mb := InputEventMouseButton.new()
	mb.device = OWN_DEVICE
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = false
	mb.position = FAR
	mb.global_position = FAR
	get_viewport().push_input(mb, true)
