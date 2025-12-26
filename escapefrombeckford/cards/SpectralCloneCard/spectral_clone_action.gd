extends CardAction

func activate(ctx: CardActionContext) -> bool:
	var insert_at := ctx.resolved_target.insert_index
	if insert_at < 0:
		return false
	var clone_scene: PackedScene = load("res://scenes/turn_takers/summoned_ally.tscn")
	var clone := clone_scene.instantiate()
	ctx.battle_scene.add_combatant(clone, 0, insert_at)
	
	ctx.summoned_fighters.append(clone)
	ctx.affected_fighters.append(clone)
	# copy stats, bind card, etc.
	return true

func description_arity() -> int:
	return 1

func get_description_values(_ctx: CardActionContext) -> Array:
	return [duration]

func get_description(description: String, _target_fighter: Fighter = null) -> String:
	#var n_damage = player.modifier_system.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	return description# % n_damage

func get_unmod_description(description: String) -> String:
	return get_description(description)
