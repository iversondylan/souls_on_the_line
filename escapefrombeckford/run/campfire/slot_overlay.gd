class_name CampfireSlotOverlay extends ColorRect

signal slot_selected(slot_index: int, slot_uid: String)
signal canceled()

const MENU_CARD := preload("uid://d4g7iin5x7648")

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

		var button := Button.new()
		button.custom_minimum_size = Vector2(275, 370)
		button.pressed.connect(_on_slot_pressed.bind(slot_index, String(card_data.uid)))
		slots.add_child(button)

		var menu_card := MENU_CARD.instantiate() as MenuCard
		button.add_child(menu_card)
		menu_card.set_anchors_preset(Control.PRESET_FULL_RECT)
		menu_card.offset_left = 0.0
		menu_card.offset_top = 0.0
		menu_card.offset_right = 0.0
		menu_card.offset_bottom = 0.0
		menu_card.set_card_data(card_data)
		_set_mouse_passthrough(menu_card)

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


func _set_mouse_passthrough(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_passthrough(child)
