# aura.gd
class_name Aura extends Status

enum AuraType {ALLIES, ENEMIES}
@export var aura_type: AuraType
@export var projected_statuses: Array[Status] = []

func affects_others() -> bool:
	return true

func get_projected_statuses() -> Array[Status]:
	var out: Array[Status] = []
	for projected: Status in projected_statuses:
		if projected != null:
			out.append(projected)
	return out

func affects_target(state: BattleState, source_id: int, target_id: int) -> bool:
	if state == null or source_id <= 0 or target_id <= 0:
		return false

	var source := state.get_unit(source_id)
	var target := state.get_unit(target_id)
	if source == null or target == null:
		return false
	if int(target.mortality) == int(CombatantState.Mortality.HOLLOW):
		return false

	match int(aura_type):
		AuraType.ALLIES:
			return int(source.team) == int(target.team)
		AuraType.ENEMIES:
			return int(source.team) != int(target.team)
		_:
			return false
