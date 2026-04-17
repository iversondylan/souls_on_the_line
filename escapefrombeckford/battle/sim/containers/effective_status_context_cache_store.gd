class_name EffectiveStatusContextCacheStore extends RefCounted

var _contexts_by_key: Dictionary = {}
var _epoch: int = 1


func has_contexts(
	target_id: int,
	unit_status_version: int
) -> bool:
	return _contexts_by_key.has(
		_make_cache_key(
			target_id,
			unit_status_version
		)
	)


func get_contexts(
	target_id: int,
	unit_status_version: int
) -> Array[SimStatusContext]:
	var cache_key := _make_cache_key(
		target_id,
		unit_status_version
	)
	if !_contexts_by_key.has(cache_key):
		return []
	var cached: Array[SimStatusContext] = _contexts_by_key[cache_key]
	return _copy_contexts(cached)


func set_contexts(
	target_id: int,
	unit_status_version: int,
	contexts: Array[SimStatusContext]
) -> void:
	var cache_key := _make_cache_key(
		target_id,
		unit_status_version
	)
	_contexts_by_key[cache_key] = _copy_contexts(contexts)


func invalidate() -> void:
	_contexts_by_key.clear()
	_epoch += 1


func _make_cache_key(
	target_id: int,
	unit_status_version: int
) -> String:
	return "%s::%s::%s" % [
		str(int(target_id)),
		str(int(unit_status_version)),
		str(int(_epoch)),
	]


func _copy_contexts(source_contexts: Array[SimStatusContext]) -> Array[SimStatusContext]:
	var copied: Array[SimStatusContext] = []
	for ctx: SimStatusContext in source_contexts:
		copied.append(ctx)
	return copied
