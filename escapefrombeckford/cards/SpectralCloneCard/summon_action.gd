extends CardAction

const SUMMONED_ALLY_SCN := preload("res://scenes/turn_takers/summoned_ally.tscn")

@export var summon_data: CombatantData
@export var sound: AudioStream

func activate(ctx: CardActionContext) -> bool:
	var insert_at := ctx.resolved_target.insert_index
	#var combatant_scn: PackedScene = load("res://scenes/turn_takers/summoned_ally.tscn")
	var summoned_ally: SummonedAlly = SUMMONED_ALLY_SCN.instantiate()
	ctx.battle_scene.add_combatant(summoned_ally, 0, insert_at)
	var combatant_data: CombatantData = summon_data.duplicate()
	combatant_data.init()
	combatant_data.max_mana_red = ctx.player.combatant_data.max_mana_red
	combatant_data.max_mana_green = ctx.player.combatant_data.max_mana_green
	combatant_data.max_mana_blue = ctx.player.combatant_data.max_mana_blue
	SFXPlayer.play(sound)
	summoned_ally.combatant_data = combatant_data
	for child in summoned_ally.get_children():
			if child is NPCAIBehavior:
				child.plan_next_intent()
				child.refresh_intent_display_only()
	
	var summon_behavior := summoned_ally.get_node_or_null("SummonedAllyBehavior")
	if summon_behavior:
		summon_behavior.bind_card(ctx.card_data)
	
	ctx.summoned_fighters.append(summoned_ally)
	ctx.affected_fighters.append(summoned_ally)
	
	return true

func description_arity() -> int:
	return 0

func get_description_values(_ctx: CardActionContext) -> Array:
	return []
