# small.gd

class_name SmallStatus extends Status

const ID := Keys.STATUS_SMALL


func get_id() -> StringName:
	return ID


func grants_received_cleave(_ctx: SimStatusContext) -> bool:
	return true


func get_tooltip(_intensity: int = 0, _duration: int = 0) -> String:
	return "Small: excess damage dealt here spills into the next combatant."
