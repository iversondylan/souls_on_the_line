class_name RunSavePicker
extends Control

signal entry_selected(entry_key: String)
signal slot_selected(slot_key: String)
signal canceled()

@onready var title_label: Label = %Title
@onready var empty_label: Label = %EmptyLabel
@onready var slots_container: VBoxContainer = %Slots
@onready var cancel_button: Button = %CancelButton


func _ready() -> void:
	visible = false
	cancel_button.pressed.connect(_on_cancel_pressed)


func show_slots(title_text: String, slots: Array[DebugRunSaveInfo]) -> void:
	var entries: Array[Dictionary] = []
	for info in slots:
		entries.append({
			"key": info.slot_key,
			"text": _format_slot_text(info),
		})
	_show_entries(title_text, entries, "No debug saves found.")


func show_profiles(title_text: String, profiles: Array[UserProfileInfo]) -> void:
	var entries: Array[Dictionary] = []
	for info in profiles:
		entries.append({
			"key": String(info.profile_key),
			"text": String(info.display_name),
		})
	_show_entries(title_text, entries, "No profiles found.")


func hide_picker() -> void:
	visible = false


func _format_slot_text(info: DebugRunSaveInfo) -> String:
	var parts: PackedStringArray = [info.display_name]
	if !info.player_profile_id.is_empty():
		parts.append("Profile: %s" % info.player_profile_id)
	parts.append("Gold: %d" % int(info.gold))
	return " | ".join(parts)


func _show_entries(title_text: String, entries: Array[Dictionary], empty_text: String) -> void:
	title_label.text = title_text
	empty_label.text = empty_text
	_clear_slots()
	empty_label.visible = entries.is_empty()

	for entry in entries:
		var entry_key := String(entry.get("key", ""))
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.theme = cancel_button.theme
		button.text = String(entry.get("text", entry_key))
		button.pressed.connect(func() -> void:
			visible = false
			entry_selected.emit(entry_key)
			slot_selected.emit(entry_key)
		)
		slots_container.add_child(button)

	visible = true


func _clear_slots() -> void:
	for child in slots_container.get_children():
		child.queue_free()


func _on_cancel_pressed() -> void:
	visible = false
	canceled.emit()
