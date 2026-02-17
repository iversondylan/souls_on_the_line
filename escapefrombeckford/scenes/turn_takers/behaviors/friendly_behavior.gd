# friendly_behavior.gd

class_name FriendlyBehavior extends FighterBehavior

func _on_combatant_data_set(new_owner: Fighter) -> void:
	owner = new_owner
	if !owner.is_node_ready():
		await owner.ready
	owner.area_left.monitorable = true
	owner.area_left.monitoring = true
	owner.area_left.fighter = owner
