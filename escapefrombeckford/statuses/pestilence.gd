class_name PestilenceStatus extends Status

const ID := &"pestilence"
const EXPLOSIVE_DEPARTURE := preload("res://statuses/explosive_departure.tres")

func get_id() -> StringName:
	return ID

func get_tooltip(stacks: int = 0) -> String:
	return "Pestilence: On death, give allies: on death, deal %s damage to enemies." % stacks

func on_removal(ctx: SimStatusContext, removal_ctx) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null:
		return
	if removal_ctx == null or int(removal_ctx.removal_type) != int(Removal.Type.DEATH):
		return
	if int(removal_ctx.target_id) != int(ctx.owner_id):
		return

	var stacks := maxi(int(ctx.get_stacks()), 0)
	if stacks <= 0:
		return

	if ctx.owner == null:
		return

	var player_id := int(ctx.api.get_player_id())
	for cid in ctx.api.get_combatants_in_group(int(ctx.owner.team), false):
		var ally_id := int(cid)
		if ally_id <= 0 or ally_id == int(ctx.owner_id) or ally_id == player_id:
			continue
		if !ctx.api.is_alive(ally_id):
			continue
		var status_ctx := StatusContext.new()
		status_ctx.source_id = int(ctx.owner_id)
		status_ctx.target_id = ally_id
		status_ctx.status_id = EXPLOSIVE_DEPARTURE.get_id()
		status_ctx.stacks = stacks
		status_ctx.reason = "pestilence"
		ctx.api.apply_status(status_ctx)
