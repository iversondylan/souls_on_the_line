class_name Campfire extends Control

@export var player_data: PlayerData
var run_state: RunState

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _on_rest_button_pressed() -> void:
	if player_data == null or run_state == null or run_state.player_run_state == null:
		return
	var ctx := HealContext.new(1, 1, 0, 0.3, 0)
	run_state.player_run_state.heal(int(player_data.max_health), ctx)
	animation_player.play("fade_out")

func _on_fade_out_finished() -> void:
	Events.campfire_exited.emit()
