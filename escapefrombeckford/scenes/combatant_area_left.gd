# combatant_area_left.gd
class_name CombatantAreaLeft extends Area2D

#var fighter: Fighter

var combatant_view: CombatantView
var cid: int = -1
func _ready() -> void:
	if get_parent() is CombatantView:
		combatant_view = get_parent() as CombatantView
