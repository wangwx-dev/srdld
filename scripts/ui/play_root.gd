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
var shell_layer: TextureRect
var bed_layer: TextureRect
var shelf_layer: TextureRect
var chair_layer: TextureRect
var char_layer: TextureRect
var desk_layer: TextureRect
var hotspots: Dictionary = {}
var hud_time: Label
var hud_money: Label
var hud_body: Label
var hud_bill: Label
var page: Control
var page_scroll: Control
var page_box: VBoxContainer
var place_view: PlaceView
var tutor: Label
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
		await _shot_tour()


func _load_content() -> Dictionary:
	var file := FileAccess.open("res://data/diary_content.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _build_world() -> void:
	world = Control.new()
	world.position = Vector2(80, 40)
	world.size = CANVAS
	world.scale = Vector2(zoom, zoom)
	add_child(world)
	var catch := ColorRect.new()
	catch.color = Color(0, 0, 0, 0)
	catch.size = CANVAS
	catch.gui_input.connect(_world_input)
	world.add_child(catch)
	shell_layer = _layer("res://assets/room/layers/shell.png")
	bed_layer = _layer("res://assets/room/layers/bed.png")
	shelf_layer = _layer("res://assets/room/layers/shelf.png")
	chair_layer = _layer("res://assets/room/layers/chair.png")
	char_layer = _layer("res://assets/room/layers/char_f_sit.png")
	desk_layer = _layer("res://assets/room/layers/desk_front.png")
	var anchors := _anchors()
	_hotspot("创作", "computer", anchors["computer"], _open_computer)
	_hotspot("休息", "bed", anchors["bed"], _rest)
	_hotspot("阅读", "bookshelf", anchors["bookshelf"], _read)
	_hotspot("出门", "door", anchors["door"], _open_city)


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


func _hotspot(text: String, id: String, spec: Dictionary, callback: Callable) -> void:
	var pixel: Array = spec.get("pixel", [100, 100])
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(96, 44)
	button.size = Vector2(96, 44)
	button.position = Vector2(float(pixel[0]), float(pixel[1])) - Vector2(48, 62)
	button.set_meta("ui_id", "hot_%s" % id)
	button.set_meta("action", callback)
	button.mouse_entered.connect(_hot_hover.bind(id, button, true))
	button.mouse_exited.connect(_hot_hover.bind(id, button, false))
	button.gui_input.connect(_hot_input.bind(id, button))
	world.add_child(button)
	hotspots[id] = button


func _build_page() -> void:
	page = ColorRect.new()
	page.color = Color(0.96, 0.93, 0.88, 0.94)
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.visible = false
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(page)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 64)
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
	var hud := HBoxContainer.new()
	hud.add_theme_constant_override("separation", 12)
	add_child(hud)
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.offset_left = 12
	hud.offset_top = 8
	hud.offset_right = -12
	hud.offset_bottom = 56
	hud_time = _label("时间")
	hud_money = _label("钱")
	hud_body = _label("状态")
	hud_bill = _label("账单")
	hud.add_child(hud_time)
	hud.add_child(hud_money)
	hud.add_child(hud_body)
	hud.add_child(hud_bill)
	tutor = _label("点家具上的字。拖空白处移动房间，滚轮缩放。拖动超过一小段不会误触。", 15)
	tutor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutor.visible = false
	tutor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tutor.offset_left = 16
	tutor.offset_right = -16
	tutor.offset_top = -64
	tutor.offset_bottom = -12
	add_child(tutor)
	var pause := Button.new()
	pause.text = "菜单"
	pause.custom_minimum_size = Vector2(88, 44)
	pause.pressed.connect(_open_pause)
	hud.add_child(pause)


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
	tutor.visible = not seen_tutor
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
	var rows: Array = [["title", "新作品"], ["body", "形式、题材、梗和打磨。预览不揭开这次能不能融住。"]]
	rows.append(["button", "文章 · 3 小时", func(): form = "article"; _show_topics()])
	rows.append(["button", "视频 · 5 小时", func(): form = "video"; _show_topics()])
	rows.append(["button", "返回", _show_computer])
	_fill(rows)


func _show_topics() -> void:
	var rows: Array = [["title", "选题"], ["body", "榜上的话题更受欢迎，但追榜不是必成。"]]
	for topic in content.get("topics", []):
		var id := str(topic.get("id", ""))
		var mark := " · 本周喜爱" if sim._on_chart(id) else ""
		rows.append(["button", str(topic.get("name", id)) + mark, _set_topic.bind(id)])
	rows.append(["button", "返回", _show_create])
	_fill(rows)


func _show_memes() -> void:
	var rows: Array = [["title", "要不要融梗"], ["body", "可以不放。放得合拍，成功时上限更高；放得乱，会伤表达。没有条数上限，列表最多带着 8 条进这篇。"]]
	var shown := 0
	for owned in sim.memes:
		if shown >= 8:
			break
		var spec := sim.meme_def(str(owned.get("id", "")))
		var id := str(owned.get("id", ""))
		var label := "%s · 热度 %.0f%s" % [str(spec.get("name", id)), sim.heat_of(owned), " · 已选" if chosen_memes.has(id) else ""]
		rows.append(["button", label, _toggle_meme.bind(id)])
		shown += 1
	if sim.memes.is_empty():
		rows.append(["body", "你还没有梗。可以先出门，也可以直接写。"])
	rows.append(["body", "已选 %d 条" % chosen_memes.size()])
	rows.append(["button", "主题串联", func(): link = "串联"; _show_polish()])
	rows.append(["button", "对照反差", func(): link = "反差"; _show_polish()])
	rows.append(["button", "旁敲侧击", func(): link = "侧击"; _show_polish()])
	rows.append(["button", "生硬堆砌", func(): link = "堆砌"; _show_polish()])
	rows.append(["button", "返回", _show_topics])
	_fill(rows)


func _show_polish() -> void:
	var rows: Array = [["title", "打磨"], ["button", "不额外打磨", func(): polish = "none"; _show_preview()], ["button", "短铺垫", func(): polish = "short"; _show_preview()], ["button", "认真理顺", func(): polish = "careful"; _show_preview()], ["button", "返回", _show_memes]]
	_fill(rows)


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
	var body := "传播 %d · 互动 %d · 涨粉 %d\n深度 %.0f · 趣味 %.0f · 表达 %.0f · 契合 %.0f\n整段收益预计 %s，之后每天到账，前几天多，后面只剩薄薄一层。\n%s" % [
		int(work.get("reach", 0)), int(work.get("engage", 0)), int(work.get("follow", 0)),
		float(scores.get("depth", 0)), float(scores.get("fun", 0)), float(scores.get("voice", 0)), float(scores.get("fit", 0)),
		sim.gold_text(int(work.get("lifetime", 0))), str(work.get("note", "")),
	]
	body += _report_text(result.get("report", {}))
	_consume_reports(result.get("report", {}))
	_fill([["title", "发出去了"], ["body", body], ["button", "看往期", _show_history], ["button", "回到房间", _close_page]])
	_refresh_hud()


func _show_history() -> void:
	var rows: Array = [["title", "往期"], ["body", "粉丝 %d · 信任 %.0f。每篇的钱按天继续进账，不会在第三天清零。" % [sim.fans, sim.trust]]]
	var start := maxi(0, sim.works.size() - 8)
	for index in range(start, sim.works.size()):
		var work: Dictionary = sim.works[index]
		rows.append(["body", "第%d日 %s《%s》已到账 %s / 预计 %s。%s" % [
			int(work.get("born_day", 0)), "视频" if str(work.get("form", "")) == "video" else "文章",
			str(work.get("topic_name", "")), sim.gold_text(int(work.get("paid", 0))),
			sim.gold_text(int(work.get("lifetime", 0))), str(work.get("note", "")),
		]])
	if sim.works.is_empty():
		rows.append(["body", "还没有作品。"])
	rows.append(["button", "本周喜爱", _show_chart])
	rows.append(["button", "返回", _show_computer])
	_fill(rows)


func _show_chart() -> void:
	var rows: Array = [["title", "本周观众喜爱"], ["body", "用来选题。排前面只是更好接，不是必火。每周换一次，写在存档里。"]]
	var rank := 1
	for row in sim.chart_rows():
		rows.append(["body", "%d. %s" % [rank, str(row.get("name", ""))]])
		rank += 1
	rows.append(["button", "返回", _show_history])
	_fill(rows)


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
	_place_button("公园", Vector2(0.16, 0.62), _enter_place.bind("park"))
	_place_button("电影院", Vector2(0.36, 0.58), _enter_place.bind("cinema"))
	_place_button("商场", Vector2(0.58, 0.60), _enter_place.bind("mall"))
	_place_button("健身房", Vector2(0.78, 0.66), _enter_place.bind("gym"))
	_place_button("图书馆", Vector2(0.47, 0.78), _enter_place.bind("library"))
	_place_button("回到房间", Vector2(0.08, 0.12), _close_page)


func _use_place(id: String) -> void:
	page.visible = true
	if page_scroll != null:
		page_scroll.visible = false
	place_view.visible = true
	place_view.place_id = id
	place_view.portrait = char_layer.texture if char_layer != null else null
	place_view.mouse_filter = Control.MOUSE_FILTER_STOP
	place_view.queue_redraw()
	for child in place_view.get_children():
		place_view.remove_child(child)
		child.free()


func _place_button(text: String, anchor: Vector2, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 48)
	button.size = Vector2(140, 48)
	button.position = place_view.spot(anchor)
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
	var wide := _wide_home()
	var bed_level := 1 if sim == null else int(sim.furniture.get("bed", 1))
	var desk_level := 1 if sim == null else int(sim.furniture.get("desk", 1))
	var shelf_level := 1 if sim == null else int(sim.furniture.get("shelf", 1))
	_set_tex(shell_layer, "res://assets/room/layers/shell.png")
	_set_tex(bed_layer, "res://assets/room/layers/bed%s%s.png" % ["_b" if wide else "", "_l2" if bed_level >= 2 else ""])
	_set_tex(shelf_layer, "res://assets/room/layers/shelf%s.png" % ["_l2" if shelf_level >= 2 else ""])
	_set_tex(chair_layer, "res://assets/room/layers/chair%s.png" % ["_b" if wide else ""])
	var desk_name := "desk_front"
	if wide and desk_level >= 2:
		desk_name = "desk_b_l2"
	elif wide:
		desk_name = "desk_b"
	elif desk_level >= 2:
		desk_name = "desk_l2"
	_set_tex(desk_layer, "res://assets/room/layers/%s.png" % desk_name)
	if char_layer == null:
		return
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
	var suffix := ""
	if wide and (pose == "sit" or pose == "bed"):
		suffix = "_b"
	var path := "res://assets/room/layers/char_%s_%s%s.png" % [who, pose, suffix]
	if not _set_tex(char_layer, path):
		_set_tex(char_layer, "res://assets/room/layers/char_%s_%s.png" % [who, pose])
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
		pack = parsed.get("anchors_b", {}) if wide else parsed.get("anchors", {})
	for id in hotspots.keys():
		var button: Button = hotspots[id]
		var spec: Dictionary = pack.get(id, {})
		var pixel: Array = spec.get("pixel", [400, 400])
		button.position = Vector2(float(pixel[0]), float(pixel[1])) - Vector2(48, 62)
		button.text = str(spec.get("label", button.text))


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
		hud_bill.text = ""
		return
	hud_time.text = sim.clock_text()
	hud_money.text = sim.gold_text(sim.money)
	hud_body.text = "体力 %d/%d  灵感 %d  粉 %d" % [sim.stamina, sim.stamina_max, sim.inspiration, sim.fans]
	hud_bill.text = "%s  %s" % [sim.next_rent_text(), sim.next_loan_text()]


func _chart_line() -> String:
	var rows := sim.chart_rows()
	if rows.is_empty():
		return "还没有"
	return str(rows[0].get("name", ""))


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


func _hot_hover(id: String, button: Button, entered: bool) -> void:
	if entered:
		selected = id
		button.modulate = Color("F6E2A8")
	else:
		if selected == id:
			selected = ""
		button.modulate = Color.WHITE


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
	if tutor != null:
		tutor.visible = false
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


func _shot_tour() -> void:
	var shots := ShotUtil.new()
	add_child(shots)
	await shots.capture(self, "01_title")
	if name_edit != null:
		name_edit.text = "小林"
	gender = "f"
	_start_game()
	await shots.capture(self, "02_room_sit")
	await shots.click(self, "hot_bed")
	await shots.capture(self, "03_rest_note")
	_close_page()
	await shots.capture(self, "04_bed")
	sim.read_home()
	_close_page()
	await shots.capture(self, "05_read")
	_open_city()
	await shots.capture(self, "06_city")
	_enter_place("park")
	await shots.capture(self, "07_park")
	_enter_place("cinema")
	await shots.capture(self, "08_cinema")
	_show_gym()
	await shots.capture(self, "09_gym")
	_show_mall()
	await shots.capture(self, "10_mall")
	_close_page()
	sim.gender = "m"
	sim.pose = "sit"
	_apply_visuals()
	await shots.capture(self, "11_male")
	sim.gender = "f"
	sim.inspiration = 90
	sim.stamina = 90
	var made := sim.confirm_work("article", "life", [], "串联", "none")
	sim.advance_time(DiarySim.DAY * 3)
	_refresh_hud()
	_show_history()
	await shots.capture(self, "12_history")
	_show_chart()
	await shots.capture(self, "13_chart")
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
	print("SHOT_TOUR made=", made.get("ok", false))
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
