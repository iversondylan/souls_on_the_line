# swap_with_target_action.gd

class_name SwapWithTargetAction extends CardAction

@export var sound: Sound = preload("res://audio/warp_zap.tres")

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
	var actor_id := int(payload.get(Keys.SWAP_A, ctx.source_id))
	if actor_id <= 0:
		return false
	var target_id := int(payload.get(Keys.SWAP_B, ctx.source_id))
	if actor_id <= 0:
		return false
	
	
	if ctx.params == null:
		ctx.params = {}

	if payload.has(Keys.WINDUP_ORDER_IDS):
		ctx.params[Keys.WINDUP_ORDER_IDS] = payload[Keys.WINDUP_ORDER_IDS]

	var move := MoveContext.new()
	move.move_type = MoveContext.MoveType.SWAP_WITH_TARGET
	move.actor_id = actor_id
	move.target_id = target_id
	move.can_restore_turn = true
	move.sound = sound

	ctx.runtime.run_move(move)

	if move.sound != null:
		ctx.api.play_sfx(move.sound)

	ctx.runtime.append_affected_id(ctx, int(ctx.source_id))
	ctx.runtime.append_affected_id(ctx, target_id)

	return true

func get_interaction_mode(ctx: CardContext) -> int:
	return InteractionMode.ESCROW

func description_arity() -> int:
	return 0


func get_description_values(_ctx: CardActionContext) -> Array:
	return []
