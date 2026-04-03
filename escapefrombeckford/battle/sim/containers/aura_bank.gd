# aura_bank.gd

class_name AuraBank extends RefCounted

var _entries_by_key: Dictionary = {}


func track(source_id: int, status_id: StringName, pending := false) -> void:
	if source_id <= 0 or status_id == &"":
		return

	var key := _make_key(source_id, status_id, bool(pending))
	_entries_by_key[key] = {
		"source_id": int(source_id),
		"status_id": StringName(status_id),
		"pending": bool(pending),
	}


func untrack(source_id: int, status_id: StringName, pending := false) -> void:
	_entries_by_key.erase(_make_key(source_id, status_id, bool(pending)))


func clear() -> void:
	_entries_by_key.clear()


func get_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in _entries_by_key.keys():
		var entry = _entries_by_key.get(key, {})
		if entry is Dictionary and !entry.is_empty():
			out.append((entry as Dictionary).duplicate(true))

	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_source := int(a.get("source_id", 0))
		var b_source := int(b.get("source_id", 0))
		if a_source != b_source:
			return a_source < b_source

		var a_status := String(a.get("status_id", &""))
		var b_status := String(b.get("status_id", &""))
		if a_status != b_status:
			return a_status < b_status

		return int(bool(a.get("pending", false))) < int(bool(b.get("pending", false)))
	)

	return out


func clone():
	var bank = get_script().new()
	for key in _entries_by_key.keys():
		var entry = _entries_by_key.get(key, {})
		if entry is Dictionary:
			bank._entries_by_key[key] = (entry as Dictionary).duplicate(true)
	return bank


func _make_key(source_id: int, status_id: StringName, pending: bool) -> String:
	return "%s::%s::%s" % [str(source_id), String(status_id), "pending" if pending else "realized"]
