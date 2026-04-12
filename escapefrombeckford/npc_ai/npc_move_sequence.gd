# npc_move_sequence.gd

class_name NPCMoveSequence extends NPCEffectSequence

func execute(ctx: NPCAIContext) -> void:
	if ctx == null or bool(ctx.forecast) or !is_sequence_executable(ctx):
		return

	var runtime := ctx.runtime if ctx.runtime != null else (ctx.api.runtime if ctx.api != null else null)
	if runtime == null or ctx.api == null:
		push_warning("npc_move_sequence.gd execute(): missing runtime or api")
		return

	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		return

	var params: Dictionary = ctx.params if ctx.params else {}
	var move_type := int(params.get(Keys.MOVE_TYPE, MoveContext.MoveType.MOVE_TO_FRONT))
	var target_id := int(params.get(Keys.TARGET_ID, 0))
	if target_id <= 0:
		var raw_target_ids = params.get(Keys.TARGET_IDS, PackedInt32Array())
		if raw_target_ids is PackedInt32Array and !raw_target_ids.is_empty():
			target_id = int(raw_target_ids[0])
		elif raw_target_ids is Array and !raw_target_ids.is_empty():
			target_id = int(raw_target_ids[0])

	if target_id <= 0:
		push_warning("npc_move_sequence.gd execute(): no valid target_id resolved (actor=%d, move_type=%d, params=%s)" % [actor_id, move_type, str(params)])
		return

	var move := MoveContext.new()
	move.move_type = move_type
	move.actor_id = actor_id
	var swap_b := int(params.get(Keys.SWAP_B, 0))
	move.target_id = swap_b if swap_b > 0 else target_id
	move.index = int(params.get(Keys.TO_INDEX, -1))
	move.reason = String(params.get(Keys.REASON, "npc_move"))

	runtime.run_move(move)

	_append_unique_affected_id(ctx, actor_id)

func _append_unique_affected_id(ctx: NPCAIContext, unit_id: int) -> void:
	if ctx == null or unit_id <= 0:
		return
	for existing_id in ctx.affected_ids:
		if int(existing_id) == unit_id:
			return
	ctx.affected_ids.append(unit_id)
