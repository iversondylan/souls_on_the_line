class_name ProjectionSourceEntryLookup extends RefCounted

const ProjectionSourceEntry := preload("res://battle/sim/containers/projection_source_entry.gd")

var _entries_by_source_key: Dictionary = {}


func clear() -> void:
	_entries_by_source_key.clear()


func is_empty() -> bool:
	return _entries_by_source_key.is_empty()


func set_entry(entry: ProjectionSourceEntry) -> void:
	if entry == null:
		return
	var source_key := entry.get_source_key()
	if source_key.is_empty():
		return
	_entries_by_source_key[source_key] = entry


func has_entry(source_key: String) -> bool:
	if source_key.is_empty():
		return false
	return _entries_by_source_key.has(source_key)


func get_entry(source_key: String) -> ProjectionSourceEntry:
	if !has_entry(source_key):
		return null
	return _entries_by_source_key[source_key] as ProjectionSourceEntry


func get_source_keys() -> Array[String]:
	var out: Array[String] = []
	for source_key_variant in _entries_by_source_key.keys():
		out.append(String(source_key_variant))
	return out
