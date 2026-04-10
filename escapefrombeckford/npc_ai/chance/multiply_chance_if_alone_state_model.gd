# multiply_chance_if_alone_state_model.gd
class_name MultiplyChanceIfAloneStateModel
extends StateModel

@export var chance_multiplier: float = 0.0

func change_chance_weight_state_sim(ctx: NPCAIContext, action_state: Dictionary) -> void:
	if ctx == null or ctx.api == null or action_state == null:
		return

	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		return

	var group_index := int(ctx.api.get_group(actor_id))
	if group_index < 0:
		return

	var other_living_allies := 0
	for cid in ctx.api.get_combatants_in_group(group_index, false):
		var ally_id := int(cid)
		if ally_id <= 0 or ally_id == actor_id:
			continue
		other_living_allies += 1
		break

	if other_living_allies > 0:
		return

	var chance_mult := float(action_state.get(Keys.CHANCE_MULT, 1.0))
	action_state[Keys.CHANCE_MULT] = chance_mult * float(chance_multiplier)
