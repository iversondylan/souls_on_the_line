# heal_context.gd

class_name HealContext extends RefCounted

enum Phase {
	PRE_MODIFIERS,
	POST_MODIFIERS,
	APPLIED
}

var source_id: int = 0

var target_id: int = 0

# Inputs
var flat_amount: int = 0
var of_total: float = 0.0
var of_missing: float = 0.0

# Output/result
var healed_amount: int = 0

# Optional tags / logging
var tags: Array[StringName] = []
var phase: Phase = Phase.PRE_MODIFIERS

func _init(_source_id: int, _target_id: int, _flat: int, _of_total: float, _of_missing: float) -> void:
	source_id = _source_id
	target_id = _target_id
	flat_amount = _flat
	of_total = _of_total
	of_missing = _of_missing
