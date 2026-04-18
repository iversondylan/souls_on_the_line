class_name OnAnyDeathInterceptor
extends "res://battle/sim/interceptors/interceptor.gd"

const InterceptorScript := preload("res://battle/sim/interceptors/interceptor.gd")


func _init(
	_source_kind: StringName = &"",
	_source_owner_id: int = 0,
	_source_group_index: int = -1,
	_source_id: StringName = &""
) -> void:
	hook_kind = InterceptorScript.HOOK_ON_ANY_DEATH
	source_kind = StringName(_source_kind)
	source_owner_id = int(_source_owner_id)
	source_group_index = int(_source_group_index)
	source_id = StringName(_source_id)


func clone():
	return get_script().new(
		source_kind,
		source_owner_id,
		source_group_index,
		source_id
	)


func dispatch(api, removal_ctx: RemovalContext) -> void:
	if api == null or removal_ctx == null or !is_valid():
		return
	api._dispatch_on_any_death_interceptor(self, removal_ctx)
