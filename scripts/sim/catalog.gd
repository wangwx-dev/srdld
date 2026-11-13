extends RefCounted
class_name Catalog

var balance: Dictionary = {}
var platforms: Array = []
var topics: Array = []
var events: Array = []
var sponsors: Array = []
var rivals: Array = []
var platform_by_id: Dictionary = {}
var topic_by_id: Dictionary = {}
var problems: Array[String] = []


static func load_default() -> Catalog:
	var catalog := Catalog.new()
	catalog.load_dir("res://data")
	return catalog


func load_dir(dir_path: String) -> void:
	balance = _read_json(dir_path.path_join("balance.json"))
	platforms = _read_json(dir_path.path_join("platforms.json"))
	topics = _read_json(dir_path.path_join("topics.json"))
	events = _read_json(dir_path.path_join("events.json"))
	sponsors = _read_json(dir_path.path_join("sponsors.json"))
	rivals = _read_json(dir_path.path_join("rivals.json"))
	platform_by_id.clear()
	topic_by_id.clear()
	if typeof(platforms) != TYPE_ARRAY:
		platforms = []
	if typeof(topics) != TYPE_ARRAY:
		topics = []
	if typeof(events) != TYPE_ARRAY:
		events = []
	if typeof(sponsors) != TYPE_ARRAY:
		sponsors = []
	if typeof(rivals) != TYPE_ARRAY:
		rivals = []
	if typeof(balance) != TYPE_DICTIONARY:
		balance = {}
	for platform in platforms:
		platform_by_id[str(platform.get("id", ""))] = platform
	for topic in topics:
		topic_by_id[str(topic.get("id", ""))] = topic
	var loaded_problems: Array[String] = []
	for item in problems:
		loaded_problems.append(str(item))
	problems = loaded_problems
	problems.append_array(validate())


func platform(id: String) -> Dictionary:
	return platform_by_id.get(id, {})


func topic(id: String) -> Dictionary:
	return topic_by_id.get(id, {})


func validate() -> Array[String]:
	var found: Array[String] = []
	if balance.is_empty():
		found.append("balance missing")
		return found
	if platforms.is_empty():
		found.append("no platforms")
	var ids := {}
	for platform in platforms:
		var id := str(platform.get("id", ""))
		if id == "" or ids.has(id):
			found.append("bad platform id")
		ids[id] = true
		for key in ["cold_audience", "fan_weight", "follow_rate", "rpm", "trend_sensitivity", "fatigue_gain"]:
			if not _is_num(platform.get(key)):
				found.append("platform %s missing %s" % [id, key])
		if not balance.get("formats", {}).has(str(platform.get("preferred_format", ""))):
			found.append("platform %s bad format" % id)
	for topic in topics:
		var id := str(topic.get("id", ""))
		if id == "" or topic_by_id.get(id) != topic:
			found.append("bad topic id")
		var tags: Array = topic.get("tags", [])
		if tags.is_empty():
			found.append("topic %s has no tags" % id)
		var fit: Dictionary = topic.get("fit", {})
		for platform in platforms:
			if not _is_num(fit.get(platform.get("id"))):
				found.append("topic %s missing fit %s" % [id, platform.get("id")])
			else:
				var fit_value := float(fit[platform.get("id")])
				if fit_value < 0.5 or fit_value > 1.5:
					found.append("topic %s fit out of range" % id)
	var tag_set := {}
	for topic in topics:
		for tag in topic.get("tags", []):
			tag_set[str(tag)] = true
	for tag in balance.get("trend_tags", []):
		if not tag_set.has(str(tag)):
			found.append("trend tag has no topic: %s" % tag)
	for event in events:
		if str(event.get("pool", "")) not in ["morning", "outing"]:
			found.append("event %s bad pool" % event.get("id"))
		if not bool(event.get("auto", false)):
			var choices: Array = event.get("choices", [])
			if choices.size() < 2:
				found.append("event %s needs choices" % event.get("id"))
			for choice in choices:
				if str(choice.get("id", "")) == "" or str(choice.get("label", "")) == "":
					found.append("event %s bad choice" % event.get("id"))
				var money = choice.get("effects", {}).get("money", 0)
				if _is_num(money) and (float(money) < -200.0 or float(money) > 200.0):
					found.append("event money out of bounds")
		elif event.has("effects"):
			var money = event.effects.get("money", 0)
			if _is_num(money) and (float(money) < -200.0 or float(money) > 200.0):
				found.append("event money out of bounds")
	for sponsor in sponsors:
		if not platform_by_id.has(str(sponsor.get("platform", ""))):
			found.append("sponsor bad platform")
		if not tag_set.has(str(sponsor.get("tag", ""))):
			found.append("sponsor bad tag")
		if int(sponsor.get("pay", 0)) <= 0 or int(sponsor.get("pay", 0)) > 800:
			found.append("sponsor pay out of bounds")
	if int(balance.get("days", 0)) != 30:
		found.append("campaign is not 30 days")
	if balance.get("bills", []).size() < 3:
		found.append("need three bills")
	return found


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		problems.append("unreadable %s" % path)
		return [] if path.ends_with("balance.json") == false else {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null:
		problems.append("bad json %s" % path)
		return {} if path.ends_with("balance.json") else []
	return parsed


func _is_num(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
