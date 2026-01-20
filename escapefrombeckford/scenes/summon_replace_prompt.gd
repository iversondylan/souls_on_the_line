extends Node2D

@onready var label: RichTextLabel = $Control/PanelContainer/MarginContainer/VBoxContainer/DialogueText
@onready var cancel: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/CancelButton


func _ready() -> void:
	visible = false
	cancel.pressed.connect(_on_cancel_pressed)

func show_prompt(text: String) -> void:
	label.text = text
	visible = true

func hide_prompt() -> void:
	visible = false

func _on_cancel_pressed() -> void:
	Events.summon_replace_cancel_requested.emit()
