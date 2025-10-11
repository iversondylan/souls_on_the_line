class_name Campfire extends Control

@export var player_data: CombatantData

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _on_rest_button_pressed() -> void:
	player_data.heal(ceili(player_data.max_health * 0.3))
	animation_player.play("fade_out")

func _on_fade_out_finished() -> void:
	Events.campfire_exited.emit()
