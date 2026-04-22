class_name MultiplyChanceIfPartySizeAtOrAboveChanceStateModel
extends StateModel

@export var threshold: int = 4
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

	var party_size := ctx.api.get_combatants_in_group(group_index, false).size()
	if party_size < int(threshold):
		return

	var chance_mult := float(action_state.get(Keys.CHANCE_MULT, 1.0))
	action_state[Keys.CHANCE_MULT] = chance_mult * float(chance_multiplier)
