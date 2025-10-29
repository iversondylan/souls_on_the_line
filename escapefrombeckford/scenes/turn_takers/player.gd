class_name Player extends Fighter

func do_turn() -> void:
	Events.player_turn_started.emit()
	combatant_data.set_armor(0)
	combatant_data.reset_mana()

func can_play_card(card_data: CardData) -> bool:
	return combatant_data.can_play_card(card_data)

func spend_mana(card_data: CardData) -> bool:
	if combatant_data.spend_mana(card_data):
		return true
	else:
		return false

func reset():
	combatant_data.health = combatant_data.max_health
	combatant_data.mana_red = combatant_data.max_mana_red
	combatant_data.mana_green = combatant_data.max_mana_green
	combatant_data.mana_blue = combatant_data.max_mana_blue
	combatant_data.armor = combatant_data.starting_armor
	combatant_data.stats_changed()

func _on_hand_drawn() -> void:
	Events.end_turn_button_pressed.connect(_on_end_turn_button_pressed)

func _on_hand_discarded() -> void:
	turn_complete()

func _on_end_turn_button_pressed() -> void:
	Events.player_turn_completed.emit()
	Events.end_turn_button_pressed.disconnect(_on_end_turn_button_pressed)
