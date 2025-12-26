extends CardAction

var n_armor := 5

func activate(ctx: CardActionContext) -> bool:
	var targets := ctx.resolved_target.fighters
	if targets.is_empty():
		return false

	var block_effect := BlockEffect.new()
	block_effect.targets = targets
	block_effect.n_armor = n_armor
	block_effect.sound = ctx.card_data.sound
	block_effect.execute()

	return true

func get_description(_ctx: CardActionContext, base_text: String) -> String:
	#var n_damage = player.modifier_system.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	return get_unmod_description(base_text)

func get_unmod_description(base_text: String) -> String:
	return base_text % n_armor
