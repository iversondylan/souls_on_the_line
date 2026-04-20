class_name TransformerRecord extends RefCounted

const TRANSFORMER_KIND_PROJECTION := &"projection"
const TRANSFORMER_KIND_INTERCEPTOR := &"interceptor"

const SOURCE_KIND_STATUS_TOKEN := &"status_token"
const SOURCE_KIND_PROJECTED_STATUS_EFFECTIVE := &"projected_status_effective"
const SOURCE_KIND_ARCANUM_ENTRY := &"arcanum_entry"

var tid: int = 0
var transformer_kind: StringName = &""
var hook_kind: StringName = &""
var source_kind: StringName = &""
var source_owner_id: int = 0
var source_group_index: int = -1
var source_id: StringName = &""
var source_instance_id: int = 0
var priority: int = 1


func _init(
	_tid: int = 0,
	_transformer_kind: StringName = &"",
	_hook_kind: StringName = &"",
	_source_kind: StringName = &"",
	_source_owner_id: int = 0,
	_source_group_index: int = -1,
	_source_id: StringName = &"",
	_source_instance_id: int = 0,
	_priority: int = 1
) -> void:
	tid = int(_tid)
	transformer_kind = StringName(_transformer_kind)
	hook_kind = StringName(_hook_kind)
	source_kind = StringName(_source_kind)
	source_owner_id = int(_source_owner_id)
	source_group_index = int(_source_group_index)
	source_id = StringName(_source_id)
	source_instance_id = int(_source_instance_id)
	priority = int(_priority)


func is_valid() -> bool:
	return (
		tid > 0
		and transformer_kind != &""
		and source_kind != &""
		and source_owner_id > 0
		and source_id != &""
	)


func is_projection() -> bool:
	return transformer_kind == TRANSFORMER_KIND_PROJECTION


func is_interceptor() -> bool:
	return transformer_kind == TRANSFORMER_KIND_INTERCEPTOR


func get_source_key() -> String:
	if source_kind == &"" or source_owner_id <= 0 or source_id == &"":
		return ""
	return make_source_key(source_kind, source_owner_id, source_id, source_instance_id)


func get_transformer_key() -> String:
	if transformer_kind == &"":
		return ""
	return make_transformer_key(
		transformer_kind,
		hook_kind,
		source_kind,
		source_owner_id,
		source_id,
		source_instance_id
	)


func clone():
	return get_script().new(
		tid,
		transformer_kind,
		hook_kind,
		source_kind,
		source_owner_id,
		source_group_index,
		source_id,
		source_instance_id,
		priority
	)


static func make_source_key(
	_source_kind: StringName,
	_source_owner_id: int,
	_source_id: StringName,
	_source_instance_id: int = 0
) -> String:
	if _source_kind == &"" or int(_source_owner_id) <= 0 or _source_id == &"":
		return ""
	return "%s::%s::%s" % [
		String(_source_kind),
		str(int(_source_owner_id)),
		"%s::%s" % [String(_source_id), str(int(_source_instance_id))],
	]


static func make_transformer_key(
	_transformer_kind: StringName,
	_hook_kind: StringName,
	_source_kind: StringName,
	_source_owner_id: int,
	_source_id: StringName,
	_source_instance_id: int = 0
) -> String:
	var source_key := make_source_key(_source_kind, _source_owner_id, _source_id, _source_instance_id)
	if _transformer_kind == &"" or source_key.is_empty():
		return ""
	return "%s::%s::%s" % [
		String(_transformer_kind),
		String(_hook_kind),
		source_key,
	]
