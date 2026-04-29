class_name RabbleRouseStatus extends Aura

const ID := &"rabble_rouse"

func get_id() -> StringName:
	return ID

func affects_target(state: BattleState, source_id: int, target_id: int) -> bool:
	if source_id == target_id:
		return false
	return super.affects_target(state, source_id, target_id)

func get_tooltip(stacks: int = 0) -> String:
	return "Rabble Rouse: until your next turn, allies gain on death: deal %s damage to all enemies." % stacks
