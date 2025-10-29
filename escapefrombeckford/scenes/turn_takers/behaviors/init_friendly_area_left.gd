class_name InitFriendlyAreaLeft extends Node

func _ready() -> void:
	var fighter: Fighter = get_parent()
	if !fighter.is_node_ready():
		await fighter.ready
	fighter.area_left.monitorable = true
	fighter.area_left.monitoring = true
	fighter.area_left.fighter = fighter
