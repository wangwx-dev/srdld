extends RefCounted
class_name CareerSim

var catalog: Catalog
var rng := SimRng.new(1)
var seed_value := 1
var day := 1
var actions_left := 3
var phase := "playing"
var loss_reason := ""
var loss_detail := ""
var money := 0
var stamina := 0.0
var mood := 0.0
var stress := 0.0
var inspiration := 0.0
var writing := 1.0
var editing := 1.0
var reputation := 50.0
var fans: Dictionary = {}
var fatigue: Dictionary = {}
var trends: Array = []
var bills_paid: Array = []
var seen_events: Array = []
var flags: Dictionary = {}
var editing_penalty := 0.0
var editing_penalty_days := 0
var duel_until := 0
var days_since_freelance := 99
var pending_event: Dictionary = {}
var sponsor_offer: Dictionary = {}
var contract: Dictionary = {}
var last_sponsor_id := ""
var did_rest := false
var did_outing := false
var did_publish := false
var day_earned := 0
var day_spent := 0
var post_count := 0
var posts: Array = []
var log: Array = []
var tutorial_done := false
var day_snapshot: Dictionary = {}


static func create_new(game_catalog: Catalog, new_seed: int) -> CareerSim:
	var sim := CareerSim.new()
	sim.catalog = game_catalog
	sim.seed_value = max(1, int(new_seed))
	sim.rng = SimRng.new(sim.seed_value)
	sim._apply_start()
	sim._roll_trends()
	sim.phase = "playing"
	sim.day = 1
	sim.actions_left = int(game_catalog.balance["actions_per_day"])
	sim.begin_day()
	return sim


func state_dict() -> Dictionary:
	return {
		"schema": 1,
		"seed": seed_value,
		"rng": rng.state,
		"day": day,
		"actions_left": actions_left,
		"phase": phase,
		"loss_reason": loss_reason,
		"loss_detail": loss_detail,
		"money": money,
		"stamina": stamina,
		"mood": mood,
		"stress": stress,
		"inspiration": inspiration,
		"writing": writing,
		"editing": editing,
		"reputation": reputation,
		"fans": fans.duplicate(),
		"fatigue": fatigue.duplicate(),
		"trends": trends.duplicate(),
		"bills_paid": bills_paid.duplicate(),
		"seen_events": seen_events.duplicate(),
		"flags": flags.duplicate(true),
		"editing_penalty": editing_penalty,
		"editing_penalty_days": editing_penalty_days,
		"duel_until": duel_until,
		"days_since_freelance": days_since_freelance,
		"pending_event": pending_event.duplicate(true),
		"sponsor_offer": sponsor_offer.duplicate(true),
		"contract": contract.duplicate(true),
		"last_sponsor_id": last_sponsor_id,
		"did_rest": did_rest,
		"did_outing": did_outing,
		"did_publish": did_publish,
		"day_earned": day_earned,
		"day_spent": day_spent,
		"post_count": post_count,
		"posts": posts.duplicate(true),
		"log": log.duplicate(true),
		"tutorial_done": tutorial_done,
		"day_snapshot": day_snapshot.duplicate(true),
	}


static func from_state(game_catalog: Catalog, data: Dictionary) -> CareerSim:
	var sim := CareerSim.new()
	sim.catalog = game_catalog
	sim.seed_value = int(data["seed"])
	sim.rng = SimRng.new(1)
	sim.rng.state = int(data["rng"])
	sim.day = int(data["day"])
	sim.actions_left = int(data["actions_left"])
	sim.phase = str(data["phase"])
	sim.loss_reason = str(data["loss_reason"])
	sim.loss_detail = str(data["loss_detail"])
	sim.money = int(data["money"])
	sim.stamina = float(data["stamina"])
	sim.mood = float(data["mood"])
	sim.stress = float(data["stress"])
	sim.inspiration = float(data["inspiration"])
	sim.writing = float(data["writing"])
	sim.editing = float(data["editing"])
	sim.reputation = float(data["reputation"])
	sim.fans = data["fans"].duplicate()
	sim.fatigue = data["fatigue"].duplicate()
	sim.trends = data["trends"].duplicate()
	sim.bills_paid = data["bills_paid"].duplicate()
	sim.seen_events = data["seen_events"].duplicate()
	sim.flags = data["flags"].duplicate(true)
	sim.editing_penalty = float(data["editing_penalty"])
	sim.editing_penalty_days = int(data["editing_penalty_days"])
	sim.duel_until = int(data["duel_until"])
	sim.days_since_freelance = int(data["days_since_freelance"])
	sim.pending_event = data["pending_event"].duplicate(true)
	sim.sponsor_offer = data["sponsor_offer"].duplicate(true)
	sim.contract = data["contract"].duplicate(true)
	sim.last_sponsor_id = str(data["last_sponsor_id"])
	sim.did_rest = bool(data["did_rest"])
	sim.did_outing = bool(data["did_outing"])
	sim.did_publish = bool(data["did_publish"])
	sim.day_earned = int(data["day_earned"])
	sim.day_spent = int(data["day_spent"])
	sim.post_count = int(data["post_count"])
	sim.posts = data["posts"].duplicate(true)
	sim.log = data["log"].duplicate(true)
	sim.tutorial_done = bool(data["tutorial_done"])
	sim.day_snapshot = data["day_snapshot"].duplicate(true)
	sim._normalize()
	return sim


func total_fans() -> int:
	var total := 0
	for value in fans.values():
		total += int(value)
	return total


func trend_for_day(which_day: int) -> String:
	if trends.is_empty():
		return ""
	var index := int((which_day - 1) / 7)
	index = clampi(index, 0, trends.size() - 1)
	return str(trends[index])


func next_trend() -> String:
	if trends.is_empty():
		return ""
	var index := int((day - 1) / 7) + 1
	if index >= trends.size():
		return ""
	return str(trends[index])


func rival_rows() -> Array:
	var week := int((day - 1) / 7)
	var rows: Array = []
	for rival in catalog.rivals:
		var growth := int(rival.get("weekly_base", 0))
		if growth > 0:
			growth += (seed_value + week * 37) % 180
		rows.append({
			"id": str(rival.get("id", "")),
			"name": str(rival.get("name", "")),
			"line": str(rival.get("line", "")),
			"growth": growth,
		})
	return rows


func next_bill() -> Dictionary:
	var best: Dictionary = {}
	for bill in catalog.balance["bills"]:
		var bill_id := _bill_id(bill)
		if bills_paid.has(bill_id):
			continue
		if int(bill["day"]) < day:
			continue
		if best.is_empty() or int(bill["day"]) < int(best["day"]):
			best = bill
	return best


func due_bill() -> Dictionary:
	var best: Dictionary = {}
	for bill in catalog.balance["bills"]:
		var bill_id := _bill_id(bill)
		if bills_paid.has(bill_id):
			continue
		if int(bill["day"]) <= day:
			if best.is_empty() or int(bill["day"]) < int(best["day"]):
				best = bill
	return best


func rest() -> Dictionary:
	var gate := _gate_action()
	if not gate.is_empty():
		return gate
	var action: Dictionary = catalog.balance["actions"]["rest"]
	stamina += float(action["stamina"])
	stress += float(action["stress"])
	mood += float(action["mood"])
	inspiration += float(action["inspiration"])
	did_rest = true
	actions_left -= 1
	_normalize()
	_log({"kind": "action", "code": "rest"})
	return {"ok": true, "code": "rest"}


func outing() -> Dictionary:
	var gate := _gate_action()
	if not gate.is_empty():
		return gate
	var action: Dictionary = catalog.balance["actions"]["outing"]
	var cost := -int(action["money"])
	if stamina < float(catalog.balance["min_stamina_to_work"]):
		return {"ok": false, "code": "need_stamina"}
	if money < cost:
		return {"ok": false, "code": "cant_afford"}
	money -= cost
	day_spent += cost
	stamina += float(action["stamina"])
	stress += float(action["stress"])
	mood += float(action["mood"])
	inspiration += float(action["inspiration"])
	did_outing = true
	actions_left -= 1
	_normalize()
	_log({"kind": "action", "code": "outing"})
	_roll_event("outing")
	return {"ok": true, "code": "outing"}


func freelance() -> Dictionary:
	var gate := _gate_action()
	if not gate.is_empty():
		return gate
	if stamina < float(catalog.balance["min_stamina_to_work"]):
		return {"ok": false, "code": "need_stamina"}
	var action: Dictionary = catalog.balance["actions"]["freelance"]
	var pay := int(action["money"]) + Formulas.round_half_up(writing * float(action["money_per_writing"]))
	money += pay
	day_earned += pay
	stamina += float(action["stamina"])
	stress += float(action["stress"])
	mood += float(action["mood"])
	reputation += float(action["reputation"])
	days_since_freelance = 0
	actions_left -= 1
	_normalize()
	_log({"kind": "action", "code": "freelance", "money": pay})
	return {"ok": true, "code": "freelance", "money": pay}


func study(which: String) -> Dictionary:
	var gate := _gate_action()
	if not gate.is_empty():
		return gate
	var key := "study_writing" if which == "writing" else "study_editing"
	if which != "writing" and which != "editing":
		return {"ok": false, "code": "bad_id"}
	var action: Dictionary = catalog.balance["actions"][key]
	var cost := -int(action["money"])
	if money < cost:
		return {"ok": false, "code": "cant_afford"}
	money -= cost
	day_spent += cost
	stamina += float(action["stamina"])
	inspiration += float(action["inspiration"])
	if which == "writing":
		writing += float(action["writing"])
	else:
		editing += float(action["editing"])
	actions_left -= 1
	_normalize()
	_log({"kind": "action", "code": key})
	return {"ok": true, "code": key}


func preview_post(platform_id: String, topic_id: String, format_id: String, effort_id: String, as_sponsor: bool) -> Dictionary:
	var context := _context(platform_id, topic_id, format_id, effort_id, -1.0, as_sponsor)
	if context.is_empty():
		return {"ok": false, "code": "bad_id"}
	var result := Formulas.compute(context)
	result["ok"] = true
	result["code"] = "preview"
	return result


func publish(platform_id: String, topic_id: String, format_id: String, effort_id: String, as_sponsor: bool) -> Dictionary:
	var gate := _gate_action()
	if not gate.is_empty():
		return gate
	if stamina < float(catalog.balance["min_stamina_to_work"]):
		return {"ok": false, "code": "need_stamina"}
	if as_sponsor and contract.is_empty():
		return {"ok": false, "code": "no_contract"}
	var context := _context(platform_id, topic_id, format_id, effort_id, _roll_variance(), as_sponsor)
	if context.is_empty():
		return {"ok": false, "code": "bad_id"}
	var result: Dictionary = Formulas.compute(context)
	var effort: Dictionary = catalog.balance["efforts"][effort_id]
	var format_cfg: Dictionary = catalog.balance["formats"][format_id]
	stamina -= float(effort["stamina"])
	inspiration -= float(effort["inspiration"])
	stress += float(effort["stress"])
	mood += float(effort["mood"])
	var gained := int(result["followers"])
	fans[platform_id] = int(fans[platform_id]) + gained
	var income := int(result["ad_money"]) + int(result["sponsor_pay"])
	money += income
	day_earned += income
	reputation += float(result["rep_delta"])
	writing += float(catalog.balance["skill_gain"]) * float(format_cfg["writing_w"])
	editing += float(catalog.balance["skill_gain"]) * float(format_cfg["editing_w"])
	var fatigue_key := "%s|%s" % [platform_id, topic_id]
	var weight := float(context["topic"].get("fatigue_weight", 1.0))
	fatigue[fatigue_key] = float(fatigue.get(fatigue_key, 0.0)) + float(context["platform"]["fatigue_gain"]) * weight
	if bool(result["sponsor_completes"]):
		contract = {}
	did_publish = true
	actions_left -= 1
	post_count += 1
	var post := {
		"day": day,
		"platform_id": platform_id,
		"topic_id": topic_id,
		"format_id": format_id,
		"effort_id": effort_id,
		"platform_name": str(context["platform"]["name"]),
		"topic_name": str(context["topic"]["name"]),
		"format_name": str(format_cfg["label"]),
		"effort_name": str(effort["label"]),
		"trend": trend_for_day(day),
		"quality": result["quality"],
		"views": result["views"],
		"view_low": result["view_low"],
		"view_high": result["view_high"],
		"followers": result["followers"],
		"ad_money": result["ad_money"],
		"sponsor_pay": result["sponsor_pay"],
		"sponsor_note": result["sponsor_note"],
		"rep_delta": result["rep_delta"],
		"variance_used": result["variance_used"],
		"factors": result["factors"],
		"as_sponsor": as_sponsor,
	}
	posts.append(post)
	_normalize()
	_log({"kind": "post", "post_index": posts.size() - 1})
	return {"ok": true, "code": "publish", "post": post}


func decide_sponsor(accept: bool) -> Dictionary:
	var gate := _gate_meta()
	if not gate.is_empty():
		return gate
	if sponsor_offer.is_empty():
		return {"ok": false, "code": "no_offer"}
	if accept:
		contract = sponsor_offer.duplicate(true)
		contract["due_day"] = day + int(catalog.balance["sponsor_days"]) - 1
		last_sponsor_id = str(sponsor_offer["id"])
		var brand := str(sponsor_offer["brand"])
		sponsor_offer = {}
		_log({"kind": "action", "code": "sponsor_accept", "brand": brand, "due_day": contract["due_day"]})
		return {"ok": true, "code": "sponsor_accept", "due_day": int(contract["due_day"]), "brand": brand}
	last_sponsor_id = str(sponsor_offer["id"])
	var brand := str(sponsor_offer["brand"])
	sponsor_offer = {}
	reputation += float(catalog.balance["sponsor_reject_rep"])
	mood += float(catalog.balance["sponsor_reject_mood"])
	_normalize()
	_log({"kind": "action", "code": "sponsor_reject", "brand": brand})
	return {"ok": true, "code": "sponsor_reject", "brand": brand}


func resolve_event(choice_id: String) -> Dictionary:
	if phase != "playing":
		return {"ok": false, "code": "not_playing"}
	if pending_event.is_empty():
		return {"ok": false, "code": "no_event"}
	var choice: Dictionary = {}
	for item in pending_event.get("choices", []):
		if str(item.get("id", "")) == choice_id:
			choice = item
			break
	if choice.is_empty():
		return {"ok": false, "code": "bad_choice"}
	var effects: Dictionary = choice.get("effects", {})
	var cost := int(effects.get("money", 0))
	if cost < 0 and money < -cost:
		return {"ok": false, "code": "cant_afford"}
	var label := str(choice.get("label", ""))
	var text := str(pending_event.get("text", ""))
	pending_event = {}
	_apply_effects(effects)
	_log({"kind": "event", "text": text, "choice": label})
	return {"ok": true, "code": "event_resolved", "label": label}


func end_day() -> Dictionary:
	var gate := _gate_meta()
	if not gate.is_empty():
		return gate
	var sponsor_failed := false
	var sponsor_expired := false
	if not contract.is_empty() and day >= int(contract.get("due_day", day)):
		reputation += float(catalog.balance["sponsor_fail_rep"])
		stress += float(catalog.balance["sponsor_fail_stress"])
		var brand := str(contract.get("brand", ""))
		contract = {}
		sponsor_failed = true
		_log({"kind": "action", "code": "sponsor_failed", "brand": brand})
	if not sponsor_offer.is_empty():
		last_sponsor_id = str(sponsor_offer.get("id", last_sponsor_id))
		sponsor_offer = {}
		sponsor_expired = true
		_log({"kind": "action", "code": "sponsor_expired"})
	stamina += float(catalog.balance["sleep_stamina"])
	if not did_rest:
		stress += float(catalog.balance["no_rest_stress"])
	if not did_outing:
		inspiration -= float(catalog.balance["inspiration_idle_decay"])
	if stress > float(catalog.balance["high_stress"]):
		mood -= float(catalog.balance["high_stress_mood_penalty"])
	elif stress < float(catalog.balance["low_stress"]):
		mood += float(catalog.balance["low_stress_mood_gain"])
	if editing_penalty_days > 0:
		editing_penalty_days -= 1
		if editing_penalty_days <= 0:
			editing_penalty = 0.0
			editing_penalty_days = 0
	if days_since_freelance < 90:
		days_since_freelance += 1
	_decay_fatigue()
	_normalize()

	var food := int(catalog.balance["food_per_day"])
	var food_paid := false
	if money < food:
		phase = "lost"
		loss_reason = "food"
		loss_detail = ""
		return _recap("lost", food, false, {}, false, sponsor_failed, sponsor_expired)
	money -= food
	day_spent += food
	food_paid = true

	var paid_any := false
	var paid_sum := 0
	var paid_name := ""
	var paid_count := 0
	while true:
		var bill := due_bill()
		if bill.is_empty():
			break
		var amount := int(bill["amount"])
		if money < amount:
			phase = "lost"
			loss_reason = "bill"
			loss_detail = str(bill["name"])
			var failed := bill.duplicate()
			if paid_count > 0:
				failed["name"] = "到期账单"
				failed["amount"] = paid_sum
			return _recap("lost", food, food_paid, failed if paid_count > 0 else bill, paid_count > 0, sponsor_failed, sponsor_expired)
		money -= amount
		day_spent += amount
		bills_paid.append(_bill_id(bill))
		paid_any = true
		paid_sum += amount
		paid_count += 1
		paid_name = str(bill["name"]) if paid_count == 1 else "到期账单"
	var bill_info := {}
	if paid_any:
		bill_info = {"name": paid_name, "amount": paid_sum}

	if day >= int(catalog.balance["days"]):
		phase = "won"
		return _recap("won", food, food_paid, bill_info, paid_any, sponsor_failed, sponsor_expired)

	var recap := _recap("day_end", food, food_paid, bill_info, paid_any, sponsor_failed, sponsor_expired)
	day += 1
	actions_left = int(catalog.balance["actions_per_day"])
	begin_day()
	return recap


func begin_day() -> void:
	did_rest = false
	did_outing = false
	did_publish = false
	day_earned = 0
	day_spent = 0
	capture_snapshot()
	_roll_event("morning")
	_roll_sponsor()


func capture_snapshot() -> void:
	day_snapshot = {
		"money": money,
		"fans": fans.duplicate(),
		"stamina": stamina,
		"mood": mood,
		"stress": stress,
		"inspiration": inspiration,
		"reputation": reputation,
		"writing": writing,
		"editing": editing,
	}


func _apply_start() -> void:
	var start: Dictionary = catalog.balance["start"]
	money = int(start["money"])
	stamina = float(start["stamina"])
	mood = float(start["mood"])
	stress = float(start["stress"])
	inspiration = float(start["inspiration"])
	writing = float(start["writing"])
	editing = float(start["editing"])
	reputation = float(start["reputation"])
	fans = {}
	for platform in catalog.platforms:
		var id := str(platform["id"])
		fans[id] = int(start["fans"].get(id, 0))
	fatigue = {}
	bills_paid = []
	seen_events = []
	flags = {}
	editing_penalty = 0.0
	editing_penalty_days = 0
	duel_until = 0
	days_since_freelance = 99
	pending_event = {}
	sponsor_offer = {}
	contract = {}
	last_sponsor_id = ""
	posts = []
	log = []
	post_count = 0
	tutorial_done = false
	loss_reason = ""
	loss_detail = ""
	_normalize()


func _roll_trends() -> void:
	var trend_rng := SimRng.new((seed_value ^ 0x51ED) & 0x7fffffff)
	var tags: Array = catalog.balance["trend_tags"]
	trends = []
	var last := ""
	for _i in 6:
		var pool: Array = []
		for tag in tags:
			if str(tag) != last:
				pool.append(str(tag))
		var picked: String = pool[trend_rng.pick_index(pool.size())]
		trends.append(picked)
		last = picked


func _roll_variance() -> float:
	var low := float(catalog.balance["variance_min"])
	var high := float(catalog.balance["variance_max"])
	return low + rng.unit() * (high - low)


func _context(platform_id: String, topic_id: String, format_id: String, effort_id: String, variance: float, as_sponsor: bool) -> Dictionary:
	var platform: Dictionary = catalog.platform(platform_id)
	var topic: Dictionary = catalog.topic(topic_id)
	if platform.is_empty() or topic.is_empty():
		return {}
	if not catalog.balance["formats"].has(format_id) or not catalog.balance["efforts"].has(effort_id):
		return {}
	return {
		"balance": catalog.balance,
		"platform": platform,
		"topic": topic,
		"format_id": format_id,
		"effort_id": effort_id,
		"writing": writing,
		"editing": editing,
		"editing_penalty": editing_penalty,
		"inspiration": inspiration,
		"mood": mood,
		"stamina": stamina,
		"stress": stress,
		"reputation": reputation,
		"fans": int(fans.get(platform_id, 0)),
		"fatigue": float(fatigue.get("%s|%s" % [platform_id, topic_id], 0.0)),
		"did_outing": did_outing,
		"duel_active": day <= duel_until and duel_until > 0,
		"trend": trend_for_day(day),
		"variance": variance,
		"as_sponsor": as_sponsor and not contract.is_empty(),
		"contract": contract,
	}


func _roll_event(pool: String) -> void:
	if not pending_event.is_empty():
		return
	var chance := float(catalog.balance["morning_event_chance"] if pool == "morning" else catalog.balance["outing_event_chance"])
	if not rng.chance(chance):
		return
	var valid: Array = []
	for event in catalog.events:
		if str(event.get("pool", "")) != pool:
			continue
		if _event_ok(event):
			valid.append(event)
	if valid.is_empty():
		return
	_present_event(_pick_weighted(valid))


func _roll_sponsor() -> void:
	if not sponsor_offer.is_empty() or not contract.is_empty():
		return
	var balance: Dictionary = catalog.balance
	if day < int(balance["sponsor_min_day"]) or day > int(balance["sponsor_last_day"]):
		return
	if total_fans() < int(balance["sponsor_min_fans"]) or reputation < float(balance["sponsor_min_rep"]):
		return
	if not rng.chance(float(balance["sponsor_chance"])):
		return
	var pool: Array = []
	for sponsor in catalog.sponsors:
		if str(sponsor.get("id", "")) != last_sponsor_id:
			pool.append(sponsor)
	if pool.is_empty():
		pool = catalog.sponsors.duplicate()
	if pool.is_empty():
		return
	var picked: Dictionary = _pick_weighted(pool)
	sponsor_offer = {
		"id": str(picked["id"]),
		"brand": str(picked["brand"]),
		"pay": int(picked["pay"]),
		"tag": str(picked["tag"]),
		"platform": str(picked["platform"]),
		"blurb": str(picked["blurb"]),
	}


func _present_event(event: Dictionary) -> void:
	seen_events.append(str(event.get("id", "")))
	if bool(event.get("auto", false)):
		_apply_effects(event.get("effects", {}))
		_log({"kind": "event", "text": str(event.get("text", "")), "auto": true})
		return
	pending_event = {
		"id": str(event.get("id", "")),
		"text": str(event.get("text", "")),
		"choices": (event.get("choices", []) as Array).duplicate(true),
	}


func _event_ok(event: Dictionary) -> bool:
	var once := bool(event.get("once", true))
	if once and seen_events.has(str(event.get("id", ""))):
		return false
	if event.has("min_day") and day < int(event["min_day"]):
		return false
	if event.has("max_day") and day > int(event["max_day"]):
		return false
	if event.has("min_fans") and total_fans() < int(event["min_fans"]):
		return false
	if event.has("min_reputation") and reputation < float(event["min_reputation"]):
		return false
	if event.has("min_stress") and stress < float(event["min_stress"]):
		return false
	if event.has("max_stress") and stress > float(event["max_stress"]):
		return false
	if event.has("requires_flag") and not bool(flags.get(str(event["requires_flag"]), false)):
		return false
	if event.has("forbids_flag") and bool(flags.get(str(event["forbids_flag"]), false)):
		return false
	if event.has("max_days_since_freelance") and days_since_freelance > int(event["max_days_since_freelance"]):
		return false
	return true


func _pick_weighted(items: Array) -> Dictionary:
	var total := 0
	for item in items:
		total += int(item.get("weight", 10))
	if total <= 0:
		return items[0]
	var roll := rng.next_u32() % total
	var cursor := 0
	for item in items:
		cursor += int(item.get("weight", 10))
		if roll < cursor:
			return item
	return items[items.size() - 1]


func _apply_effects(effects: Dictionary) -> void:
	if effects.has("money"):
		var delta := int(effects["money"])
		money += delta
		if delta > 0:
			day_earned += delta
		elif delta < 0:
			day_spent += -delta
	for key in ["stamina", "mood", "stress", "inspiration", "reputation", "writing", "editing"]:
		if effects.has(key):
			set(key, float(get(key)) + float(effects[key]))
	if effects.has("fans"):
		for platform_id in effects["fans"].keys():
			var id := str(platform_id)
			if fans.has(id):
				fans[id] = max(0, int(fans[id]) + int(effects["fans"][platform_id]))
	if effects.has("flag"):
		flags[str(effects["flag"])] = true
	if effects.has("duel_days"):
		duel_until = day + int(effects["duel_days"])
	if bool(effects.get("clear_penalty", false)):
		editing_penalty = 0.0
		editing_penalty_days = 0
	if effects.has("editing_penalty"):
		editing_penalty = float(effects["editing_penalty"])
		editing_penalty_days = int(effects.get("penalty_days", 2))
	_normalize()


func _decay_fatigue() -> void:
	var decay := float(catalog.balance["fatigue_decay"])
	var keys: Array = fatigue.keys()
	for key in keys:
		var left := float(fatigue[key]) - decay
		if left <= 0.05:
			fatigue.erase(key)
		else:
			fatigue[key] = Formulas.r3(left)


func _recap(code: String, food: int, food_paid: bool, bill: Dictionary, bill_paid: bool, sponsor_failed: bool, sponsor_expired: bool) -> Dictionary:
	var fans_delta := {}
	var snap_fans: Dictionary = day_snapshot.get("fans", {})
	for platform_id in fans.keys():
		fans_delta[platform_id] = int(fans[platform_id]) - int(snap_fans.get(platform_id, 0))
	return {
		"ok": true,
		"code": code,
		"day": day,
		"food": food,
		"food_paid": food_paid,
		"bill_name": str(bill.get("name", "")),
		"bill_amount": int(bill.get("amount", 0)),
		"bill_paid": bill_paid,
		"earned": day_earned,
		"spent": day_spent,
		"money_after": money,
		"fans_delta": fans_delta,
		"stamina_delta": Formulas.r3(stamina - float(day_snapshot.get("stamina", stamina))),
		"mood_delta": Formulas.r3(mood - float(day_snapshot.get("mood", mood))),
		"stress_delta": Formulas.r3(stress - float(day_snapshot.get("stress", stress))),
		"inspiration_delta": Formulas.r3(inspiration - float(day_snapshot.get("inspiration", inspiration))),
		"reputation_delta": Formulas.r3(reputation - float(day_snapshot.get("reputation", reputation))),
		"sleep_stamina": int(catalog.balance["sleep_stamina"]),
		"phase": phase,
		"loss_reason": loss_reason,
		"loss_detail": loss_detail,
		"sponsor_failed": sponsor_failed,
		"sponsor_expired": sponsor_expired,
		"seed": seed_value,
	}


func _gate_action() -> Dictionary:
	var gate := _gate_meta()
	if not gate.is_empty():
		return gate
	if actions_left <= 0:
		return {"ok": false, "code": "no_actions"}
	return {}


func _gate_meta() -> Dictionary:
	if phase != "playing":
		return {"ok": false, "code": "not_playing"}
	if not pending_event.is_empty():
		return {"ok": false, "code": "pending_event"}
	return {}


func _normalize() -> void:
	stamina = clampf(Formulas.r3(stamina), 0.0, 100.0)
	mood = clampf(Formulas.r3(mood), 0.0, 100.0)
	stress = clampf(Formulas.r3(stress), 0.0, 100.0)
	inspiration = clampf(Formulas.r3(inspiration), 0.0, 100.0)
	reputation = clampf(Formulas.r3(reputation), 0.0, 100.0)
	var skill_min := float(catalog.balance["skill_min"])
	var skill_max := float(catalog.balance["skill_max"])
	writing = clampf(Formulas.r3(writing), skill_min, skill_max)
	editing = clampf(Formulas.r3(editing), skill_min, skill_max)
	editing_penalty = max(0.0, Formulas.r3(editing_penalty))
	money = max(0, int(money))
	for platform_id in fans.keys():
		fans[platform_id] = max(0, int(fans[platform_id]))


func _log(entry: Dictionary) -> void:
	entry["day"] = day
	log.append(entry)
	var limit := int(catalog.balance["log_limit"])
	while log.size() > limit:
		log.remove_at(0)


func _bill_id(bill: Dictionary) -> String:
	return "%d:%s" % [int(bill["day"]), str(bill["name"])]
