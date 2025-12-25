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

func get_description(description: String, _target_fighter: Fighter = null) -> String:
	#var n_damage = player.modifier_system.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	return description# % n_damage

func get_unmod_description(description: String) -> String:
	return get_description(description)
