extends RefCounted
class_name DiarySim

const DAY := 1440
const GOLD := 100

var catalog: Dictionary = {}
var rng := SimRng.new(1)
var seed_value := 1
var player_name := "小林"
var gender := "f"
var clock_minutes := 480
var last_settled := 0
var money := 120000
var stamina := 80
var stamina_max := 100
var inspiration := 36
var expression := 32.0
var observation := 32.0
var craft := 24.0
var fitness := 30.0
var trust := 50.0
var fans := 40
var audience := {"生活": 0.28, "情绪": 0.22, "娱乐": 0.15, "知识": 0.15, "消费": 0.10, "社会": 0.10}
var house_tier := 1
var owned_home := false
var furniture := {"bed": 1, "desk": 1, "shelf": 1}
var accrued_rent := 0
var loan_left := 8
var memes: Array = []
var works: Array = []
var ledger: Dictionary = {}
var charts: Dictionary = {}
var items := {"snack": 1, "bento": 0, "drink": 0}
var phase := "playing"
var loss_reason := ""
var rent_streak := 0
var goals := {"steady": false, "audience": false, "moved": false, "owned": false}
var rest_today := 0
var works_today := 0
var item_stamina_today := 0
var gym_week := 0
var gig_week := 0
var drink_arm := 0
var seen_events: Dictionary = {}
var week_event: Dictionary = {}
var log: Array = []
var work_serial := 0
var pose := "sit"


static func create_new(content: Dictionary, new_seed: int, name: String, new_gender: String) -> DiarySim:
	var sim := DiarySim.new()
	sim.catalog = content
	sim.seed_value = maxi(1, new_seed)
	sim.rng = SimRng.new(sim.seed_value)
	sim.player_name = name if name.strip_edges() != "" else "小林"
	sim.gender = "m" if new_gender == "m" else "f"
	sim.clock_minutes = 480
	sim._ensure_chart(sim.week_index())
	sim._log_line("第 1 日 08:00，%s开始记账。第 7 日结束要交租，第 14 日还有贷款。" % sim.player_name)
	return sim


func absolute_day() -> int:
	return int(clock_minutes / DAY) + 1


func week_index() -> int:
	return int((absolute_day() - 1) / 7) + 1


func weekday() -> int:
	return int((absolute_day() - 1) % 7) + 1


func minutes_of_day() -> int:
	return clock_minutes % DAY


func clock_text() -> String:
	var mins := minutes_of_day()
	return "第%d日 %02d:%02d" % [absolute_day(), int(mins / 60), mins % 60]


func gold_text(fen: int) -> String:
	var sign := "-" if fen < 0 else ""
	var value := absi(fen)
	return "%s%d.%02d" % [sign, int(value / GOLD), value % GOLD]


func next_rent_text() -> String:
	var due := _next_multiple(7 * DAY)
	return "房租 %s · 第%d日结束" % [gold_text(_rent_due_amount()), int(due / DAY)]


func next_loan_text() -> String:
	if loan_left <= 0:
		return "贷款已还清"
	var due := _next_multiple(14 * DAY)
	return "贷款 %s · 第%d日结束" % [gold_text(180 * GOLD), int(due / DAY)]


func topic_by_id(id: String) -> Dictionary:
	for topic in catalog.get("topics", []):
		if str(topic.get("id", "")) == id:
			return topic
	return {}


func meme_def(id: String) -> Dictionary:
	for meme in catalog.get("memes", []):
		if str(meme.get("id", "")) == id:
			return meme
	return {}


func heat_of(owned: Dictionary) -> float:
	var base := float(meme_def(str(owned.get("id", ""))).get("heat", 60))
	var age := maxi(0, absolute_day() - int(owned.get("day", absolute_day())))
	var uses := int(owned.get("uses", 0))
	var value := base * pow(0.85, float(age)) * pow(0.6, float(uses))
	return maxf(8.0, value)


func chart_rows() -> Array:
	_ensure_chart(week_index())
	return charts[str(week_index())]


func preview_work(form: String, topic_id: String, meme_ids: Array, link: String, polish: String) -> Dictionary:
	var topic := topic_by_id(topic_id)
	if topic.is_empty():
		return {"ok": false, "reason": "没有这个题材"}
	var picked := _resolve_memes(meme_ids)
	var plan := FusionMath.analyze(topic.get("tags", []), picked, link, _ability(), _effort(polish))
	var cost := _work_cost(form, polish)
	var end_clock := clock_minutes + int(cost["minutes"])
	return {
		"ok": true,
		"minutes": int(cost["minutes"]),
		"inspiration": int(cost["inspiration"]),
		"stamina": int(cost["stamina"]),
		"end_text": _text_at(end_clock),
		"cross_rent": _crosses_bill(clock_minutes, end_clock),
		"risk": str(plan["risk"]),
		"potential": str(plan["potential"]),
		"can_afford": inspiration >= int(cost["inspiration"]) and stamina >= int(cost["stamina"]) and works_today < 1 and phase == "playing",
		"plan": plan,
	}


func confirm_work(form: String, topic_id: String, meme_ids: Array, link: String, polish: String) -> Dictionary:
	var preview := preview_work(form, topic_id, meme_ids, link, polish)
	if not preview.get("ok", false):
		return preview
	if not preview.get("can_afford", false):
		return {"ok": false, "reason": "灵感、体力不够，或今天已经发过一篇。"}
	if bool(preview.get("cross_rent", false)) and money < _rent_due_amount():
		return {"ok": false, "reason": "这件作品会跨过一笔你现在付不起的账单。"}
	var spent := _work_cost(form, polish)
	inspiration = maxi(0, inspiration - int(spent["inspiration"]))
	stamina = maxi(0, stamina - int(spent["stamina"]))
	drink_arm = 0
	var moved := advance_time(int(spent["minutes"]))
	if phase != "playing":
		return {"ok": false, "reason": loss_reason, "bankrupt": true, "report": moved}
	var topic := topic_by_id(topic_id)
	var picked := _resolve_memes(meme_ids)
	for owned in memes:
		if meme_ids.has(str(owned.get("id", ""))):
			owned["uses"] = int(owned.get("uses", 0)) + 1
	var plan: Dictionary = preview["plan"]
	var unit := rng.unit()
	var noise := 0.9 + rng.unit() * 0.22
	var r := FusionMath.sample_r(plan, unit)
	var scores := _base_scores(form, topic)
	scores = FusionMath.apply_to_scores(scores, plan, r)
	var chart_hit := _on_chart(topic_id)
	var reach := _reach(scores, form, chart_hit, noise, plan, r, picked)
	var engage := int(round(reach * (0.08 + float(scores["fun"]) / 400.0)))
	var follow := int(round(reach * (0.012 + float(scores["fit"]) / 2500.0) * (0.7 + trust / 200.0)))
	follow = maxi(0, follow)
	var lifetime_gold := (float(reach) * 0.28 + float(fans) * 0.10) * (0.85 + trust / 200.0)
	if form == "video":
		lifetime_gold *= 1.22
	var lifetime := maxi(GOLD, int(round(lifetime_gold * float(GOLD))))
	fans += follow
	var trust_delta := (float(scores["depth"]) - 48.0) * 0.04
	if float(scores["fun"]) > 70.0 and float(scores["depth"]) < 35.0:
		trust_delta -= 1.5
	if r < 0.4 and int(plan.get("n", 0)) > 0:
		trust_delta -= 2.0
	trust = clampf(trust + trust_delta, 0.0, 100.0)
	_shift_audience(topic.get("tags", []))
	if form == "video":
		_grow("expression", 0.9)
		_grow("craft", 1.4)
	else:
		_grow("expression", 1.2)
	works_today += 1
	work_serial += 1
	var work := {
		"id": "w%d" % work_serial,
		"form": form,
		"topic": topic_id,
		"topic_name": str(topic.get("name", topic_id)),
		"born_day": absolute_day(),
		"scores": scores,
		"reach": reach,
		"engage": engage,
		"follow": follow,
		"lifetime": lifetime,
		"paid": 0,
		"r": r,
		"noise": noise,
		"memes": meme_ids.duplicate(),
		"link": link,
		"note": str(scores.get("fusion_note", "")),
		"chart": chart_hit,
	}
	works.append(work)
	pose = "sit"
	_log_line("%s完成《%s》，传播 %d，涨粉 %d。%s" % [clock_text(), work["topic_name"], reach, follow, work["note"]])
	return {"ok": true, "work": work, "report": moved}


func rest(minutes: int = 120) -> Dictionary:
	var gain := 32 if int(furniture["bed"]) >= 2 else 22
	if rest_today >= 1:
		gain = int(round(float(gain) * 0.6))
	var moved := advance_time(minutes)
	if phase != "playing":
		return {"ok": false, "reason": loss_reason, "bankrupt": true}
	stamina = mini(stamina_max, stamina + gain)
	rest_today += 1
	pose = "bed"
	var spark := ""
	if minutes_of_day() >= 23 * 60 or minutes_of_day() < 2 * 60:
		var spark_key := "spark:%d" % absolute_day()
		if not seen_events.has(spark_key):
			seen_events[spark_key] = true
			inspiration = mini(100, inspiration + 6)
			spark = "夜深时冒出一句能用的话。"
	var reason := "躺了 %d 分钟，体力 %+d，现在 %d。%s" % [minutes, gain, stamina, spark]
	_log_line("%s%s" % [clock_text(), reason])
	return {"ok": true, "gain": gain, "reason": reason, "report": moved}


func read_home() -> Dictionary:
	var gain := 18 if int(furniture["shelf"]) >= 2 else 12
	var moved := advance_time(90)
	if phase != "playing":
		return {"ok": false, "reason": loss_reason, "bankrupt": true}
	inspiration = mini(100, inspiration + gain)
	_grow("observation", 0.6)
	pose = "read"
	var reason := "在书架前读了 90 分钟，灵感 %+d，现在 %d。" % [gain, inspiration]
	_log_line("%s%s" % [clock_text(), reason])
	return {"ok": true, "gain": gain, "reason": reason, "report": moved}


func use_item(item_id: String) -> Dictionary:
	if int(items.get(item_id, 0)) <= 0:
		return {"ok": false, "reason": "没有这个消耗品。"}
	if item_stamina_today >= 40:
		return {"ok": false, "reason": "今天靠吃喝恢复的体力已经到 40。"}
	var spec := {}
	for good in catalog.get("goods", []):
		if str(good.get("id", "")) == item_id:
			spec = good
	if spec.is_empty():
		return {"ok": false, "reason": "没有这个货物。"}
	var gain := mini(int(spec.get("stamina", 0)), 40 - item_stamina_today)
	items[item_id] = int(items[item_id]) - 1
	stamina = mini(stamina_max, stamina + gain)
	item_stamina_today += gain
	if int(spec.get("craft_discount", 0)) > 0:
		drink_arm = int(spec["craft_discount"])
	return {"ok": true, "gain": gain}


func go_out(place_id: String) -> Dictionary:
	var place := _place(place_id)
	if place.is_empty():
		return {"ok": false, "reason": "没有这个地方。"}
	var now := minutes_of_day()
	var open: Array = place.get("open", [0, DAY])
	if now < int(open[0]) or now >= int(open[1]):
		return {"ok": false, "reason": "%s现在没开门。" % str(place.get("name", ""))}
	var total := int(place.get("trip", 15)) * 2 + int(place.get("activity", 60))
	var cost := int(place.get("cost", 0))
	if money < cost:
		return {"ok": false, "reason": "路费或门票不够。"}
	if not bool(place.get("interruptible", true)):
		var end_tod := (now + total) % DAY
		if end_tod >= int(open[1]) and now + total < DAY:
			return {"ok": false, "reason": "这趟结束时已经打烊，去不了。"}
	if _crosses_bill(clock_minutes, clock_minutes + total) and money - cost < _rent_due_amount() and not bool(place.get("interruptible", true)):
		return {"ok": false, "reason": "这趟会跨过一笔你现在付不起的账单。"}
	money -= cost
	var moved := advance_time(total)
	if phase != "playing":
		return {"ok": false, "reason": loss_reason, "bankrupt": true}
	inspiration = mini(100, inspiration + int(place.get("inspiration", 0)))
	stamina = maxi(0, stamina + int(place.get("stamina", 0)))
	_grow("observation", 0.65)
	var gained := _maybe_meme(place_id, 0.55)
	var event := _location_event(place_id, total)
	pose = "door"
	var reason := "从%s回来。灵感 %+d，体力 %+d。%s" % [
		str(place.get("name", "")), int(place.get("inspiration", 0)), int(place.get("stamina", 0)),
		"带回一条梗。" if gained else "这次没带回新梗。",
	]
	_log_line("%s%s" % [clock_text(), reason])
	return {"ok": true, "gained": gained, "event": event, "reason": reason, "report": moved}


func gym(package_id: String) -> Dictionary:
	if gym_week >= 3:
		return {"ok": false, "reason": "这周已经练过 3 次。"}
	var pack := {}
	for item in catalog.get("gym_packages", []):
		if str(item.get("id", "")) == package_id:
			pack = item
	if pack.is_empty():
		return {"ok": false, "reason": "没有这个套餐。"}
	if money < int(pack.get("cost", 0)):
		return {"ok": false, "reason": "这个套餐的钱不够。"}
	if stamina < int(pack.get("stamina_cost", 0)):
		return {"ok": false, "reason": "体力不够练这一档。"}
	var place := _place("gym")
	var now := minutes_of_day()
	var open: Array = place.get("open", [0, DAY])
	if now < int(open[0]) or now >= int(open[1]):
		return {"ok": false, "reason": "健身房没开门。"}
	money -= int(pack["cost"])
	stamina -= int(pack["stamina_cost"])
	var moved := advance_time(20 + 90 + 20)
	if phase != "playing":
		return {"ok": false, "reason": loss_reason, "bankrupt": true}
	var damp := 1.0 if gym_week == 0 else (0.7 if gym_week == 1 else 0.45)
	var cap_gain := int(round(float(pack.get("cap", 6)) * damp))
	stamina_max = mini(160, stamina_max + cap_gain)
	_grow("fitness", float(pack.get("fitness", 0.5)) * damp)
	gym_week += 1
	pose = "door"
	var reason := "练完%s。体力上限 %+d，现在上限 %d。" % [str(pack.get("name", "")), cap_gain, stamina_max]
	_log_line("%s%s" % [clock_text(), reason])
	return {"ok": true, "cap": cap_gain, "reason": reason, "report": moved}


func gig() -> Dictionary:
	if gig_week >= 1:
		return {"ok": false, "reason": "这周的短约已经接过了。"}
	if stamina < 8:
		return {"ok": false, "reason": "太累了，短约也做不动。"}
	var moved := advance_time(90)
	if phase != "playing":
		return {"ok": false, "reason": loss_reason, "bankrupt": true}
	stamina = maxi(0, stamina - 8)
	money += 70 * GOLD
	gig_week += 1
	pose = "sit"
	_log_line("%s交了一单短约，+%s。" % [clock_text(), gold_text(70 * GOLD)])
	return {"ok": true, "report": moved}


func buy_good(item_id: String) -> Dictionary:
	if int(items.get(item_id, 0)) >= 5:
		return {"ok": false, "reason": "这种东西最多带 5 份。"}
	var spec := {}
	for good in catalog.get("goods", []):
		if str(good.get("id", "")) == item_id:
			spec = good
	if spec.is_empty():
		return {"ok": false, "reason": "柜台上没有这个。"}
	if money < int(spec.get("cost", 0)):
		return {"ok": false, "reason": "钱不够，这笔没扣。"}
	money -= int(spec["cost"])
	items[item_id] = int(items.get(item_id, 0)) + 1
	return {"ok": true}


func upgrade(slot: String) -> Dictionary:
	var prices := {"bed": 520, "desk": 580, "shelf": 460}
	var price := int(prices.get(slot, 0))
	if price <= 0:
		return {"ok": false, "reason": "这个位置不能升级。"}
	if int(furniture.get(slot, 1)) >= 2:
		return {"ok": false, "reason": "这里已经是更好的那一件了。"}
	var fen: int = price * GOLD
	if money < fen:
		return {"ok": false, "reason": "钱不够，家具维持原样。"}
	money -= fen
	furniture[slot] = 2
	return {"ok": true}


func move_house() -> Dictionary:
	if house_tier >= 2 or owned_home:
		return {"ok": false, "reason": "已经不住这间最小的出租屋了。"}
	var fee := 600 * GOLD
	if money < fee:
		return {"ok": false, "reason": "搬家费不够。"}
	money -= fee
	house_tier = 2
	goals["moved"] = true
	_log_line("%s搬进靠门那套布局。升级还在，旧家具不进背包。" % clock_text())
	return {"ok": true}


func buy_home() -> Dictionary:
	if owned_home:
		return {"ok": false, "reason": "这套房已经是自己的了。"}
	var price := 4800 * GOLD
	var settle := accrued_rent
	if money < price + settle:
		return {"ok": false, "reason": "买房要连本周期已住的房租一起付清。"}
	money -= price + settle
	accrued_rent = 0
	owned_home = true
	house_tier = maxi(house_tier, 2)
	goals["owned"] = true
	_log_line("%s买下住房，换成第二套布局。之后只交日用，贷款还在。" % clock_text())
	return {"ok": true}


func advance_time(delta: int) -> Dictionary:
	var reports: Array = []
	var end_at := clock_minutes + delta
	while clock_minutes < end_at:
		var next_midnight := (int(clock_minutes / DAY) + 1) * DAY
		var boundary := mini(end_at, next_midnight)
		clock_minutes = boundary
		if boundary == next_midnight and boundary > last_settled:
			var report := _settle_boundary(boundary)
			reports.append(report)
			if phase != "playing":
				return {"bankrupt": true, "reports": reports}
	return {"bankrupt": false, "reports": reports}


func tail_weight(age: int) -> float:
	var n := maxi(0, age - 1)
	return exp(-0.85 * float(n)) + 0.045 * exp(-0.07 * float(n))


func tail_amount(lifetime: int, age: int) -> int:
	if age < 1:
		return 0
	var amount := int(round(float(lifetime) * tail_weight(age) / _tail_norm()))
	return amount


func state_dict() -> Dictionary:
	return {
		"schema": 2,
		"seed": seed_value,
		"rng": rng.state,
		"player_name": player_name,
		"gender": gender,
		"clock_minutes": clock_minutes,
		"last_settled": last_settled,
		"money": money,
		"stamina": stamina,
		"stamina_max": stamina_max,
		"inspiration": inspiration,
		"expression": expression,
		"observation": observation,
		"craft": craft,
		"fitness": fitness,
		"trust": trust,
		"fans": fans,
		"audience": audience.duplicate(true),
		"house_tier": house_tier,
		"owned_home": owned_home,
		"furniture": furniture.duplicate(true),
		"accrued_rent": accrued_rent,
		"loan_left": loan_left,
		"memes": memes.duplicate(true),
		"works": works.duplicate(true),
		"ledger": ledger.duplicate(true),
		"charts": charts.duplicate(true),
		"items": items.duplicate(true),
		"phase": phase,
		"loss_reason": loss_reason,
		"rent_streak": rent_streak,
		"goals": goals.duplicate(true),
		"rest_today": rest_today,
		"works_today": works_today,
		"item_stamina_today": item_stamina_today,
		"gym_week": gym_week,
		"gig_week": gig_week,
		"drink_arm": drink_arm,
		"seen_events": seen_events.duplicate(true),
		"week_event": week_event.duplicate(true),
		"log": log.duplicate(true),
		"work_serial": work_serial,
		"pose": pose,
	}


static func from_state(content: Dictionary, data: Dictionary) -> DiarySim:
	var sim := DiarySim.new()
	sim.catalog = content
	sim.seed_value = int(data["seed"])
	sim.rng = SimRng.new(1)
	sim.rng.state = int(data["rng"])
	sim.player_name = str(data["player_name"])
	sim.gender = str(data["gender"])
	sim.clock_minutes = int(data["clock_minutes"])
	sim.last_settled = int(data["last_settled"])
	sim.money = int(data["money"])
	sim.stamina = int(data["stamina"])
	sim.stamina_max = int(data["stamina_max"])
	sim.inspiration = int(data["inspiration"])
	sim.expression = float(data["expression"])
	sim.observation = float(data["observation"])
	sim.craft = float(data["craft"])
	sim.fitness = float(data["fitness"])
	sim.trust = float(data["trust"])
	sim.fans = int(data["fans"])
	sim.audience = data["audience"].duplicate(true)
	sim.house_tier = int(data["house_tier"])
	sim.owned_home = bool(data["owned_home"])
	sim.furniture = data["furniture"].duplicate(true)
	sim.accrued_rent = int(data["accrued_rent"])
	sim.loan_left = int(data["loan_left"])
	sim.memes = data["memes"].duplicate(true)
	sim.works = data["works"].duplicate(true)
	sim.ledger = data["ledger"].duplicate(true)
	sim.charts = data["charts"].duplicate(true)
	sim.items = data["items"].duplicate(true)
	sim.phase = str(data["phase"])
	sim.loss_reason = str(data["loss_reason"])
	sim.rent_streak = int(data["rent_streak"])
	sim.goals = data["goals"].duplicate(true)
	sim.rest_today = int(data["rest_today"])
	sim.works_today = int(data["works_today"])
	sim.item_stamina_today = int(data["item_stamina_today"])
	sim.gym_week = int(data["gym_week"])
	sim.gig_week = int(data["gig_week"])
	sim.drink_arm = int(data["drink_arm"])
	sim.seen_events = data["seen_events"].duplicate(true)
	sim.week_event = data["week_event"].duplicate(true)
	sim.log = data["log"].duplicate(true)
	sim.work_serial = int(data["work_serial"])
	sim.pose = str(data.get("pose", "sit"))
	return sim


func _settle_boundary(boundary: int) -> Dictionary:
	var ended := int(boundary / DAY)
	var gained := _pay_tails(ended)
	var weekly := _weekly_rent()
	var share := int(weekly / 7)
	if ended % 7 == 0:
		share += weekly % 7
	if not owned_home:
		accrued_rent += share
	var rent_paid := 0
	var loan_paid := 0
	if ended % 7 == 0:
		var due := accrued_rent + _upkeep()
		if money < due:
			phase = "lost"
			loss_reason = "付不起第 %d 日结束的房租和日用，还差 %s。" % [ended, gold_text(due - money)]
			return {"ended": ended, "lost": true, "reason": loss_reason, "income": gained}
		money -= due
		rent_paid = due
		accrued_rent = 0
		rent_streak += 1
		if rent_streak >= 4:
			goals["steady"] = true
	if ended % 14 == 0 and ended > 0 and loan_left > 0:
		var loan := 180 * GOLD
		if money < loan:
			phase = "lost"
			loss_reason = "付不起第 %d 日结束的贷款，还差 %s。" % [ended, gold_text(loan - money)]
			return {"ended": ended, "lost": true, "reason": loss_reason, "income": gained, "rent": rent_paid}
		money -= loan
		loan_left -= 1
		loan_paid = loan
	rest_today = 0
	works_today = 0
	item_stamina_today = 0
	if ended % 7 == 0:
		gym_week = 0
		gig_week = 0
		_ensure_chart(int(ended / 7) + 1)
	if fans >= 400:
		goals["audience"] = true
	last_settled = boundary
	_log_line("第%d日结束。到账 %s。%s%s" % [
		ended, gold_text(gained),
		("交租 %s。" % gold_text(rent_paid)) if rent_paid > 0 else "",
		("还贷 %s。" % gold_text(loan_paid)) if loan_paid > 0 else "",
	])
	return {"ended": ended, "lost": false, "income": gained, "rent": rent_paid, "loan": loan_paid}


func _pay_tails(ended_day: int) -> int:
	var total := 0
	for work in works:
		var age := ended_day - int(work.get("born_day", ended_day)) + 1
		if age < 1:
			continue
		var key := "%s:%d" % [str(work.get("id", "")), age]
		if ledger.has(key):
			continue
		var amount := tail_amount(int(work.get("lifetime", 0)), age)
		if amount <= 0:
			continue
		ledger[key] = amount
		money += amount
		work["paid"] = int(work.get("paid", 0)) + amount
		total += amount
	return total


func income_series(work: Dictionary) -> Array:
	var born := int(work.get("born_day", 1))
	var work_id := str(work.get("id", ""))
	var life := int(work.get("lifetime", 0))
	var rows: Array = []
	var total := 0
	var last_age := absolute_day() - born
	for age in range(1, last_age + 1):
		var key := "%s:%d" % [work_id, age]
		if not ledger.has(key):
			continue
		var raw: Variant = ledger[key]
		var amt := tail_amount(life, age)
		if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
			amt = int(raw)
		total += amt
		rows.append({"age": age, "day": born + age - 1, "amount": amt, "total": total})
	return rows


func _tail_norm() -> float:
	var total := 0.0
	for age in range(1, 421):
		total += tail_weight(age)
	return maxf(0.01, total)


func _weekly_rent() -> int:
	if owned_home:
		return 0
	return 320 * GOLD if house_tier >= 2 else 200 * GOLD


func _upkeep() -> int:
	return 50 * GOLD if house_tier >= 2 and not owned_home else 40 * GOLD


func _rent_due_amount() -> int:
	return _weekly_rent() + _upkeep()


func _work_cost(form: String, polish: String) -> Dictionary:
	var minutes := 180 if form == "article" else 300
	var insp := 25 if form == "article" else 35
	var stam := 8 if form == "article" else 14
	if int(furniture.get("desk", 1)) >= 2:
		stam = maxi(1, stam - 2)
	stam = maxi(1, stam - drink_arm)
	if polish == "short":
		minutes += 30
		insp += 4
	elif polish == "careful":
		minutes += 60
		insp += 8
	return {"minutes": minutes, "inspiration": insp, "stamina": stam}


func _base_scores(form: String, topic: Dictionary) -> Dictionary:
	var tags: Array = topic.get("tags", [])
	var depth := clampf(observation * 0.9 + expression * 0.35, 8, 92)
	if int(furniture.get("shelf", 1)) >= 2 and _on_chart(str(topic.get("id", ""))):
		depth += 3.0
	var fun := clampf(18.0 + expression * 1.05, 8, 94)
	var voice := clampf(expression * 1.15, 8, 96)
	var audio := 0.0
	if form == "video":
		audio = clampf(craft * 1.1 + (10.0 if int(furniture.get("desk", 1)) >= 2 else 4.0), 0, 96)
	var fit := 0.0
	if tags.is_empty():
		fit = 40.0
	else:
		for tag in tags:
			fit += float(audience.get(tag, 0.0))
		fit = clampf(fit / float(tags.size()) * 140.0, 12, 96)
	var repeats := 0
	for work in works:
		if str(work.get("topic", "")) == str(topic.get("id", "")) and absolute_day() - int(work.get("born_day", 0)) <= 7:
			repeats += 1
	var repeat_table: Array = [1.0, 0.8, 0.6, 0.45, 0.35]
	var repeat_mult: float = float(repeat_table[mini(repeats, 4)])
	fit *= repeat_mult
	return {"depth": depth, "fun": fun, "voice": voice, "audio": audio, "fit": fit}


func _reach(scores: Dictionary, form: String, chart_hit: bool, noise: float, plan: Dictionary, r: float, picked: Array) -> int:
	var appeal := 0.45 * float(scores["fun"]) + 0.4 * float(scores["fit"]) + 0.15 * float(scores["depth"])
	if form == "video":
		appeal = 0.35 * float(scores["fun"]) + 0.3 * float(scores["fit"]) + 0.15 * float(scores["depth"]) + 0.2 * float(scores["audio"])
	var week_n := 1
	for work in works:
		if int(work.get("born_day", 0)) > absolute_day() - 7:
			week_n += 1
	var decay_table: Array = [1.0, 0.84, 0.64, 0.44, 0.28, 0.18, 0.14]
	var week_decay: float = float(decay_table[mini(week_n - 1, 6)])
	var chart := 1.12 if chart_hit else 0.96
	var meme_boost := 0.0
	if int(plan.get("n", 0)) > 0 and r >= 0.4:
		var heat := 0.0
		for meme in picked:
			heat += float(meme.get("heat_now", 40))
		meme_boost = heat * float(plan.get("theme_fit", 0.5)) * r * 1.15
	var reach: float = (360.0 + float(fans) * 1.05) * (appeal / 52.0) * week_decay * chart * noise + meme_boost
	return maxi(1, int(round(reach)))


func _on_chart(topic_id: String) -> bool:
	var rows: Array = chart_rows()
	for i in mini(3, rows.size()):
		if str(rows[i].get("id", "")) == topic_id:
			return true
	return false


func _ensure_chart(week: int) -> void:
	var key := str(week)
	if charts.has(key):
		return
	var roller := SimRng.new((seed_value + week * 97) ^ 0x51ED)
	var rows: Array = []
	for topic in catalog.get("topics", []):
		var bias := 0.0
		for tag in topic.get("tags", []):
			bias += float(audience.get(tag, 0.0))
		rows.append({
			"id": str(topic.get("id", "")),
			"name": str(topic.get("name", "")),
			"score": int(roller.next_u32() % 700) + int(bias * 400.0),
		})
	rows.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	charts[key] = rows


func _resolve_memes(ids: Array) -> Array:
	var picked: Array = []
	for id in ids:
		for owned in memes:
			if str(owned.get("id", "")) == str(id):
				var spec := meme_def(str(id)).duplicate(true)
				spec["heat_now"] = heat_of(owned)
				picked.append(spec)
	return picked


func _maybe_meme(place_id: String, chance: float) -> bool:
	if rng.unit() > chance:
		return false
	var pool: Array = []
	for meme in catalog.get("memes", []):
		if str(meme.get("place", "")) == place_id and not _owns(str(meme.get("id", ""))):
			pool.append(meme)
	if pool.is_empty():
		return false
	var picked: Dictionary = pool[rng.pick_index(pool.size())]
	memes.append({"id": str(picked.get("id", "")), "day": absolute_day(), "uses": 0})
	return true


func _owns(id: String) -> bool:
	for owned in memes:
		if str(owned.get("id", "")) == id:
			return true
	return false


func _location_event(place_id: String, trip: int) -> Dictionary:
	var end_tod := minutes_of_day()
	var start_tod := end_tod - trip
	if start_tod < 0:
		start_tod = 0
	if place_id == "park" and weekday() == 6 and _overlaps(start_tod, end_tod, 18 * 60, 21 * 60):
		if not _mark_week_event("park_evening"):
			return {}
		inspiration = mini(100, inspiration + 8)
		_maybe_meme("park", 0.7)
		return {"text": "这一周的第六日傍晚，公园晚风里有人把一天讲得很轻。你坐了一会儿。"}
	if place_id == "park" and weekday() == 7 and _overlaps(start_tod, end_tod, 8 * 60, 11 * 60):
		if not _mark_week_event("park_morning"):
			return {}
		inspiration = mini(100, inspiration + 6)
		return {"text": "这一周的第七日早晨，公园里有人在读你上周的句子。"}
	if place_id == "library" and weekday() <= 5 and _overlaps(start_tod, end_tod, 14 * 60, 17 * 60):
		if not _mark_week_event("library_note"):
			return {}
		inspiration = mini(100, inspiration + 5)
		_maybe_meme("library", 0.5)
		return {"text": "馆员递来一本边角写满批注的书。"}
	if place_id == "cinema" and (weekday() == 3 or weekday() == 5) and _overlaps(start_tod, end_tod, 19 * 60, 22 * 60):
		if not _mark_week_event("cinema_short"):
			return {}
		inspiration = mini(100, inspiration + 8)
		_maybe_meme("cinema", 0.65)
		return {"text": "散场前放了一小段没人说话的片子。灯还没亮。"}
	if place_id == "mall" and weekday() == 6 and _overlaps(start_tod, end_tod, 13 * 60, 18 * 60):
		if not _mark_week_event("mall_pop"):
			return {}
		inspiration = mini(100, inspiration + 6)
		return {"text": "这一周的第六日，商场里有个小快闪，你看了一圈价签。"}
	return {}


func _overlaps(start_tod: int, end_tod: int, window_start: int, window_end: int) -> bool:
	return start_tod < window_end and end_tod > window_start


func _mark_week_event(event_id: String) -> bool:
	var key := "%s:%d" % [event_id, week_index()]
	if week_event.has(key):
		return false
	week_event[key] = true
	return true


func _shift_audience(tags: Array) -> void:
	if tags.is_empty():
		return
	for tag in audience.keys():
		audience[tag] = float(audience[tag]) * 0.92
	var share := 0.08 / float(tags.size())
	for tag in tags:
		audience[tag] = float(audience.get(tag, 0.0)) + share
	var total := 0.0
	for tag in audience.keys():
		total += float(audience[tag])
	if total <= 0.0:
		return
	for tag in audience.keys():
		audience[tag] = float(audience[tag]) / total


func _ability() -> float:
	return clampf((expression + observation) / 160.0, 0.0, 1.0)


func _effort(polish: String) -> float:
	if polish == "careful":
		return 1.0
	if polish == "short":
		return 0.45
	return 0.0


func _grow(stat: String, amount: float) -> void:
	var current := float(get(stat))
	var room := maxf(0.0, 80.0 - current)
	set(stat, current + amount * clampf(room / 40.0, 0.15, 1.0))


func _place(id: String) -> Dictionary:
	for place in catalog.get("places", []):
		if str(place.get("id", "")) == id:
			return place
	return {}


func _crosses_bill(start: int, end_at: int) -> bool:
	var cursor := (int(start / DAY) + 1) * DAY
	while cursor <= end_at:
		var ended := int(cursor / DAY)
		if ended % 7 == 0 or (ended % 14 == 0 and loan_left > 0):
			return true
		cursor += DAY
	return false


func _next_multiple(step: int) -> int:
	var cursor := (int(clock_minutes / DAY) + 1) * DAY
	while cursor % step != 0:
		cursor += DAY
	return cursor


func _text_at(at: int) -> String:
	var day := int(at / DAY) + 1
	var mins := at % DAY
	return "第%d日 %02d:%02d" % [day, int(mins / 60), mins % 60]


func _log_line(text: String) -> void:
	log.append({"day": absolute_day(), "text": text})
	while log.size() > 80:
		log.remove_at(0)
