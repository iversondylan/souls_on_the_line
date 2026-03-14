extends CardAction

var n_armor := 5

#func activate(ctx: CardActionContext) -> bool:
	#var targets := ctx.resolved_target.fighters
	#if targets.is_empty():
		#return false
#
	#var block_effect := BlockEffect.new()
	#block_effect.targets = targets
	#block_effect.n_armor = n_armor
	#block_effect.sound = ctx.card_data.sound
	#block_effect.execute(ctx.battle_scene.api)
#
	#return true

func description_arity() -> int:
	return 1

#func get_description_values(_ctx: CardActionContext) -> Array:
	#return [n_armor]
