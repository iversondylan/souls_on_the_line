# SelectionPrompt.gd

class_name SelectionPrompt extends Node2D

@onready var label: RichTextLabel = $Control/PanelContainer/MarginContainer/VBoxContainer/DialogueText
@onready var button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/Button

func _ready() -> void:
	visible = false
	button.pressed.connect(_on_button_pressed)

func show_prompt(text: String) -> void:
	label.text = text
	visible = true

func hide_prompt() -> void:
	visible = false

func _on_button_pressed() -> void:
	Events.selection_prompt_button_pressed.emit()
