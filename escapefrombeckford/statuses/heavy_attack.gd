# heavy_attack.gd

class_name HeavyAttackStatus extends Status

const ID := &"heavy_attack"


func get_id() -> StringName:
	return ID


func grants_attack_cleave(_ctx: SimStatusContext) -> bool:
	return true


func get_tooltip(_stacks: int = 0) -> String:
	return "Heavy Attack: excess damage chains through the next combatants."
