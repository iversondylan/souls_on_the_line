extends RefCounted

var card_data: CardData

func activate(targets: Array[Node]) -> bool:
	var action_processed: bool = false
	if GameState.player.can_play_card(card_data):
		GameState.player.spend_mana(card_data)
		var combatant_scn: PackedScene = load("res://scenes/turn_takers/summoned_ally.tscn")
		var clone: SummonedAlly = combatant_scn.instantiate()
		GameState.battle_scene.add_combatant(clone, 0, targets.size()-1)# get_between_allies_rank(targets)
		clone.combatant_data = CombatantLibrary.combatant_library[2].duplicate()
		
		clone.bind_card(card_data)
		clone.spawned()
		SFXPlayer.play(card_data.sound)
		action_processed = true
		
	return action_processed
