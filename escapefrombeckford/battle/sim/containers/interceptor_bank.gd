class_name InterceptorBank extends RefCounted

const InterceptorScript := preload("res://battle/sim/interceptors/interceptor.gd")
const OnAnyDeathInterceptorScript := preload("res://battle/sim/interceptors/on_any_death_interceptor.gd")

const FRIENDLY := 0
const ENEMY := 1

var _interceptors_by_hook: Dictionary = {}
var _dirty_hooks: Dictionary = {}


func clear() -> void:
	_interceptors_by_hook.clear()
	_dirty_hooks.clear()


func mark_dirty(hook_kind: StringName) -> void:
	if hook_kind == &"":
		return
	_dirty_hooks[hook_kind] = true


func get_interceptors_for_hook_and_group(state, hook_kind: StringName, group_index: int) -> Array[Interceptor]:
	_ensure_hook(state, hook_kind)

	var grouped: Dictionary = _interceptors_by_hook.get(hook_kind, {})
	var ordered: Array = grouped.get(clampi(int(group_index), FRIENDLY, ENEMY), [])
	var out: Array[Interceptor] = []
	for interceptor in ordered:
		if interceptor != null and interceptor is Interceptor:
			out.append(interceptor.clone())
	return out


func clone():
	var copied: Variant = get_script().new()
	copied._dirty_hooks = _dirty_hooks.duplicate(true)
	for hook_key in _interceptors_by_hook.keys():
		var grouped: Dictionary = _interceptors_by_hook[hook_key]
		var grouped_copy := {}
		for group_key in grouped.keys():
			var ordered: Array = grouped[group_key]
			var ordered_copy: Array = []
			for interceptor in ordered:
				if interceptor != null:
					ordered_copy.append(interceptor.clone())
			grouped_copy[group_key] = ordered_copy
		copied._interceptors_by_hook[StringName(hook_key)] = grouped_copy
	return copied


func _ensure_hook(state, hook_kind: StringName) -> void:
	if hook_kind == &"":
		return
	if !_dirty_hooks.get(hook_kind, true):
		return

	match hook_kind:
		InterceptorScript.HOOK_ON_ANY_DEATH:
			_rebuild_on_any_death(state)
		_:
			_interceptors_by_hook[hook_kind] = {
				FRIENDLY: [],
				ENEMY: [],
			}

	_dirty_hooks[hook_kind] = false


func _rebuild_on_any_death(state) -> void:
	var grouped := {
		FRIENDLY: [],
		ENEMY: [],
	}
	if state == null:
		_interceptors_by_hook[InterceptorScript.HOOK_ON_ANY_DEATH] = grouped
		return

	if state.status_catalog != null:
		for gi in [FRIENDLY, ENEMY]:
			for raw_id in state.groups[int(gi)].order:
				var owner_id := int(raw_id)
				var owner = state.get_unit(owner_id)
				if owner == null or !owner.is_alive() or owner.statuses == null:
					continue

				for token in owner.statuses.get_all_tokens(false):
					if token == null or token.id == &"":
						continue
					var proto = state.status_catalog.get_proto(StringName(token.id))
					if proto == null or !proto.listens_for_any_death():
						continue
					grouped[int(gi)].append(
						OnAnyDeathInterceptorScript.new(
							InterceptorScript.SOURCE_KIND_STATUS_TOKEN,
							owner_id,
							int(gi),
							StringName(token.id)
						)
					)

	if state.arcana != null and state.arcana_catalog != null:
		var owner_id := int(state.groups[FRIENDLY].player_id)
		var owner = state.get_unit(owner_id)
		if owner != null and owner.is_alive():
			for entry in state.arcana.list:
				if entry == null or entry.id == &"":
					continue
				var proto = state.arcana_catalog.get_proto(entry.id)
				if proto == null or !proto.listens_for_any_death():
					continue
				grouped[FRIENDLY].append(
					OnAnyDeathInterceptorScript.new(
						InterceptorScript.SOURCE_KIND_ARCANUM_ENTRY,
						owner_id,
						FRIENDLY,
						entry.id
					)
				)

	for gi in grouped.keys():
		var ordered: Array = grouped[gi]
		ordered.sort_custom(func(a, b) -> bool:
			if a == null or b == null:
				return false
			var a_kind := String(a.source_kind)
			var b_kind := String(b.source_kind)
			if a_kind != b_kind:
				return a_kind < b_kind
			var a_owner := int(a.source_owner_id)
			var b_owner := int(b.source_owner_id)
			if a_owner != b_owner:
				return a_owner < b_owner
			return String(a.source_id) < String(b.source_id)
		)
		grouped[int(gi)] = ordered

	_interceptors_by_hook[InterceptorScript.HOOK_ON_ANY_DEATH] = grouped
