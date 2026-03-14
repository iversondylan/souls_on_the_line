# swap_with_target_action.gd
class_name SwapWithTargetAction extends CardAction

@export var sound: Sound = preload("res://audio/warp_zap.tres")

#func activate(ctx: CardActionContext) -> bool:
	#if ctx == null or ctx.battle_scene == null or ctx.resolved_target == null:
		#return false
	#
	#var targets := ctx.resolved_target.fighters
	#if targets.is_empty():
		#return false
	#
	#var actor: Fighter = targets[0]
	#if actor == null:
		#return false
	#
	## Enter SWAP_PARTNER mode and escrow this card.
	#Events.request_swap_partner.emit(ctx.card_data_source_card, ctx, actor, self)
	#
	#return true

func description_arity() -> int:
	return 0

#func get_description_values(_ctx: CardActionContext) -> Array:
	#return []
