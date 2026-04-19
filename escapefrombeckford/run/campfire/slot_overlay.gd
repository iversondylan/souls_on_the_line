class_name CampfireSlotOverlay extends ColorRect

signal slot_selected(slot_index: int, slot_uid: String)
signal canceled()

const CARD_BUTTON := preload("res://ui/card_button.tscn")

@onready var slots: HBoxContainer = %Slots
@onready var cancel_button: Button = %CancelButton


func _ready() -> void:
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	_clear_slots()


func show_slots(recess: SoulRecessState) -> void:
	_clear_slots()
	if recess == null:
		visible = false
		return

	var visible_slots := maxi(int(recess.unlocked_slot_count), 0)
	for slot_index in range(visible_slots):
		var snapshot := recess.get_attuned_soul_snapshot_at(slot_index)
		var card_data := snapshot.instantiate_card() if snapshot != null else null
		if card_data == null:
			continue
		card_data.ensure_uid()

		var button := CARD_BUTTON.instantiate() as Button
		button.pressed.connect(_on_slot_pressed.bind(slot_index, String(card_data.uid)))
		button.set("card_data", card_data)
		button.set("caption_text", recess.get_attuned_soul_slot_label(slot_index))
		slots.add_child(button)

	visible = true


func hide_overlay() -> void:
	visible = false


func _clear_slots() -> void:
	if !is_node_ready():
		return
	for child in slots.get_children():
		child.queue_free()


func _on_slot_pressed(slot_index: int, slot_uid: String) -> void:
	slot_selected.emit(slot_index, slot_uid)


func _on_cancel_button_pressed() -> void:
	canceled.emit()
	hide_overlay()
