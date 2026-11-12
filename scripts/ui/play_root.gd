extends Control

const CANVAS := Vector2(1760, 1400)

var sim: DiarySim
var content: Dictionary = {}
var mode := "title"
var zoom := 0.62
var dragging := false
var panning := false
var press_pos := Vector2.ZERO
var selected := ""
var create_step := 0
var form := "article"
var topic_id := "life"
var chosen_memes: Array = []
var link := "串联"
var polish := "none"
var pending_report: Array = []
var settings := {"music": 0.4, "sfx": 0.7}
var click_player: AudioStreamPlayer
var music_player: AudioStreamPlayer

var world: Control
var room_view: RoomComposite
var selected_work := -1
var chart_cumulative := false
var hotspots: Dictionary = {}
var hud_time: Label
var hud_money: Label
var hud_body: Label
var hud_idea: Label
var hud_fans: Label
var hud_bill: Label
var hud_loan: Label
var page: Control
var page_scroll: Control
var page_box: VBoxContainer
var place_view: PlaceView
var tutor: Label
var tutor_wrap: PanelContainer
var name_edit: LineEdit
var gender := "f"
var seen_tutor := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ThemeBuilder.make()
	content = _load_content()
	_load_settings()
	click_player = AudioStreamPlayer.new()
	click_player.stream = _tone(660, 40)
	add_child(click_player)
	music_player = AudioStreamPlayer.new()
	var loop := _tone(196, 1600)
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music_player.stream = loop
	music_player.volume_db = linear_to_db(maxf(0.001, float(settings.get("music", 0.35))))
	add_child(music_player)
	if float(settings.get("music", 0.35)) > 0.0:
		music_player.play()
	_build_world()
	_build_page()
	_apply_visuals()
	_show_title()
	if ShotUtil.enabled():
		if OS.get_cmdline_user_args().has("--small"):
			get_window().size = Vector2i(1024, 576)
			await get_tree().process_frame
			await get_tree().process_frame
			print("WINDOW ", get_window().size, " VIEW ", get_viewport().get_visible_rect().size)
		await _shot_tour()


func _load_content() -> Dictionary:
	var file := FileAccess.open("res://data/diary_content.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _build_world() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("E4DDD2")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	world = Control.new()
	world.position = Vector2(24, 100)
	world.size = CANVAS
	world.scale = Vector2(zoom, zoom)
	world.z_index = 1
	add_child(world)
	var catch := ColorRect.new()
	catch.color = Color(0, 0, 0, 0)
	catch.size = CANVAS
	catch.gui_input.connect(_world_input)
	world.add_child(catch)
	room_view = RoomComposite.new()
	room_view.size = CANVAS
	world.add_child(room_view)
	_hotspot("休息", "bed", _rest)
	_hotspot("阅读", "bookshelf", _read)
	_hotspot("出门", "door", _open_city)
	_hotspot("逗猫", "cat", _pet_cat)
	_hotspot("创作", "computer", _open_computer)


func _layer(path: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = CANVAS
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	var texture: Resource = load(path)
	if texture is Texture2D:
		rect.texture = texture
	world.add_child(rect)
	return rect


func _anchors() -> Dictionary:
	var file := FileAccess.open("res://assets/room/hotspot_anchors.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text() if file else "{}")
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed.get("anchors", {})


func _hotspot(text: String, id: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = ""
	var chip := PanelContainer.new()
	chip.name = "chip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", ThemeBuilder.button_style(Color("FFF8EE"), Color("2C241C"), 2))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path := "res://assets/ui/icon_%s.png" % id
	var icon_tex: Resource = load(icon_path)
	if icon_tex is Texture2D:
		icon.texture = icon_tex
	row.add_child(icon)
	var caption := Label.new()
	caption.text = text
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 20)
	caption.add_theme_color_override("font_color", Color("2C241C"))
	row.add_child(caption)
	chip.add_child(row)
	chip.custom_minimum_size = Vector2(128, 44)
	button.add_child(chip)
	button.set_meta("ui_id", "hot_%s" % id)
	button.set_meta("action", callback)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_stylebox_override("normal", _hot_style(0.0))
	button.add_theme_stylebox_override("hover", _hot_style(0.22))
	button.add_theme_stylebox_override("pressed", _hot_style(0.32))
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("focus", _hot_style(0.0))
	button.mouse_entered.connect(_hot_hover.bind(id, button, true))
	button.mouse_exited.connect(_hot_hover.bind(id, button, false))
	button.gui_input.connect(_hot_input.bind(id, button))
	world.add_child(button)
	hotspots[id] = button


func _build_page() -> void:
	page = ColorRect.new()
	page.color = Color("E7E1D6")
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.visible = false
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	page.z_index = 10
	add_child(page)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 100)
	margin.add_theme_constant_override("margin_bottom", 16)
	page.add_child(margin)
	place_view = PlaceView.new()
	place_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	place_view.visible = false
	place_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(place_view)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	page_scroll = scroll
	page_box = VBoxContainer.new()
	page_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_box.add_theme_constant_override("separation", 8)
	scroll.add_child(page_box)
	var hud := PanelContainer.new()
	var hud_style := ThemeBuilder.panel_style()
	hud_style.bg_color = Color("FFF8EE")
	hud.add_theme_stylebox_override("panel", hud_style)
	hud.z_index = 30
	add_child(hud)
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.offset_left = 12
	hud.offset_top = 10
	hud.offset_right = -12
	hud.offset_bottom = 92
	var hud_box := VBoxContainer.new()
	hud_box.add_theme_constant_override("separation", 4)
	hud.add_child(hud_box)
	var row_a := HBoxContainer.new()
	row_a.add_theme_constant_override("separation", 14)
	var row_b := HBoxContainer.new()
	row_b.add_theme_constant_override("separation", 16)
	hud_box.add_child(row_a)
	hud_box.add_child(row_b)
	hud_time = _hud_label("时间")
	hud_money = _hud_label("现金")
	hud_body = _hud_label("体力")
	hud_idea = _hud_label("灵感")
	hud_fans = _hud_label("粉丝")
	hud_bill = _hud_label("房租")
	hud_loan = _hud_label("贷款")
	row_a.add_child(_stat("res://assets/ui/icon_time.png", hud_time))
	row_a.add_child(_stat("res://assets/ui/icon_coin.png", hud_money))
	row_a.add_child(_stat("res://assets/ui/icon_stamina.png", hud_body))
	row_a.add_child(_stat("res://assets/ui/icon_idea.png", hud_idea))
	row_a.add_child(_stat("res://assets/ui/icon_fans.png", hud_fans))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_a.add_child(spacer)
	row_b.add_child(_stat("res://assets/ui/icon_rent.png", hud_bill))
	row_b.add_child(_stat("res://assets/ui/icon_loan.png", hud_loan))
	tutor = _label("点整件家具。拖空白处移动房间，滚轮缩放。拖过一小段不会当成点击。", 16)
	tutor.add_theme_color_override("font_color", Color("2C241C"))
	tutor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutor_wrap = PanelContainer.new()
	tutor_wrap.add_theme_stylebox_override("panel", hud_style)
	tutor_wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tutor_wrap.offset_left = 16
	tutor_wrap.offset_right = -16
	tutor_wrap.offset_top = -72
	tutor_wrap.offset_bottom = -12
	tutor_wrap.z_index = 30
	tutor_wrap.visible = false
	tutor_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tutor_wrap)
	tutor_wrap.add_child(tutor)
	var pause := Button.new()
	pause.text = "菜单"
	pause.custom_minimum_size = Vector2(96, 40)
	pause.pressed.connect(_open_pause)
	row_a.add_child(pause)


func _show_title() -> void:
	mode = "title"
	world.visible = true
	page.visible = true
	_fill([["title", "自媒体经营日记"], ["body", "给自己起个名字，选一个固定形象。房间可以拖动和缩放。"], ["name"], ["gender"], ["button", "开始", _start_game], ["button", "继续自动档", _load_auto], ["button", "退出", _quit]])
	_refresh_hud()


func _start_game() -> void:
	var name := name_edit.text.strip_edges() if name_edit else "小林"
	if name.length() > 8:
		name = name.substr(0, 8)
	sim = DiarySim.create_new(content, int(Time.get_unix_time_from_system()) % 900000000 + 1, name, gender)
	page.visible = false
	mode = "room"
	_apply_visuals()
	_center_on(Vector2(935, 560))
	tutor_wrap.visible = not seen_tutor
	_refresh_hud()


func _fill(rows: Array) -> void:
	page.visible = true
	if place_view != null:
		place_view.visible = false
	if page_scroll != null:
		page_scroll.visible = true
	for child in page_box.get_children():
		page_box.remove_child(child)
		child.free()
	name_edit = null
	for row in rows:
		var kind := str(row[0])
		if kind == "title":
			page_box.add_child(_label(str(row[1]), 28))
		elif kind == "body":
			var label := _label(str(row[1]), 16)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			page_box.add_child(label)
		elif kind == "name":
			name_edit = LineEdit.new()
			name_edit.placeholder_text = "名字，最多 8 个字"
			name_edit.text = "小林"
			name_edit.custom_minimum_size = Vector2(0, 48)
			page_box.add_child(name_edit)
		elif kind == "gender":
			var box := HBoxContainer.new()
			var female := Button.new()
			female.text = "女"
			female.custom_minimum_size = Vector2(120, 48)
			female.pressed.connect(func(): gender = "f"; _apply_pose())
			var male := Button.new()
			male.text = "男"
			male.custom_minimum_size = Vector2(120, 48)
			male.pressed.connect(func(): gender = "m"; _apply_pose())
			box.add_child(female)
			box.add_child(male)
			page_box.add_child(box)
		elif kind == "button":
			var button := Button.new()
			button.text = str(row[1])
			button.custom_minimum_size = Vector2(0, 48)
			button.pressed.connect(row[2])
			page_box.add_child(button)


func _open_computer() -> void:
	if sim == null or sim.phase != "playing":
		return
	mode = "computer"
	page.visible = true
	sim.pose = "sit"
	_apply_pose()
	_show_computer()


func _show_computer() -> void:
	var lines: Array = [["title", "澄闪 · 电脑"], ["body", "今天还能发 %d 篇。少梗更稳，多梗上限更高，也可能翻车。本周榜首：%s" % [1 - sim.works_today, _chart_line()]], ["button", "写一篇", _show_create], ["button", "往期作品", _show_history], ["button", "接一单短约（本周一次，90 分钟，70 金）", _do_gig], ["button", "用掉背包里的吃的", _show_items], ["button", "回到房间", _close_page]]
	_fill(lines)


func _show_create() -> void:
	create_step = 0
	chosen_memes.clear()
	_fill([])
	page_box.add_child(_label("新作品", 28))
	page_box.add_child(_wrap_label("先选形式。文章更快，视频更花时间。预览不揭开这次能不能融住。"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.add_child(_pick_card("res://assets/ui/icon_article.png", "文章", "3 小时", Color("F3E6D0"), func(): form = "article"; _show_topics()))
	row.add_child(_pick_card("res://assets/ui/icon_video.png", "视频", "5 小时", Color("D7E4EA"), func(): form = "video"; _show_topics()))
	page_box.add_child(row)
	page_box.add_child(_text_button("返回", _show_computer))


func _show_topics() -> void:
	_fill([])
	page_box.add_child(_label("选题", 28))
	page_box.add_child(_wrap_label("榜上的话题更受欢迎，但追榜不是必成。"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tints := {
		"life": Color("F3E6D0"),
		"film": Color("D7E4EA"),
		"knowledge": Color("E7F0EA"),
		"mood": Color("F6D5CC"),
		"consume": Color("F6E2A8"),
		"society": Color("E4DDD2"),
	}
	for topic in content.get("topics", []):
		var id := str(topic.get("id", ""))
		var tags: Array = topic.get("tags", [])
		var mark := "本周喜爱" if sim._on_chart(id) else (str(tags[0]) if not tags.is_empty() else "题材")
		var tint: Color = tints.get(id, Color("F6EFE4"))
		flow.add_child(_pick_card("", str(topic.get("name", id)), mark, tint, _set_topic.bind(id)))
	page_box.add_child(flow)
	page_box.add_child(_text_button("返回", _show_create))


func _show_memes() -> void:
	_fill([])
	page_box.add_child(_label("要不要融梗", 28))
	page_box.add_child(_wrap_label("可以不放。放得合拍，成的时候上限更高；放得乱，会伤表达。这篇最多带 8 条。选好之后，挑一种接法。"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	var shown := 0
	for owned in sim.memes:
		if shown >= 8:
			break
		var spec := sim.meme_def(str(owned.get("id", "")))
		var id := str(owned.get("id", ""))
		var picked := chosen_memes.has(id)
		var tint := Color("F6E2A8") if picked else Color("FFF8EE")
		var subtitle := "热度 %.0f%s" % [sim.heat_of(owned), " · 已选" if picked else ""]
		flow.add_child(_pick_card("res://assets/ui/icon_idea.png", str(spec.get("name", id)), subtitle, tint, _toggle_meme.bind(id)))
		shown += 1
	if sim.memes.is_empty():
		page_box.add_child(_wrap_label("你还没有梗。可以先出门，也可以直接写。"))
	page_box.add_child(flow)
	page_box.add_child(_wrap_label("已选 %d 条" % chosen_memes.size()))
	var links := HBoxContainer.new()
	links.add_theme_constant_override("separation", 12)
	links.add_child(_pick_card("", "主题串联", "顺着说", Color("E7F0EA"), func(): link = "串联"; _show_polish()))
	links.add_child(_pick_card("", "对照反差", "反着说", Color("F6D5CC"), func(): link = "反差"; _show_polish()))
	links.add_child(_pick_card("", "旁敲侧击", "绕着说", Color("D7E4EA"), func(): link = "侧击"; _show_polish()))
	links.add_child(_pick_card("", "生硬堆砌", "硬凑", Color("E4DDD2"), func(): link = "堆砌"; _show_polish()))
	page_box.add_child(links)
	page_box.add_child(_text_button("返回选题", _show_topics))


func _show_polish() -> void:
	_fill([])
	page_box.add_child(_label("打磨", 28))
	page_box.add_child(_wrap_label("多花一点时间，表达会更稳，也更耗体力和灵感。"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_pick_card("", "不额外打磨", "直接写", Color("FFF8EE"), func(): polish = "none"; _show_preview()))
	row.add_child(_pick_card("", "短铺垫", "顺一下", Color("F3E6D0"), func(): polish = "short"; _show_preview()))
	row.add_child(_pick_card("", "认真理顺", "多花时间", Color("E7F0EA"), func(): polish = "careful"; _show_preview()))
	page_box.add_child(row)
	page_box.add_child(_text_button("返回", _show_memes))


func _show_preview() -> void:
	var preview := sim.preview_work(form, topic_id, chosen_memes, link, polish)
	var body := "预计 %d 分钟，到 %s。灵感 %d，体力 %d。\n%s\n%s" % [
		int(preview.get("minutes", 0)), str(preview.get("end_text", "")),
		int(preview.get("inspiration", 0)), int(preview.get("stamina", 0)),
		str(preview.get("risk", "")), str(preview.get("potential", "")),
	]
	if bool(preview.get("cross_rent", false)):
		body += "\n途中会碰到账单。"
	var rows: Array = [["title", "预览"], ["body", body]]
	if bool(preview.get("can_afford", false)):
		rows.append(["button", "确认开写", _confirm_create])
	else:
		rows.append(["body", "现在开不了：资源、今天的篇幅，或会跨过付不起的账单。"])
	rows.append(["button", "返回", _show_polish])
	_fill(rows)


func _confirm_create() -> void:
	var result := sim.confirm_work(form, topic_id, chosen_memes, link, polish)
	_sfx()
	if bool(result.get("bankrupt", false)):
		_show_over()
		return
	if not result.get("ok", false):
		_fill([["title", "没写成"], ["body", str(result.get("reason", ""))], ["button", "返回", _show_computer]])
		return
	var work: Dictionary = result.get("work", {})
	var scores: Dictionary = work.get("scores", {})
	var body := "%s · %s\n%s %d · 互动 %d · 涨粉 %d\n深度 %.0f · 趣味 %.0f · 表达 %.0f · 契合 %.0f" % [
		"视频" if str(work.get("form", "")) == "video" else "文章", str(work.get("topic_name", "")),
		"播放" if str(work.get("form", "")) == "video" else "阅读",
		int(work.get("reach", 0)), int(work.get("engage", 0)), int(work.get("follow", 0)),
		float(scores.get("depth", 0)), float(scores.get("fun", 0)), float(scores.get("voice", 0)), float(scores.get("fit", 0)),
	]
	body += _report_text(result.get("report", {}))
	_consume_reports(result.get("report", {}))
	_fill([["title", "发出去了"], ["body", body], ["button", "看往期", _show_history], ["button", "回到房间", _close_page]])
	_refresh_hud()


func _show_history() -> void:
	_fill([])
	if selected_work < 0 or selected_work >= sim.works.size():
		selected_work = sim.works.size() - 1
	var board := HBoxContainer.new()
	board.add_theme_constant_override("separation", 16)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_box.add_child(board)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(340, 0)
	list.add_theme_constant_override("separation", 8)
	board.add_child(list)
	list.add_child(_label("往期", 28))
	if sim.works.is_empty():
		list.add_child(_wrap_label("还没有发出去的作品。"))
	else:
		for index in sim.works.size():
			var work: Dictionary = sim.works[index]
			var item := Button.new()
			item.custom_minimum_size = Vector2(320, 64)
			item.alignment = HORIZONTAL_ALIGNMENT_LEFT
			item.text = "第%d日  %s\n%s" % [int(work.get("born_day", 0)), "视频" if str(work.get("form", "")) == "video" else "文章", str(work.get("topic_name", ""))]
			item.pressed.connect(_select_work.bind(index))
			if index == selected_work:
				item.modulate = Color("F6E2A8")
			list.add_child(item)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var chart_button := Button.new()
	chart_button.text = "本周喜爱"
	chart_button.custom_minimum_size = Vector2(140, 44)
	chart_button.pressed.connect(_show_chart)
	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(100, 44)
	back.pressed.connect(_show_computer)
	actions.add_child(chart_button)
	actions.add_child(back)
	list.add_child(actions)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)
	board.add_child(detail)
	if sim.works.is_empty():
		detail.add_child(_wrap_label("发出一篇之后，这里会列出阅读或播放、互动、涨粉，以及每天到账的钱。"))
		return
	var work: Dictionary = sim.works[selected_work]
	var series: Array = sim.income_series(work)
	var today := 0
	var total := int(work.get("paid", 0))
	if not series.is_empty():
		var last: Dictionary = series[series.size() - 1]
		today = int(last.get("amount", 0))
		total = int(last.get("total", total))
	var form := "视频" if str(work.get("form", "")) == "video" else "文章"
	detail.add_child(_label("%s · %s" % [form, str(work.get("topic_name", ""))], 26))
	detail.add_child(_wrap_label("第%d日发出" % int(work.get("born_day", 0))))
	var reach_name := "播放" if form == "视频" else "阅读"
	detail.add_child(_wrap_label("%s %d    互动 %d    涨粉 %d" % [reach_name, int(work.get("reach", 0)), int(work.get("engage", 0)), int(work.get("follow", 0))]))
	detail.add_child(_wrap_label("当日 %s 金    累计 %s 金" % [sim.gold_text(today), sim.gold_text(total)]))
	var scores: Dictionary = work.get("scores", {})
	detail.add_child(_score_bar("深度", float(scores.get("depth", 0))))
	detail.add_child(_score_bar("趣味", float(scores.get("fun", 0))))
	detail.add_child(_score_bar("表达", float(scores.get("voice", 0))))
	detail.add_child(_score_bar("契合", float(scores.get("fit", 0))))
	if form == "视频":
		detail.add_child(_score_bar("声音", float(scores.get("audio", 0))))
	var fusion := _fusion_line(work)
	if fusion != "":
		detail.add_child(_wrap_label(fusion))
	var chart := IncomeChart.new()
	chart.custom_minimum_size = Vector2(420, 220)
	chart.points = series
	chart.cumulative = chart_cumulative
	detail.add_child(chart)
	var toggle := Button.new()
	toggle.text = "看每日" if chart_cumulative else "看累计"
	toggle.custom_minimum_size = Vector2(120, 40)
	toggle.pressed.connect(_toggle_income_chart)
	detail.add_child(toggle)


func _toggle_income_chart() -> void:
	chart_cumulative = not chart_cumulative
	_show_history()


func _select_work(index: int) -> void:
	selected_work = index
	_show_history()


func _show_chart() -> void:
	_fill([])
	page_box.add_child(_label("本周观众喜爱", 28))
	page_box.add_child(_wrap_label("这周大家更爱这些题材。靠前更好接，不是一定能成。下周会换。"))
	var rows: Array = sim.chart_rows()
	var top := 1
	if not rows.is_empty():
		top = maxi(1, int(rows[0].get("score", 1)))
	var rank := 1
	for row in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var name := _label("%d  %s" % [rank, str(row.get("name", ""))], 18)
		name.custom_minimum_size = Vector2(220, 0)
		name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		line.add_child(name)
		var bar := ProgressBar.new()
		bar.max_value = float(top)
		bar.value = float(row.get("score", 0))
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(220, 22)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(bar)
		page_box.add_child(line)
		rank += 1
	var back_row := HBoxContainer.new()
	var back := Button.new()
	back.text = "返回往期"
	back.custom_minimum_size = Vector2(140, 44)
	back.pressed.connect(_show_history)
	back_row.add_child(back)
	page_box.add_child(back_row)


func _show_items() -> void:
	var rows: Array = [["title", "背包"], ["body", "吃喝只恢复体力。提神饮料会让下一篇少耗一点体力。"]]
	var names := {"snack": "方便食品", "bento": "盒饭", "drink": "提神饮料"}
	for id in ["snack", "bento", "drink"]:
		rows.append(["button", "%s × %d" % [str(names[id]), int(sim.items.get(id, 0))], _use_item.bind(id)])
	rows.append(["button", "返回", _show_computer])
	_fill(rows)


func _do_gig() -> void:
	var result := sim.gig()
	_after_action(result, "短约")


func _rest() -> void:
	if sim == null:
		return
	var result := sim.rest(120)
	_after_action(result, "休息")


func _read() -> void:
	if sim == null:
		return
	var result := sim.read_home()
	_after_action(result, "阅读")


func _open_city() -> void:
	if sim == null or sim.phase != "playing":
		return
	mode = "city"
	sim.pose = "door"
	_apply_visuals()
	_show_map()


func _show_map() -> void:
	_use_place("map")
	_place_button("公园", Vector2(0.12, 0.50), _enter_place.bind("park"))
	_place_button("电影院", Vector2(0.30, 0.46), _enter_place.bind("cinema"))
	_place_button("图书馆", Vector2(0.46, 0.40), _enter_place.bind("library"))
	_place_button("商场", Vector2(0.62, 0.50), _enter_place.bind("mall"))
	_place_button("健身房", Vector2(0.80, 0.48), _enter_place.bind("gym"))
	_place_button("回到房间", Vector2(0.08, 0.12), _close_page)


func _use_place(id: String) -> void:
	page.visible = true
	if page_scroll != null:
		page_scroll.visible = false
	place_view.visible = true
	place_view.show_place(id)
	place_view.portrait = null
	place_view.mouse_filter = Control.MOUSE_FILTER_STOP
	place_view.queue_redraw()
	for child in place_view.get_children():
		place_view.remove_child(child)
		child.free()


func _place_button(text: String, anchor: Vector2, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(148, 52)
	button.size = Vector2(maxf(148, text.length() * 18.0), 52)
	button.position = place_view.spot(anchor)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", ThemeBuilder.button_style(Color("FFF8EE"), Color("2C241C"), 2))
	button.add_theme_stylebox_override("hover", ThemeBuilder.button_style(Color("F6E2A8"), Color("2C241C"), 2))
	button.add_theme_stylebox_override("pressed", ThemeBuilder.button_style(Color("E7C07B"), Color("2C241C"), 2))
	button.pressed.connect(callback)
	place_view.add_child(button)


func _enter_place(place_id: String) -> void:
	if place_id == "gym":
		_show_gym()
		return
	if place_id == "mall":
		_show_mall()
		return
	_use_place(place_id)
	var label := "逛一逛"
	if place_id == "cinema":
		label = "看一场"
	elif place_id == "library":
		label = "坐下来读"
	elif place_id == "park":
		label = "在长椅上坐一会儿"
	_place_button(label, Vector2(0.34, 0.78), _do_outing.bind(place_id))
	_place_button("返回地图", Vector2(0.08, 0.12), _show_map)


func _show_gym() -> void:
	_use_place("gym")
	var x := 0.12
	for pack in content.get("gym_packages", []):
		var id := str(pack.get("id", ""))
		_place_button("%s %s" % [str(pack.get("name", "")), sim.gold_text(int(pack.get("cost", 0)))], Vector2(x, 0.78), _do_gym.bind(id))
		x += 0.22
	_place_button("离开", Vector2(0.78, 0.12), _show_map)


func _show_mall() -> void:
	_use_place("mall")
	_place_button("先逛街", Vector2(0.08, 0.78), _mall_walk)
	var goods: Array = content.get("goods", [])
	var x := 0.28
	for good in goods:
		var id := str(good.get("id", ""))
		_place_button(str(good.get("name", id)), Vector2(x, 0.78), _do_buy.bind(id))
		x += 0.16
	_place_button("升级床", Vector2(0.08, 0.88), _do_upgrade.bind("bed"))
	_place_button("升级书桌", Vector2(0.28, 0.88), _do_upgrade.bind("desk"))
	_place_button("升级书架", Vector2(0.48, 0.88), _do_upgrade.bind("shelf"))
	_place_button("换租", Vector2(0.68, 0.88), _do_move)
	_place_button("买房", Vector2(0.84, 0.88), _do_buy_home)
	_place_button("离开", Vector2(0.82, 0.12), _show_map)


func _shop_result(result: Dictionary) -> void:
	_apply_visuals()
	_refresh_hud()
	_fill([["title", "商场"], ["body", "办成了。家具在新布局里原地换成更好的，不留下旧的。" if result.get("ok", false) else str(result.get("reason", "没办成"))], ["button", "继续看", _show_mall], ["button", "回家", _close_page]])


func _after_action(result: Dictionary, title: String) -> void:
	_sfx()
	_apply_pose()
	_refresh_hud()
	if bool(result.get("bankrupt", false)) or (sim != null and sim.phase != "playing"):
		_show_over()
		return
	var body := str(result.get("reason", "做完了。"))
	if result.get("ok", false):
		var event: Dictionary = result.get("event", {})
		if not event.is_empty():
			body += str(event.get("text", ""))
		body += _report_text(result.get("report", {}))
	_consume_reports(result.get("report", {}))
	page.visible = true
	mode = "note"
	_fill([["title", title], ["body", body], ["button", "回到房间", _close_page]])


func _consume_reports(report: Dictionary) -> void:
	if report.is_empty():
		return
	for item in report.get("reports", []):
		if bool(item.get("lost", false)):
			_autosave()
			return
		_autosave()
	_refresh_hud()


func _close_page() -> void:
	if sim != null and sim.phase != "playing":
		_show_over()
		return
	page.visible = false
	mode = "room"
	_apply_pose()
	_refresh_hud()


func _open_pause() -> void:
	if sim == null:
		_show_title()
		return
	mode = "pause"
	page.visible = true
	var rows: Array = [["title", "菜单"], ["body", sim.clock_text()], ["button", "继续", _close_page], ["button", "状态", _show_status], ["button", "存到槽 1", _save_slot.bind(1)], ["button", "存到槽 2", _save_slot.bind(2)], ["button", "存到槽 3", _save_slot.bind(3)], ["button", "读取槽 1", _load_slot.bind(1)], ["button", "读取槽 2", _load_slot.bind(2)], ["button", "读取槽 3", _load_slot.bind(3)], ["button", "读取每日自动档", _load_auto], ["button", "音效开", _set_sfx.bind(0.7)], ["button", "音效关", _set_sfx.bind(0.0)], ["button", "音乐开", _set_music.bind(0.35)], ["button", "音乐关", _set_music.bind(0.0)], ["button", "回到标题", _show_title]]
	_fill(rows)


func _save_slot(slot: int) -> void:
	var result := DiarySave.save_to_path(sim, DiarySave.manual_path(slot))
	_fill([["title", "存档"], ["body", "槽 %d 已保存。" % slot if result.get("ok", false) else str(result.get("message", ""))], ["button", "返回", _open_pause]])


func _load_slot(slot: int) -> void:
	var result := DiarySave.load_from_path(DiarySave.manual_path(slot), content)
	if not result.get("ok", false):
		_fill([["title", "读档"], ["body", str(result.get("message", ""))], ["button", "返回", _open_pause]])
		return
	sim = result["sim"]
	_apply_visuals()
	_close_page()


func _load_auto() -> void:
	var result := DiarySave.load_from_path(DiarySave.AUTO_PATH, content)
	if not result.get("ok", false):
		_fill([["title", "自动档"], ["body", str(result.get("message", "还没有自动档"))], ["button", "返回", _show_title if sim == null else _open_pause]])
		return
	sim = result["sim"]
	if sim.phase != "playing":
		_show_over()
		return
	_close_page()


func _autosave() -> void:
	if sim == null:
		return
	DiarySave.save_to_path(sim, DiarySave.AUTO_PATH)


func _show_over() -> void:
	mode = "over"
	page.visible = true
	_refresh_hud()
	_autosave()
	var body := sim.loss_reason if sim != null else ""
	body += "\n存活到 %s。粉丝 %d，作品 %d，现金 %s。" % [sim.clock_text(), sim.fans, sim.works.size(), sim.gold_text(sim.money)]
	body += "\n自动档停在失败这一下，不能当成第二天继续。手动档还在。"
	_fill([["title", "这期没撑住"], ["body", body], ["button", "读取槽 1", func(): _load_slot(1)], ["button", "回到标题", _show_title]])


func _apply_pose() -> void:
	_apply_visuals()


func _wide_home() -> bool:
	return sim != null and (sim.house_tier >= 2 or sim.owned_home)


func _apply_visuals() -> void:
	if room_view == null:
		return
	var wide := _wide_home()
	var bed_level := 1 if sim == null else int(sim.furniture.get("bed", 1))
	var desk_level := 1 if sim == null else int(sim.furniture.get("desk", 1))
	var shelf_level := 1 if sim == null else int(sim.furniture.get("shelf", 1))
	var bed_name := "bed%s%s" % ["_b" if wide else "", "_l2" if bed_level >= 2 else ""]
	var shelf_name := "shelf%s" % ["_l2" if shelf_level >= 2 else ""]
	var chair_name := "chair%s" % ["_b" if wide else ""]
	var desk_name := "desk_front"
	if wide and desk_level >= 2:
		desk_name = "desk_b_l2"
	elif wide:
		desk_name = "desk_b"
	elif desk_level >= 2:
		desk_name = "desk_l2"
	room_view.set_pair("shell", "res://assets/room/layers/shell.png", "")
	room_view.set_pair("bed", "res://assets/room/layers/%s.png" % bed_name, "res://assets/room/layers/%s_z.png" % bed_name)
	room_view.set_pair("shelf", "res://assets/room/layers/%s.png" % shelf_name, "res://assets/room/layers/%s_z.png" % shelf_name)
	room_view.set_pair("chair", "res://assets/room/layers/%s.png" % chair_name, "res://assets/room/layers/%s_z.png" % chair_name)
	room_view.set_pair("desk", "res://assets/room/layers/%s.png" % desk_name, "res://assets/room/layers/%s_z.png" % desk_name)
	room_view.set_pair("cat", "res://assets/room/layers/cat.png", "res://assets/room/layers/cat_z.png")
	var who := "m" if (sim != null and sim.gender == "m") or (sim == null and gender == "m") else "f"
	var pose := "sit"
	if sim != null:
		match sim.pose:
			"bed":
				pose = "bed"
			"read":
				pose = "read"
			"door":
				pose = "door"
			"cat":
				pose = "cat"
	var suffix := ""
	if wide and (pose == "sit" or pose == "bed"):
		suffix = "_b"
	var char_name := "char_%s_%s%s" % [who, pose, suffix]
	if not FileAccess.file_exists("res://assets/room/layers/%s.png" % char_name):
		char_name = "char_%s_%s" % [who, pose]
	room_view.set_pair("char", "res://assets/room/layers/%s.png" % char_name, "res://assets/room/layers/%s_z.png" % char_name)
	_place_hotspots(wide)


func _set_tex(rect: TextureRect, path: String) -> bool:
	if rect == null:
		return false
	var texture: Resource = load(path)
	if texture is Texture2D:
		rect.texture = texture
		return true
	return false


func _place_hotspots(wide: bool) -> void:
	var file := FileAccess.open("res://assets/room/hotspot_anchors.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text() if file else "{}")
	var pack: Dictionary = {}
	if typeof(parsed) == TYPE_DICTIONARY:
		pack = parsed.get("rects_b", {}) if wide else parsed.get("rects", {})
	for id in hotspots.keys():
		var button: Button = hotspots[id]
		var rect: Array = pack.get(id, [400, 400, 160, 80])
		button.position = Vector2(float(rect[0]), float(rect[1]))
		button.size = Vector2(float(rect[2]), float(rect[3]))
		button.custom_minimum_size = button.size
		var chip := button.get_node_or_null("chip")
		if chip is Control:
			chip.position = Vector2(maxf(8.0, button.size.x * 0.5 - 56.0), 6.0)
			var marked := _chip_on(id)
			chip.modulate = Color("F6E2A8") if marked else Color.WHITE


func _center_on(pixel: Vector2) -> void:
	zoom = 0.62
	world.scale = Vector2(zoom, zoom)
	world.position = get_size() * 0.5 - pixel * zoom


func _world_input(event: InputEvent) -> void:
	if mode != "room" or page.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom(0.08)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom(-0.08)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			panning = false
			press_pos = event.position
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		if event.position.distance_to(press_pos) > 10.0:
			panning = true
		if panning:
			world.position += event.relative


func _zoom(delta: float) -> void:
	var before := zoom
	zoom = clampf(zoom + delta, 0.35, 1.15)
	var focus := get_local_mouse_position()
	var world_point := (focus - world.position) / before
	world.scale = Vector2(zoom, zoom)
	world.position = focus - world_point * zoom


func _refresh_hud() -> void:
	if sim == null:
		hud_time.text = "尚未开局"
		hud_money.text = ""
		hud_body.text = ""
		hud_idea.text = ""
		hud_fans.text = ""
		hud_bill.text = ""
		if hud_loan != null:
			hud_loan.text = ""
		return
	hud_time.text = sim.clock_text()
	hud_money.text = "现金  %s 金" % sim.gold_text(sim.money)
	hud_body.text = "体力 %d/%d" % [sim.stamina, sim.stamina_max]
	hud_idea.text = "灵感 %d" % sim.inspiration
	hud_fans.text = "粉丝 %d" % sim.fans
	hud_bill.text = sim.next_rent_text()
	hud_loan.text = sim.next_loan_text()


func _chart_line() -> String:
	var rows := sim.chart_rows()
	if rows.is_empty():
		return "还没有"
	return str(rows[0].get("name", ""))


func _stat(icon_path: String, label: Label) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture: Resource = load(icon_path)
	if texture is Texture2D:
		icon.texture = texture
	row.add_child(icon)
	row.add_child(label)
	return row


func _chip_on(id: String) -> bool:
	if sim == null:
		return false
	match id:
		"bed":
			return sim.pose == "bed"
		"bookshelf":
			return sim.pose == "read"
		"computer":
			return sim.pose == "sit"
		"door":
			return sim.pose == "door" or mode == "city"
		"cat":
			return sim.pose == "cat"
	return false


func _pet_cat() -> void:
	if sim == null:
		return
	_after_action(sim.pet_cat(), "逗猫")


func _hud_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("2C241C"))
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return label


func _wrap_label(text: String) -> Label:
	var label := _hud_label(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _hot_style(alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 0.96, 0.88, alpha)
	box.set_corner_radius_all(12)
	box.set_border_width_all(0)
	return box


func _hover_slot(id: String) -> int:
	match id:
		"bed":
			return 1
		"bookshelf":
			return 2
		"computer":
			return 3
		"door":
			return 4
		"cat":
			return 5
	return 0


func _score_bar(title: String, value: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name := _hud_label(title)
	name.custom_minimum_size = Vector2(52, 0)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(160, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	row.add_child(bar)
	row.add_child(_hud_label("%.0f" % value))
	return row


func _fusion_line(work: Dictionary) -> String:
	var note := str(work.get("note", ""))
	if note.find("缺过渡") >= 0:
		return "融梗：没接上"
	if note.find("火花") >= 0:
		return "融梗：只接上一部分"
	if note.find("接上了") >= 0:
		return "融梗：接上了"
	var memes: Array = work.get("memes", [])
	if memes.is_empty():
		return "这篇没有放梗"
	return ""


func _text_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 48)
	button.pressed.connect(callback)
	return button


func _pick_card(icon_path: String, title: String, subtitle: String, tint: Color, callback: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(210, 118)
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	var fill := ThemeBuilder.button_style(tint, Color("2C241C"), 2)
	fill.content_margin_left = 14
	fill.content_margin_right = 14
	fill.content_margin_top = 10
	fill.content_margin_bottom = 10
	button.add_theme_stylebox_override("normal", fill)
	button.add_theme_stylebox_override("hover", ThemeBuilder.button_style(tint.lightened(0.06), Color("2C241C"), 2))
	button.add_theme_stylebox_override("pressed", ThemeBuilder.button_style(tint.darkened(0.06), Color("2C241C"), 2))
	button.add_theme_stylebox_override("focus", fill)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	button.add_child(box)
	if icon_path != "":
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var texture: Resource = load(icon_path)
		if texture is Texture2D:
			icon.texture = texture
		box.add_child(icon)
	var title_label := _label(title, 20)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_label)
	if subtitle != "":
		var sub := _label(subtitle, 14)
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub.add_theme_color_override("font_color", Color("5C5348"))
		box.add_child(sub)
	button.pressed.connect(callback)
	return button


func _label(text: String, size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _sfx() -> void:
	if click_player == null:
		return
	click_player.volume_db = linear_to_db(maxf(0.001, float(settings.get("sfx", 0.7))))
	click_player.play()


func _tone(freq: float, ms: int) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * float(ms) / 1000.0)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var env := 1.0 - float(i) / float(count)
		var sample := int(sin(TAU * freq * float(i) / float(rate)) * 8000.0 * env)
		data[i * 2] = sample & 255
		data[i * 2 + 1] = (sample >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://diary_settings.cfg") == OK:
		settings["sfx"] = float(config.get_value("audio", "sfx", 0.7))
		settings["music"] = float(config.get_value("audio", "music", 0.35))
		seen_tutor = bool(config.get_value("meta", "tutor", false))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "sfx", float(settings.get("sfx", 0.7)))
	config.set_value("audio", "music", float(settings.get("music", 0.35)))
	config.set_value("meta", "tutor", seen_tutor)
	config.save("user://diary_settings.cfg")


func _report_text(report: Dictionary) -> String:
	var text := ""
	for item in report.get("reports", []):
		var income := int(item.get("income", 0))
		if income > 0:
			text += "\n跨过第%d日，作品继续到账 %s。" % [int(item.get("ended", 0)), sim.gold_text(income)]
		if int(item.get("rent", 0)) > 0:
			text += "交租 %s。" % sim.gold_text(int(item.get("rent", 0)))
		if int(item.get("loan", 0)) > 0:
			text += "还贷 %s。" % sim.gold_text(int(item.get("loan", 0)))
	return text


func _hot_hover(id: String, _button: Button, entered: bool) -> void:
	if entered:
		selected = id
		if room_view != null:
			room_view.set_hover(_hover_slot(id))
	else:
		if selected == id:
			selected = ""
			if room_view != null:
				room_view.set_hover(0)


func _hot_input(event: InputEvent, id: String, button: Button) -> void:
	if mode != "room" or page.visible:
		return
	if event is InputEventMouseMotion and dragging:
		var motion := event as InputEventMouseMotion
		if motion.position.distance_to(press_pos) > 10.0:
			panning = true
		if panning:
			world.position += motion.relative
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			dragging = true
			panning = false
			press_pos = click.position
			selected = id
			button.modulate = Color("F6E2A8")
		else:
			var moved: bool = click.position.distance_to(press_pos) > 10.0
			dragging = false
			if not moved and not panning:
				_sfx()
				_dismiss_tutor()
				var action: Callable = button.get_meta("action")
				action.call()


func _dismiss_tutor() -> void:
	if tutor_wrap != null:
		tutor_wrap.visible = false
	if not seen_tutor:
		seen_tutor = true
		_save_settings()


func _use_item(id: String) -> void:
	var used := sim.use_item(id)
	var body := "体力 %+d。" % int(used.get("gain", 0)) if used.get("ok", false) else str(used.get("reason", ""))
	_fill([["title", "吃了" if used.get("ok", false) else "没用成"], ["body", body], ["button", "返回", _show_items]])
	_refresh_hud()


func _show_status() -> void:
	if sim == null:
		return
	var home := "自有住房" if sim.owned_home else ("第二套出租" if sim.house_tier >= 2 else "最小出租屋")
	var body := "%s\n体力 %d/%d  灵感 %d  表达 %.0f  观察 %.0f  手艺 %.0f  体能 %.0f\n信任 %.0f  粉丝 %d\n床 %d  书桌 %d  书架 %d  · %s\n%s\n%s" % [
		sim.player_name, sim.stamina, sim.stamina_max, sim.inspiration, sim.expression, sim.observation, sim.craft, sim.fitness,
		sim.trust, sim.fans, int(sim.furniture.get("bed", 1)), int(sim.furniture.get("desk", 1)), int(sim.furniture.get("shelf", 1)), home,
		sim.next_rent_text(), sim.next_loan_text(),
	]
	_fill([["title", "状态"], ["body", body], ["button", "本周喜爱", _show_chart], ["button", "返回", _open_pause]])


func _set_sfx(value: float) -> void:
	settings["sfx"] = value
	_save_settings()
	_sfx()


func _set_music(value: float) -> void:
	settings["music"] = value
	_save_settings()
	if music_player == null:
		return
	music_player.volume_db = linear_to_db(maxf(0.001, value))
	if value > 0.0 and not music_player.playing:
		music_player.play()
	if value <= 0.0:
		music_player.stop()


func _mall_walk() -> void:
	_after_action(sim.go_out("mall"), "逛街")


func _do_outing(place_id: String) -> void:
	_after_action(sim.go_out(place_id), "外出")


func _do_upgrade(slot: String) -> void:
	_shop_result(sim.upgrade(slot))


func _do_move() -> void:
	_shop_result(sim.move_house())


func _do_buy_home() -> void:
	_shop_result(sim.buy_home())


func _set_topic(id: String) -> void:
	topic_id = id
	_show_memes()


func _toggle_meme(id: String) -> void:
	if chosen_memes.has(id):
		chosen_memes.erase(id)
	elif chosen_memes.size() < 8:
		chosen_memes.append(id)
	_show_memes()


func _do_gym(id: String) -> void:
	_after_action(sim.gym(id), "健身")


func _do_buy(id: String) -> void:
	_shop_result(sim.buy_good(id))


func _clear_hover() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(6, 6)
	motion.global_position = Vector2(6, 6)
	get_viewport().push_input(motion)
	selected = ""
	if room_view != null:
		room_view.set_hover(0)


func _shot_tour() -> void:
	var shots := ShotUtil.new()
	add_child(shots)
	await shots.capture(self, "01_title")
	if name_edit != null:
		name_edit.text = "小林"
	gender = "f"
	_start_game()
	await shots.capture(self, "02_room_sit")
	await shots.capture(self, "quality_fix_sit")
	_show_history()
	await shots.capture(self, "quality_fix_history_empty")
	_close_page()
	await shots.click(self, "hot_bed")
	await shots.capture(self, "03_rest_note")
	_close_page()
	_clear_hover()
	await get_tree().process_frame
	await shots.capture(self, "04_bed")
	await shots.capture(self, "quality_fix_bed")
	sim.read_home()
	_close_page()
	_clear_hover()
	await get_tree().process_frame
	await shots.capture(self, "05_read")
	await shots.capture(self, "quality_fix_read")
	sim.pet_cat()
	_apply_visuals()
	_close_page()
	_clear_hover()
	await get_tree().process_frame
	await shots.capture(self, "05b_cat")
	_open_city()
	await shots.capture(self, "06_city")
	_enter_place("park")
	await shots.capture(self, "07_park")
	_enter_place("cinema")
	await shots.capture(self, "08_cinema")
	_enter_place("library")
	await shots.capture(self, "08b_library")
	_show_gym()
	await shots.capture(self, "09_gym")
	_show_mall()
	await shots.capture(self, "10_mall")
	_close_page()
	_show_create()
	await shots.capture(self, "11b_create")
	_show_topics()
	await shots.capture(self, "11c_topics")
	_close_page()
	sim.gender = "m"
	sim.pose = "sit"
	_apply_visuals()
	await shots.capture(self, "11_male")
	sim.pose = "bed"
	_apply_visuals()
	await shots.capture(self, "11d_male_bed")
	sim.pose = "sit"
	sim.gender = "f"
	sim.inspiration = 90
	sim.stamina = 90
	var made := sim.confirm_work("article", "life", [], "串联", "none")
	sim.advance_time(DiarySim.DAY * 3)
	sim.works_today = 0
	sim.inspiration = 80
	sim.stamina = 80
	sim.confirm_work("video", "film", [], "串联", "short")
	sim.advance_time(DiarySim.DAY)
	_refresh_hud()
	selected_work = 0
	_show_history()
	await shots.capture(self, "12_history")
	await shots.capture(self, "quality_fix_history")
	_show_chart()
	await shots.capture(self, "13_chart")
	await shots.capture(self, "quality_fix_chart")
	sim.money = 9000 * DiarySim.GOLD
	sim.upgrade("bed")
	sim.upgrade("desk")
	sim.upgrade("shelf")
	sim.move_house()
	sim.pose = "sit"
	_apply_visuals()
	_close_page()
	await shots.capture(self, "14_layout_b")
	sim.pose = "bed"
	_apply_visuals()
	await shots.capture(self, "15_layout_b_bed")
	_open_pause()
	await shots.capture(self, "16_pause")
	sim.money = 0
	sim.works.clear()
	sim.ledger.clear()
	sim.clock_minutes = 7 * DiarySim.DAY - 20
	sim.last_settled = 6 * DiarySim.DAY
	sim.advance_time(60)
	if sim.phase != "playing":
		_show_over()
	await shots.capture(self, "17_gameover")
	print("SHOT_TOUR made=", made.get("ok", false), " phase=", sim.phase)
	get_tree().quit()


func _quit() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if mode == "room":
			_open_pause()
		elif mode != "title" and mode != "over":
			_close_page()
		get_viewport().set_input_as_handled()
