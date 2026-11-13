class_name UiFont
extends RefCounted
## The game's lettering, "Mecha Anime" style (picked 2026-11-12): heavy Japanese poster type for the big words
## (titles, banners, mech / boss names, big numbers) with small katakana / kanji over them, like a mecha anime
## title card, and a condensed sans for everything else.
##   DISPLAY  Dela Gothic One       big words + the Japanese labels (it has the kana and kanji)
##   BODY     Saira Condensed SemiBold, also the project default (project.godot gui/theme/custom_font), so every
##            Label / Button and every draw_string that uses ThemeDB.fallback_font gets it with no override
##   MEDIUM / BOLD / XBOLD   the other Saira Condensed weights
## Both SIL OFL, unmodified, see assets/fonts/OFL.txt. The lobby (ui/lobby_kit.gd) uses the same fonts.
## Saira Condensed has no Japanese, so Japanese text must always be drawn with DISPLAY.

const DISPLAY := preload("res://assets/fonts/DelaGothicOne-Regular.ttf")
const MEDIUM := preload("res://assets/fonts/SairaCondensed-Medium.ttf")
const BODY := preload("res://assets/fonts/SairaCondensed-SemiBold.ttf")
const BOLD := preload("res://assets/fonts/SairaCondensed-Bold.ttf")
const XBOLD := preload("res://assets/fonts/SairaCondensed-ExtraBold.ttf")

## The title-card look: the word in its colour on a dark outline, with a hard offset "print" shadow in this red.
const SHADOW := Color(0.91, 0.26, 0.18)
const INK := Color(0.02, 0.03, 0.07)
## The small Japanese labels.
const KATA_COLOR := Color(1.0, 0.45, 0.36)

## Japanese labels for the big words. Loanwords in katakana; kanji where a mecha anime would use it
## (出撃 "sortie" on LAUNCH, 格納庫 the hangar bay, 機体大破 "unit destroyed").
const KATA := {
	# lobby / pages
	"LAUNCH": "出撃", "CAMPAIGN": "キャンペーン", "ENDLESS": "エンドレス", "HANGAR": "格納庫", "ARMORY": "武器庫",
	"CUSTOMIZE": "カスタマイズ", "WEAPON RANGE": "射撃場", "SETTINGS": "設定", "SELECT ARENA": "作戦選択",
	"DIFFICULTY": "難易度", "CONTROLS": "操作設定", "LOADOUT": "装備", "PAUSED": "一時停止",
	"ARENA CLEARED": "作戦成功", "MECH DESTROYED": "機体大破", "LEVEL UP!": "レベルアップ",
	# mechs
	"NIMBUS-07": "ニンバス", "GRIFFIN": "グリフィン", "TUSKER": "タスカー", "TEMPEST": "テンペスト",
	"FROSTBLADE": "フロストブレード", "SOLSTICE": "ソルスティス", "AURORA": "オーロラ", "RAVEN CLAW": "レイヴンクロー",
	# bosses
	"WARDEN": "ウォーデン", "RONIN": "浪人", "SHOGUN": "将軍", "SERAPH": "セラフ", "VULCAN": "ヴァルカン",
	"SCARAB": "スカラベ", "ZENITH": "ゼニス",
	# banners
	"BOSS WAVE": "ボスウェーブ", "WAVE CLEARED": "ウェーブクリア", "WAVE BROKEN": "増援接近", "WAVE": "ウェーブ",
	"ZONE CLEARED": "ゾーンクリア", "BOSS DESTROYED": "ボス撃破", "FLYING": "飛行モード", "WALKING": "歩行モード",
	"OUT OF FUEL": "燃料切れ", "RIVAL DEFEATED": "ライバル撃破", "HOSTILES INBOUND": "敵機接近", "WARNING": "警告", "ZONE LOCKED": "区域封鎖",
	"TWIST": "突発",
}

static var _tracked := {}


## The Japanese label for `text`: an exact match first, then the longest key it starts with ("WAVE 3 / 5" ->
## ウェーブ, "WARDEN MK-II" -> ウォーデン, "BOSS WAVE 10" -> ボスウェーブ). "" when there is none.
static func kata(text: String) -> String:
	var t := text.strip_edges().to_upper()
	if KATA.has(t):
		return KATA[t]
	# "RIVAL  GRIFFIN" -> ライバル・グリフィン
	if t.begins_with("RIVAL ") and not t.begins_with("RIVAL DEFEATED"):
		var who := kata(t.trim_prefix("RIVAL").strip_edges())
		return "ライバル・" + who if who != "" else "ライバル"
	var best := ""
	for k: String in KATA:
		if k.length() > best.length() and t.begins_with(k) and (t.length() == k.length() or not _is_word_char(t[k.length()])):
			best = k
	return KATA[best] if best != "" else ""


static func _is_word_char(c: String) -> bool:
	return (c >= "A" and c <= "Z") or (c >= "0" and c <= "9")


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


## A small Japanese label (letter-spaced) drawn in code, baseline at `pos`.
## `outline` -1 = the usual thin one, 0 for dark text on a bright fill.
static func draw_kata(ci: CanvasItem, pos: Vector2, s: String, fs: int, col := KATA_COLOR,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := -1) -> void:
	if s == "":
		return
	var f := kata_font(fs)
	if outline < 0:
		outline = kata_outline(fs)
	if outline > 0:
		ci.draw_string_outline(f, pos, s, align, width, fs, outline, Color(INK, 0.8 * col.a))
	ci.draw_string(f, pos, s, align, width, fs, col)


## Kanji turn to blobs under a thick outline, so the labels' outline stays thin.
static func kata_outline(fs: int) -> int:
	return clampi(roundi(fs * 0.2), 2, 4)


## The letter-spaced display font the Japanese labels use (for measuring them).
static func kata_font(fs: int) -> Font:
	return tracked(DISPLAY, maxi(2, roundi(fs * 0.35)))


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


## A page title: `l` becomes display text and gets its Japanese label as a child just right of the words
## (vertically centred on them). Call again after changing l.text.
static func page_title(l: Label, fs: int, col := Color.WHITE) -> void:
	display_label(l, fs, col)
	var k: Label = l.get_node_or_null(^"Kata")
	if k == null:
		k = kata_label("", maxi(13, roundi(fs * 0.42)))
		k.name = "Kata"
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		k.anchor_top = 0.0
		k.anchor_bottom = 1.0
		l.add_child(k)
	k.text = kata(l.text)
	var w := DISPLAY.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# Measured from the start of the words: the left edge, or the middle for a centred title.
	var centred := l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
	k.anchor_left = 0.5 if centred else 0.0
	k.anchor_right = k.anchor_left
	k.offset_left = (w / 2.0 if centred else w) + roundf(fs * 0.4)
	k.offset_right = k.offset_left + 220.0
	k.offset_top = -roundf(fs * 0.22)
	k.offset_bottom = -roundf(fs * 0.22)


## A small Japanese label as a Label node (centred), for screens built from nodes.
static func kata_label(s: String, fs: int, col := KATA_COLOR) -> Label:
	var l := Label.new()
	l.text = s
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", kata_font(fs))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(INK, 0.8))
	l.add_theme_constant_override("outline_size", kata_outline(fs))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
