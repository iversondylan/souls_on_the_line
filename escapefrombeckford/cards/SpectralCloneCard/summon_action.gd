extends CardAction

const SUMMONED_ALLY_SCN := preload("res://scenes/turn_takers/summoned_ally.tscn")

@export var summon_data: CombatantData

func activate(ctx: CardActionContext) -> bool:
	var insert_at := ctx.resolved_target.insert_index
	#var combatant_scn: PackedScene = load("res://scenes/turn_takers/summoned_ally.tscn")
	var summoned_ally: SummonedAlly = SUMMONED_ALLY_SCN.instantiate()
	ctx.battle_scene.add_combatant(summoned_ally, 0, insert_at)
	var combatant_data: CombatantData = summon_data.duplicate()
	
	combatant_data.max_mana_red = ctx.player.combatant_data.max_mana_red
	combatant_data.max_mana_green = ctx.player.combatant_data.max_mana_green
	combatant_data.max_mana_blue = ctx.player.combatant_data.max_mana_blue
	
	summoned_ally.combatant_data = combatant_data
	summoned_ally.reset()
	
	
	
	ctx.summoned_fighters.append(summoned_ally)
	ctx.affected_fighters.append(summoned_ally)
	# copy stats, bind card, etc.
	return true

func description_arity() -> int:
	return 0

func get_description_values(_ctx: CardActionContext) -> Array:
	return []
