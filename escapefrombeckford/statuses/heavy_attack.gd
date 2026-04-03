# heavy_attack.gd

class_name HeavyAttackStatus extends Status

const ID := Keys.STATUS_HEAVY_ATTACK


func get_id() -> StringName:
	return ID


func grants_attack_spillthrough(_ctx: SimStatusContext) -> bool:
	return true


func get_tooltip(_intensity: int = 0, _duration: int = 0) -> String:
	return "Heavy Attack: excess damage dealt by this unit is applied to the next target."
