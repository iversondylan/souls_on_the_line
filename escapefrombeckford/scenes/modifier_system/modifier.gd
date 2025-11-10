class_name Modifier extends Node

signal modifier_changed

enum Type {DMG_DEALT, DMG_TAKEN, CARD_COST, SHOP_COST, NO_MODIFIER}

@export var type: Type

func get_value(source: String) -> ModifierValue:
	for value: ModifierValue in get_children():
		if value.source == source:
			return value
	return null

func add_new_value(value: ModifierValue) -> void:
	var modifier_value := get_value(value.source)
	if !modifier_value:
		add_child(value)
	else:
		modifier_value.flat_value = value.flat_value
		modifier_value.mult_value = value.mult_value
	modifier_changed.emit()

func remove_value(source: String) -> void:
	for value: ModifierValue in get_children():
		if value.source == source:
			value.queue_free()
	modifier_changed.emit()

func clear_values() -> void:
	for value: ModifierValue in get_children():
		value.queue_free()
	modifier_changed.emit()

func get_modified_value(base: int) -> int:
	var flat_result: int = base
	var mult_result: float = 1.0
	# Apply flat modifiers first
	for value: ModifierValue in get_children():
		if value.mod_type == ModifierValue.Type.FLAT:
			flat_result += value.flat_value
	# Apply % modifiers next
	for value: ModifierValue in get_children():
		if value.mod_type == ModifierValue.Type.MULT:
			mult_result += value.mult_value
	
	return floori(flat_result * mult_result)
