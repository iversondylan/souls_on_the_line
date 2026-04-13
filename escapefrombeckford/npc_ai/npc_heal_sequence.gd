# npc_heal_sequence.gd

class_name NPCHealSequence extends NPCEffectSequence

func execute(ctx: NPCAIContext) -> void:
	if ctx == null or bool(ctx.forecast) or ctx.api == null or !is_sequence_executable(ctx):
		return
	var runtime := ctx.runtime if ctx.runtime != null else (ctx.api.runtime if ctx.api != null else null)
	if runtime == null:
		push_warning("npc_heal_sequence.gd execute(): missing runtime")
		return

	var params: Dictionary = ctx.params if ctx.params else {}
	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		return

	var raw_target_ids = params.get(Keys.TARGET_IDS, PackedInt32Array())
	var target_ids := PackedInt32Array()
	if raw_target_ids is PackedInt32Array:
		target_ids = raw_target_ids
	elif raw_target_ids is Array:
		target_ids = PackedInt32Array(raw_target_ids)

	var flat_amount := maxi(int(params.get(Keys.FLAT_AMOUNT, 0)), 0)
	var of_total := maxf(float(params.get(Keys.OF_TOTAL, 0.0)), 0.0)
	var of_missing := maxf(float(params.get(Keys.OF_MISSING, 0.0)), 0.0)
	if flat_amount <= 0 and of_total <= 0.0 and of_missing <= 0.0:
		return

	for tid in target_ids:
		var target_id := int(tid)
		if target_id <= 0 or !ctx.api.is_alive(target_id):
			continue

		var heal_ctx := HealContext.new(actor_id, target_id, flat_amount, of_total, of_missing)
		var healed := runtime.run_heal_action(heal_ctx, actor_id)
		if healed > 0:
			_append_unique_affected_id(ctx, target_id)

func _append_unique_affected_id(ctx: NPCAIContext, unit_id: int) -> void:
	if ctx == null or unit_id <= 0:
		return
	for existing_id in ctx.affected_ids:
		if int(existing_id) == unit_id:
			return
	ctx.affected_ids.append(unit_id)
