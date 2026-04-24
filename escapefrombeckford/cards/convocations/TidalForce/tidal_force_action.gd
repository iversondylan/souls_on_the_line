extends CardAction

class_name TidalForceAction

const AttackNowActionScript := preload("res://cards/_generic_actions/attack_now_action.gd")

func starts_compiled_turn_span(_ctx: CardContext) -> bool:
	return true

func get_compiled_turn_span_kind(_ctx: CardContext) -> StringName:
	return &"attack_now"

func get_compiled_turn_span_actor_id(ctx: CardContext) -> int:
	if ctx == null or ctx.target_ids.is_empty():
		return 0
	return int(ctx.target_ids[0])

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.runtime == null or ctx.target_ids.is_empty():
		return false

	var mover_id := int(ctx.target_ids[0])
	if mover_id <= 0 or !ctx.api.is_alive(mover_id):
		return false

	var moved_forward := _move_target_to_front(ctx, mover_id)
	var attack_any := false
	var attack_now = AttackNowActionScript.new()
	if attack_now != null:
		attack_any = bool(attack_now.activate_sim(ctx))

	var shoved_enemy := false
	if moved_forward:
		shoved_enemy = _push_frontmost_enemy_back_one(ctx)

	return moved_forward or attack_any or shoved_enemy

func _move_target_to_front(ctx: CardContext, mover_id: int) -> bool:
	var before := _to_packed_int_array(ctx.api.get_combatants_in_group(SimBattleAPI.FRIENDLY, false))
	if before.is_empty():
		return false
	if int(before[0]) == mover_id:
		return false

	var move := MoveContext.new()
	move.move_type = MoveContext.MoveType.MOVE_TO_FRONT
	move.actor_id = int(ctx.source_id)
	move.move_unit_id = mover_id
	var queue_adjustments := _compute_player_turn_queue_adjustments_to_front(ctx.api, int(ctx.source_id), mover_id)
	move.grant_turns = PackedInt32Array(queue_adjustments.get(Keys.GRANT_TURNS, PackedInt32Array()))
	move.revoke_turns = PackedInt32Array(queue_adjustments.get(Keys.REVOKE_TURNS, PackedInt32Array()))
	move.reason = "card_tidal_force_forward"
	if ctx.card_data != null:
		ctx.card_data.ensure_uid()
		move.origin_card_uid = String(ctx.card_data.uid)

	ctx.runtime.run_move(move)
	ctx.runtime.append_affected_id(ctx, mover_id)
	return true

func _push_frontmost_enemy_back_one(ctx: CardContext) -> bool:
	var enemy_order := _to_packed_int_array(ctx.api.get_combatants_in_group(SimBattleAPI.ENEMY, false))
	if enemy_order.size() < 2:
		return false

	var target_id := int(enemy_order[0])
	if target_id <= 0 or !ctx.api.is_alive(target_id):
		return false

	var move := MoveContext.new()
	move.move_type = MoveContext.MoveType.INSERT_AT_INDEX
	move.actor_id = int(ctx.source_id)
	move.move_unit_id = target_id
	move.index = 1
	move.reason = "card_tidal_force_enemy_shove"
	if ctx.card_data != null:
		ctx.card_data.ensure_uid()
		move.origin_card_uid = String(ctx.card_data.uid)

	ctx.runtime.run_move(move)
	ctx.runtime.append_affected_id(ctx, target_id)
	return true

func _compute_player_turn_queue_adjustments_to_front(api: SimBattleAPI, actor_id: int, move_unit_id: int) -> Dictionary:
	if api == null:
		return {}

	var player_id := int(api.get_player_id())
	if player_id <= 0 or actor_id != player_id:
		return {}

	var before := _to_packed_int_array(api.get_combatants_in_group(SimBattleAPI.FRIENDLY, false))
	if before.is_empty():
		return {}

	var move_idx := before.find(move_unit_id)
	if move_idx <= 0:
		return {}

	var after := before.duplicate()
	after.remove_at(move_idx)
	after.insert(0, move_unit_id)

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
