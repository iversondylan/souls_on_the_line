class_name Interceptor extends RefCounted

const HOOK_ON_TARGETING_RETARGET := &"on_targeting_retarget"
const HOOK_ON_TARGETING_INTERPOSE := &"on_targeting_interpose"
const HOOK_ON_PLAYER_TURN_BEGIN := &"on_player_turn_begin"
const HOOK_ON_GROUP_TURN_BEGIN := &"on_group_turn_begin"
const HOOK_ON_GROUP_TURN_END := &"on_group_turn_end"
const HOOK_ON_ANY_DEATH := &"on_any_death"

const SOURCE_KIND_STATUS_TOKEN := &"status_token"
const SOURCE_KIND_PROJECTED_STATUS_EFFECTIVE := &"projected_status_effective"
const SOURCE_KIND_ARCANUM_ENTRY := &"arcanum_entry"

var hook_kind: StringName = &""
var source_kind: StringName = &""
var source_owner_id: int = 0
var source_group_index: int = -1
var source_id: StringName = &""
var source_instance_id: int = 0
var tid: int = 0
var priority: int = 1


func _init(
	_hook_kind: StringName = &"",
	_source_kind: StringName = &"",
	_source_owner_id: int = 0,
	_source_group_index: int = -1,
	_source_id: StringName = &"",
	_source_instance_id: int = 0,
	_tid: int = 0,
	_priority: int = 1
) -> void:
	hook_kind = StringName(_hook_kind)
	source_kind = StringName(_source_kind)
	source_owner_id = int(_source_owner_id)
	source_group_index = int(_source_group_index)
	source_id = StringName(_source_id)
	source_instance_id = int(_source_instance_id)
	tid = int(_tid)
	priority = int(_priority)


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
		"%s::%s" % [String(source_id), str(int(source_instance_id))],
	]


func clone():
	return get_script().new(
		hook_kind,
		source_kind,
		source_owner_id,
		source_group_index,
		source_id,
		source_instance_id,
		tid,
		priority
	)

# variant arguments here bugs me
func dispatch(api: SimBattleAPI, payload = null) -> void:
	if api == null or !is_valid():
		return
	api._dispatch_interceptor(self, payload)
