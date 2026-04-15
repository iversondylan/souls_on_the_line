# multiply_chance_if_in_front_state_model.gd

class_name MultiplyChanceIfInFrontStateModel
extends StateModel

@export var chance_multiplier: float = 0.0

func change_chance_weight_state_sim(ctx: NPCAIContext, action_state: Dictionary) -> void:
	if ctx == null or ctx.api == null or action_state == null:
		return

	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		return

	if int(ctx.api.get_rank_in_group(actor_id)) != 0:
		return

	var chance_mult := float(action_state.get(Keys.CHANCE_MULT, 1.0))
	action_state[Keys.CHANCE_MULT] = chance_mult * float(chance_multiplier)
