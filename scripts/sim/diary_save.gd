extends RefCounted
class_name DiarySave

const VERSION := 2
const AUTO_PATH := "user://diary_auto.json"


static func manual_path(slot: int) -> String:
	return "user://diary_manual_%d.json" % clampi(slot, 1, 3)


static func save_to_path(sim: DiarySim, path: String) -> Dictionary:
	var state := sim.state_dict()
	var envelope := {"version": VERSION, "checksum": SaveGame.checksum(state), "state": state}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "code": "io", "message": "无法写入存档"}
	file.store_string(JSON.stringify(envelope, "\t"))
	return {"ok": true, "code": "saved"}


static func load_from_path(path: String, content: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "code": "missing", "message": "没有这个存档"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "code": "io", "message": "无法读取存档"}
	return from_text(file.get_as_text(), content)


static func from_text(text: String, content: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "code": "bad_json", "message": "存档不是有效的 JSON"}
	var envelope: Dictionary = parsed
	if int(envelope.get("version", 0)) != VERSION:
		return {"ok": false, "code": "bad_version", "message": "这是旧规则或别的版本的存档，不能读进现在这局。"}
	if typeof(envelope.get("state", null)) != TYPE_DICTIONARY:
		return {"ok": false, "code": "missing_field", "message": "存档缺少内容"}
	var state: Dictionary = envelope["state"]
	if str(envelope.get("checksum", "")) != SaveGame.checksum(state):
		return {"ok": false, "code": "bad_checksum", "message": "存档校验失败"}
	var field := _validate(state)
	if field != "":
		var code := "missing_field" if field.begins_with("missing:") else "bad_field"
		return {"ok": false, "code": code, "message": "存档字段无效：%s" % field}
	return {"ok": true, "sim": DiarySim.from_state(content, state)}


static func _validate(state: Dictionary) -> String:
	for key in ["schema", "seed", "rng", "player_name", "gender", "clock_minutes", "money", "phase", "works", "ledger", "charts", "furniture"]:
		if not state.has(key):
			return "missing:%s" % key
	if int(state["schema"]) != 2:
		return "schema"
	if str(state["gender"]) not in ["f", "m"]:
		return "gender"
	if int(state["clock_minutes"]) < 0 or int(state["clock_minutes"]) > 400 * DiarySim.DAY:
		return "clock_minutes"
	if int(state["money"]) < 0 or int(state["money"]) > 5000000 * DiarySim.GOLD:
		return "money"
	if str(state["phase"]) not in ["playing", "lost"]:
		return "phase"
	if typeof(state["works"]) != TYPE_ARRAY or typeof(state["charts"]) != TYPE_DICTIONARY:
		return "works"
	return ""
