extends CardAction

class_name InvigorateAction

const MIGHT := preload("res://statuses/might.tres")

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.target_ids.is_empty():
		return false

	var target_id := int(ctx.target_ids[0])
	if target_id <= 0 or !ctx.api.is_alive(target_id):
		return false

	var unit := ctx.api.state.get_unit(target_id) if ctx.api.state != null else null
	if unit == null:
		return false

	var missing_health := maxi(int(unit.max_health) - int(unit.health), 0)
	var heal_ctx := HealContext.new(int(ctx.source_id), target_id, 0, 0.0, 1.0)
	if ctx.card_data != null:
		heal_ctx.tags.append(&"card")
		heal_ctx.tags.append(StringName(ctx.card_data.name))
	var healed := int(ctx.api.heal(heal_ctx))
	if healed > 0 and ctx.runtime != null:
		ctx.runtime.append_affected_id(ctx, target_id)

	var might_stacks := int(healed / 3)
	if might_stacks > 0:
		var status_ctx := StatusContext.new()
		status_ctx.source_id = int(ctx.source_id)
		status_ctx.target_id = target_id
		status_ctx.status_id = MIGHT.get_id()
		status_ctx.stacks = might_stacks
		status_ctx.reason = "invigorate"
		if ctx.card_data != null:
			ctx.card_data.ensure_uid()
			status_ctx.origin_card_uid = String(ctx.card_data.uid)
		ctx.api.apply_status(status_ctx)
		if ctx.runtime != null:
			ctx.runtime.append_affected_id(ctx, target_id)

	return healed > 0 or missing_health == 0
