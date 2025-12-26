extends CardAction


func activate(ctx: CardActionContext) -> bool:
	var targets := ctx.resolved_target.fighters
	if targets.is_empty():
		return false

	var fighter := targets[0]

	# NOTE:
	# This should eventually become a MoveEffect,
	# but keeping it direct for now is fine.
	fighter.traverse_player()
	
	SFXPlayer.play(ctx.card_data.sound)
	return true

func description_arity() -> int:
	return 0

func get_description_values(_ctx: CardActionContext) -> Array:
	return []
