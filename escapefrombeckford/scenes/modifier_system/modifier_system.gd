class_name ModifierSystem extends Node

signal modifier_changed()

func _ready() -> void:
	for modifier: Modifier in get_children():
		modifier.modifier_changed.connect(_modifier_changed)

func has_modifier(type: Modifier.Type) -> bool:
	for modifier: Modifier in get_children():
		if modifier.type == type:
			return true
	return false
	
func get_modifier(type: Modifier.Type) -> Modifier:
	for modifier: Modifier in get_children():
		if modifier.type == type:
			return modifier
	return null

func get_modified_value(base: int, type: Modifier.Type) -> int:
	var modifier := get_modifier(type)
	
	if !modifier:
		return base
	
	return modifier.get_modified_value(base)

func _modifier_changed() -> void:
	modifier_changed.emit()
	
