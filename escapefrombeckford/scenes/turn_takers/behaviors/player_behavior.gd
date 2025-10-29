class_name PlayerBehavior extends Node

func _ready() -> void:
	var player: Player = get_parent()
	if !player.is_node_ready():
		await player.ready
	Events.hand_drawn.connect(_on_hand_drawn)
	Events.hand_discarded.connect(_on_hand_discarded)

func _on_do_turn() -> void:
	Events.player_turn_started.emit()

func _on_hand_drawn() -> void:
	Events.end_turn_button_pressed.connect(_on_end_turn_button_pressed)

func _on_hand_discarded() -> void:
	var fighter: Fighter = get_parent()
	fighter.turn_complete()

func _on_end_turn_button_pressed() -> void:
	Events.player_turn_completed.emit()
	Events.end_turn_button_pressed.disconnect(_on_end_turn_button_pressed)
