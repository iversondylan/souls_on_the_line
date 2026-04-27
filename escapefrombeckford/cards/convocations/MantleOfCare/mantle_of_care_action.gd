extends CardAction

class_name MantleOfCareAction

const PRESSURE_BARRIER := preload("res://statuses/pressure_barrier.tres")

@export var stacks: int = 3

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false

	var sacrificed_id := 0
	if !ctx.target_ids.is_empty():
		sacrificed_id = int(ctx.target_ids[0])

	for ally_id in ctx.api.get_combatants_in_group(SimBattleAPI.FRIENDLY, false):
		var target_id := int(ally_id)
		if target_id <= 0 or target_id == sacrificed_id:
			continue

		var status_ctx := StatusContext.new()
		status_ctx.source_id = int(ctx.source_id)
		status_ctx.target_id = target_id
		status_ctx.status_id = PRESSURE_BARRIER.get_id()
		status_ctx.stacks = int(stacks)
		status_ctx.reason = "mantle_of_care"
		if ctx.card_data != null:
			ctx.card_data.ensure_uid()
			status_ctx.origin_card_uid = String(ctx.card_data.uid)
		ctx.api.apply_status(status_ctx)
		if ctx.runtime != null:
			ctx.runtime.append_affected_id(ctx, target_id)

	return true

func get_description_value(_ctx: CardActionContext) -> String:
	return str(int(stacks))
