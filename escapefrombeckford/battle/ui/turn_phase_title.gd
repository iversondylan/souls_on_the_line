class_name TurnPhaseTitle extends Node2D

signal preview_button_pressed()

@onready var preview_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/PreviewTurnFlow
@onready var turn_text: RichTextLabel = $Control/PanelContainer/MarginContainer/VBoxContainer/TurnText

func enable_button(enabled: bool) -> void:
	preview_button.disabled = !enabled

func _on_preview_turn_flow_pressed() -> void:
	preview_button_pressed.emit()

func update_turn_text(text: String) -> void:
	turn_text.text = text
		
