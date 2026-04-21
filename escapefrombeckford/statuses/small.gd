# small.gd

class_name SmallStatus extends Status

const ID := &"small"


func get_id() -> StringName:
	return ID


func grants_received_cleave(_ctx: SimStatusContext) -> bool:
	return true


func get_tooltip(_stacks: int = 0) -> String:
	return "Small: excess damage continues to the next target."
