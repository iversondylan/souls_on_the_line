# heal_context.gd
class_name HealthContext
extends RefCounted

#enum Phase {
	#PRE_MODIFIERS,
	#POST_MODIFIERS,
	#APPLIED
#}
var api: SimBattleAPI
var source: Fighter = null
var target: Fighter = null

var flat_amount: int = 0
var of_total: float = 0.0
var of_missing: float = 0.0

# Results (filled in when applied)
var restored_amount: int = 0

# Optional flags / tags (handy later)
var tags: Array[StringName] = []

func _init(_source: Fighter, _target: Fighter, _flat_amount: int, _of_total: float, _of_missing: float) -> void:
	source = _source
	target = _target
	flat_amount = _flat_amount
	of_total = _of_total
	of_missing = _of_missing
