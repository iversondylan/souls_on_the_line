extends CardAction

class_name SwapWithTargetAction

@export var sound: Sound = preload("uid://duvojjmcskogd")

func begin_preflight_interaction(ctx: CardContext) -> bool:
	if ctx == null or ctx.runtime == null:
		return false

	var action_index := int(ctx.current_action_index)
	if action_index < 0:
		return false

	if Events != null and Events.has_signal("request_interaction"):
		var interaction := SwapPartnerInteractionContext.new()
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
	if actor_id <= 0:
		return false
	var move_unit_id := int(payload.get(Keys.MOVE_UNIT_ID, 0))
	if move_unit_id <= 0:
		return false
	var target_id := int(payload.get(Keys.TARGET_ID, 0))
	if target_id <= 0:
		return false

	if ctx.params == null:
		ctx.params = {}

	if payload.has(Keys.WINDUP_ORDER_IDS):
		ctx.params[Keys.WINDUP_ORDER_IDS] = payload[Keys.WINDUP_ORDER_IDS]

	var move := MoveContext.new()
	move.move_type = MoveContext.MoveType.SWAP_WITH_TARGET
	move.actor_id = actor_id
	move.move_unit_id = move_unit_id
	move.target_id = target_id
	var queue_adjustments := _compute_player_turn_queue_adjustments(ctx.api, actor_id, move_unit_id, target_id)
	move.grant_turns = PackedInt32Array(queue_adjustments.get(Keys.GRANT_TURNS, PackedInt32Array()))
	move.revoke_turns = PackedInt32Array(queue_adjustments.get(Keys.REVOKE_TURNS, PackedInt32Array()))
	move.sound = sound
	move.reason = "card_swap"
	if ctx.card_data != null:
		ctx.card_data.ensure_uid()
		move.origin_card_uid = String(ctx.card_data.uid)

	ctx.runtime.run_move(move)

	if move.sound != null:
		ctx.api.play_sfx(move.sound)

	ctx.runtime.append_affected_id(ctx, move_unit_id)
	ctx.runtime.append_affected_id(ctx, target_id)

	return true


func get_preflight_interaction_mode(_ctx: CardContext) -> int:
	return InteractionMode.PREFLIGHT


func _compute_player_turn_queue_adjustments(api: SimBattleAPI, actor_id: int, move_unit_id: int, target_id: int) -> Dictionary:
	if api == null:
		return {}

	var player_id := int(api.get_player_id())
	if player_id <= 0 or int(actor_id) != player_id:
		return {}

	var before := _to_packed_int_array(api.get_combatants_in_group(SimBattleAPI.FRIENDLY, false))
	if before.is_empty():
		return {}

	var after := before.duplicate()
	var move_idx := after.find(move_unit_id)
	var target_idx := after.find(target_id)
	if move_idx == -1 or target_idx == -1:
		return {}

	after[move_idx] = target_id
	after[target_idx] = move_unit_id

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
