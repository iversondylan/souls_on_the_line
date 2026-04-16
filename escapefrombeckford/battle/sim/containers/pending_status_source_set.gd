class_name PendingStatusSourceSet extends RefCounted

var _by_source_id: Dictionary = {}


func clone():
	var copied = get_script().new()
	copied._by_source_id = _by_source_id.duplicate(true)
	return copied


func clear() -> void:
	_by_source_id.clear()


func is_empty() -> bool:
	return _by_source_id.is_empty()


func include_source(source_id: int) -> void:
	if int(source_id) <= 0:
		return
	_by_source_id[int(source_id)] = true


func has_source(source_id: int) -> bool:
	if int(source_id) <= 0:
		return false
	return bool(_by_source_id.get(int(source_id), false))


func get_sorted_source_ids() -> Array[int]:
	var ids: Array[int] = []
	for source_id_variant in _by_source_id.keys():
		var source_id := int(source_id_variant)
		if source_id <= 0:
			continue
		if !bool(_by_source_id.get(source_id_variant, false)):
			continue
		ids.append(source_id)
	ids.sort()
	return ids


func signature() -> String:
	var ids := get_sorted_source_ids()
	if ids.is_empty():
		return ""
	var parts: Array[String] = []
	for source_id in ids:
		parts.append(str(int(source_id)))
	return ",".join(parts)
