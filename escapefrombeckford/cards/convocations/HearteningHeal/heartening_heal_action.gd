extends CardAction

class_name HearteningHealAction

const ENERGY_SURGE := preload("res://statuses/energy_surge.tres")

@export var heal_amount: int = 5

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.target_ids.is_empty():
		return false

	var target_id := int(ctx.target_ids[0])
	if target_id <= 0 or !ctx.api.is_alive(target_id):
		return false

	var heal_ctx := HealContext.new(int(ctx.source_id), target_id, int(heal_amount), 0.0, 0.0)
	if ctx.card_data != null:
		heal_ctx.tags.append(&"card")
		heal_ctx.tags.append(StringName(ctx.card_data.name))
	var healed := int(ctx.api.heal(heal_ctx))
	if healed > 0:
		var status_ctx := StatusContext.new()
		status_ctx.source_id = int(ctx.source_id)
		status_ctx.target_id = target_id
		status_ctx.status_id = ENERGY_SURGE.get_id()
		status_ctx.stacks = healed
		status_ctx.reason = "heartening_heal"
		if ctx.card_data != null:
			ctx.card_data.ensure_uid()
			status_ctx.origin_card_uid = String(ctx.card_data.uid)
		ctx.api.apply_status(status_ctx)
		if ctx.runtime != null:
			ctx.runtime.append_affected_id(ctx, target_id)

	if ctx.runtime != null:
		var draw_ctx := DrawContext.new()
		draw_ctx.amount = 1
		draw_ctx.source_id = int(ctx.api.get_player_id())
		draw_ctx.reason = "heartening_heal"
		ctx.runtime.run_draw_action(draw_ctx)

	return true

func get_description_value(_ctx: CardActionContext) -> String:
	return str(int(heal_amount))
