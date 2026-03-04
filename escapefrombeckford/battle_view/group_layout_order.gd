# group_layout_context.gd

class_name GroupLayoutOrder extends RefCounted

var group_index: int
var order: PackedInt32Array
var animate_to_position: bool = false
var new_combatant: CombatantView = null
