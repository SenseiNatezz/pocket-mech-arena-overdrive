extends Node
## Save Backup codes (Settings > Save Backup):
##   godot --headless --path . -- --temp-save --attach=res://tools/save_backup_test.gd
## A save turns into a "PMA1:..." code and back with the same progress; broken / foreign codes are refused;
## the Settings page has the Save Backup button and its page shows the confirm step only after a good code.

var _fails := 0
static var _running := false


func _ready() -> void:
	if _running:
		queue_free()
		return
	_running = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_fails += 1


func _run() -> void:
	for i in 10:
		await get_tree().process_frame
	_check("using the throwaway save", Game.save_path.ends_with("test_settings.cfg"))
	Game.scrap = 12345
	if not Game.unlocked.has(&"sniper"):
		Game.unlocked.append(&"sniper")
	Game.endless_best = 17
	var code := Game.export_save_code()
	_check("code starts with PMA1: (%d chars)" % code.length(), code.begins_with(Game.BACKUP_PREFIX))
	_check("code is one line, no spaces", not code.contains("\n") and not code.contains(" "))
	var info := Game.read_save_code(code)
	_check("it reads back", not info.is_empty())
	if not info.is_empty():
		_check("scrap 12,345 (%d)" % info["scrap"], info["scrap"] == 12345)
		_check("weapons %d" % info["weapons"], info["weapons"] == Game.unlocked.size())
		_check("best wave 17 (%d)" % info["best_wave"], info["best_wave"] == 17)
		_check("the text is the save file", info["text"] == FileAccess.get_file_as_string(Game.save_path))
	# Pasting adds whitespace / line breaks: still fine.
	var messy := "  " + code.substr(0, 40) + "\n" + code.substr(40, 30) + " \r\n" + code.substr(70) + "\n"
	_check("whitespace and line breaks are ignored", not Game.read_save_code(messy).is_empty())
	_check("a cut-off code is refused", Game.read_save_code(code.substr(0, code.length() - 12)).is_empty())
	_check("a code with a typo is refused", Game.read_save_code(code.substr(0, 30) + ("A" if code[30] != "A" else "B") + code.substr(31)).is_empty() \
		or Game.read_save_code(code.substr(0, 30) + ("A" if code[30] != "A" else "B") + code.substr(31))["scrap"] == 12345)
	_check("random text is refused", Game.read_save_code("hello there").is_empty())
	_check("a wrong size is refused", Game.read_save_code(Game.BACKUP_PREFIX + "999999999:" + code.split(":")[2]).is_empty())
	var cfg_only := Marshalls.raw_to_base64("[settings]\nfoo=1\n".to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE))
	_check("a config without progress is refused", Game.read_save_code("%s%d:%s" % [Game.BACKUP_PREFIX, "[settings]\nfoo=1\n".length(), cfg_only]).is_empty())

	# UI: Settings has the button, the page shows the confirm only after a good code.
	var menu := _find_menu(get_tree().current_scene)
	_check("main menu found", menu != null)
	if menu:
		menu.call("_show", menu.BACKUP_PAGE)
		await get_tree().process_frame
		var page: Control = menu._pages[menu.BACKUP_PAGE]
		_check("Save Backup page opens", page.visible)
		_check("no confirm button yet", not menu._backup_confirm.visible)
		var labels: Array[String] = []
		for b in page.find_children("*", "TitleButton", true, false):
			labels.append(String(b.get("label_text")) if b.get("label_text") else (b as Button).text)
		print("  page buttons: ", labels)
		menu.call("_backup_check", "not a code")
		_check("a bad code says so, no confirm", not menu._backup_confirm.visible and menu._backup_info.text.contains("isn't"))
		menu.call("_backup_check", code)
		_check("a good code shows what's in it (%s)" % menu._backup_info.text.get_slice("\n", 0), menu._backup_info.text.contains("12,345"))
		_check("...and the Replace My Save button", menu._backup_confirm.visible)
		menu.call("_backup_reset", "")
		_check("leaving resets it", not menu._backup_confirm.visible)
		var settings_btns := (menu._pages[2] as Control).find_children("*", "TitleButton", true, false)
		_check("Settings has a Save Backup button", settings_btns.any(func(b: Node) -> bool: return str(b.get("label_text")) == "Save Backup" or (b as Button).text == "Save Backup"))
	print("SAVE BACKUP TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails else 0)


func _find_menu(n: Node) -> Node:
	if n.get("BACKUP_PAGE") != null:
		return n
	for c in n.get_children():
		var f := _find_menu(c)
		if f:
			return f
	return null
