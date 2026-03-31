extends CardAction

class_name StatusOnFrontmostAllyAction

@export var status: Status

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false
	if status == null:
		push_warning("status_on_frontmost_ally_action.gd activate_sim(): missing status")
		return false

	var player_id := int(ctx.api.get_player_id())
	var friendly_ids := ctx.api.get_combatants_in_group(SimBattleAPI.FRIENDLY, false)
	var target_id := 0
	for cid in friendly_ids:
		var ally_id := int(cid)
		if ally_id <= 0 or ally_id == player_id:
			continue
		target_id = ally_id
		break

	if target_id <= 0:
		return false

	var sctx := StatusContext.new()
	sctx.source_id = int(ctx.source_id)
	sctx.target_id = target_id
	sctx.status_id = status.get_id()

	ctx.api.apply_status(sctx)

	if !ctx.affected_ids.has(target_id):
		ctx.affected_ids.append(target_id)

	return true
