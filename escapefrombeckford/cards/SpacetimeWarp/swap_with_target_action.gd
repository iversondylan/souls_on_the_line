# swap_with_target_action.gd

class_name SwapWithTargetAction extends CardAction

@export var sound: Sound = preload("res://audio/warp_zap.tres")

func activate_sim(ctx: CardActionContextSim) -> bool:
	if ctx == null:
		return false
	
	var req := CardPlayRequest.new()
	req.card = ctx.card_data
	req.source_id = int(ctx.source_id)
	req.source_card = ctx.source_card
	req.params = ctx.params.duplicate(true) if ctx.params != null else {}

	Events.request_swap_partner.emit(ctx.source_card, req, self)
	return true
	

func description_arity() -> int:
	return 0


func get_description_values(_ctx: CardActionContext) -> Array:
	return []
