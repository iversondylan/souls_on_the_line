class_name ConfirmationPrompt
extends Control

signal confirmed()
signal canceled()

@onready var dialogue_label: RichTextLabel = %DialogueText
@onready var cancel_button: Button = %CancelButton
@onready var confirm_button: Button = %ConfirmButton


func _ready() -> void:
	visible = false
	cancel_button.pressed.connect(_on_cancel_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)


func open(dialogue_text: String, confirm_text: String = "Confirm", cancel_text: String = "Cancel") -> void:
	dialogue_label.text = dialogue_text
	confirm_button.text = confirm_text
	cancel_button.text = cancel_text
	_set_buttons_enabled(true)
	visible = true
	call_deferred("_focus_confirm_button")


func hide_prompt() -> void:
	visible = false
	_set_buttons_enabled(true)


func _unhandled_input(event: InputEvent) -> void:
	if !visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()


func _focus_confirm_button() -> void:
	if visible:
		confirm_button.grab_focus()


func _set_buttons_enabled(enabled: bool) -> void:
	cancel_button.disabled = !enabled
	confirm_button.disabled = !enabled


func _on_cancel_pressed() -> void:
	hide_prompt()
	canceled.emit()


func _on_confirm_pressed() -> void:
	hide_prompt()
	confirmed.emit()
