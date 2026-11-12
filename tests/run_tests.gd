extends Node

var failures: Array[String] = []
var checks := 0
var content: Dictionary = {}


func _ready() -> void:
	print("DIARY tests")
	var file := FileAccess.open("res://data/diary_content.json", FileAccess.READ)
	content = JSON.parse_string(file.get_as_text())
	_test_tail()
	_test_rent_and_rest()
	_test_fusion_shape()
	_test_chart_and_save()
	_test_corrupt()
	_test_fifty_six()
	_test_house_keeps_upgrades()
	await _test_boot()
	print("CHECKS %d FAILURES %d" % [checks, failures.size()])
	for failure in failures:
		print("FAIL ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _test_tail() -> void:
	var sim := DiarySim.create_new(content, 3, "测", "f")
	var lifetime := 10000
	var day1 := sim.tail_amount(lifetime, 1)
	var day3 := sim.tail_amount(lifetime, 3)
	var day10 := sim.tail_amount(lifetime, 10)
	var day30 := sim.tail_amount(lifetime, 30)
	check(day1 > day3 and day3 > day10 and day10 > day30, "tail falls quickly but stays ordered")
	var day60 := sim.tail_amount(lifetime, 60)
	check(day3 > 0 and day30 > 0 and day60 > 0, "day 3, 30 and 60 still pay, day60=%d" % day60)
	var total := 0
	for age in range(1, 401):
		total += sim.tail_amount(lifetime, age)
	check(abs(total - lifetime) <= int(lifetime * 0.03) + 5, "long tail sums near the lifetime total, got %d" % total)


func _test_rent_and_rest() -> void:
	var sim := DiarySim.create_new(content, 4, "休", "m")
	var guard := 0
	while sim.phase == "playing" and guard < 80:
		guard += 1
		sim.rest(12 * 60)
	check(sim.phase == "lost", "resting without publishing loses")
	check(sim.absolute_day() >= 21 and sim.absolute_day() <= 36, "loss lands on a bill week, day %d" % sim.absolute_day())
	check(sim.loss_reason.find("贷款") >= 0 or sim.loss_reason.find("房租") >= 0, sim.loss_reason)


func _test_fusion_shape() -> void:
	var topic: Array = ["生活", "情绪"]
	var fit := {"tags": ["生活", "情绪"], "family": "daily", "heat_now": 70}
	var clash := {"tags": ["消费", "娱乐"], "family": "shop", "heat_now": 90}
	var calm := FusionMath.analyze(topic, [fit], "串联", 0.4, 0.0)
	var wild := FusionMath.analyze(topic, [fit, fit, fit, fit], "串联", 0.4, 1.0)
	var mess := FusionMath.analyze(["知识", "社会"], [clash, clash, clash, clash], "堆砌", 0.4, 0.0)
	check(float(wild["phi"]) > float(calm["phi"]), "more fitting memes raise the ceiling")
	check(float(mess["phi"]) < float(calm["phi"]), "clashing pile does not buy a ceiling")
	check(float(wild["spread"]) > float(calm["spread"]), "more memes are riskier")
	var calm_pay: Array = []
	var wild_pay: Array = []
	for seed in range(1, 41):
		var rng := SimRng.new(seed)
		calm_pay.append(FusionMath.sample_r(calm, rng.unit()))
		wild_pay.append(FusionMath.sample_r(wild, rng.unit()))
	calm_pay.sort()
	wild_pay.sort()
	check(wild_pay[wild_pay.size() - 1] >= calm_pay[calm_pay.size() - 1] - 0.02, "wild success tail can reach at least as high")
	check(wild_pay[0] < calm_pay[0], "wild downside is worse")


func _test_chart_and_save() -> void:
	var sim := DiarySim.create_new(content, 11, "榜", "f")
	var first: Array = sim.chart_rows()
	sim.clock_minutes = 8 * DiarySim.DAY
	sim._ensure_chart(sim.week_index())
	var second: Array = sim.chart_rows()
	check(str(first[0].get("id", "")) != str(second[0].get("id", "")) or int(first[0].get("score", 0)) != int(second[0].get("score", 0)), "weekly chart moves")
	var before := sim.money
	sim.works.append({"id": "w9", "born_day": 1, "lifetime": 20000, "paid": 0})
	var paid := sim._pay_tails(8)
	var again := sim._pay_tails(8)
	check(paid > 0 and again == 0 and sim.money == before + paid, "ledger does not pay the same day twice")
	var text := JSON.stringify({"version": 2, "checksum": SaveGame.checksum(sim.state_dict()), "state": sim.state_dict()})
	var loaded := DiarySave.from_text(text, content)
	check(loaded.get("ok", false), "save loads")
	var back: DiarySim = loaded["sim"]
	check(back.chart_rows()[0]["id"] == sim.chart_rows()[0]["id"], "chart survives save")
	check(back.money == sim.money and back.rng.state == sim.rng.state, "money and rng survive save")


func _test_corrupt() -> void:
	var sim := DiarySim.create_new(content, 2, "坏", "f")
	var text := JSON.stringify({"version": 2, "checksum": SaveGame.checksum(sim.state_dict()), "state": sim.state_dict()})
	check(DiarySave.from_text("{", content).get("code", "") == "bad_json", "bad json")
	var env: Dictionary = JSON.parse_string(text)
	env["version"] = 1
	check(DiarySave.from_text(JSON.stringify(env), content).get("code", "") == "bad_version", "old prototype save rejected")
	env = JSON.parse_string(text)
	env["checksum"] = "00000000"
	check(DiarySave.from_text(JSON.stringify(env), content).get("code", "") == "bad_checksum", "bad checksum")


func _test_fifty_six() -> void:
	var rest := _run_policy(8, "rest")
	var steady := _run_policy(8, "steady")
	var reckless := _run_policy(8, "reckless")
	print("POLICY rest phase=%s day=%d money=%d" % [rest.phase, rest.absolute_day(), rest.money])
	print("POLICY steady phase=%s day=%d money=%d fans=%d works=%d" % [steady.phase, steady.absolute_day(), steady.money, steady.fans, steady.works.size()])
	print("POLICY reckless phase=%s day=%d money=%d fans=%d works=%d" % [reckless.phase, reckless.absolute_day(), reckless.money, reckless.fans, reckless.works.size()])
	check(rest.phase == "lost", "56-day rest policy loses")
	check(steady.phase == "playing" and steady.absolute_day() >= 56, "steady publishing reaches day 56")
	check(steady.money > 0 and steady.fans > 80, "steady path has cash and an audience")
	var fused := 0
	var flopped := 0
	for work in reckless.works:
		var used: Array = work.get("memes", [])
		if used.size() >= 2:
			fused += 1
		if str(work.get("note", "")).find("缺过渡") >= 0:
			flopped += 1
	check(fused > 0, "reckless path publishes with more than one meme")
	check(flopped > 0, "reckless path sometimes fails to land the memes")
	print("POLICY reckless fused=%d flopped=%d mean_reach=%.0f" % [fused, flopped, _mean_reach(reckless)])
	print("POLICY steady mean_reach=%.0f" % _mean_reach(steady))
	for seed_value in [3, 5, 9, 12, 18]:
		var a := _run_policy(seed_value, "steady")
		var b := _run_policy(seed_value, "reckless")
		print("SEED %d steady %s day=%d money=%d fans=%d | reckless %s day=%d money=%d fans=%d" % [
			seed_value, a.phase, a.absolute_day(), a.money, a.fans, b.phase, b.absolute_day(), b.money, b.fans,
		])


func _mean_reach(sim: DiarySim) -> float:
	if sim.works.is_empty():
		return 0.0
	var total := 0
	for work in sim.works:
		total += int(work.get("reach", 0))
	return float(total) / float(sim.works.size())


func _run_policy(seed_value: int, policy: String) -> DiarySim:
	var sim := DiarySim.create_new(content, seed_value, policy, "f")
	var guard := 0
	while sim.phase == "playing" and sim.absolute_day() <= 56 and guard < 1600:
		guard += 1
		if policy == "rest":
			sim.rest(180)
			continue
		if sim.stamina < 20:
			sim.rest(120)
			continue
		if policy == "reckless" and sim.memes.size() < 4 and sim.stamina > 12 and sim.minutes_of_day() < 20 * 60:
			var places: Array = ["park", "library", "mall", "cinema"]
			var place_id: String = str(places[sim.absolute_day() % 4])
			var trip := sim.go_out(place_id)
			if not trip.get("ok", false):
				sim.read_home()
			continue
		if sim.inspiration < 28:
			if sim.minutes_of_day() >= 10 * 60 and sim.minutes_of_day() < 20 * 60:
				sim.go_out("library")
			else:
				sim.read_home()
			continue
		if sim.works_today >= 1:
			sim.rest(120)
			continue
		var memes: Array = []
		if policy == "reckless":
			for owned in sim.memes:
				if memes.size() < 4:
					memes.append(str(owned.get("id", "")))
			var result := sim.confirm_work("article", "society", memes, "堆砌", "none")
			if not result.get("ok", false):
				sim.read_home()
		else:
			var topics: Array = ["life", "mood", "knowledge", "film"]
			var topic: String = str(topics[sim.absolute_day() % 4])
			for owned in sim.memes:
				var spec := sim.meme_def(str(owned.get("id", "")))
				if spec.get("tags", []).has("生活") or spec.get("tags", []).has("情绪"):
					memes.append(str(owned.get("id", "")))
					break
			var made := sim.confirm_work("article", topic, memes, "串联", "none")
			if not made.get("ok", false):
				sim.rest(90)
	return sim


func _test_house_keeps_upgrades() -> void:
	var sim := DiarySim.create_new(content, 6, "搬", "m")
	sim.money = 9000 * DiarySim.GOLD
	check(sim.upgrade("bed").get("ok", false), "bed upgrades in place")
	check(int(sim.furniture["bed"]) == 2, "bed level stays 2")
	check(not sim.upgrade("bed").get("ok", false), "second upgrade does not mint an old item")
	var before := sim.money
	check(sim.move_house().get("ok", false), "move house")
	check(sim.house_tier == 2 and int(sim.furniture["bed"]) == 2, "new layout keeps the upgrade")
	check(sim.money == before - 600 * DiarySim.GOLD, "move fee is exact")
	sim.accrued_rent = 40 * DiarySim.GOLD
	var cash := sim.money
	check(sim.buy_home().get("ok", false), "buy home")
	check(sim.owned_home and sim.accrued_rent == 0, "buying pays accrued rent")
	check(sim.money == cash - (4800 + 40) * DiarySim.GOLD, "buy price includes accrued rent")


func _test_boot() -> void:
	var packed: PackedScene = load("res://scenes/play.tscn")
	check(packed != null, "play scene loads")
	var node := packed.instantiate()
	add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	check(node.get_child_count() > 2, "play scene builds a room")
	node.queue_free()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("FAIL ", message)
