class_name TransformerRecordLookup extends RefCounted


var _records_by_source_key: Dictionary = {}


func clear() -> void:
	_records_by_source_key.clear()


func is_empty() -> bool:
	return _records_by_source_key.is_empty()


func set_record(record: TransformerRecord) -> void:
	if record == null or !record.is_valid():
		return
	var source_key := record.get_source_key()
	if source_key.is_empty():
		return
	_records_by_source_key[source_key] = record


func has_record(source_key: String) -> bool:
	if source_key.is_empty():
		return false
	return _records_by_source_key.has(source_key)


func get_record(source_key: String) -> TransformerRecord:
	if !has_record(source_key):
		return null
	return _records_by_source_key[source_key] as TransformerRecord


func get_source_keys() -> Array[String]:
	var out: Array[String] = []
	for source_key_variant in _records_by_source_key.keys():
		out.append(String(source_key_variant))
	return out
