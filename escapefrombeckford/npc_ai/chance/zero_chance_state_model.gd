# zero_chance_state_model.gd
class_name ZeroChanceOnTurnNumbersStateModel
extends StateModel

@export var turn_numbers: PackedInt32Array = PackedInt32Array()

func change_chance_weight_state_sim(ctx: NPCAIContext, action_state: Dictionary) -> void:
	if ctx == null or action_state == null or ctx.state == null:
		return

	var subjective_turn_number := int(ctx.state.get(Keys.ACTIONS_PERFORMED_COUNT, 0)) + 1
	for turn_number in turn_numbers:
		if int(turn_number) != subjective_turn_number:
			continue
		action_state[Keys.CHANCE_MULT] = 0.0
		return
