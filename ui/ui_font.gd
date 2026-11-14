class_name UiFont
extends RefCounted
## The game's lettering (picked 2026-11-13): Anta, armour-plate letters with cut corners, for the big words
## (titles, banners, mech / boss names, big numbers) drawn title-card style, and a condensed sans for
## everything else.
##   DISPLAY  Anta                     big words
##   BODY     Saira Condensed SemiBold, also the project default (project.godot gui/theme/custom_font), so every
##            Label / Button and every draw_string that uses ThemeDB.fallback_font gets it with no override
##   MEDIUM / BOLD / XBOLD   the other Saira Condensed weights
## Both SIL OFL, unmodified, see assets/fonts/OFL.txt. The lobby (ui/lobby_kit.gd) uses the same fonts.

const DISPLAY := preload("res://assets/fonts/Anta-Regular.ttf")
const MEDIUM := preload("res://assets/fonts/SairaCondensed-Medium.ttf")
const BODY := preload("res://assets/fonts/SairaCondensed-SemiBold.ttf")
const BOLD := preload("res://assets/fonts/SairaCondensed-Bold.ttf")
const XBOLD := preload("res://assets/fonts/SairaCondensed-ExtraBold.ttf")

## The title-card look: the word in its colour on a dark outline, with a hard offset "print" shadow in this red.
const SHADOW := Color(0.91, 0.26, 0.18)
const INK := Color(0.02, 0.03, 0.07)

static var _tracked := {}


## `font` with `px` extra pixels between letters.
static func tracked(font: Font, px: int) -> Font:
	var key := "%d:%d" % [font.get_instance_id(), px]
	if not _tracked.has(key):
		var v := FontVariation.new()
		v.base_font = font
		v.spacing_glyph = px
		_tracked[key] = v
	return _tracked[key]


## The shadow offset and outline width for display text at size `fs`.
static func shadow_offset(fs: int) -> float:
	return maxf(2.0, roundf(fs * 0.075))


static func outline_size(fs: int) -> int:
	return maxi(3, roundi(fs * 0.13))


## Big display text drawn in code: hard offset shadow, dark outline, then the fill. `shadow` with alpha 0 = no
## offset shadow (dark text on a bright button).
static func draw_display(ci: CanvasItem, pos: Vector2, s: String, fs: int, col: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, shadow := SHADOW) -> void:
	var ol := outline_size(fs)
	if shadow.a > 0.0:
		var sp := pos + Vector2.ONE * shadow_offset(fs)
		var sc := Color(shadow, shadow.a * col.a)
		ci.draw_string_outline(DISPLAY, sp, s, align, width, fs, ol, sc)
		ci.draw_string(DISPLAY, sp, s, align, width, fs, sc)
	ci.draw_string_outline(DISPLAY, pos, s, align, width, fs, ol, Color(INK, 0.92 * col.a))
	ci.draw_string(DISPLAY, pos, s, align, width, fs, col)


## Turns a Label into display text: font, size, colour, dark outline and the hard offset shadow.
static func display_label(l: Label, fs: int, col: Color, shadow := SHADOW) -> void:
	l.add_theme_font_override("font", DISPLAY)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(INK, 0.95))
	l.add_theme_constant_override("outline_size", outline_size(fs))
	l.add_theme_color_override("font_shadow_color", shadow)
	var off := int(shadow_offset(fs))
	l.add_theme_constant_override("shadow_offset_x", off)
	l.add_theme_constant_override("shadow_offset_y", off)
	l.add_theme_constant_override("shadow_outline_size", outline_size(fs))


## A page title (Hangar, Armory, Customize, Controls): display text in white. Call again after changing l.text.
static func page_title(l: Label, fs: int, col := Color.WHITE) -> void:
	display_label(l, fs, col)
