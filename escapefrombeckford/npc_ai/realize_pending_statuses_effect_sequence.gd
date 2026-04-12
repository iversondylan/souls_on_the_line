# realize_pending_statuses_effect_sequence.gd

class_name RealizePendingStatusesEffectSequence extends NPCEffectSequence

func realizes_pending_statuses() -> bool:
	return true

func execute(ctx: NPCAIContext) -> void:
	if ctx == null or bool(ctx.forecast) or !is_sequence_executable(ctx):
		return

	var runtime := ctx.runtime if ctx.runtime != null else (ctx.api.runtime if ctx.api != null else null)
	if runtime == null:
		push_warning("realize_pending_statuses_effect_sequence.gd execute(): missing runtime")
		return

	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		return

	var target_ids := _resolve_target_ids(ctx, actor_id)
	for target_id in target_ids:
		runtime.run_realize_pending_statuses(int(target_id), actor_id, "npc_realize_pending_statuses")

func _resolve_target_ids(ctx: NPCAIContext, actor_id: int) -> PackedInt32Array:
	var target_ids := PackedInt32Array()
	var has_explicit_targets := ctx.params != null and ctx.params.has(Keys.TARGET_IDS)
	if has_explicit_targets:
		var raw_value = ctx.params.get(Keys.TARGET_IDS, PackedInt32Array())
		if raw_value is PackedInt32Array:
			target_ids = raw_value
		elif raw_value is Array:
			target_ids = PackedInt32Array(raw_value)
	else:
		target_ids.append(actor_id)

	var filtered := PackedInt32Array()
	for tid in target_ids:
		var target_id := int(tid)
		if target_id <= 0:
			continue
		if ctx.api != null and !ctx.api.is_alive(target_id):
			continue
		filtered.append(target_id)
	return filtered
