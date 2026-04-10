class_name BurningAmbitionStatus extends Aura

const ID := &"burning_ambition"

func get_id() -> StringName:
	return ID

func affects_target(state: BattleState, source_id: int, target_id: int) -> bool:
	if source_id == target_id:
		return false
	return super.affects_target(state, source_id, target_id)

func get_tooltip(intensity: int = 0, _duration: int = 0) -> String:
	return "Burning Ambition: other allies gain On Death: deal %s damage to all enemies." % intensity
