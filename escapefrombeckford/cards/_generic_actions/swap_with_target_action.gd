extends CardAction

class_name SwapWithTargetAction

@export var sound: Sound = preload("uid://duvojjmcskogd")

func activate_interaction(ctx: CardContext) -> bool:
	if ctx == null or ctx.runtime == null:
		return false

	var action_index := int(ctx.current_action_index)
	if action_index < 0:
		action_index = int(ctx.escrow_action_index)

	if Events != null and Events.has_signal("request_swap_partner"):
		Events.request_swap_partner.emit(ctx, action_index)
		return true

	return false


func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.runtime == null:
		return false

	var payload := ctx.runtime.get_action_interaction_payload(ctx, ctx.current_action_index)
	var actor_id := int(ctx.source_id)
	if actor_id <= 0:
		return false
	var move_unit_id := int(payload.get(Keys.MOVE_UNIT_ID, 0))
	if move_unit_id <= 0:
		return false
	var target_id := int(payload.get(Keys.TARGET_ID, 0))
	if target_id <= 0:
		return false

	if ctx.params == null:
		ctx.params = {}

	if payload.has(Keys.WINDUP_ORDER_IDS):
		ctx.params[Keys.WINDUP_ORDER_IDS] = payload[Keys.WINDUP_ORDER_IDS]

	var move := MoveContext.new()
	move.move_type = MoveContext.MoveType.SWAP_WITH_TARGET
	move.actor_id = actor_id
	move.move_unit_id = move_unit_id
	move.target_id = target_id
	move.can_restore_turn = true
	move.sound = sound
	move.reason = "card_swap"
	if ctx.card_data != null:
		ctx.card_data.ensure_uid()
		move.origin_card_uid = String(ctx.card_data.uid)

	ctx.runtime.run_move(move)

	if move.sound != null:
		ctx.api.play_sfx(move.sound)

	ctx.runtime.append_affected_id(ctx, move_unit_id)
	ctx.runtime.append_affected_id(ctx, target_id)

	return true


func get_interaction_mode(_ctx: CardContext) -> int:
	return InteractionMode.ESCROW


func description_arity() -> int:
	return 0


func get_description_values(_ctx: CardActionContext) -> Array:
	return []
