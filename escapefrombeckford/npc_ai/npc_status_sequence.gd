# npc_status_sequence.gd

class_name NPCStatusSequence extends NPCEffectSequence

func execute(ctx: NPCAIContext) -> void:
	if ctx == null or bool(ctx.forecast):
		return
	
	var runtime := ctx.runtime if ctx.runtime != null else (ctx.api.runtime if ctx.api != null else null)
	if runtime == null:
		push_warning("npc_status_sequence.gd execute(): missing runtime")
		return
	
	var params: Dictionary = ctx.params if ctx.params else {}
	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		return
	
	var status_id: StringName = &""
	if params.has(Keys.STATUS_ID):
		var v = params[Keys.STATUS_ID]
		if v is StringName:
			status_id = v
		elif v is String:
			status_id = StringName(v)
	if status_id == &"":
		var status_res = params.get(Keys.STATUS_SCENE, null)
		if status_res != null and status_res is Status:
			status_id = StringName((status_res as Status).get_id())
	if status_id == &"":
		return
	
	var raw_target_ids: PackedInt32Array = PackedInt32Array()
	if params.has(Keys.TARGET_IDS):
		var raw_value = params.get(Keys.TARGET_IDS, PackedInt32Array())
		if raw_value is PackedInt32Array:
			raw_target_ids = raw_value
		elif raw_value is Array:
			raw_target_ids = PackedInt32Array(raw_value)
	
	var resolved_target_ids := PackedInt32Array()
	var seen := {}
	
	if raw_target_ids.is_empty():
		resolved_target_ids.append(actor_id)
	else:
		for tid in raw_target_ids:
			var target_id := int(tid)
			if target_id <= 0 or seen.has(target_id):
				continue
			seen[target_id] = true
			if ctx.api == null or ctx.api.is_alive(target_id):
				resolved_target_ids.append(target_id)

	ctx.params[Keys.TARGET_IDS] = resolved_target_ids

	if resolved_target_ids.is_empty():
		return

	var source_id := int(params.get(Keys.SOURCE_ID, actor_id))
	var intensity := int(params.get(Keys.STATUS_INTENSITY, 0))
	var duration := int(params.get(Keys.STATUS_DURATION, 0))
	var pending := bool(params.get(Keys.STATUS_PENDING, false))

	for target_id in resolved_target_ids:
		var status_ctx := StatusContext.new()
		status_ctx.actor_id = actor_id
		status_ctx.source_id = source_id
		status_ctx.target_id = int(target_id)
		status_ctx.status_id = status_id
		status_ctx.intensity = intensity
		status_ctx.duration = duration
		status_ctx.pending = pending
		status_ctx.reason = "npc_status_action"
		status_ctx.presentation_hint = (
			&"embedded_summon_candidate"
			if _has_unit_id(ctx.summoned_ids, int(target_id))
			else &"standalone"
		)
		runtime.run_status_action(status_ctx)
		_append_unit_id(ctx.affected_ids, int(target_id))

func _append_unit_id(arr: PackedInt32Array, unit_id: int) -> void:
	if unit_id <= 0:
		return
	for existing_id in arr:
		if int(existing_id) == unit_id:
			return
	arr.append(unit_id)

func _has_unit_id(arr: PackedInt32Array, unit_id: int) -> bool:
	if unit_id <= 0:
		return false
	for existing_id in arr:
		if int(existing_id) == unit_id:
			return true
	return false
