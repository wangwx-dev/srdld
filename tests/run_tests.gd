extends Node

var failures: Array[String] = []
var checks := 0


func _ready() -> void:
	print("SRDLD tests")
	_test_catalog()
	_test_rng()
	_test_formulas()
	_test_day_and_actions()
	_test_publish_and_preview()
	_test_bills_loss_win()
	_test_determinism()
	_test_economy_bounds()
	_test_save_roundtrip()
	_test_corrupt_saves()
	_test_strategies()
	_test_font()
	await _test_scenes()
	print("CHECKS %d FAILURES %d" % [checks, failures.size()])
	for failure in failures:
		print("FAIL ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _test_catalog() -> void:
	var catalog := Catalog.load_default()
	check(catalog.problems.is_empty(), "catalog valid: %s" % str(catalog.problems))
	check(catalog.platforms.size() == 3, "three platforms")
	check(catalog.topics.size() >= 8, "enough topics")
	check(catalog.events.size() >= 8, "enough events")
	check(int(catalog.balance["days"]) == 30, "30 day month")


func _test_rng() -> void:
	var rng := SimRng.new(1)
	check(rng.next_u32() == 1103527590, "lcg first value")
	var again := SimRng.new(1)
	var other := SimRng.new(2)
	check(again.next_u32() == 1103527590, "same seed repeats")
	check(other.next_u32() != 1103527590, "different seed diverges")


func _test_formulas() -> void:
	var catalog := Catalog.load_default()
	var matched := _context(catalog, "美食", 0.0, 1.0)
	var missed := _context(catalog, "故事", 0.0, 1.0)
	var tired := _context(catalog, "美食", 80.0, 1.0)
	var low := _context(catalog, "美食", 0.0, float(catalog.balance["variance_min"]))
	var high := _context(catalog, "美食", 0.0, float(catalog.balance["variance_max"]))
	var a := Formulas.compute(matched)
	var b := Formulas.compute(matched)
	check(a["views"] == b["views"] and a["ad_money"] == b["ad_money"], "formula is pure")
	check(int(a["views"]) > int(Formulas.compute(missed)["views"]), "on-trend earns more reach")
	check(int(a["views"]) > int(Formulas.compute(tired)["views"]), "fatigue lowers reach")
	check(int(Formulas.compute(low)["views"]) <= int(Formulas.compute(high)["views"]), "variance band is ordered")
	check(_factor(a, "trend")["matched"] == true, "trend match is explained")
	check(float(_factor(a, "trend")["amount"]) > 1.0, "trend match multiplier above 1")
	check(float(_factor(Formulas.compute(missed), "trend")["amount"]) < 1.0, "trend miss multiplier below 1")
	check(float(_factor(Formulas.compute(tired), "fatigue")["amount"]) < float(_factor(a, "fatigue")["amount"]), "fatigue factor drops")
	check(int(a["views"]) >= int(a["view_low"]) and int(a["views"]) <= int(a["view_high"]), "mid view sits inside the band")
	var sponsored := _context(catalog, "美食", 0.0, 1.0)
	sponsored["as_sponsor"] = true
	sponsored["contract"] = {"pay": 560, "tag": "美食", "platform": "shizi", "brand": "清泉汽水"}
	var good := Formulas.compute(sponsored)
	check(str(good["sponsor_note"]) == "great" or str(good["sponsor_note"]) == "ok", "matching sponsor is explained")
	check(int(good["sponsor_pay"]) > 0, "matching sponsor pays")
	sponsored["contract"] = {"pay": 560, "tag": "数码", "platform": "changhe", "brand": "墨白课堂"}
	var off := Formulas.compute(sponsored)
	check(str(off["sponsor_note"]) == "mismatch", "off-brand sponsor is named")
	check(int(off["sponsor_pay"]) < 560, "off-brand sponsor pays less")
	check(float(off["sponsor_rep"]) < 0.0, "off-brand sponsor costs trust")


func _test_day_and_actions() -> void:
	var catalog := Catalog.load_default()
	var sim := CareerSim.create_new(catalog, 11)
	_silence(sim)
	_drain(sim)
	sim.stamina = 40
	sim.stress = 50
	sim.mood = 40
	sim.inspiration = 20
	sim.actions_left = 3
	var rest: Dictionary = catalog.balance["actions"]["rest"]
	var result := sim.rest()
	check(result["ok"], "rest succeeds")
	check(is_equal_approx(sim.stamina, 40.0 + float(rest["stamina"])), "rest restores stamina")
	check(is_equal_approx(sim.stress, 50.0 + float(rest["stress"])), "rest lowers stress")
	check(sim.actions_left == 2, "rest spends an action")
	sim.actions_left = 0
	check(sim.rest()["code"] == "no_actions", "no actions left")
	sim.actions_left = 1
	sim.pending_event = {"id": "x", "text": "测试", "choices": [{"id": "ok", "label": "知道了", "effects": {}}]}
	check(sim.rest()["code"] == "pending_event", "event blocks actions")
	check(sim.resolve_event("ok")["ok"], "event can be resolved")
	check(sim.pending_event.is_empty(), "event clears")
	sim.stamina = 50
	sim.inspiration = 10
	sim.mood = 40
	sim.stress = 40
	sim.money = 200
	sim.actions_left = 2
	var before := sim.actions_left
	check(sim.outing()["ok"], "outing succeeds")
	check(sim.money == 155, "outing fare is exact")
	check(sim.actions_left == before - 1, "outing spends an action")
	var day := sim.day
	var money := sim.money
	_silence(sim)
	_drain(sim)
	sim.actions_left = 0
	var recap := sim.end_day()
	check(recap["ok"] and sim.phase == "playing", "day can end")
	check(sim.day == day + 1, "day advances")
	check(sim.actions_left == 3, "actions refill")
	check(sim.money == money - int(catalog.balance["food_per_day"]), "food is charged exactly")


func _test_publish_and_preview() -> void:
	var catalog := Catalog.load_default()
	var sim := CareerSim.create_new(catalog, 21)
	_silence(sim)
	_drain(sim)
	sim.pending_event = {}
	sim.sponsor_offer = {}
	sim.contract = {}
	sim.stamina = 80
	sim.inspiration = 50
	sim.actions_left = 3
	var rng_state := sim.rng.state
	var preview := sim.preview_post("shizi", "budget_recipe", "short", "standard", false)
	check(preview["ok"], "preview ok")
	check(sim.rng.state == rng_state, "preview does not roll rng")
	check(sim.preview_post("shizi", "budget_recipe", "short", "standard", false)["views"] == preview["views"], "preview is stable")
	var money := sim.money
	var fans := int(sim.fans["shizi"])
	var published := sim.publish("shizi", "budget_recipe", "short", "standard", false)
	check(published["ok"], "publish ok")
	var post: Dictionary = published["post"]
	check(int(post["views"]) >= int(post["view_low"]) and int(post["views"]) <= int(post["view_high"]), "actual views land in the promised band")
	check(sim.money == money + int(post["ad_money"]), "ad money is added exactly")
	check(int(sim.fans["shizi"]) == fans + int(post["followers"]), "followers are added exactly")
	check(float(sim.fatigue.get("shizi|budget_recipe", 0.0)) > 0.0, "topic fatigue increases")
	check(_factor(post, "variance") != {}, "variance is visible")
	check(_factor(post, "trend") != {}, "trend is visible")
	var second := sim.preview_post("shizi", "budget_recipe", "short", "standard", false)
	check(float(_factor(second, "fatigue")["amount"]) < float(_factor(preview, "fatigue")["amount"]), "repeat topic is less fresh")
	sim.stamina = 5
	sim.actions_left = 1
	var blocked := sim.publish("shizi", "city_walk", "short", "rush", false)
	check(blocked["code"] == "need_stamina", "exhausted publish is refused")
	check(sim.actions_left == 1, "refused publish does not spend the action")


func _test_bills_loss_win() -> void:
	var catalog := Catalog.load_default()
	var sim := CareerSim.create_new(catalog, 31)
	_silence(sim)
	_drain(sim)
	sim.day = 12
	sim.money = 2000
	sim.bills_paid = []
	sim.phase = "playing"
	sim.pending_event = {}
	sim.contract = {}
	sim.sponsor_offer = {}
	var recap := sim.end_day()
	check(recap["bill_paid"], "rent is paid on day 12")
	check(int(recap["bill_amount"]) == 800, "rent amount is 800")
	check(sim.money == 2000 - 25 - 800, "food and rent deducted exactly")
	check(sim.bills_paid.has("12:房租"), "rent marked paid")
	check(sim.day == 13 and sim.phase == "playing", "game continues after rent")
	var after := sim.money
	_silence(sim)
	_drain(sim)
	sim.pending_event = {}
	var next := sim.end_day()
	check(not next["bill_paid"], "rent is not charged again")
	check(sim.money == after - 25, "only food on the following day")

	var broke := CareerSim.create_new(catalog, 32)
	_silence(broke)
	_drain(broke)
	broke.day = 12
	broke.money = 25
	broke.bills_paid = []
	broke.pending_event = {}
	broke.contract = {}
	broke.sponsor_offer = {}
	var lost := broke.end_day()
	check(broke.phase == "lost" and broke.loss_reason == "bill", "unpaid rent loses")
	check(broke.loss_detail == "房租", "loss names the rent")
	check(broke.money == 0, "failed bill is not partially deducted")
	check(broke.day == 12, "loss does not advance the day")
	check(broke.rest()["code"] == "not_playing", "loss blocks further actions")
	check(lost["code"] == "lost", "recap reports the loss")

	var hungry := CareerSim.create_new(catalog, 33)
	_silence(hungry)
	_drain(hungry)
	hungry.day = 4
	hungry.money = 10
	hungry.pending_event = {}
	hungry.contract = {}
	hungry.sponsor_offer = {}
	hungry.end_day()
	check(hungry.phase == "lost" and hungry.loss_reason == "food", "unpaid food loses")
	check(hungry.money == 10, "failed food is not partially deducted")

	var winner := CareerSim.create_new(catalog, 34)
	_silence(winner)
	_drain(winner)
	winner.day = 30
	winner.money = 5000
	winner.bills_paid = ["12:房租", "22:助学贷款"]
	winner.pending_event = {}
	winner.contract = {}
	winner.sponsor_offer = {}
	var won := winner.end_day()
	check(winner.phase == "won", "month end with bills paid wins")
	check(winner.money == 5000 - 25 - 900, "final food and rent deducted exactly")
	check(winner.day == 30, "win stays on day 30")
	check(won["code"] == "won", "recap reports the win")
	check(winner.publish("shizi", "city_walk", "short", "rush", false)["code"] == "not_playing", "win blocks publishing")


func _test_determinism() -> void:
	var catalog := Catalog.load_default()
	var left := _play_fixed(catalog, 99)
	var right := _play_fixed(catalog, 99)
	check(SaveGame.canonical(left.state_dict()) == SaveGame.canonical(right.state_dict()), "same seed and choices match")
	var other := _play_fixed(catalog, 100)
	check(left.seed_value != other.seed_value, "seeds are stored")
	check(SaveGame.canonical(left.state_dict()) != SaveGame.canonical(other.state_dict()), "different seeds do not alias")
	var text := SaveGame.to_text(left)
	var loaded := SaveGame.from_text(text, catalog)
	check(loaded["ok"], "reload saved run")
	var continued: CareerSim = loaded["sim"]
	_step_fixed(left)
	_step_fixed(continued)
	check(SaveGame.canonical(left.state_dict()) == SaveGame.canonical(continued.state_dict()), "load continues the same rng stream")


func _test_economy_bounds() -> void:
	var catalog := Catalog.load_default()
	var sim := CareerSim.create_new(catalog, 2026)
	var picker := SimRng.new(77)
	var steps := 0
	while sim.phase == "playing" and steps < 120:
		steps += 1
		_drain(sim)
		if not sim.sponsor_offer.is_empty():
			sim.decide_sponsor(picker.unit() > 0.5)
		if sim.actions_left <= 0:
			var before := sim.money
			sim.end_day()
			if sim.phase == "playing":
				check(sim.money <= before, "settlement does not print money")
			_assert_ranges(sim)
			continue
		var before_money := sim.money
		var action := _random_action(sim, picker)
		var result := _run_action(sim, action, picker)
		if result.get("ok", false):
			var delta := sim.money - before_money
			check(delta >= int(catalog.balance["action_money_min"]) and delta <= int(catalog.balance["action_money_max"]), "action money delta in bounds (%s %d)" % [action, delta])
			if action == "publish":
				var post: Dictionary = result["post"]
				check(int(post["views"]) >= 0 and int(post["views"]) <= int(catalog.balance["views_max"]), "views in bounds")
				check(post["factors"].size() >= 8, "publish explains itself")
		_assert_ranges(sim)
	check(sim.day <= 30, "calendar never passes day 30")
	check(sim.money >= 0 and sim.money < 500000, "money stays finite")


func _test_save_roundtrip() -> void:
	var catalog := Catalog.load_default()
	var sim := _play_fixed(catalog, 123456)
	var text := SaveGame.to_text(sim)
	var loaded := SaveGame.from_text(text, catalog)
	check(loaded["ok"], "memory roundtrip loads")
	check(SaveGame.canonical(sim.state_dict()) == SaveGame.canonical(loaded["sim"].state_dict()), "canonical state matches after load")
	var path := "/tmp/srdld_test_slot.json"
	var saved := SaveGame.save_to_path(sim, path)
	check(saved["ok"], "file save ok")
	var from_file := SaveGame.load_from_path(path, catalog)
	check(from_file["ok"], "file load ok")
	check(SaveGame.canonical(sim.state_dict()) == SaveGame.canonical(from_file["sim"].state_dict()), "file roundtrip matches")
	var missing := SaveGame.load_from_path("/tmp/srdld_missing_slot.json", catalog)
	check(missing["code"] == "missing", "missing file is reported")


func _test_corrupt_saves() -> void:
	var catalog := Catalog.load_default()
	var sim := CareerSim.create_new(catalog, 9)
	var text := SaveGame.to_text(sim)
	check(SaveGame.from_text("{", catalog)["code"] == "bad_json", "broken json")
	check(SaveGame.from_text("[]", catalog)["code"] == "bad_type", "wrong json type")
	check(SaveGame.from_text("", catalog)["code"] == "bad_json", "empty file")
	var env: Dictionary = JSON.parse_string(text)
	env["version"] = 9
	check(SaveGame.from_text(JSON.stringify(env), catalog)["code"] == "bad_version", "future version rejected")
	env = JSON.parse_string(text)
	env["checksum"] = "deadbeef"
	check(SaveGame.from_text(JSON.stringify(env), catalog)["code"] == "bad_checksum", "bad checksum rejected")
	env = JSON.parse_string(text)
	env["state"]["day"] = 99
	env["checksum"] = SaveGame.checksum(env["state"])
	check(SaveGame.from_text(JSON.stringify(env), catalog)["code"] == "bad_field", "impossible day rejected")
	env = JSON.parse_string(text)
	env["state"]["stamina"] = 250
	env["checksum"] = SaveGame.checksum(env["state"])
	check(SaveGame.from_text(JSON.stringify(env), catalog)["code"] == "bad_field", "impossible stamina rejected")
	env = JSON.parse_string(text)
	env["state"]["fans"]["shizi"] = -5
	env["checksum"] = SaveGame.checksum(env["state"])
	check(SaveGame.from_text(JSON.stringify(env), catalog)["code"] == "bad_field", "negative fans rejected")
	env = JSON.parse_string(text)
	env["state"].erase("money")
	env["checksum"] = SaveGame.checksum(env["state"])
	check(SaveGame.from_text(JSON.stringify(env), catalog)["code"] == "missing_field", "missing money rejected")
	var path := "/tmp/srdld_corrupt.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("this is not a save")
	var corrupt := SaveGame.load_from_path(path, catalog)
	check(not corrupt["ok"] and corrupt["code"] == "bad_json", "corrupt file does not crash")


func _test_strategies() -> void:
	var catalog := Catalog.load_default()
	var rest := _play_policy(catalog, 7, "rest")
	var freelance := _play_policy(catalog, 7, "freelance")
	var content := _play_policy(catalog, 7, "content")
	print("STRATEGY rest phase=%s day=%d money=%d fans=%d" % [rest.phase, rest.day, rest.money, rest.total_fans()])
	print("STRATEGY freelance phase=%s day=%d money=%d fans=%d" % [freelance.phase, freelance.day, freelance.money, freelance.total_fans()])
	print("STRATEGY content phase=%s day=%d money=%d fans=%d posts=%d" % [content.phase, content.day, content.money, content.total_fans(), content.post_count])
	check(rest.phase == "lost", "resting without work loses")
	check(freelance.phase == "won", "freelance plus rest can survive")
	check(content.phase == "won", "publishing plus recovery can survive")
	check(content.total_fans() > freelance.total_fans() + 100, "publishing grows an audience the freelance path does not")
	check(content.post_count >= 8, "content path actually publishes")


func _test_font() -> void:
	var font := ThemeBuilder.font()
	var sample := "自媒体经营日记赞助疲劳剪辑柿帖河贷"
	var supported := font.get_supported_chars()
	var missing := ""
	check(font.get_height(16) > 8, "cjk font loads")
	check(supported.length() > 1000, "cjk font has a real glyph set")
	for glyph in sample:
		if not supported.contains(glyph):
			missing += glyph
	check(missing == "", "font covers ui characters %s" % missing)
	check(font.get_string_size("自媒体经营日记", HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x > 80, "chinese string has width")


func _test_scenes() -> void:
	RunConfig.mode = "new"
	RunConfig.seed_value = 20261112
	RunConfig.boot_error = ""
	var menu_scene: PackedScene = load("res://scenes/main_menu.tscn")
	var game_scene: PackedScene = load("res://scenes/game.tscn")
	check(menu_scene != null and game_scene != null, "scenes load")
	var menu := menu_scene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	check(menu.get_child_count() > 0, "menu builds")
	menu.queue_free()
	var game := game_scene.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	check(game.get("sim") != null, "game boots a simulation")
	game.queue_free()
	await get_tree().process_frame


func _play_policy(catalog: Catalog, seed_value: int, policy: String) -> CareerSim:
	var sim := CareerSim.create_new(catalog, seed_value)
	var guard := 0
	while sim.phase == "playing" and guard < 160:
		guard += 1
		_drain(sim)
		if sim.phase != "playing":
			break
		if not sim.sponsor_offer.is_empty():
			var accept := policy == "content" and sim.reputation >= 45.0 and sim.actions_left > 0
			sim.decide_sponsor(accept)
		if sim.actions_left <= 0:
			sim.end_day()
			continue
		if policy == "rest":
			sim.rest()
		elif policy == "freelance":
			if sim.stamina < 36.0 or sim.stress > 62.0:
				sim.rest()
			else:
				var result := sim.freelance()
				if not result["ok"]:
					sim.rest()
		else:
			_content_action(sim)
	return sim


func _content_action(sim: CareerSim) -> void:
	if sim.stamina < 36.0 or sim.stress > 64.0:
		sim.rest()
		return
	if sim.inspiration < 18.0 and sim.money >= 120 and sim.stamina >= 20.0:
		var outing := sim.outing()
		if outing["ok"]:
			return
	if sim.writing < 3.0 and sim.money > 1200 and sim.day <= 5 and sim.actions_left == 3:
		sim.study("writing")
		return
	var best_score := -1.0
	var best := {}
	var has_contract := not sim.contract.is_empty()
	for platform in sim.catalog.platforms:
		for topic in sim.catalog.topics:
			for format_id in ["note", "short", "long"]:
				for effort_id in ["rush", "standard", "polish"]:
					for as_sponsor in [false, true] if has_contract else [false]:
						var preview := sim.preview_post(str(platform["id"]), str(topic["id"]), format_id, effort_id, as_sponsor)
						if not preview.get("ok", false):
							continue
						if float(preview["stamina_cost"]) > sim.stamina:
							continue
						var score := float(preview["ad_money"]) + float(preview["sponsor_pay"]) + float(preview["followers"]) * 0.35
						if score > best_score:
							best_score = score
							best = {
								"platform": str(platform["id"]),
								"topic": str(topic["id"]),
								"format": format_id,
								"effort": effort_id,
								"sponsor": as_sponsor,
							}
	if best.is_empty():
		sim.rest()
		return
	var published := sim.publish(best["platform"], best["topic"], best["format"], best["effort"], best["sponsor"])
	if not published["ok"]:
		sim.rest()


func _play_fixed(catalog: Catalog, seed_value: int) -> CareerSim:
	var sim := CareerSim.create_new(catalog, seed_value)
	for _i in 4:
		_step_fixed(sim)
	return sim


func _step_fixed(sim: CareerSim) -> void:
	_drain(sim)
	if not sim.sponsor_offer.is_empty():
		sim.decide_sponsor(false)
	if sim.phase != "playing":
		return
	if sim.actions_left <= 0:
		sim.end_day()
		return
	if sim.stamina < 30.0:
		sim.rest()
		return
	var result := sim.publish("qingtie", "rent_makeover", "note", "standard", false)
	if not result["ok"]:
		sim.rest()


func _random_action(sim: CareerSim, picker: SimRng) -> String:
	var actions: Array[String] = ["rest"]
	var minimum := float(sim.catalog.balance["min_stamina_to_work"])
	if sim.stamina >= minimum:
		actions.append("freelance")
		actions.append("publish")
		if sim.money >= -int(sim.catalog.balance["actions"]["outing"]["money"]):
			actions.append("outing")
	if sim.money >= -int(sim.catalog.balance["actions"]["study_writing"]["money"]):
		actions.append("study_writing")
	if sim.money >= -int(sim.catalog.balance["actions"]["study_editing"]["money"]):
		actions.append("study_editing")
	return actions[picker.pick_index(actions.size())]


func _run_action(sim: CareerSim, action: String, picker: SimRng) -> Dictionary:
	match action:
		"rest":
			return sim.rest()
		"outing":
			return sim.outing()
		"freelance":
			return sim.freelance()
		"study_writing":
			return sim.study("writing")
		"study_editing":
			return sim.study("editing")
		"publish":
			var platforms: Array = sim.catalog.platforms
			var topics: Array = sim.catalog.topics
			var formats := ["note", "short", "long"]
			var efforts := ["rush", "standard", "polish"]
			return sim.publish(
				str(platforms[picker.pick_index(platforms.size())]["id"]),
				str(topics[picker.pick_index(topics.size())]["id"]),
				formats[picker.pick_index(formats.size())],
				efforts[picker.pick_index(efforts.size())],
				false
			)
		_:
			return {"ok": false}


func _assert_ranges(sim: CareerSim) -> void:
	check(sim.money >= 0, "money non-negative")
	check(sim.stamina >= 0.0 and sim.stamina <= 100.0, "stamina clamped")
	check(sim.mood >= 0.0 and sim.mood <= 100.0, "mood clamped")
	check(sim.stress >= 0.0 and sim.stress <= 100.0, "stress clamped")
	check(sim.inspiration >= 0.0 and sim.inspiration <= 100.0, "inspiration clamped")
	check(sim.reputation >= 0.0 and sim.reputation <= 100.0, "reputation clamped")
	for value in sim.fans.values():
		check(int(value) >= 0, "fans non-negative")


func _context(catalog: Catalog, trend: String, fatigue: float, variance: float) -> Dictionary:
	return {
		"balance": catalog.balance,
		"platform": catalog.platform("shizi"),
		"topic": catalog.topic("budget_recipe"),
		"format_id": "short",
		"effort_id": "standard",
		"writing": 2.0,
		"editing": 1.4,
		"editing_penalty": 0.0,
		"inspiration": 46.0,
		"mood": 72.0,
		"stamina": 78.0,
		"stress": 22.0,
		"reputation": 52.0,
		"fans": 160,
		"fatigue": fatigue,
		"did_outing": false,
		"duel_active": false,
		"trend": trend,
		"variance": variance,
		"as_sponsor": false,
		"contract": {},
	}


func _factor(result: Dictionary, id: String) -> Dictionary:
	for factor in result.get("factors", []):
		if str(factor.get("id", "")) == id:
			return factor
	return {}


func _silence(sim: CareerSim) -> void:
	sim.catalog.balance["morning_event_chance"] = 0
	sim.catalog.balance["outing_event_chance"] = 0
	sim.catalog.balance["sponsor_chance"] = 0


func _drain(sim: CareerSim) -> void:
	var guard := 0
	while not sim.pending_event.is_empty() and guard < 6:
		guard += 1
		var picked := ""
		for choice in sim.pending_event.get("choices", []):
			var cost := int(choice.get("effects", {}).get("money", 0))
			if cost >= 0 or sim.money >= -cost:
				picked = str(choice.get("id", ""))
				break
		if picked == "":
			break
		if not sim.resolve_event(picked)["ok"]:
			break


func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		return
	failures.append(message)
	print("FAIL ", message)
