# lowest_health_ally_status_target_model.gd

class_name LowestHealthAllyStatusTargetModel extends ParamModel

@export var include_self: bool = true

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return _write_target_ids(ctx)

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	return _write_target_ids(ctx)

func _write_target_ids(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx or ctx.api == null or ctx.api.state == null:
		return ctx

	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		return ctx

	var group_index := int(ctx.api.get_group(actor_id))
	if group_index < 0:
		return ctx

	var target_id := 0
	var lowest_health := 1_000_000
	var best_rank := 1_000_000
	var ally_ids := ctx.api.get_combatants_in_group(group_index, false)

	for i in range(ally_ids.size()):
		var cid := int(ally_ids[i])
		if cid <= 0:
			continue
		if !include_self and cid == actor_id:
			continue

		var unit: CombatantState = ctx.api.state.get_unit(cid)
		if unit == null or !unit.is_alive():
			continue

		var health := int(unit.health)
		if health < lowest_health or (health == lowest_health and i < best_rank):
			lowest_health = health
			best_rank = i
			target_id = cid

	var target_ids := PackedInt32Array()
	if target_id > 0:
		target_ids.append(target_id)
		ctx.params[Keys.TARGET_ID] = target_id
	ctx.params[Keys.TARGET_IDS] = target_ids
	return ctx
