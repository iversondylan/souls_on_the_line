# selection_prompt.gd

class_name SelectionPrompt extends Node2D

@onready var label: RichTextLabel = $Control/PanelContainer/MarginContainer/VBoxContainer/DialogueText
@onready var button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/Button

func _ready() -> void:
	visible = false
	button.pressed.connect(_on_button_pressed)

func show_prompt(dialogue_text: String, button_text: String) -> void:
	label.text = dialogue_text
	button.text = button_text
	visible = true

func hide_prompt() -> void:
	visible = false


func set_button_enabled(on: bool) -> void:
	button.disabled = !on

func _on_button_pressed() -> void:
	#print("selection_prompt.gd _on_button_pressed()")
	Events.selection_prompt_button_pressed.emit()
