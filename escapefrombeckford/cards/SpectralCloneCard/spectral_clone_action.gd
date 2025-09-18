extends RefCounted

var card_data: CardData

func activate(targets: Array[Node], player: Player) -> bool:
	
	if !player.can_play_card(card_data):
		return false
	
	GameState.player.spend_mana(card_data)
	var combatant_scn: PackedScene = load("res://scenes/turn_takers/summoned_ally.tscn")
	var clone: SummonedAlly = combatant_scn.instantiate()
	GameState.battle_scene.add_combatant(clone, 0, targets.size()-1)
	clone.combatant_data = load("res://fighters/BasicClone/basic_clone_data.tres").duplicate() #CombatantLibrary.combatant_library[2].duplicate()
	
	clone.bind_card(card_data)
	clone.spawned()
	SFXPlayer.play(card_data.sound)
		
	return true
