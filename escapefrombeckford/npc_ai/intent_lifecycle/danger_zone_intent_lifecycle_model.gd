# danger_zone_intent_lifecycle_model.gd
class_name DangerZoneIntentLifecycleModel
extends "res://npc_ai/intent_lifecycle/targeted_status_from_opp_turn_until_end_of_my_turn_model.gd"

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
	if _front_id_from_order(before_order_ids) == _front_id_from_order(after_order_ids):
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

	if bool(reapply_on_layout_change_only_if_missing) and _status_exists_on_opposing_team(ctx):
		return

	_apply_targeted_status_sim(ctx, reapply_target_model)

func on_action_execution_started(_ctx: NPCAIContext) -> void:
	pass

func _front_id_from_order(order: PackedInt32Array) -> int:
	if order.is_empty():
		return 0
	return int(order[0])
