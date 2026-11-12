extends Control

var menu_mode := "title"
var card: VBoxContainer
var error_label: Label
var seed_edit: LineEdit


func _ready() -> void:
	_set_title()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ThemeBuilder.make()
	_build()
	_show_mode("title")
	if ShotUtil.enabled():
		await _demo()


func _set_title() -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_window().title = "自媒体经营日记"


func _build() -> void:
	var backdrop := DeskBackdrop.new()
	backdrop.sky_phase = 2
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.add_theme_stylebox_override("panel", ThemeBuilder.panel_style())
	center.add_child(panel)
	card = VBoxContainer.new()
	card.add_theme_constant_override("separation", 10)
	panel.add_child(card)


func _show_mode(mode: String) -> void:
	menu_mode = mode
	for child in card.get_children():
		card.remove_child(child)
		child.free()
	var title := _label("自媒体经营日记", 40, ThemeBuilder.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)
	var subtitle := _label("第一个月，把房租和自己都留住", 18, ThemeBuilder.INK_SOFT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(subtitle)
	if mode == "title":
		card.add_child(_label("离线虚构的创作经营。没有真实平台，也没有隐藏的大暴击。", 16, ThemeBuilder.INK_SOFT))
		card.add_child(_button("新游戏", "new_game", _open_new, true))
		var continue_button := _button("继续" if FileAccess.file_exists(SaveGame.SLOT_PATH) else "继续（没有存档）", "continue_game", _continue_game, false)
		continue_button.disabled = not FileAccess.file_exists(SaveGame.SLOT_PATH)
		card.add_child(continue_button)
		card.add_child(_button("帮助", "help", _open_help, false))
		card.add_child(_button("退出", "quit", _quit, false))
	elif mode == "new":
		card.add_child(_label("种子相同、选择相同，三十天的结果就相同。把它记下来可以重开同一局。", 16, ThemeBuilder.INK_SOFT))
		seed_edit = LineEdit.new()
		seed_edit.placeholder_text = "输入数字种子"
		seed_edit.text = str(_random_seed())
		seed_edit.custom_minimum_size = Vector2(0, 48)
		seed_edit.set_meta("ui_id", "seed_input")
		card.add_child(seed_edit)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		row.add_child(_button("随机一个", "random_seed", _roll_seed, false))
		row.add_child(_button("开始", "start_game", _start_game, true))
		card.add_child(_button("返回", "back", _show_title, false))
	else:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(560, 360)
		card.add_child(scroll)
		var body := _label(Loc.help_text(), 16, ThemeBuilder.INK)
		body.custom_minimum_size = Vector2(540, 0)
		scroll.add_child(body)
		card.add_child(_button("返回", "back", _show_title, true))
	error_label = _label(RunConfig.boot_error, 16, ThemeBuilder.DANGER)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(error_label)
	var footer := _label("v0.1.0  ·  Godot 4.7.2  ·  神人大乱斗下赛季才开", 14, ThemeBuilder.INK_SOFT)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(footer)


func _show_title() -> void:
	RunConfig.boot_error = ""
	call_deferred("_show_mode", "title")


func _open_new() -> void:
	call_deferred("_show_mode", "new")


func _open_help() -> void:
	call_deferred("_show_mode", "help")


func _roll_seed() -> void:
	if seed_edit:
		seed_edit.text = str(_random_seed())


func _start_game() -> void:
	var text := seed_edit.text.strip_edges() if seed_edit else ""
	if text == "":
		text = str(_random_seed())
	if not text.is_valid_int():
		error_label.text = "种子只能是数字。"
		return
	var seed_value := int(text)
	if seed_value < 1 or seed_value > 999999999:
		error_label.text = "种子请用 1 到 999999999。"
		return
	RunConfig.mode = "new"
	RunConfig.seed_value = seed_value
	RunConfig.boot_error = ""
	call_deferred("_go_game")


func _go_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _continue_game() -> void:
	RunConfig.mode = "load"
	RunConfig.boot_error = ""
	call_deferred("_go_game")


func _quit() -> void:
	get_tree().quit()


func _random_seed() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0) % 900000000 + 1


func _button(text: String, ui_id: String, callback: Callable, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 52)
	button.set_meta("ui_id", ui_id)
	if primary:
		ThemeBuilder.paint_primary(button)
	button.pressed.connect(callback)
	return button


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _demo() -> void:
	var shots := ShotUtil.new()
	add_child(shots)
	await get_tree().process_frame
	await get_tree().process_frame
	await shots.capture(self, "01_menu")
	await shots.click(self, "help")
	await shots.capture(self, "02_help")
	await shots.click(self, "back")
	await shots.click(self, "new_game")
	if seed_edit:
		seed_edit.text = "20261112"
	await shots.capture(self, "03_seed")
	_start_game()
