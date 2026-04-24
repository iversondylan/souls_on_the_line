extends CardAction

class_name LockstepFormationAction

const FULL_FORTITUDE := preload("res://statuses/full_fortitude.tres")
const MIGHT := preload("res://statuses/might.tres")

func get_preflight_interaction_mode(_ctx: CardContext) -> int:
	return InteractionMode.PREFLIGHT

func begin_preflight_interaction(ctx: CardContext) -> bool:
	if ctx == null or ctx.runtime == null or ctx.target_ids.is_empty():
		return false

	var action_index := int(ctx.current_action_index)
	if action_index < 0:
		return false

	if Events != null and Events.has_signal("request_interaction"):
		var interaction := InsertTargetInteractionContext.new()
		interaction.card_ctx = ctx
		interaction.action_index = action_index
		Events.request_interaction.emit(interaction)
		return true

	return false

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.runtime == null:
		return false

	var payload := ctx.runtime.get_action_interaction_payload(ctx, ctx.current_action_index)
	var actor_id := int(ctx.source_id)
	var move_unit_id := int(payload.get(Keys.MOVE_UNIT_ID, 0))
	var insert_index := int(payload.get(Keys.INSERT_INDEX, -1))
	if actor_id <= 0 or move_unit_id <= 0 or insert_index < 0:
		return false

	var before := _get_group_order_for_unit(ctx.api, move_unit_id)
	var current_index := before.find(move_unit_id)
	if current_index == -1:
		return false
	if current_index == insert_index:
		return true

	var move := MoveContext.new()
	move.move_type = MoveContext.MoveType.INSERT_AT_INDEX
	move.actor_id = actor_id
	move.move_unit_id = move_unit_id
	move.index = insert_index
	var queue_adjustments := _compute_player_turn_queue_adjustments(ctx.api, actor_id, move_unit_id, insert_index)
	move.grant_turns = PackedInt32Array(queue_adjustments.get(Keys.GRANT_TURNS, PackedInt32Array()))
	move.revoke_turns = PackedInt32Array(queue_adjustments.get(Keys.REVOKE_TURNS, PackedInt32Array()))
	move.reason = "card_lockstep_formation"
	if ctx.card_data != null:
		ctx.card_data.ensure_uid()
		move.origin_card_uid = String(ctx.card_data.uid)

	ctx.runtime.run_move(move)
	ctx.runtime.append_affected_id(ctx, move_unit_id)

	var after := _get_group_order_for_unit(ctx.api, move_unit_id)
	var final_index := after.find(move_unit_id)
	if final_index == -1:
		return true

	if final_index == 0 and FULL_FORTITUDE != null:
		return _apply_status(ctx, move_unit_id, FULL_FORTITUDE.get_id(), 2, "lockstep_front")
	if final_index == after.size() - 1 and MIGHT != null:
		return _apply_status(ctx, move_unit_id, MIGHT.get_id(), 2, "lockstep_back")

	return true

func _apply_status(ctx: CardContext, target_id: int, status_id: StringName, stacks: int, reason: String) -> bool:
	if ctx == null or ctx.api == null or target_id <= 0 or status_id == &"":
		return false

	var sctx := StatusContext.new()
	sctx.source_id = int(ctx.source_id)
	sctx.target_id = int(target_id)
	sctx.status_id = status_id
	sctx.stacks = int(stacks)
	sctx.reason = reason
	if ctx.card_data != null:
		ctx.card_data.ensure_uid()
		sctx.origin_card_uid = String(ctx.card_data.uid)

	ctx.api.apply_status(sctx)
	ctx.runtime.append_affected_id(ctx, target_id)
	return true

func _compute_player_turn_queue_adjustments(api: SimBattleAPI, actor_id: int, move_unit_id: int, insert_index: int) -> Dictionary:
	if api == null:
		return {}

	var player_id := int(api.get_player_id())
	if player_id <= 0 or int(actor_id) != player_id:
		return {}

	var before := _to_packed_int_array(api.get_combatants_in_group(SimBattleAPI.FRIENDLY, false))
	if before.is_empty():
		return {}

	var move_idx := before.find(move_unit_id)
	if move_idx == -1:
		return {}

	var after := before.duplicate()
	after.remove_at(move_idx)
	after.insert(clampi(insert_index, 0, after.size()), move_unit_id)

	var before_future := _units_after_actor(before, actor_id)
	var after_future := _units_after_actor(after, actor_id)

	return {
		Keys.GRANT_TURNS: _packed_set_difference(after_future, before_future),
		Keys.REVOKE_TURNS: _packed_set_difference(before_future, after_future),
	}

func _units_after_actor(order: PackedInt32Array, actor_id: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var actor_idx := order.find(actor_id)
	if actor_idx == -1:
		return out

	for i in range(actor_idx + 1, order.size()):
		var id := int(order[i])
		if id > 0 and id != actor_id:
			out.append(id)
	return out

func _packed_set_difference(left: PackedInt32Array, right: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for value in left:
		var id := int(value)
		if id > 0 and !right.has(id):
			out.append(id)
	return out

func _to_packed_int_array(values: Array[int]) -> PackedInt32Array:
	var out := PackedInt32Array()
	for value in values:
		out.append(int(value))
	return out

func _get_group_order_for_unit(api: SimBattleAPI, unit_id: int) -> PackedInt32Array:
	if api == null or unit_id <= 0:
		return PackedInt32Array()

	var friendly := _to_packed_int_array(api.get_combatants_in_group(SimBattleAPI.FRIENDLY, false))
	if friendly.has(unit_id):
		return friendly

	var enemy := _to_packed_int_array(api.get_combatants_in_group(SimBattleAPI.ENEMY, false))
	if enemy.has(unit_id):
		return enemy

	return PackedInt32Array()
