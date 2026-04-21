extends CardAction

class_name PulseWaveAction

const FULL_FORTITUDE := preload("res://statuses/full_fortitude.tres")

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.runtime == null or ctx.target_ids == null or ctx.target_ids.is_empty():
		return false

	var target_id := int(ctx.target_ids[0])
	if target_id <= 0:
		return false

	var target_state := ctx.api.state.get_unit(target_id) if ctx.api.state != null else null
	if target_state == null:
		return false

	var was_at_or_below_half := int(target_state.health) * 2 <= int(target_state.max_health)
	var heal_ctx := HealContext.new(int(ctx.source_id), target_id, 4, 0.0, 0.0)
	if ctx.card_data != null:
		heal_ctx.tags.append(&"card")
		heal_ctx.tags.append(StringName(ctx.card_data.name))
	var healed := int(ctx.api.heal(heal_ctx))
	if healed > 0:
		ctx.runtime.append_affected_id(ctx, target_id)

	if !was_at_or_below_half:
		return true
	if FULL_FORTITUDE == null:
		return true

	var fortitude_ctx := StatusContext.new()
	fortitude_ctx.source_id = int(ctx.source_id)
	fortitude_ctx.target_id = target_id
	fortitude_ctx.status_id = FULL_FORTITUDE.get_id()
	fortitude_ctx.stacks = 2
	fortitude_ctx.reason = "pulse_wave"
	if ctx.card_data != null:
		ctx.card_data.ensure_uid()
		fortitude_ctx.origin_card_uid = String(ctx.card_data.uid)
	ctx.api.apply_status(fortitude_ctx)
	ctx.runtime.append_affected_id(ctx, target_id)

	var draw_ctx := DrawContext.new()
	draw_ctx.amount = 1
	draw_ctx.source_id = int(ctx.api.get_player_id())
	draw_ctx.reason = "pulse_wave"
	ctx.runtime.run_draw_action(draw_ctx)
	return true
