class_name Player extends Friendly

#func do_turn() -> void:
	#Events.player_turn_started.emit()
	#combatant_data.set_armor(0)
	#combatant_data.reset_mana()
