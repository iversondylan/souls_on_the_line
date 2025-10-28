class_name Player extends Fighter

func _ready() -> void:
	Events.hand_drawn.connect(_on_hand_drawn)
	Events.hand_discarded.connect(_on_hand_discarded)
	combatant.target_area_area_entered.connect(_on_target_area_area_entered)
	combatant.target_area_area_exited.connect(_on_target_area_area_exited)
	Events.aura_changed.connect(_on_aura_changed)
	Events.aura_removed.connect(_on_aura_removed)
	area_left.monitorable = true
	area_left.monitoring = true
	area_left.fighter = self
	target_area.combatant = self
	combatant.fighter = self

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
