class_name TurnPhaseTitle extends Node2D

signal preview_button_pressed()

@onready var preview_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/PreviewTurnFlow
@onready var turn_text: RichTextLabel = $Control/PanelContainer/MarginContainer/VBoxContainer/TurnText

var player_took_turn: bool = false

func enable_button(enabled: bool) -> void:
	preview_button.disabled = !enabled

func _on_preview_turn_flow_pressed() -> void:
	preview_button_pressed.emit()

func update_turn_text(fighter: Fighter) -> void:
	if fighter is Player:
		player_took_turn = true
		turn_text.text = "Player Turn"
	elif fighter.get_parent() is BattleGroupFriendly:
		if player_took_turn:
			turn_text.text = "Backline Turn"
		else:
			turn_text.text = "Frontline Turn"
	elif fighter.get_parent() is BattleGroupEnemy:
		player_took_turn = false
		turn_text.text = "Enemy Turn"
		
