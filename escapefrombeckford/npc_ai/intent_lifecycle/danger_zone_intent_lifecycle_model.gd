# danger_zone_intent_lifecycle_model.gd

class_name DangerZoneIntentLifecycleModel extends TargetedStatusFromOppTurnUntilEndOfMyTurnModel

@export var reapply_on_layout_change_only_if_missing: bool = false

func on_group_layout_changed(
	ctx: NPCAIContext,
	changed_group_index: int,
	before_order_ids: PackedInt32Array,
	after_order_ids: PackedInt32Array,
	_reason: String
) -> void:
	if !_can_run_sim(ctx):
		return
	if reapply_target_model == null:
		return

	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		return

	var actor_group := int(ctx.api.get_group(actor_id))
	if actor_group < 0:
		return

	var opposing_group := int(ctx.api.get_opposing_group(actor_group))
	if int(changed_group_index) != opposing_group:
		return

	var player_id := int(ctx.api.get_player_id())
	var preferred_target_id := _find_preferred_opposing_target_id(ctx, after_order_ids)

	if _status_is_only_on_player(ctx) and preferred_target_id > 0 and preferred_target_id != player_id:
		_apply_status_to_target_sim(ctx, preferred_target_id)
		return

	if bool(reapply_on_layout_change_only_if_missing):
		if _status_exists_on_opposing_team(ctx):
			return
		if preferred_target_id > 0:
			_apply_status_to_target_sim(ctx, preferred_target_id)
		else:
			_apply_targeted_status_sim(ctx, reapply_target_model)
		return

	if preferred_target_id > 0 and preferred_target_id != player_id:
		if _front_id_from_order(before_order_ids) != _front_id_from_order(after_order_ids) or !_status_exists_on_opposing_team(ctx):
			_apply_status_to_target_sim(ctx, preferred_target_id)
			return

	if _front_id_from_order(before_order_ids) == _front_id_from_order(after_order_ids):
		return

	_apply_targeted_status_sim(ctx, reapply_target_model)

func on_action_execution_started(_ctx: NPCAIContext) -> void:
	pass

func _front_id_from_order(order: PackedInt32Array) -> int:
	if order.is_empty():
		return 0
	return int(order[0])


func _status_is_only_on_player(ctx: NPCAIContext) -> bool:
	var player_id := int(ctx.api.get_player_id())
	var actor_group := int(ctx.api.get_group(ctx.get_actor_id()))
	var opposing_group := int(ctx.api.get_opposing_group(actor_group))
	var found_on_player := false
	for cid in ctx.api.get_combatants_in_group(opposing_group, false):
		if ctx.api.has_status(int(cid), _status_id()):
			if int(cid) != player_id:
				return false
			found_on_player = true
	return found_on_player


func _find_preferred_opposing_target_id(
	ctx: NPCAIContext,
	ordered_ids: PackedInt32Array = PackedInt32Array()
) -> int:
	if ctx == null or ctx.api == null:
		return 0

	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		return 0

	var actor_group := int(ctx.api.get_group(actor_id))
	if actor_group < 0:
		return 0

	var opposing_group := int(ctx.api.get_opposing_group(actor_group))
	var player_id := int(ctx.api.get_player_id())
	var target_order := ordered_ids
	if target_order.is_empty():
		target_order = ctx.api.get_combatants_in_group(opposing_group, false)

	var fallback_player_id := 0
	for cid in target_order:
		var unit_id := int(cid)
		if unit_id <= 0 or !ctx.api.is_alive(unit_id):
			continue
		if unit_id == player_id:
			fallback_player_id = unit_id
			continue
		return unit_id

	return fallback_player_id


func _apply_status_to_target_sim(ctx: NPCAIContext, target_id: int) -> void:
	if ctx == null or ctx.api == null:
		return
	if int(target_id) <= 0:
		return

	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		return

	var sc := StatusContext.new()
	sc.source_id = actor_id
	sc.target_id = int(target_id)
	sc.status_id = _status_id()
	sc.stacks = int(stacks)
	sc.pending = bool(pending)
	ctx.api.apply_status(sc)
	_set_flag(ctx, true)
