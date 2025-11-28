class_name PlayerBehavior extends FighterBehavior



func _ready() -> void:
	var player: Player = get_parent()
	if !player.is_node_ready():
		await player.ready
	Events.hand_drawn.connect(_on_hand_drawn)
	Events.hand_discarded.connect(_on_hand_discarded)

func _on_do_turn() -> void:
	Events.request_draw_hand.emit()

func _on_hand_drawn() -> void:
	Events.end_turn_button_pressed.connect(_on_end_turn_button_pressed)

func _on_hand_discarded() -> void:
	var fighter: Fighter = get_parent()
	fighter.turn_complete()

func _on_end_turn_button_pressed() -> void:
	Events.request_activate_arcana_by_type.emit(Arcanum.Type.END_OF_TURN)
	#Events.player_turn_completed.emit() #replace with arcana call. Put player_turn_complete.emit() in battle.gd
	Events.end_turn_button_pressed.disconnect(_on_end_turn_button_pressed)

func _on_modifier_changed() -> void:
	print("player_behavior.gd _on_modifier_changed()")
	Events.player_modifier_changed.emit()

func _on_arcana_activated(type: Arcanum.Type) -> void:
	match type:
		Arcanum.Type.START_OF_TURN:
			Events.request_draw_hand.emit()
		Arcanum.Type.END_OF_TURN:
			Events.player_turn_completed.emit()
