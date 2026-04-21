class_name ProjectedStatusContributionIndex extends RefCounted


var _stacks_by_source_key: Dictionary = {}
var _status_ids_by_source_key: Dictionary = {}
var _source_keys_by_status_id: Dictionary = {}
var _order_by_source_key: Dictionary = {}


func clear() -> void:
	_stacks_by_source_key.clear()
	_status_ids_by_source_key.clear()
	_source_keys_by_status_id.clear()
	_order_by_source_key.clear()


func clone():
	var copied: Variant = get_script().new()
	for source_key_variant in _stacks_by_source_key.keys():
		var source_key := String(source_key_variant)
		var source_map: Dictionary = _stacks_by_source_key[source_key]
		var cloned_source_map: Dictionary = {}
		for status_id_key in source_map.keys():
			var source_token: StatusToken = source_map[status_id_key]
			if source_token != null:
				cloned_source_map[StringName(status_id_key)] = source_token.clone()
		copied._stacks_by_source_key[source_key] = cloned_source_map
	copied._status_ids_by_source_key = _status_ids_by_source_key.duplicate(true)
	copied._source_keys_by_status_id = _source_keys_by_status_id.duplicate(true)
	copied._order_by_source_key = _order_by_source_key.duplicate(true)
	return copied


func get_dependency_status_ids(source_key: String) -> Array[StringName]:
	var out: Array[StringName] = []
	if source_key.is_empty() or !_status_ids_by_source_key.has(source_key):
		return out
	var status_ids: Dictionary = _status_ids_by_source_key[source_key]
	for status_id_key in status_ids.keys():
		out.append(StringName(status_id_key))
	return out


func get_all_source_keys() -> Array[String]:
	var out: Array[String] = []
	for source_key_variant in _stacks_by_source_key.keys():
		out.append(String(source_key_variant))
	return out

func get_all_status_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for status_id_key in _source_keys_by_status_id.keys():
		out.append(StringName(status_id_key))
	out.sort()
	return out


func get_source_keys_for_status(status_id: StringName) -> Array[String]:
	var out: Array[String] = []
	if status_id == &"" or !_source_keys_by_status_id.has(status_id):
		return out
	var source_keys: Dictionary = _source_keys_by_status_id[status_id]
	for source_key_variant in source_keys.keys():
		out.append(String(source_key_variant))
	return out


func replace_source(source_key: String, projected_tokens: Array[StatusToken], order_info := {}) -> Array[StringName]:
	var affected_ids := {}
	if source_key.is_empty():
		return []

	var previous_map := _get_source_map(source_key)
	var next_map: Dictionary = {}
	for token: StatusToken in projected_tokens:
		if token == null or token.id == &"":
			continue
		var copied_token: Variant = token.clone()
		copied_token.pending = false
		next_map[copied_token.id] = copied_token
		affected_ids[copied_token.id] = true

	for status_id_key in previous_map.keys():
		affected_ids[StringName(status_id_key)] = true

	_stacks_by_source_key[source_key] = next_map
	_status_ids_by_source_key[source_key] = _make_status_set(next_map)
	_order_by_source_key[source_key] = order_info.duplicate(true) if order_info is Dictionary else {}
	_rebuild_status_source_index(source_key, affected_ids)
	return _to_sorted_status_id_array(affected_ids)


func remove_source(source_key: String) -> Array[StringName]:
	var affected_ids := {}
	if source_key.is_empty():
		return []

	var previous_map := _get_source_map(source_key)
	for status_id_key in previous_map.keys():
		affected_ids[StringName(status_id_key)] = true

	_stacks_by_source_key.erase(source_key)
	_status_ids_by_source_key.erase(source_key)
	_order_by_source_key.erase(source_key)
	_rebuild_status_source_index(source_key, affected_ids)
	return _to_sorted_status_id_array(affected_ids)


func build_projected_token(status_id: StringName, proto: Status = null) -> StatusToken:
	if status_id == &"":
		return null
	if !_source_keys_by_status_id.has(status_id):
		return null

	var source_keys: Dictionary = _source_keys_by_status_id[status_id]
	if source_keys.is_empty():
		return null

	var contributors: Array[Dictionary] = []
	for source_key_variant in source_keys.keys():
		var source_key := String(source_key_variant)
		var source_map := _get_source_map(source_key)
		if !source_map.has(status_id):
			continue
		var token: StatusToken = source_map[status_id]
		if token == null:
			continue
		contributors.append({
			"token": token,
			"order": _order_by_source_key.get(source_key, {}),
		})

	if contributors.is_empty():
		return null

	contributors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _source_entry_sorts_before(a, b)
	)

	var effective_reapply_type := int(proto.get_effective_reapply_type()) if proto != null else int(Status.ReapplyType.ADD)
	var total_stacks := 0
	match effective_reapply_type:
		int(Status.ReapplyType.REPLACE):
			# Contributors are sorted oldest->newest, so .back() is the newest projection.
			var latest := contributors.back().get("token", null) as StatusToken
			total_stacks = int(latest.stacks) if latest != null else 0
		int(Status.ReapplyType.IGNORE):
			# Contributors are sorted oldest->newest, so .front() is the oldest projection.
			var earliest := contributors.front().get("token", null) as StatusToken
			total_stacks = int(earliest.stacks) if earliest != null else 0
		_:
			for contributor in contributors:
				var contributor_token := contributor.get("token", null) as StatusToken
				if contributor_token == null:
					continue
				total_stacks += int(contributor_token.stacks)

	if total_stacks <= 0:
		return null

	var out_token := StatusToken.new(status_id)
	out_token.pending = false
	out_token.stacks = total_stacks
	return out_token


func _get_source_map(source_key: String) -> Dictionary:
	if source_key.is_empty() or !_stacks_by_source_key.has(source_key):
		return {}
	return _stacks_by_source_key[source_key]


func _make_status_set(source_map: Dictionary) -> Dictionary:
	var out := {}
	for status_id_key in source_map.keys():
		out[StringName(status_id_key)] = true
	return out


func _rebuild_status_source_index(source_key: String, affected_ids: Dictionary) -> void:
	for status_id_key in affected_ids.keys():
		var status_id := StringName(status_id_key)
		if _source_keys_by_status_id.has(status_id):
			var source_keys: Dictionary = _source_keys_by_status_id[status_id]
			source_keys.erase(source_key)
			if source_keys.is_empty():
				_source_keys_by_status_id.erase(status_id)
			else:
				_source_keys_by_status_id[status_id] = source_keys

	if !_status_ids_by_source_key.has(source_key):
		return

	var source_status_ids: Dictionary = _status_ids_by_source_key[source_key]
	for status_id_key in source_status_ids.keys():
		var status_id := StringName(status_id_key)
		var source_keys: Dictionary = _source_keys_by_status_id.get(status_id, {})
		source_keys[source_key] = true
		_source_keys_by_status_id[status_id] = source_keys


func _to_sorted_status_id_array(source_ids: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for status_id_key in source_ids.keys():
		out.append(StringName(status_id_key))
	out.sort()
	return out

func _source_entry_sorts_before(a: Dictionary, b: Dictionary) -> bool:
	var a_order := a.get("order", {}) if a != null else {}
	var b_order := b.get("order", {}) if b != null else {}
	var a_priority := int(a_order.get("priority", 0))
	var b_priority := int(b_order.get("priority", 0))
	# Lower priority runs earlier, and lower tid is older within the same priority.
	if a_priority != b_priority:
		return a_priority < b_priority
	return int(a_order.get("tid", 0)) < int(b_order.get("tid", 0))
