extends RefCounted
class_name Formulas

## Pure traffic and payout math. `variance` < 0 means "preview": the reported
## views use 1.00, and view_low / view_high use the documented variance band.


static func round_half_up(value: float) -> int:
	if value <= 0.0:
		return 0
	return int(floor(value + 0.5))


static func r3(value: float) -> float:
	return round(value * 1000.0) / 1000.0


static func compute(p: Dictionary) -> Dictionary:
	var balance: Dictionary = p["balance"]
	var platform: Dictionary = p["platform"]
	var topic: Dictionary = p["topic"]
	var format_id := str(p["format_id"])
	var effort_id := str(p["effort_id"])
	var quality_cfg: Dictionary = balance["quality"]
	var format_cfg: Dictionary = balance["formats"][format_id]
	var effort_cfg: Dictionary = balance["efforts"][effort_id]
	var factors: Array = []

	var writing := float(p["writing"])
	var editing: float = max(0.0, float(p["editing"]) - float(p.get("editing_penalty", 0.0)))
	var inspiration := float(p["inspiration"])
	var mood := float(p["mood"])
	var stamina := float(p["stamina"])
	var stress := float(p["stress"])
	var reputation := float(p["reputation"])

	var quality := float(quality_cfg["base"])
	factors.append(_add("base", quality))
	var writing_part := writing * float(quality_cfg["writing"]) * float(format_cfg["writing_w"])
	quality += writing_part
	factors.append(_add("writing", writing_part))
	var editing_part := editing * float(quality_cfg["editing"]) * float(format_cfg["editing_w"])
	quality += editing_part
	factors.append(_add("editing", editing_part))
	if float(p.get("editing_penalty", 0.0)) > 0.0:
		factors.append(_note("editing_penalty", float(p["editing_penalty"])))
	var inspiration_part := inspiration * float(quality_cfg["inspiration"])
	quality += inspiration_part
	factors.append(_add("inspiration", inspiration_part))
	var mood_part := mood * float(quality_cfg["mood"])
	quality += mood_part
	factors.append(_add("mood", mood_part))
	var stamina_part := stamina * float(quality_cfg["stamina"])
	quality += stamina_part
	factors.append(_add("stamina", stamina_part))
	var stress_part := stress * float(quality_cfg["stress"])
	quality -= stress_part
	factors.append(_add("stress", -stress_part))
	var reputation_part := (reputation - 50.0) * float(quality_cfg["reputation"])
	quality += reputation_part
	factors.append(_add("reputation", reputation_part))
	if bool(p.get("duel_active", false)):
		quality += float(balance["duel_quality"])
		factors.append(_add("duel", float(balance["duel_quality"])))

	var bonus: Dictionary = topic.get("bonus", {})
	var bonus_on := _bonus_active(bonus, p)
	if bonus_on and float(bonus.get("quality", 0.0)) != 0.0:
		quality += float(bonus["quality"])
		factors.append(_add("topic_bonus", float(bonus["quality"])))

	quality *= float(effort_cfg["quality_mult"])
	factors.append(_mult("effort", float(effort_cfg["quality_mult"])))

	var inspiration_cost := float(effort_cfg["inspiration"])
	if inspiration + 0.001 < inspiration_cost:
		var ratio := 0.0 if inspiration_cost <= 0.0 else inspiration / inspiration_cost
		var low_mult := float(balance["inspiration_floor_mult"]) + (1.0 - float(balance["inspiration_floor_mult"])) * ratio
		quality *= low_mult
		factors.append(_mult("inspiration_low", low_mult))

	var stamina_cost := float(effort_cfg["stamina"])
	if stamina + 0.001 < stamina_cost:
		var ratio := 0.0 if stamina_cost <= 0.0 else stamina / stamina_cost
		var low_mult: float = max(float(quality_cfg["low_stamina_floor"]), ratio)
		quality *= low_mult
		factors.append(_mult("stamina_low", low_mult))

	quality = clampf(quality, float(quality_cfg["min"]), float(quality_cfg["max"]))

	var fit := float(topic["fit"][str(platform["id"])])
	factors.append(_mult("fit", fit))
	if bonus_on and float(bonus.get("fit_mult", 1.0)) != 1.0:
		fit *= float(bonus["fit_mult"])
		factors.append(_mult("topic_fit_bonus", float(bonus["fit_mult"])))

	var trend := str(p.get("trend", ""))
	var trend_hit := false
	for tag in topic.get("tags", []):
		if str(tag) == trend:
			trend_hit = true
			break
	var sensitivity := float(platform["trend_sensitivity"])
	var trend_mult := 1.0 + float(balance["trend_bonus"]) * sensitivity if trend_hit else 1.0 - float(balance["trend_penalty"]) * sensitivity
	factors.append({
		"id": "trend",
		"kind": "mult",
		"amount": r3(trend_mult),
		"tag": trend,
		"matched": trend_hit,
	})

	var fatigue := float(p.get("fatigue", 0.0))
	var fatigue_mult := clampf(1.0 - fatigue / float(balance["fatigue_divisor"]), float(balance["fatigue_floor"]), 1.0)
	factors.append({
		"id": "fatigue",
		"kind": "mult",
		"amount": r3(fatigue_mult),
		"fatigue": r3(fatigue),
	})

	var format_match := format_id == str(platform["preferred_format"])
	var format_mult := float(balance["format_match"] if format_match else balance["format_off"])
	factors.append({
		"id": "format",
		"kind": "mult",
		"amount": r3(format_mult),
		"matched": format_match,
	})

	var quality_mult := float(balance["quality_reach_base"]) + (quality / 100.0) * float(balance["quality_reach_span"])
	factors.append(_mult("quality_reach", quality_mult))
	var reach_mult := float(effort_cfg["reach_mult"])
	factors.append(_mult("reach_effort", reach_mult))

	var as_sponsor := bool(p.get("as_sponsor", false))
	var contract: Dictionary = p.get("contract", {})
	var sponsor_view := 1.0
	if as_sponsor and not contract.is_empty():
		sponsor_view = float(balance["sponsor_view_mult"])
		factors.append(_mult("sponsor_view", sponsor_view))

	var audience := float(platform["cold_audience"]) + float(p["fans"]) * float(platform["fan_weight"])
	factors.append({"id": "audience", "kind": "note", "amount": r3(audience)})

	var chain := audience * format_mult * trend_mult * fatigue_mult * quality_mult * fit * reach_mult * sponsor_view
	var var_min := float(balance["variance_min"])
	var var_max := float(balance["variance_max"])
	var requested := float(p.get("variance", -1.0))
	var var_used := requested if requested >= 0.0 else 1.0
	factors.append({
		"id": "variance",
		"kind": "mult",
		"amount": r3(var_used),
		"preview": requested < 0.0,
	})

	var views := round_half_up(chain * var_used)
	var view_low := round_half_up(chain * var_min)
	var view_high := round_half_up(chain * var_max)
	var ad_money := _ad_money(views, quality, reputation, platform, balance)
	var money_low := _ad_money(view_low, quality, reputation, platform, balance)
	var money_high := _ad_money(view_high, quality, reputation, platform, balance)
	var followers := _followers(views, quality, fit, platform, balance)
	var follower_low := _followers(view_low, quality, fit, platform, balance)
	var follower_high := _followers(view_high, quality, fit, platform, balance)

	var organic_rep := clampf(
		(quality - float(balance["rep_quality_center"])) * float(balance["rep_from_quality"]),
		float(balance["rep_min_delta"]),
		float(balance["rep_max_delta"])
	)
	var sponsor_pay := 0
	var sponsor_rep := 0.0
	var sponsor_note := "none"
	var sponsor_completes := false
	if as_sponsor and not contract.is_empty():
		sponsor_completes = true
		var tag_ok := false
		for tag in topic.get("tags", []):
			if str(tag) == str(contract.get("tag", "")):
				tag_ok = true
				break
		var platform_ok := str(contract.get("platform", "")) == str(platform["id"])
		var pay := int(contract.get("pay", 0))
		if not tag_ok or not platform_ok:
			sponsor_pay = round_half_up(float(pay) * float(balance["sponsor_mismatch_pay"]))
			sponsor_rep = float(balance["sponsor_mismatch_rep"])
			sponsor_note = "mismatch"
		elif quality < float(balance["sponsor_sloppy_quality"]):
			sponsor_pay = round_half_up(float(pay) * float(balance["sponsor_sloppy_pay"]))
			sponsor_rep = float(balance["sponsor_sloppy_rep"])
			sponsor_note = "sloppy"
		elif quality >= float(balance["sponsor_great_quality"]):
			sponsor_pay = pay
			sponsor_rep = float(balance["sponsor_great_rep"])
			sponsor_note = "great"
		else:
			sponsor_pay = pay
			sponsor_rep = float(balance["sponsor_ok_rep"])
			sponsor_note = "ok"
		factors.append({"id": "sponsor_pay", "kind": "note", "amount": sponsor_pay, "note": sponsor_note})
		factors.append({"id": "sponsor_rep", "kind": "note", "amount": r3(sponsor_rep), "note": sponsor_note})
		money_low += sponsor_pay
		money_high += sponsor_pay

	factors.append(_add("organic_rep", organic_rep))

	return {
		"quality": r3(quality),
		"views": views,
		"view_low": view_low,
		"view_high": view_high,
		"followers": followers,
		"follower_low": follower_low,
		"follower_high": follower_high,
		"ad_money": ad_money,
		"money_low": money_low,
		"money_high": money_high,
		"sponsor_pay": sponsor_pay,
		"sponsor_rep": r3(sponsor_rep),
		"sponsor_note": sponsor_note,
		"sponsor_completes": sponsor_completes,
		"rep_delta": r3(organic_rep + sponsor_rep),
		"factors": factors,
		"stamina_cost": int(effort_cfg["stamina"]),
		"inspiration_cost": int(effort_cfg["inspiration"]),
		"stress_delta": int(effort_cfg["stress"]),
		"mood_delta": int(effort_cfg["mood"]),
		"variance_used": r3(var_used),
	}


static func _ad_money(views: int, quality: float, reputation: float, platform: Dictionary, balance: Dictionary) -> int:
	var quality_term := float(balance["revenue_quality_base"]) + quality * float(balance["revenue_quality_span"])
	var reputation_term := float(balance["revenue_rep_base"]) + reputation * float(balance["revenue_rep_span"])
	return round_half_up(float(views) / 1000.0 * float(platform["rpm"]) * quality_term * reputation_term)


static func _followers(views: int, quality: float, fit: float, platform: Dictionary, balance: Dictionary) -> int:
	var quality_term := float(balance["follow_quality_base"]) + quality * float(balance["follow_quality_span"])
	var gain := float(views) * float(platform["follow_rate"]) * quality_term * fit
	return mini(round_half_up(gain), int(balance["max_follower_gain"]))


static func _bonus_active(bonus: Dictionary, p: Dictionary) -> bool:
	if bonus.is_empty():
		return false
	if str(bonus.get("kind", "")) != "outing_or_inspiration":
		return false
	if bool(p.get("did_outing", false)):
		return true
	return float(p.get("inspiration", 0.0)) >= float(bonus.get("inspiration_at_least", 999))


static func _add(id: String, amount: float) -> Dictionary:
	return {"id": id, "kind": "add", "amount": r3(amount)}


static func _mult(id: String, amount: float) -> Dictionary:
	return {"id": id, "kind": "mult", "amount": r3(amount)}


static func _note(id: String, amount: float) -> Dictionary:
	return {"id": id, "kind": "note", "amount": r3(amount)}
