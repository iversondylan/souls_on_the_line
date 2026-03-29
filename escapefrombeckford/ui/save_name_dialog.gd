class_name SaveNameDialog
extends Control

signal save_requested(slot_name: String)
signal canceled()

var _existing_entry_keys: PackedStringArray = []
var _allow_existing_match: bool = true
var _confirm_text: String = "Save"
var _overwrite_text: String = "Overwrite Save"
var _duplicate_warning_text: String = "A save with this name already exists. Saving will overwrite it."
var _key_builder: Callable = Callable()

@onready var title_label: Label = %Title
@onready var line_edit: LineEdit = %NameEdit
@onready var warning_label: Label = %OverwriteWarning
@onready var save_button: Button = %SaveButton
@onready var cancel_button: Button = %CancelButton


func _ready() -> void:
	visible = false
	line_edit.text_changed.connect(_on_text_changed)
	line_edit.text_submitted.connect(_on_text_submitted)
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)


func open(
	existing_entry_keys: PackedStringArray,
	initial_name: String = "",
	title_text: String = "Save Debug Run",
	confirm_text: String = "Save",
	overwrite_text: String = "Overwrite Save",
	duplicate_warning_text: String = "A save with this name already exists. Saving will overwrite it.",
	allow_existing_match: bool = true,
	key_builder: Callable = Callable()
) -> void:
	_existing_entry_keys = existing_entry_keys
	_allow_existing_match = allow_existing_match
	_confirm_text = confirm_text
	_overwrite_text = overwrite_text
	_duplicate_warning_text = duplicate_warning_text
	_key_builder = key_builder
	title_label.text = title_text
	line_edit.text = initial_name
	warning_label.text = duplicate_warning_text
	visible = true
	_update_state()
	line_edit.call_deferred("grab_focus")
	line_edit.call_deferred("select_all")


func hide_dialog() -> void:
	visible = false


func _update_state() -> void:
	var trimmed := line_edit.text.strip_edges()
	var has_text := !trimmed.is_empty()
	var entry_key := _build_key(trimmed)
	var matches_existing := has_text and _existing_entry_keys.has(entry_key)

	if !has_text:
		save_button.disabled = true
		save_button.text = _confirm_text
	elif matches_existing and !_allow_existing_match:
		save_button.disabled = true
		save_button.text = _confirm_text
	else:
		save_button.disabled = false
		save_button.text = _overwrite_text if matches_existing else _confirm_text
	warning_label.visible = matches_existing


func _on_text_changed(_new_text: String) -> void:
	_update_state()


func _on_text_submitted(_text: String) -> void:
	if !save_button.disabled:
		_on_save_pressed()


func _on_save_pressed() -> void:
	var trimmed := line_edit.text.strip_edges()
	if trimmed.is_empty():
		return
	visible = false
	save_requested.emit(trimmed)


func _on_cancel_pressed() -> void:
	visible = false
	canceled.emit()


func _build_key(value: String) -> String:
	if _key_builder.is_valid():
		return String(_key_builder.call(value))
	return value.strip_edges().to_lower()
