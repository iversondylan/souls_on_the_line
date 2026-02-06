# draw_action.gd
class_name DrawAction extends CardAction

@export var base_draw: int = 1

func activate(ctx: CardActionContext) -> bool:
	var e := CardDrawEffect.new()
	e.amount = base_draw
	e.source = ctx.player
	e.execute()
	return true

func description_arity() -> int:
	return 1

func get_description_values(_ctx: CardActionContext) -> Array:
	return [base_draw]

func get_modular_description(_ctx: CardActionContext) -> String:
	var base_text: String = "Draw %s."
	return base_text % base_draw
