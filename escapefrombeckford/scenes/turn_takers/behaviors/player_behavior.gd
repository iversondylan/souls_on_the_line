# player_behavior.gd

class_name PlayerBehavior extends FighterBehavior

func _ready() -> void:
	var player: Player = get_parent()
	if !player.is_node_ready():
		await player.ready
	Events.hand_drawn.connect(_on_hand_drawn)
	Events.hand_discarded.connect(_on_hand_discarded)
	Events.arcana_activated.connect(_on_arcana_activated)

func _on_do_turn() -> void:
	Events.request_activate_arcana_by_type.emit(Arcanum.Type.START_OF_TURN)

func _on_hand_drawn() -> void:
	Events.end_turn_button_pressed.connect(_on_end_turn_button_pressed)

func _on_hand_discarded() -> void:
	var fighter: Fighter = get_parent()
	fighter.resolve_action()

func _on_end_turn_button_pressed() -> void:
	#print("player_behavior.gd _on_end_turn_button_pressed()")
	Events.request_activate_arcana_by_type.emit(Arcanum.Type.END_OF_TURN)
	Events.end_turn_button_pressed.disconnect(_on_end_turn_button_pressed)

func _on_modifier_changed() -> void:
	Events.player_modifier_changed.emit()

func _on_arcana_activated(type: Arcanum.Type) -> void:
	match type:
		Arcanum.Type.START_OF_TURN:
			Events.request_draw_hand.emit()
		Arcanum.Type.END_OF_TURN:
			#print("player_behavior.gd _on_arcana_activated(END_OF_TURN)")
			Events.player_turn_completed.emit()

func _on_battle_reset() -> void:
	var fighter: Fighter = get_parent()
	fighter.combatant_data.reset_armor()
	fighter.combatant_data.reset_mana()
