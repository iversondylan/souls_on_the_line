# discard_action.gd
class_name DiscardAction extends CardAction

@export var base_discard: int = 1

func activate(ctx: CardActionContext) -> bool:
	var e := DiscardEffect.new()
	e.amount = base_discard
	e.source = ctx.player
	e.execute(BattleAPI.new())
	return true

func description_arity() -> int:
	return 1

func get_description_values(_ctx: CardActionContext) -> Array:
	return [base_discard]
