class_name MostDamagedAllyStatusTargetModel extends ParamModel

@export var include_self: bool = true
@export var exclude_player: bool = true

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return _write_target_ids(ctx)

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	return _write_target_ids(ctx)

static func find_target_id(ctx: NPCAIContext, include_self := true, exclude_player := true) -> int:
	if ctx == null:
		return 0
	return find_target_id_for_actor(ctx.api, ctx.get_actor_id(), include_self, exclude_player)

static func find_target_id_for_actor(
	api: SimBattleAPI,
	actor_id: int,
	include_self := true,
	exclude_player := true
) -> int:
	if api == null or api.state == null:
		return 0
	if int(actor_id) <= 0:
		return 0

	var group_index := int(api.get_group(actor_id))
	if group_index < 0:
		return 0

	var player_id := int(api.get_player_id())
	var target_id := 0
	var best_missing := 0
	var best_rank := 1_000_000

	var ally_ids := api.get_combatants_in_group(group_index, false)
	for i in range(ally_ids.size()):
		var cid := int(ally_ids[i])
		if cid <= 0:
			continue
		if !include_self and cid == int(actor_id):
			continue
		if exclude_player and cid == player_id:
			continue

		var ally: CombatantState = api.state.get_unit(cid)
		if ally == null or !ally.is_alive():
			continue

		var missing := maxi(int(ally.max_health) - int(ally.health), 0)
		if missing <= 0:
			continue

		if missing > best_missing:
			best_missing = missing
			best_rank = i
			target_id = cid
			continue

		if missing == best_missing:
			if i < best_rank or (i == best_rank and (target_id <= 0 or cid < target_id)):
				best_rank = i
				target_id = cid

	return target_id

func _write_target_ids(ctx: NPCAIContext) -> NPCAIContext:
	if ctx == null:
		return ctx

	var target_id := find_target_id(ctx, bool(include_self), bool(exclude_player))
	var target_ids := PackedInt32Array()
	if target_id > 0:
		target_ids.append(target_id)
		ctx.params[Keys.TARGET_ID] = target_id
	else:
		ctx.params.erase(Keys.TARGET_ID)

	ctx.params[Keys.TARGET_IDS] = target_ids
	return ctx
