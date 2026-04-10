# multiply_chance_if_no_opposing_npc_state_model.gd

class_name MultiplyChanceIfNoOpposingNpcStateModel extends StateModel

@export var chance_multiplier: float = 0.0

func change_chance_weight_state_sim(ctx: NPCAIContext, action_state: Dictionary) -> void:
	if ctx == null or ctx.api == null or action_state == null:
		return

	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		return

	var actor_group := int(ctx.api.get_group(actor_id))
	if actor_group < 0:
		return

	var opposing_group := int(ctx.api.get_opposing_group(actor_group))
	var player_id := int(ctx.api.get_player_id())
	var has_opposing_npc := false

	for cid in ctx.api.get_combatants_in_group(opposing_group, false):
		var target_id := int(cid)
		if target_id <= 0 or target_id == player_id:
			continue
		has_opposing_npc = true
		break

	if has_opposing_npc:
		return

	var chance_mult := float(action_state.get(Keys.CHANCE_MULT, 1.0))
	action_state[Keys.CHANCE_MULT] = chance_mult * float(chance_multiplier)
