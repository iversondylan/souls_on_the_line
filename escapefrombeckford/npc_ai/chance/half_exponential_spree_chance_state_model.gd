# half_exponential_spree_chance_state_model.gd
class_name HalfExponentialSpreeChanceStateModel
extends StateModel

func change_chance_weight_state_sim(_ctx: NPCAIContext, action_state: Dictionary) -> void:
	if action_state == null:
		return

	var spree := maxi(int(action_state.get(Keys.SPREE, 0)), 0)
	var chance_mult := float(action_state.get(Keys.CHANCE_MULT, 1.0))
	action_state[Keys.CHANCE_MULT] = chance_mult * pow(0.5, float(spree))
