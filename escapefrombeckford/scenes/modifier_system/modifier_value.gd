class_name ModifierValue extends Node

enum Type {MULT, FLAT}

@export var mod_type: Type
@export var mult_value: float
@export var flat_value: int
@export var source: String

static func create_new_modifier(new_source: String, new_type: Type) -> ModifierValue:
	var new_modifier_value := new()
	new_modifier_value.source = new_source
	new_modifier_value.mod_type = new_type
	return new_modifier_value
