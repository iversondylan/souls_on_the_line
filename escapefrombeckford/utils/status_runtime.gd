# status_runtime.gd

#THIS SCRIPT IS DEAD WEIGHT AND SHOULD BE DELETED


class_name StatusRuntime extends RefCounted

static func apply_status_to_fighter(fighter: Fighter, status: Status) -> void:
	if !fighter or !status:
		return
	if !fighter.combatant or !fighter.combatant.status_grid:
		return

	# Always duplicate before inserting
	fighter.combatant.status_grid.add_status(status.duplicate())

static func remove_status_from_fighter(fighter: Fighter, status_id: String) -> void:
	if !fighter or status_id == "":
		return
	if !fighter.combatant or !fighter.combatant.status_grid:
		return

	fighter.combatant.status_grid.remove_status_by_id(status_id)
