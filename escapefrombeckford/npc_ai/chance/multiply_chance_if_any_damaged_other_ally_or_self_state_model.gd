class_name MultiplyChanceIfAnyDamagedOtherAllyOrSelfStateModel
extends StateModel

@export var available_multiplier: float = 1.0
@export var unavailable_multiplier: float = 0.0

func change_chance_weight_state_sim(ctx: NPCAIContext, action_state: Dictionary) -> void:
	if ctx == null or action_state == null:
		return

	var target_id := PseudoRandomDamagedOtherAllyElseSelfStatusTargetModel.find_target_id(ctx)
	var chance_mult := float(action_state.get(Keys.CHANCE_MULT, 1.0))
	var multiplier := available_multiplier if target_id > 0 else unavailable_multiplier
	action_state[Keys.CHANCE_MULT] = chance_mult * float(multiplier)
