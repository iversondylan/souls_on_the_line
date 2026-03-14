# draw_action.gd
class_name DrawAction extends CardAction

@export var base_draw: int = 1

#func activate(ctx: CardActionContext) -> bool:
	#var draw_effect := CardDrawEffect.new()
	#draw_effect.amount = base_draw
	#draw_effect.source = ctx.player
	#draw_effect.execute(ctx.battle_scene.api)
	#return true

func activate_sim(ctx: CardActionContextSim) -> bool:
	return true

func description_arity() -> int:
	return 1

#func get_description_values(_ctx: CardActionContext) -> Array:
	#return [base_draw]

#func get_modular_description(_ctx: CardActionContext) -> String:
	#var base_text: String = "Draw %s."
	#return base_text % base_draw
