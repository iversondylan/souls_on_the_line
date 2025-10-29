class_name InitPlayer extends Node

func _ready() -> void:
	var player: Player = get_parent()
	if !player.is_node_ready():
		await player.ready
	Events.hand_drawn.connect(player._on_hand_drawn)
	Events.hand_discarded.connect(player._on_hand_discarded)
