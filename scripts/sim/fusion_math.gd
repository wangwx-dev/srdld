extends RefCounted
class_name FusionMath

## Meme fusion is a spread around a ceiling, not a linear bonus and not a hard cap.
## R is sampled once at publish. Preview never consumes the match RNG.


static func sigmoid(x: float) -> float:
	return 1.0 / (1.0 + exp(-x))


static func analyze(topic_tags: Array, memes: Array, link: String, ability: float, effort: float) -> Dictionary:
	var n := memes.size()
	if n <= 0:
		return {
			"n": 0, "phi": 0.0, "kappa": 0.0, "control": 0.0, "ease": 1.0,
			"mean": 0.0, "spread": 0.0, "theme_fit": 1.0, "compat": 1.0,
			"risk": "无梗", "potential": "靠题材和手艺，稳定，没有融梗上限",
		}
	var fit_sum := 0.0
	for meme in memes:
		fit_sum += _tag_fit(topic_tags, meme.get("tags", []))
	var theme_fit: float = fit_sum / float(n)
	var pair_sum := 0.0
	var pairs := 0
	for i in n:
		for j in range(i + 1, n):
			pair_sum += _compat(memes[i], memes[j])
			pairs += 1
	var compat := 1.0 if pairs == 0 else pair_sum / float(pairs)
	var structure := 0.92
	match link:
		"串联":
			structure = 0.55 + 0.45 * compat
		"反差":
			structure = 0.62 + 0.28 * (1.0 - abs(compat - 0.45))
		"侧击":
			structure = 0.7 + 0.22 * theme_fit
		"堆砌":
			structure = 0.28 + 0.2 * compat
		_:
			structure = 0.55 + 0.45 * compat
	var phi: float = theme_fit * structure * (0.48 + 1.45 * (1.0 - exp(-0.48 * float(maxi(0, n - 1)))))
	var links := float(n * (n - 1) / 2)
	var kappa: float = 0.16 * links + 0.55 * links * (1.0 - compat) + 0.45 * float(n) * (1.0 - theme_fit)
	if link == "堆砌":
		kappa += 0.35 * float(n)
	if link == "侧击":
		kappa *= 0.82
	var control: float = 0.18 + 0.9 * clampf(ability, 0.0, 1.0) + 0.16 * effort
	if link == "串联":
		control += 0.08 * compat
	var ease: float = clampf(control / (1.0 + kappa), 0.0, 0.92)
	# Ease near 0 stays around a coin-flip. A careful, fitting link can sit higher.
	var mean: float = sigmoid(-0.15 + 2.1 * ease)
	var spread: float = clampf(0.06 + 0.42 * kappa / (1.0 + kappa) - 0.12 * control, 0.05, 0.46)
	var risk := "较稳健"
	if spread > 0.28 or mean < 0.55:
		risk = "失手风险偏高，下行会伤表达和契合"
	elif spread > 0.16:
		risk = "有翻车空间，融住时上限更高"
	var potential := "若融住，发挥空间高于少梗；不保证这次融住"
	if phi < 0.35:
		potential = "这些梗和题材不太咬合，数量堆不出发挥空间"
	return {
		"n": n, "phi": phi, "kappa": kappa, "control": control, "ease": ease,
		"mean": mean, "spread": spread, "theme_fit": theme_fit, "compat": compat,
		"risk": risk, "potential": potential,
	}


static func sample_r(plan: Dictionary, unit: float) -> float:
	if int(plan.get("n", 0)) <= 0:
		return 1.0
	var mean := float(plan["mean"])
	var spread := float(plan["spread"])
	var centered := clampf(unit, 0.001, 0.999) * 2.0 - 1.0
	return clampf(mean + centered * spread, 0.02, 0.98)


static func apply_to_scores(base: Dictionary, plan: Dictionary, r: float) -> Dictionary:
	var out := base.duplicate(true)
	if int(plan.get("n", 0)) <= 0:
		out["fusion_note"] = "这篇没有融梗，评价只看题材、属性和家具。"
		return out
	var phi := float(plan["phi"])
	var lift := phi * pow(r, 1.7) * 28.0
	var drop := (1.0 - r) * (6.0 + float(plan["n"]) * 3.2) * (1.15 - float(plan["theme_fit"]))
	if r >= 0.7:
		out["depth"] = clampf(float(out["depth"]) + lift * 0.45, 0, 100)
		out["voice"] = clampf(float(out["voice"]) + lift * 0.35, 0, 100)
		out["fun"] = clampf(float(out["fun"]) + lift * 0.4, 0, 100)
		out["fit"] = clampf(float(out["fit"]) + lift * 0.3, 0, 100)
		out["fusion_note"] = "这几条梗这次接上了。"
	elif r >= 0.4:
		out["fun"] = clampf(float(out["fun"]) + lift * 0.2, 0, 100)
		out["voice"] = clampf(float(out["voice"]) - drop * 0.25, 0, 100)
		out["fusion_note"] = "梗有一点火花，但过渡还不稳。"
	else:
		out["depth"] = clampf(float(out["depth"]) - drop, 0, 100)
		out["voice"] = clampf(float(out["voice"]) - drop * 0.8, 0, 100)
		out["fit"] = clampf(float(out["fit"]) - drop * 0.55, 0, 100)
		out["fun"] = clampf(float(out["fun"]) - drop * 0.35, 0, 100)
		out["fusion_note"] = "缺过渡，论证跳来跳去。"
	return out


static func _tag_fit(topic_tags: Array, meme_tags: Array) -> float:
	if meme_tags.is_empty() or topic_tags.is_empty():
		return 0.35
	var hit := 0
	for tag in meme_tags:
		if topic_tags.has(tag):
			hit += 1
	return clampf(float(hit) / float(mini(meme_tags.size(), topic_tags.size())), 0.15, 1.0)


static func _compat(a: Dictionary, b: Dictionary) -> float:
	if str(a.get("family", "")) == str(b.get("family", "")):
		return 0.86
	var shared := false
	for tag in a.get("tags", []):
		if b.get("tags", []).has(tag):
			shared = true
	return 0.62 if shared else 0.28
