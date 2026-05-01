# turn_number_playable_model.gd

class_name TurnNumberPlayableModel extends PlayableModel

@export var turn_numbers: PackedInt32Array = PackedInt32Array()

func is_playable_sim(ctx: NPCAIContext) -> bool:
	if ctx == null or ctx.state == null:
		return false

	var subjective_turn_number := int(ctx.state.get(Keys.ACTIONS_PERFORMED_COUNT, 0)) + 1
	for turn_number in turn_numbers:
		if int(turn_number) == subjective_turn_number:
			return true
	return false
