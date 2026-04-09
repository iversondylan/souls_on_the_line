# multiplied_chance_on_particular_turns_state_model.gd
class_name MultipliedChanceOnParticularTurnsStateModel
extends StateModel

@export var chance_multiplier: float = 1.0
@export var turn_numbers: PackedInt32Array = PackedInt32Array()


func change_chance_weight_state_sim(ctx: NPCAIContext, action_state: Dictionary) -> void:
	if ctx == null or action_state == null or ctx.state == null:
		return

	var subjective_turn_number := int(ctx.state.get(Keys.ACTIONS_PERFORMED_COUNT, 0)) + 1
	for turn_number in turn_numbers:
		if int(turn_number) != subjective_turn_number:
			continue

		var chance_mult := float(action_state.get(Keys.CHANCE_MULT, 1.0))
		action_state[Keys.CHANCE_MULT] = chance_mult * float(chance_multiplier)
		return
