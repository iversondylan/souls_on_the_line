class_name Interceptor extends RefCounted

const HOOK_ON_ANY_DEATH := &"on_any_death"

const SOURCE_KIND_STATUS_TOKEN := &"status_token"
const SOURCE_KIND_ARCANUM_ENTRY := &"arcanum_entry"

var hook_kind: StringName = &""
var source_kind: StringName = &""
var source_owner_id: int = 0
var source_group_index: int = -1
var source_id: StringName = &""


func _init(
	_hook_kind: StringName = &"",
	_source_kind: StringName = &"",
	_source_owner_id: int = 0,
	_source_group_index: int = -1,
	_source_id: StringName = &""
) -> void:
	hook_kind = StringName(_hook_kind)
	source_kind = StringName(_source_kind)
	source_owner_id = int(_source_owner_id)
	source_group_index = int(_source_group_index)
	source_id = StringName(_source_id)


func is_valid() -> bool:
	return (
		hook_kind != &""
		and source_kind != &""
		and source_owner_id > 0
		and source_group_index >= 0
		and source_id != &""
	)


func get_source_key() -> String:
	if !is_valid():
		return ""
	return "%s::%s::%s::%s::%s" % [
		String(hook_kind),
		String(source_kind),
		str(int(source_owner_id)),
		str(int(source_group_index)),
		String(source_id),
	]


func clone():
	return get_script().new(
		hook_kind,
		source_kind,
		source_owner_id,
		source_group_index,
		source_id
	)
