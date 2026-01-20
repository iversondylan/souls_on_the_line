class_name BattleUI extends Node2D

@onready var end_turn: Button = $EndTurn

func set_end_turn_enabled(enabled: bool) -> void:
	if enabled:
		end_turn.disabled = false
	else:
		end_turn.disabled = true
