# heavy_attack.gd

class_name HeavyAttackStatus extends Status

const ID := Keys.STATUS_HEAVY_ATTACK


func get_id() -> StringName:
	return ID


func grants_attack_spillthrough(_ctx: SimStatusContext) -> bool:
	return true


func get_tooltip(_intensity: int = 0, _duration: int = 0) -> String:
	return "Heavy Attack: overkill damage spills through to the next target in lane order."
