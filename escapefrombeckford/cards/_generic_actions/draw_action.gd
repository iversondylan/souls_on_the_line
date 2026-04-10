# draw_action.gd
class_name DrawAction extends CardAction

@export var base_draw: int = 1

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.runtime == null:
		return false
	var draw_ctx := DrawContext.new()
	draw_ctx.amount = int(base_draw)
	draw_ctx.source_id = int(ctx.api.get_player_id())
	draw_ctx.reason = "CardAction"
	ctx.runtime.run_draw_action(draw_ctx)
	return true

func description_arity() -> int:
	return 1

#func get_description_values(_ctx: CardActionContext) -> Array:
	#return [base_draw]

#func get_modular_description(_ctx: CardActionContext) -> String:
	#var base_text: String = "Draw %s."
	#return base_text % base_draw
