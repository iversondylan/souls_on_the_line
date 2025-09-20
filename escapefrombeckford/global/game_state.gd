#OBSOLETE

#extends Node
#
#var combatants: Array[Fighter] = []
#var battle_scene: BattleScene
#var battle_controller: BattleController
#var hand: Hand
##var target: Combatant
#var player: Player# : set = _set_player
#var turn_number: int = 0
##var combatant_library: CombatantLibrary
##var icon_library: IconLibrary
#var between_allies_rank: int
#
##func _set_player(_player: Combatant) -> void:
	##player = _player
	##Events.combatant_data_changed.connect(_player.combatant_data.combatant_data_changed)
