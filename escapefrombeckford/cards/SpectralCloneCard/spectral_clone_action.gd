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
	return 0

func get_description_values(_ctx: CardActionContext) -> Array:
	return []
