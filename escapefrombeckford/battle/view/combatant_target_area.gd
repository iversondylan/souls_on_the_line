# combatant_target_area.gd

class_name CombatantTargetArea extends Area2D

#var combatant: Fighter
var combatant_view: CombatantView
var cid: int = -1

func _ready() -> void:
	if get_parent() is CombatantView:
		combatant_view = get_parent() as CombatantView
