class_name LivingRegretsStatus extends Aura

const ID := &"living_regrets"


func get_id() -> StringName:
	return ID


func affects_target(state: BattleState, source_id: int, target_id: int) -> bool:
	if source_id == target_id:
		return false
	return super.affects_target(state, source_id, target_id)


func get_tooltip(_stacks: int = 0) -> String:
	return "Living Regrets: other allies gain On Death: summon a Small, Fleeting 1/1 Regretful Shade."
