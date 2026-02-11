# discard_action.gd
class_name DiscardAction extends CardAction

@export var base_discard: int = 1

func activate(ctx: CardActionContext) -> bool:
	var discard_effect := DiscardEffect.new()
	discard_effect.amount = base_discard
	discard_effect.source = ctx.player
	discard_effect.execute(ctx.battle_scene.api)
	return true

func description_arity() -> int:
	return 1

func get_description_values(_ctx: CardActionContext) -> Array:
	return [base_discard]
