#class_name GameRecord 
#extends Node
#
#var account: RunAccount
#var player_data: CombatantData
#var deck: CardPile
#var draftable_cards: CardPile
#var slain_enemies: Array[CombatantData]
#
#func set_player_data(_player_data: CombatantData):
	#player_data = _player_data
#
#func combatant_died(combatant_data: CombatantData):
	#if combatant_data.team == 2:
		#slain_enemies.push_back(combatant_data)
