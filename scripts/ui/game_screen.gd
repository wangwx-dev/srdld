extends Control

var sim: CareerSim
var overlay := "none"
var center_mode := "home"
var recap: Dictionary = {}
var viewed_post: Dictionary = {}
var tutorial_step := 0
var confirm_restart := false
var _overlay_queued := false
var sel_platform := "shizi"
var sel_topic := "worker_mood"
var sel_format := "short"
var sel_effort := "standard"
var sponsor_on := false
var status_text := ""

var top_day: Label
var top_money: Label
var top_bill: Label
var home_box: VBoxContainer
var publish_box: VBoxContainer
var result_box: VBoxContainer
var home_hint: Label
var status_label: Label
var preview_label: RichTextLabel
var publish_hint: Label
var result_title: Label
var result_body: RichTextLabel
var topic_box: VBoxContainer
var log_box: VBoxContainer
var right_box: VBoxContainer
var sponsor_check: CheckButton
var backdrop: DeskBackdrop
var dimmer: ColorRect
var card: VBoxContainer
var stat_labels := {}
var stat_bars := {}
var action_buttons := {}
var choice_buttons := {}

const TUTORIAL := [
	["先把这个月活下来", "你是独立创作者。第 12 天房租 800，第 22 天助学贷款 650，第 30 天月末房租 900。每天还有 25 元伙食，付不出就结束。"],
	["一天三次行动", "可以写稿发布、休息、出门、接私活或上课。体力低于 8 就不能再工作。只休息不做事，账会先到期。"],
	["播放不是黑箱", "发布前看得到播放和收入区间。质量、平台契合、体裁、趋势、疲劳都会写明。随机波动只在 ×0.94 到 ×1.06。"],
	["暂停和存档", "Esc 或右上角可以暂停。那里能存档、读档、看帮助，也能用同一个种子重开。赞助要在期限前交，否则口碑会掉。"],
]


func _ready() -> void:
	_set_title()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ThemeBuilder.make()
	_build()
	if not _boot():
		return
	if ShotUtil.enabled():
		await _demo()


func _set_title() -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_window().title = "自媒体经营日记"


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	match overlay:
		"help":
			overlay = "pause" if sim != null else "none"
			_rebuild_overlay()
		"pause":
			_close_overlay()
		"tutorial":
			_finish_tutorial()
		"recap":
			if sim != null and sim.phase == "playing":
				_close_overlay()
		"post":
			_close_overlay()
		"event":
			confirm_restart = false
			overlay = "pause"
			_rebuild_overlay()
		_:
			if center_mode == "result":
				_show_home()
			elif center_mode == "publish":
				_show_home()
			else:
				confirm_restart = false
				overlay = "pause"
				_rebuild_overlay()
	get_viewport().set_input_as_handled()


func _boot() -> bool:
	var catalog := Catalog.load_default()
	if RunConfig.mode == "load":
		var loaded := SaveGame.load_slot(catalog)
		if not loaded.get("ok", false):
			RunConfig.boot_error = str(loaded.get("message", "读档失败"))
			RunConfig.mode = "new"
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
			return false
		sim = loaded["sim"]
	else:
		sim = CareerSim.create_new(catalog, RunConfig.seed_value)
	if RunConfig.mode == "new" and not sim.tutorial_done:
		overlay = "tutorial"
		tutorial_step = 0
	_refresh()
	return true


func _build() -> void:
	backdrop = DeskBackdrop.new()
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 8)
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root_box)
	root_box.add_child(_build_top())
	var desk_gap := Control.new()
	desk_gap.custom_minimum_size = Vector2(0, 78)
	desk_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_box.add_child(desk_gap)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 8)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_child(columns)
	columns.add_child(_build_left())
	columns.add_child(_build_center())
	columns.add_child(_build_right())
	root_box.add_child(_build_log())
	_build_overlay()


func _build_top() -> PanelContainer:
	var panel := _panel(false)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	var day_box := VBoxContainer.new()
	day_box.custom_minimum_size = Vector2(168, 0)
	top_day = _label("第 1 / 30 天", 22, ThemeBuilder.INK, false)
	day_box.add_child(top_day)
	day_box.add_child(_label("自媒体经营日记", 14, ThemeBuilder.INK_SOFT, false))
	row.add_child(day_box)
	top_money = _label("¥0", 28, ThemeBuilder.CLAY, false)
	top_money.custom_minimum_size = Vector2(150, 0)
	top_money.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(top_money)
	top_bill = _label("账单", 16, ThemeBuilder.INK, false)
	top_bill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(top_bill)
	row.add_child(_icon_button("帮助", "help_game", _open_help))
	row.add_child(_icon_button("暂停", "pause", _open_pause))
	return panel


func _build_left() -> PanelContainer:
	var panel := _panel()
	panel.custom_minimum_size = Vector2(248, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(_label("创作者状态", 18, ThemeBuilder.INK))
	_add_stat(box, "stamina", "体力", ThemeBuilder.TEAL)
	_add_stat(box, "mood", "心情", ThemeBuilder.GOLD)
	_add_stat(box, "stress", "压力", ThemeBuilder.DANGER)
	_add_stat(box, "inspiration", "灵感", ThemeBuilder.SAGE)
	_add_stat(box, "reputation", "口碑", ThemeBuilder.CLAY)
	_add_stat(box, "writing", "写作", ThemeBuilder.TEAL)
	_add_stat(box, "editing", "剪辑", ThemeBuilder.GOLD)
	return panel


func _build_center() -> PanelContainer:
	var panel := _panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(box)
	status_label = _label("", 15, ThemeBuilder.DANGER)
	status_label.visible = false
	box.add_child(status_label)
	home_box = VBoxContainer.new()
	home_box.add_theme_constant_override("separation", 8)
	home_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(home_box)
	home_hint = _label("", 16, ThemeBuilder.INK)
	home_box.add_child(home_hint)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	home_box.add_child(grid)
	_add_action(grid, "action_publish", "写稿发布", _open_publish)
	_add_action(grid, "action_rest", "休息", _do_rest)
	_add_action(grid, "action_outing", "出门采风", _do_outing)
	_add_action(grid, "action_freelance", "自由职业", _do_freelance)
	_add_action(grid, "action_study_writing", "学写作", _do_study_writing)
	_add_action(grid, "action_study_editing", "学剪辑", _do_study_editing)
	var end_button := _icon_button("结束今天", "end_day", _do_end_day)
	ThemeBuilder.paint_primary(end_button)
	end_button.custom_minimum_size = Vector2(0, 52)
	home_box.add_child(end_button)
	action_buttons["end_day"] = end_button
	publish_box = VBoxContainer.new()
	publish_box.add_theme_constant_override("separation", 4)
	publish_box.visible = false
	box.add_child(publish_box)
	_build_publish(publish_box)
	result_box = VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 6)
	result_box.visible = false
	result_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(result_box)
	result_title = _label("发出去了", 24, ThemeBuilder.INK)
	result_box.add_child(result_title)
	result_body = _reading_text(120)
	result_box.add_child(result_body)
	var back := _icon_button("继续安排今天", "result_continue", _show_home)
	ThemeBuilder.paint_primary(back)
	result_box.add_child(back)
	return panel


func _build_publish(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	parent.add_child(header)
	header.add_child(_label("写稿并发布", 20, ThemeBuilder.INK))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(_icon_button("返回", "publish_back", _show_home))
	var platforms := HBoxContainer.new()
	platforms.add_theme_constant_override("separation", 6)
	parent.add_child(platforms)
	for id in ["shizi", "qingtie", "changhe"]:
		var button := _icon_button(id, "platform_%s" % id, _select_platform.bind(id))
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		platforms.add_child(button)
		choice_buttons[id] = button
	var topic_scroll := ScrollContainer.new()
	topic_scroll.custom_minimum_size = Vector2(0, 92)
	topic_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(topic_scroll)
	topic_box = VBoxContainer.new()
	topic_box.add_theme_constant_override("separation", 4)
	topic_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topic_scroll.add_child(topic_box)
	var formats := HBoxContainer.new()
	formats.add_theme_constant_override("separation", 6)
	parent.add_child(formats)
	for id in ["note", "short", "long"]:
		var button := _icon_button(id, "format_%s" % id, _select_format.bind(id))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		formats.add_child(button)
		choice_buttons["format_%s" % id] = button
	var efforts := HBoxContainer.new()
	efforts.add_theme_constant_override("separation", 6)
	parent.add_child(efforts)
	for id in ["rush", "standard", "polish"]:
		var button := _icon_button(id, "effort_%s" % id, _select_effort.bind(id))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		efforts.add_child(button)
		choice_buttons["effort_%s" % id] = button
	sponsor_check = CheckButton.new()
	sponsor_check.text = "这次带上赞助"
	sponsor_check.custom_minimum_size = Vector2(0, 48)
	sponsor_check.set_meta("ui_id", "sponsor_toggle")
	sponsor_check.toggled.connect(_toggle_sponsor)
	parent.add_child(sponsor_check)
	preview_label = _reading_text(88)
	parent.add_child(preview_label)
	publish_hint = _label("", 14, ThemeBuilder.DANGER)
	parent.add_child(publish_hint)
	var confirm := _icon_button("发布", "publish_confirm", _confirm_publish)
	ThemeBuilder.paint_primary(confirm)
	parent.add_child(confirm)
	choice_buttons["publish_confirm"] = confirm


func _build_right() -> PanelContainer:
	var panel := _panel()
	panel.custom_minimum_size = Vector2(292, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	right_box = VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 6)
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(right_box)
	return panel


func _build_log() -> PanelContainer:
	var panel := _panel(false)
	panel.custom_minimum_size = Vector2(0, 96)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 76)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	log_box = VBoxContainer.new()
	log_box.add_theme_constant_override("separation", 4)
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(log_box)
	return panel


func _build_overlay() -> void:
	dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.18, 0.11, 0.08, 0.58)
	dimmer.visible = false
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	panel.add_theme_stylebox_override("panel", ThemeBuilder.panel_style())
	center.add_child(panel)
	card = VBoxContainer.new()
	card.add_theme_constant_override("separation", 8)
	panel.add_child(card)


func _refresh() -> void:
	if sim == null:
		return
	_sync_forced_overlay()
	top_day.text = "第 %d / 30 天" % sim.day
	top_money.text = Loc.yuan(sim.money)
	_refresh_bill()
	_refresh_stats()
	_refresh_home()
	_refresh_publish()
	_refresh_right()
	_refresh_log()
	_refresh_center_visibility()
	backdrop.sky_phase = mini(3, 3 - sim.actions_left) if sim.phase == "playing" else 0
	var max_fans := 1
	for value in sim.fans.values():
		max_fans = max(max_fans, int(value))
	backdrop.fan_ratios = [
		float(sim.fans.get("shizi", 0)) / float(max_fans),
		float(sim.fans.get("qingtie", 0)) / float(max_fans),
		float(sim.fans.get("changhe", 0)) / float(max_fans),
	]
	status_label.text = status_text
	status_label.visible = status_text != ""
	_rebuild_overlay()


func _refresh_bill() -> void:
	var bill := sim.next_bill()
	if bill.is_empty():
		top_bill.text = "这个月的账单都结清了" if sim.phase != "lost" else "有一笔没付上"
		top_bill.add_theme_color_override("font_color", ThemeBuilder.TEAL)
		return
	var left := int(bill["day"]) - sim.day
	var when := "就是今天结束时" if left <= 0 else "还有 %d 天" % left
	top_bill.text = "%s %s · %s" % [str(bill["name"]), Loc.yuan(int(bill["amount"])), when]
	top_bill.add_theme_color_override("font_color", ThemeBuilder.DANGER if left <= 3 else ThemeBuilder.INK)


func _refresh_stats() -> void:
	_set_stat("stamina", sim.stamina, 100.0)
	_set_stat("mood", sim.mood, 100.0)
	_set_stat("stress", sim.stress, 100.0)
	_set_stat("inspiration", sim.inspiration, 100.0)
	_set_stat("reputation", sim.reputation, 100.0)
	_set_stat("writing", sim.writing, 10.0)
	_set_stat("editing", sim.editing, 10.0)


func _refresh_home() -> void:
	var trend := sim.trend_for_day(sim.day)
	var upcoming := sim.next_trend()
	var next_text := "下周预告「%s」。" % upcoming if upcoming != "" else "这是本月最后一段趋势。"
	home_hint.text = "今天还剩 %d 次行动。本周趋势「%s」。%s结束今天会结算伙食 %s。" % [
		sim.actions_left, trend, next_text, Loc.yuan(int(sim.catalog.balance["food_per_day"]))
	]
	var locked := _ui_locked()
	var tired := sim.stamina < float(sim.catalog.balance["min_stamina_to_work"])
	_set_action("action_publish", locked or sim.actions_left <= 0 or tired, "写稿发布" if not tired else "写稿发布（太累）")
	_set_action("action_rest", locked or sim.actions_left <= 0, "休息")
	var outing_cost := -int(sim.catalog.balance["actions"]["outing"]["money"])
	var outing_block := locked or sim.actions_left <= 0 or tired or sim.money < outing_cost
	var outing_text := "出门采风"
	if tired:
		outing_text = "出门采风（太累）"
	elif sim.money < outing_cost:
		outing_text = "出门采风（钱不够）"
	_set_action("action_outing", outing_block, outing_text)
	_set_action("action_freelance", locked or sim.actions_left <= 0 or tired, "自由职业" if not tired else "自由职业（太累）")
	var write_cost := -int(sim.catalog.balance["actions"]["study_writing"]["money"])
	var edit_cost := -int(sim.catalog.balance["actions"]["study_editing"]["money"])
	_set_action("action_study_writing", locked or sim.actions_left <= 0 or sim.money < write_cost, "学写作" if sim.money >= write_cost else "学写作（钱不够）")
	_set_action("action_study_editing", locked or sim.actions_left <= 0 or sim.money < edit_cost, "学剪辑" if sim.money >= edit_cost else "学剪辑（钱不够）")
	var end_button: Button = action_buttons["end_day"]
	end_button.disabled = locked
	end_button.text = "结束今天" if sim.actions_left > 0 else "结束今天 · 去结算"


func _refresh_publish() -> void:
	if sim == null:
		return
	for id in ["shizi", "qingtie", "changhe"]:
		var button: Button = choice_buttons[id]
		var platform: Dictionary = sim.catalog.platform(id)
		button.text = "%s · 粉 %d" % [str(platform.get("name", id)), int(sim.fans.get(id, 0))]
		_mark(button, sel_platform == id)
	for id in ["note", "short", "long"]:
		var button: Button = choice_buttons["format_%s" % id]
		button.text = str(sim.catalog.balance["formats"][id]["label"])
		_mark(button, sel_format == id)
	for id in ["rush", "standard", "polish"]:
		var effort: Dictionary = sim.catalog.balance["efforts"][id]
		var button: Button = choice_buttons["effort_%s" % id]
		button.text = "%s · 体%d" % [str(effort["label"]), int(effort["stamina"])]
		_mark(button, sel_effort == id)
	_rebuild_topics()
	var has_contract := not sim.contract.is_empty()
	sponsor_check.visible = has_contract
	sponsor_check.set_pressed_no_signal(sponsor_on and has_contract)
	if has_contract:
		sponsor_check.text = "带上%s（%s / %s，截止第 %d 天）" % [
			str(sim.contract.get("brand", "")),
			str(sim.contract.get("tag", "")),
			_platform_name(str(sim.contract.get("platform", ""))),
			int(sim.contract.get("due_day", sim.day)),
		]
	var preview := sim.preview_post(sel_platform, sel_topic, sel_format, sel_effort, sponsor_on and has_contract)
	if preview.get("ok", false):
		var lines := Loc.factor_lines(preview)
		preview_label.text = "\n".join(lines)
		var confirm: Button = choice_buttons["publish_confirm"]
		confirm.text = "发布 · 体力-%d · 灵感-%d" % [int(preview["stamina_cost"]), int(preview["inspiration_cost"])]
	var tired := sim.stamina < float(sim.catalog.balance["min_stamina_to_work"])
	var blocked := _ui_locked() or sim.actions_left <= 0 or tired
	choice_buttons["publish_confirm"].disabled = blocked
	if tired:
		publish_hint.text = "太累了，先回去休息。"
	elif sim.actions_left <= 0:
		publish_hint.text = "今天没有行动次数了。"
	elif not sim.pending_event.is_empty():
		publish_hint.text = "先处理弹出的事件。"
	else:
		publish_hint.text = ""


func _rebuild_topics() -> void:
	_clear(topic_box)
	var trend := sim.trend_for_day(sim.day)
	for topic in sim.catalog.topics:
		var id := str(topic["id"])
		var fit := float(topic["fit"].get(sel_platform, 1.0))
		var fatigue := float(sim.fatigue.get("%s|%s" % [sel_platform, id], 0.0))
		var trend_hit := false
		for tag in topic.get("tags", []):
			if str(tag) == trend:
				trend_hit = true
		var button := Button.new()
		button.text = "%s · %s · %s%s" % [
			str(topic["name"]),
			Loc.fit_word(fit),
			Loc.fatigue_word(fatigue),
			" · 趋势" if trend_hit else "",
		]
		button.custom_minimum_size = Vector2(0, 44)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.set_meta("ui_id", "topic_%s" % id)
		button.pressed.connect(_select_topic.bind(id))
		_mark(button, sel_topic == id)
		topic_box.add_child(button)


func _refresh_right() -> void:
	_clear(right_box)
	right_box.add_child(_label("平台", 18, ThemeBuilder.INK))
	for platform in sim.catalog.platforms:
		var id := str(platform["id"])
		right_box.add_child(_label("%s  ·  粉丝 %d" % [str(platform["name"]), int(sim.fans.get(id, 0))], 16, ThemeBuilder.INK))
		right_box.add_child(_label(str(platform["blurb"]), 13, ThemeBuilder.INK_SOFT))
	right_box.add_child(_label("趋势", 18, ThemeBuilder.INK))
	var upcoming := sim.next_trend()
	right_box.add_child(_label("本周「%s」。下周「%s」。柿子最吃趋势，长河不太跟风。" % [sim.trend_for_day(sim.day), upcoming if upcoming != "" else "维持到月底"], 14, ThemeBuilder.INK))
	right_box.add_child(_label("赞助", 18, ThemeBuilder.INK))
	if not sim.sponsor_offer.is_empty():
		var offer := sim.sponsor_offer
		right_box.add_child(_label("%s 出 %s。要「%s」，发在%s。%s" % [
			str(offer["brand"]), Loc.yuan(int(offer["pay"])), str(offer["tag"]), _platform_name(str(offer["platform"])), str(offer["blurb"])
		], 14, ThemeBuilder.INK))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		right_box.add_child(row)
		var accept := _icon_button("接下", "sponsor_accept", _accept_sponsor)
		ThemeBuilder.paint_primary(accept)
		accept.disabled = _ui_locked()
		row.add_child(accept)
		var reject := _icon_button("婉拒", "sponsor_reject", _reject_sponsor)
		reject.disabled = _ui_locked()
		row.add_child(reject)
	elif not sim.contract.is_empty():
		right_box.add_child(_label("进行中：%s。%s / %s，第 %d 天结束前要交。" % [
			str(sim.contract.get("brand", "")), str(sim.contract.get("tag", "")),
			_platform_name(str(sim.contract.get("platform", ""))), int(sim.contract.get("due_day", sim.day))
		], 14, ThemeBuilder.INK))
	else:
		right_box.add_child(_label("今天没有新的赞助邀约。", 14, ThemeBuilder.INK_SOFT))
	right_box.add_child(_label("同城动态", 18, ThemeBuilder.INK))
	for rival in sim.rival_rows():
		var growth := int(rival["growth"])
		var extra := "本周涨粉约 %d。" % growth if growth > 0 else ""
		right_box.add_child(_label("%s：%s%s" % [str(rival["name"]), extra, str(rival["line"])], 13, ThemeBuilder.INK_SOFT))
	right_box.add_child(_label("种子 %d" % sim.seed_value, 13, ThemeBuilder.INK_SOFT))


func _refresh_log() -> void:
	_clear(log_box)
	if sim.log.is_empty():
		log_box.add_child(_label("发布和事件会记在这里，点一条发布可以回看拆解。", 14, ThemeBuilder.INK_SOFT))
		return
	var start: int = max(0, sim.log.size() - 6)
	for index in range(start, sim.log.size()):
		var entry: Dictionary = sim.log[index]
		if str(entry.get("kind", "")) == "post":
			var button := Button.new()
			button.text = Loc.log_line(entry, sim)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size = Vector2(0, 44)
			button.set_meta("ui_id", "log_%d" % index)
			button.pressed.connect(_open_post.bind(int(entry.get("post_index", -1))))
			log_box.add_child(button)
		else:
			log_box.add_child(_label(Loc.log_line(entry, sim), 14, ThemeBuilder.INK))


func _refresh_center_visibility() -> void:
	home_box.visible = center_mode == "home"
	publish_box.visible = center_mode == "publish"
	result_box.visible = center_mode == "result"


func _sync_forced_overlay() -> void:
	if overlay in ["pause", "help", "tutorial", "recap", "post"]:
		return
	if sim.pending_event.is_empty():
		if overlay == "event":
			overlay = "none"
		return
	overlay = "event"


func _rebuild_overlay() -> void:
	if _overlay_queued:
		return
	_overlay_queued = true
	call_deferred("_rebuild_overlay_now")


func _rebuild_overlay_now() -> void:
	_overlay_queued = false
	if card == null:
		return
	_clear(card)
	dimmer.visible = overlay != "none"
	if overlay == "none":
		return
	match overlay:
		"tutorial":
			_fill_tutorial()
		"event":
			_fill_event()
		"recap":
			_fill_recap()
		"pause":
			_fill_pause()
		"help":
			_fill_help()
		"post":
			_fill_post()


func _fill_tutorial() -> void:
	var step: Array = TUTORIAL[tutorial_step]
	card.add_child(_label(str(step[0]), 26, ThemeBuilder.INK))
	card.add_child(_label(str(step[1]), 16, ThemeBuilder.INK))
	card.add_child(_label("%d / %d" % [tutorial_step + 1, TUTORIAL.size()], 14, ThemeBuilder.INK_SOFT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	row.add_child(_icon_button("跳过", "skip_tutorial", _finish_tutorial))
	var next := _icon_button("开始第一天" if tutorial_step == TUTORIAL.size() - 1 else "下一步", "next_tutorial", _advance_tutorial)
	ThemeBuilder.paint_primary(next)
	row.add_child(next)


func _fill_event() -> void:
	card.add_child(_label("今天碰到的事", 24, ThemeBuilder.INK))
	card.add_child(_label(str(sim.pending_event.get("text", "")), 16, ThemeBuilder.INK))
	for choice in sim.pending_event.get("choices", []):
		var button := _icon_button(str(choice.get("label", "")), "event_%s" % str(choice.get("id", "")), _choose_event.bind(str(choice.get("id", ""))))
		card.add_child(button)


func _fill_recap() -> void:
	var title := "第 %d 天结束了" % int(recap.get("day", sim.day))
	if sim.phase == "won":
		title = "你把第一个月站住了"
	elif sim.phase == "lost":
		title = "这个月没有撑住"
	card.add_child(_label(title, 28, ThemeBuilder.INK))
	card.add_child(_label(_recap_body(), 16, ThemeBuilder.INK))
	if sim.phase == "playing":
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var next := _icon_button("进入下一天", "recap_next", _close_overlay)
		ThemeBuilder.paint_primary(next)
		row.add_child(next)
		row.add_child(_icon_button("暂停", "recap_pause", _open_pause))
	else:
		card.add_child(_icon_button("用同一种子重开", "restart_same", _restart_same))
		card.add_child(_icon_button("换个种子重开", "restart_new", _restart_new))
		card.add_child(_icon_button("回到标题", "back_title", _back_to_title))


func _fill_pause() -> void:
	card.add_child(_label("暂停", 28, ThemeBuilder.INK))
	if confirm_restart:
		card.add_child(_label("当前进度不自动保存。确定重开吗？", 16, ThemeBuilder.INK))
		card.add_child(_icon_button("同一种子重开", "restart_same", _restart_same))
		card.add_child(_icon_button("换个种子重开", "restart_new", _restart_new))
		card.add_child(_icon_button("取消", "restart_cancel", _cancel_restart))
		return
	card.add_child(_label("种子 %d。选择相同就会得到相同的一个月。" % sim.seed_value, 15, ThemeBuilder.INK_SOFT))
	var resume := _icon_button("继续", "pause_resume", _close_overlay)
	ThemeBuilder.paint_primary(resume)
	card.add_child(resume)
	card.add_child(_icon_button("保存", "pause_save", _save_game))
	card.add_child(_icon_button("读取", "pause_load", _load_game))
	card.add_child(_icon_button("帮助", "pause_help", _open_help))
	card.add_child(_icon_button("重新开始", "pause_restart", _ask_restart))
	card.add_child(_icon_button("回到标题", "pause_title", _back_to_title))


func _fill_help() -> void:
	card.add_child(_label("帮助", 28, ThemeBuilder.INK))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	var body := _label(Loc.help_text(), 16, ThemeBuilder.INK)
	body.custom_minimum_size = Vector2(620, 0)
	scroll.add_child(body)
	var close := _icon_button("关闭", "overlay_close", _close_help)
	ThemeBuilder.paint_primary(close)
	card.add_child(close)


func _fill_post() -> void:
	card.add_child(_label(Loc.post_summary(viewed_post), 20, ThemeBuilder.INK))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	var body := _label("\n".join(Loc.factor_lines(viewed_post)), 15, ThemeBuilder.INK)
	body.custom_minimum_size = Vector2(620, 0)
	scroll.add_child(body)
	card.add_child(_icon_button("关闭", "overlay_close", _close_overlay))


func _recap_body() -> String:
	var lines: PackedStringArray = []
	if sim.phase == "won":
		lines.append("房租和贷款都付清了。粉丝一共 %d，手头还剩 %s。" % [sim.total_fans(), Loc.yuan(sim.money)])
		lines.append("无名神人的乱斗传闻留到下赛季。这个月你先把自己留住了。")
	elif sim.phase == "lost":
		if sim.loss_reason == "food":
			lines.append("连今天的伙食 %s 都付不出。手头还剩 %s。" % [Loc.yuan(int(recap.get("food", 25))), Loc.yuan(sim.money)])
		else:
			lines.append("付不出「%s」。创作可以重来，种子是 %d。" % [sim.loss_detail, sim.seed_value])
	lines.append("今日收入 %s，支出 %s，手头 %s。" % [Loc.yuan(int(recap.get("earned", 0))), Loc.yuan(int(recap.get("spent", 0))), Loc.yuan(int(recap.get("money_after", sim.money)))])
	if bool(recap.get("food_paid", false)):
		lines.append("伙食 %s 已付。" % Loc.yuan(int(recap.get("food", 0))))
	if bool(recap.get("bill_paid", false)):
		lines.append("已缴纳%s %s。" % [str(recap.get("bill_name", "账单")), Loc.yuan(int(recap.get("bill_amount", 0)))])
	lines.append("睡觉恢复体力 %d。心情 %s，压力 %s，灵感 %s，口碑 %s。" % [
		int(recap.get("sleep_stamina", 8)),
		Loc.signed_num(float(recap.get("mood_delta", 0))),
		Loc.signed_num(float(recap.get("stress_delta", 0))),
		Loc.signed_num(float(recap.get("inspiration_delta", 0))),
		Loc.signed_num(float(recap.get("reputation_delta", 0))),
	])
	var fans_bits: PackedStringArray = []
	for platform in sim.catalog.platforms:
		var delta := int(recap.get("fans_delta", {}).get(platform["id"], 0))
		fans_bits.append("%s %s" % [str(platform["name"]), Loc.signed_int(delta)])
	lines.append("粉丝 " + "，".join(fans_bits) + "。")
	if bool(recap.get("sponsor_failed", false)):
		lines.append("有一笔赞助到点没交。")
	if bool(recap.get("sponsor_expired", false)):
		lines.append("有一笔邀约过期了，没有奖罚。")
	if sim.phase == "playing":
		var bill := sim.next_bill()
		if not bill.is_empty():
			lines.append("下一笔是第 %d 天的%s %s。" % [int(bill["day"]), str(bill["name"]), Loc.yuan(int(bill["amount"]))])
	return "\n".join(lines)


func _show_home() -> void:
	center_mode = "home"
	_refresh()


func _open_publish() -> void:
	if not sim.contract.is_empty():
		sponsor_on = true
		sel_platform = str(sim.contract.get("platform", sel_platform))
		for topic in sim.catalog.topics:
			var tags: Array = topic.get("tags", [])
			if tags.has(str(sim.contract.get("tag", ""))):
				sel_topic = str(topic["id"])
				break
	var platform: Dictionary = sim.catalog.platform(sel_platform)
	if not platform.is_empty():
		sel_format = str(platform.get("preferred_format", sel_format))
	center_mode = "publish"
	status_text = ""
	_refresh()


func _select_platform(id: String) -> void:
	sel_platform = id
	var platform: Dictionary = sim.catalog.platform(id)
	if not platform.is_empty():
		sel_format = str(platform.get("preferred_format", sel_format))
	_refresh_publish()


func _select_topic(id: String) -> void:
	sel_topic = id
	_refresh_publish()


func _select_format(id: String) -> void:
	sel_format = id
	_refresh_publish()


func _select_effort(id: String) -> void:
	sel_effort = id
	_refresh_publish()


func _toggle_sponsor(on: bool) -> void:
	sponsor_on = on
	_refresh_publish()


func _confirm_publish() -> void:
	var result := sim.publish(sel_platform, sel_topic, sel_format, sel_effort, sponsor_on and not sim.contract.is_empty())
	if not result.get("ok", false):
		status_text = Loc.error_text(str(result.get("code", "")))
		_refresh()
		return
	status_text = ""
	center_mode = "result"
	var post: Dictionary = result["post"]
	result_title.text = "%s · %s" % [str(post["platform_name"]), str(post["topic_name"])]
	result_body.text = "\n".join(Loc.factor_lines(post))
	_refresh()


func _do_rest() -> void:
	_apply_simple(sim.rest())


func _do_outing() -> void:
	_apply_simple(sim.outing())


func _do_freelance() -> void:
	_apply_simple(sim.freelance())


func _do_study_writing() -> void:
	_apply_simple(sim.study("writing"))


func _do_study_editing() -> void:
	_apply_simple(sim.study("editing"))


func _apply_simple(result: Dictionary) -> void:
	if not result.get("ok", false):
		status_text = Loc.error_text(str(result.get("code", "")))
	else:
		status_text = ""
	center_mode = "home"
	_refresh()


func _do_end_day() -> void:
	var result := sim.end_day()
	if not result.get("ok", false):
		status_text = Loc.error_text(str(result.get("code", "")))
		_refresh()
		return
	status_text = ""
	recap = result
	center_mode = "home"
	overlay = "recap"
	_refresh()


func _accept_sponsor() -> void:
	var result := sim.decide_sponsor(true)
	status_text = "" if result.get("ok", false) else Loc.error_text(str(result.get("code", "")))
	if result.get("ok", false):
		sponsor_on = true
	_refresh()


func _reject_sponsor() -> void:
	var result := sim.decide_sponsor(false)
	status_text = "" if result.get("ok", false) else Loc.error_text(str(result.get("code", "")))
	_refresh()


func _choose_event(choice_id: String) -> void:
	var result := sim.resolve_event(choice_id)
	if not result.get("ok", false):
		status_text = Loc.error_text(str(result.get("code", "")))
	else:
		status_text = ""
	_refresh()


func _open_post(index: int) -> void:
	if index < 0 or index >= sim.posts.size():
		return
	viewed_post = sim.posts[index]
	overlay = "post"
	_refresh()


func _open_pause() -> void:
	confirm_restart = false
	overlay = "pause"
	_refresh()


func _open_help() -> void:
	overlay = "help"
	_refresh()


func _close_help() -> void:
	overlay = "pause" if sim != null and sim.phase == "playing" else "none"
	if overlay == "none":
		_sync_forced_overlay()
	_refresh()


func _close_overlay() -> void:
	confirm_restart = false
	overlay = "none"
	_refresh()


func _finish_tutorial() -> void:
	sim.tutorial_done = true
	overlay = "none"
	_refresh()


func _advance_tutorial() -> void:
	if tutorial_step >= TUTORIAL.size() - 1:
		_finish_tutorial()
		return
	tutorial_step += 1
	_rebuild_overlay()


func _ask_restart() -> void:
	confirm_restart = true
	_rebuild_overlay()


func _cancel_restart() -> void:
	confirm_restart = false
	_rebuild_overlay()


func _save_game() -> void:
	var result := SaveGame.save_to_slot(sim)
	status_text = "已保存。" if result.get("ok", false) else str(result.get("message", "保存失败"))
	_refresh()


func _load_game() -> void:
	var result := SaveGame.load_slot(sim.catalog)
	if not result.get("ok", false):
		status_text = str(result.get("message", "读档失败"))
		_refresh()
		return
	sim = result["sim"]
	status_text = "已读取存档。"
	center_mode = "home"
	overlay = "none"
	_refresh()


func _restart_same() -> void:
	var seed_value := sim.seed_value
	sim = CareerSim.create_new(sim.catalog, seed_value)
	_reset_after_restart(false)


func _restart_new() -> void:
	var seed_value := int(Time.get_unix_time_from_system() * 1000.0) % 900000000 + 11
	sim = CareerSim.create_new(sim.catalog, seed_value)
	_reset_after_restart(true)


func _reset_after_restart(show_tutorial: bool) -> void:
	center_mode = "home"
	status_text = ""
	confirm_restart = false
	recap = {}
	if show_tutorial:
		sim.tutorial_done = false
		tutorial_step = 0
		overlay = "tutorial"
	else:
		sim.tutorial_done = true
		overlay = "none"
	_refresh()


func _back_to_title() -> void:
	RunConfig.mode = "new"
	RunConfig.boot_error = ""
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _ui_locked() -> bool:
	return overlay != "none" or sim.phase != "playing" or not sim.pending_event.is_empty()


func _set_action(ui_id: String, disabled: bool, text: String) -> void:
	var button: Button = action_buttons[ui_id]
	button.disabled = disabled
	button.text = text


func _set_stat(id: String, value: float, maximum: float) -> void:
	var names := {
		"stamina": "体力", "mood": "心情", "stress": "压力", "inspiration": "灵感",
		"reputation": "口碑", "writing": "写作", "editing": "剪辑",
	}
	stat_labels[id].text = "%s  %s / %s" % [names[id], Loc.num(value), Loc.num(maximum)]
	stat_bars[id].max_value = maximum
	stat_bars[id].value = value


func _add_stat(parent: VBoxContainer, id: String, title: String, color: Color) -> void:
	var label := _label(title, 14, ThemeBuilder.INK)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	ThemeBuilder.paint_bar(bar, color)
	parent.add_child(label)
	parent.add_child(bar)
	stat_labels[id] = label
	stat_bars[id] = bar


func _add_action(parent: GridContainer, ui_id: String, text: String, callback: Callable) -> void:
	var button := _icon_button(text, ui_id, callback)
	button.custom_minimum_size = Vector2(0, 48)
	parent.add_child(button)
	action_buttons[ui_id] = button


func _panel(expand_vertical: bool = true) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeBuilder.panel_style())
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if expand_vertical else Control.SIZE_SHRINK_BEGIN
	return panel


func _icon_button(text: String, ui_id: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(88, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.set_meta("ui_id", ui_id)
	button.pressed.connect(callback)
	return button


func _reading_text(min_height: int) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.bbcode_enabled = false
	text.scroll_active = true
	text.fit_content = false
	text.custom_minimum_size = Vector2(0, min_height)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_color_override("default_color", ThemeBuilder.INK)
	text.add_theme_font_size_override("normal_font_size", 14)
	return text


func _label(text: String, size: int, color: Color, wrap: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _mark(button: Button, selected: bool) -> void:
	if selected:
		button.add_theme_stylebox_override("normal", ThemeBuilder.button_style(Color("F6E2A8"), ThemeBuilder.TEAL, 2))
	else:
		button.remove_theme_stylebox_override("normal")


func _platform_name(id: String) -> String:
	var platform: Dictionary = sim.catalog.platform(id)
	return str(platform.get("name", id))


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.free()


func _demo() -> void:
	var shots := ShotUtil.new()
	add_child(shots)
	await get_tree().process_frame
	await get_tree().process_frame
	if overlay == "tutorial":
		await shots.capture(self, "04_tutorial")
		await _click_or_call(shots, "skip_tutorial", _finish_tutorial)
	await get_tree().process_frame
	if overlay == "event":
		await shots.capture(self, "05_event")
		await _click_or_call(shots, "event_%s" % _demo_choice(), _choose_event.bind(_demo_choice()))
	await shots.capture(self, "06_desk")
	await _click_or_call(shots, "action_publish", _open_publish)
	if sim.catalog.topic(sel_topic).is_empty():
		sel_topic = "budget_recipe"
	_select_platform("shizi")
	_select_topic("budget_recipe")
	_select_format("short")
	_select_effort("standard")
	await shots.capture(self, "07_preview")
	await _click_or_call(shots, "publish_confirm", _confirm_publish)
	await shots.capture(self, "08_result")
	await _click_or_call(shots, "result_continue", _show_home)
	if overlay == "event":
		await _click_or_call(shots, "event_%s" % _demo_choice(), _choose_event.bind(_demo_choice()))
	await _click_or_call(shots, "pause", _open_pause)
	await shots.capture(self, "09_pause")
	await _click_or_call(shots, "pause_resume", _close_overlay)
	if overlay == "event":
		await _click_or_call(shots, "event_%s" % _demo_choice(), _choose_event.bind(_demo_choice()))
	await _click_or_call(shots, "end_day", _do_end_day)
	await shots.capture(self, "10_recap")
	if sim.phase == "playing":
		await _click_or_call(shots, "recap_next", _close_overlay)
		await shots.capture(self, "11_next_day")
	var layout_ok := shots.audit(self)
	var report := "day=%d phase=%s posts=%d layout=%s" % [sim.day, sim.phase, sim.post_count, layout_ok]
	print("PLAYTEST ", report)
	var file := FileAccess.open(ShotUtil.directory().path_join("playtest.txt"), FileAccess.WRITE)
	if file:
		file.store_string(report)
	get_tree().quit(0 if layout_ok and sim.post_count > 0 else 2)


func _demo_choice() -> String:
	var choices: Array = sim.pending_event.get("choices", [])
	for choice in choices:
		var cost := int(choice.get("effects", {}).get("money", 0))
		if cost >= 0 or sim.money >= -cost:
			return str(choice.get("id", ""))
	if choices.is_empty():
		return ""
	return str(choices[choices.size() - 1].get("id", ""))


func _click_or_call(shots: ShotUtil, ui_id: String, fallback: Callable) -> void:
	var before := overlay
	var clicked := await shots.click(self, ui_id)
	await get_tree().process_frame
	if not clicked:
		fallback.call()
		print("PLAYTEST fallback ", ui_id)
		return
	if ui_id == "skip_tutorial" and overlay == "tutorial":
		fallback.call()
		print("PLAYTEST fallback ", ui_id)
	elif ui_id == "publish_confirm" and center_mode != "result":
		fallback.call()
		print("PLAYTEST fallback ", ui_id)
	elif ui_id == "end_day" and overlay != "recap":
		fallback.call()
		print("PLAYTEST fallback ", ui_id)
	elif ui_id.begins_with("event_") and overlay == "event" and overlay == before:
		fallback.call()
		print("PLAYTEST fallback ", ui_id)
