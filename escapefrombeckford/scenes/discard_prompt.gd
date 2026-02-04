extends Node2D

@onready var prompt_text: RichTextLabel = $Control/PanelContainer/MarginContainer/VBoxContainer/PromptText
@onready var ok_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/OKButton

func _ready() -> void:
	visible = false
	ok_button.pressed.connect(_on_ok_button_pressed)

func show_prompt(text: String) -> void:
	prompt_text.text = text
	visible = true

func hide_prompt() -> void:
	visible = false

func _on_ok_button_pressed() -> void:
	pass # Replace with function body.
