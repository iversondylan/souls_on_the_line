# heal_context.gd

class_name HealContext extends RefCounted

enum Phase {
	PRE_MODIFIERS,
	POST_MODIFIERS,
	APPLIED
}

var source: Fighter = null
var source_id: int = 0

var target: Fighter = null
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

func _init(_source: Fighter, _target: Fighter, _flat: int, _of_total: float, _of_missing: float) -> void:
	source = _source
	target = _target
	flat_amount = _flat
	of_total = _of_total
	of_missing = _of_missing
