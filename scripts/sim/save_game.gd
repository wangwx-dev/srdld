extends RefCounted
class_name SaveGame

const VERSION := 1
const SLOT_PATH := "user://srdld_slot1.json"


static func save_to_slot(sim: CareerSim) -> Dictionary:
	return save_to_path(sim, SLOT_PATH)


static func load_slot(game_catalog: Catalog) -> Dictionary:
	return load_from_path(SLOT_PATH, game_catalog)


static func save_to_path(sim: CareerSim, path: String) -> Dictionary:
	var state := sim.state_dict()
	var envelope := {
		"version": VERSION,
		"checksum": checksum(state),
		"state": state,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "code": "io", "message": "无法写入存档"}
	file.store_string(JSON.stringify(envelope, "\t"))
	return {"ok": true, "code": "saved"}


static func load_from_path(path: String, game_catalog: Catalog) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "code": "missing", "message": "没有找到存档"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "code": "io", "message": "无法读取存档"}
	return from_text(file.get_as_text(), game_catalog)


static func to_text(sim: CareerSim) -> String:
	var state := sim.state_dict()
	return JSON.stringify({
		"version": VERSION,
		"checksum": checksum(state),
		"state": state,
	})


static func from_text(text: String, game_catalog: Catalog) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		return {"ok": false, "code": "bad_json", "message": "存档不是有效的 JSON"}
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "code": "bad_type", "message": "存档结构不对"}
	var envelope: Dictionary = parsed
	if not envelope.has("version"):
		return {"ok": false, "code": "missing_field", "message": "存档缺少版本"}
	if int(envelope["version"]) != VERSION:
		return {"ok": false, "code": "bad_version", "message": "存档版本不兼容"}
	if not envelope.has("state") or typeof(envelope["state"]) != TYPE_DICTIONARY:
		return {"ok": false, "code": "missing_field", "message": "存档缺少内容"}
	if not envelope.has("checksum"):
		return {"ok": false, "code": "missing_field", "message": "存档缺少校验"}
	var state: Dictionary = envelope["state"]
	if str(envelope["checksum"]) != checksum(state):
		return {"ok": false, "code": "bad_checksum", "message": "存档校验失败，文件已损坏或被改过"}
	var field_error := validate_state(state)
	if field_error != "":
		var code := "missing_field" if field_error.begins_with("missing:") else "bad_field"
		return {"ok": false, "code": code, "message": "存档字段无效：%s" % field_error, "field": field_error}
	return {"ok": true, "code": "loaded", "sim": CareerSim.from_state(game_catalog, state)}


static func checksum(state: Dictionary) -> String:
	return fnv1a32(canonical(state))


static func canonical(value: Variant) -> String:
	if value == null:
		return "null"
	match typeof(value):
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			return _canon_float(float(value))
		TYPE_STRING:
			return JSON.stringify(str(value))
		TYPE_ARRAY:
			var parts: PackedStringArray = []
			for item in value:
				parts.append(canonical(item))
			return "[%s]" % ",".join(parts)
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			keys.sort()
			var parts: PackedStringArray = []
			for key in keys:
				parts.append("%s:%s" % [JSON.stringify(str(key)), canonical(value[key])])
			return "{%s}" % ",".join(parts)
		_:
			return "null"


static func validate_state(state: Dictionary) -> String:
	var required := [
		"schema", "seed", "rng", "day", "actions_left", "phase", "loss_reason", "loss_detail",
		"money", "stamina", "mood", "stress", "inspiration", "writing", "editing", "reputation",
		"fans", "fatigue", "trends", "bills_paid", "seen_events", "flags",
		"editing_penalty", "editing_penalty_days", "duel_until", "days_since_freelance",
		"pending_event", "sponsor_offer", "contract", "last_sponsor_id",
		"did_rest", "did_outing", "did_publish", "day_earned", "day_spent", "post_count",
		"posts", "log", "tutorial_done", "day_snapshot",
	]
	for key in required:
		if not state.has(key):
			return "missing:%s" % key
	if int(state["schema"]) != 1:
		return "schema"
	if not _in_int(state["day"], 1, 30):
		return "day"
	if not _in_int(state["actions_left"], 0, 6):
		return "actions_left"
	if str(state["phase"]) not in ["playing", "won", "lost"]:
		return "phase"
	if str(state["phase"]) == "won" and int(state["day"]) != 30:
		return "phase"
	if str(state["phase"]) == "lost" and str(state["loss_reason"]) not in ["food", "bill"]:
		return "loss_reason"
	if not _in_int(state["money"], 0, 5000000):
		return "money"
	for key in ["stamina", "mood", "stress", "inspiration", "reputation"]:
		if not _in_float(state[key], 0.0, 100.0):
			return key
	if not _in_float(state["writing"], 0.0, 10.0) or not _in_float(state["editing"], 0.0, 10.0):
		return "skill"
	if not _in_int(state["seed"], 1, 2000000000):
		return "seed"
	if not _in_int(state["rng"], 1, 2147483647):
		return "rng"
	if typeof(state["fans"]) != TYPE_DICTIONARY:
		return "fans"
	for platform_id in ["shizi", "qingtie", "changhe"]:
		if not state["fans"].has(platform_id):
			return "missing:fans"
		if not _in_int(state["fans"][platform_id], 0, 5000000):
			return "fans"
	if typeof(state["trends"]) != TYPE_ARRAY or state["trends"].size() < 5:
		return "trends"
	if typeof(state["posts"]) != TYPE_ARRAY or state["posts"].size() > 200:
		return "posts"
	if typeof(state["log"]) != TYPE_ARRAY or state["log"].size() > 200:
		return "log"
	if typeof(state["pending_event"]) != TYPE_DICTIONARY:
		return "pending_event"
	if typeof(state["contract"]) != TYPE_DICTIONARY or typeof(state["sponsor_offer"]) != TYPE_DICTIONARY:
		return "contract"
	if typeof(state["day_snapshot"]) != TYPE_DICTIONARY or not state["day_snapshot"].has("money"):
		return "day_snapshot"
	if not _in_float(state["editing_penalty"], 0.0, 5.0):
		return "editing_penalty"
	if not _in_int(state["editing_penalty_days"], 0, 30):
		return "editing_penalty_days"
	if typeof(state["tutorial_done"]) != TYPE_BOOL:
		return "tutorial_done"
	if typeof(state["did_rest"]) != TYPE_BOOL:
		return "did_rest"
	return ""


static func fnv1a32(text: String) -> String:
	var hash := 2166136261
	var prime := 16777619
	for byte in text.to_utf8_buffer():
		hash = (hash ^ int(byte)) & 0xffffffff
		hash = (hash * prime) & 0xffffffff
	return "%08x" % hash


static func _canon_float(value: float) -> String:
	var rounded: float = round(value * 1000.0) / 1000.0
	if abs(rounded - round(rounded)) < 0.0000001:
		return str(int(round(rounded)))
	var text := "%0.3f" % rounded
	while text.contains(".") and (text.ends_with("0") or text.ends_with(".")):
		text = text.substr(0, text.length() - 1)
	return text


static func _in_int(value: Variant, low: int, high: int) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := int(value)
	return number >= low and number <= high


static func _in_float(value: Variant, low: float, high: float) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return number >= low - 0.001 and number <= high + 0.001
