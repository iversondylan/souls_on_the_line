# status_from_opp_turn_model.gd
class_name StatusFromOppTurnModel
extends "res://npc_ai/intent_lifecycle/self_status_lifecycle_model.gd"

## The status to apply while this intent is active.
## NOTE: intent-lifecycle statuses must be unique by id per fighter.

func on_opposing_group_start(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_apply_to_self_sim(ctx)

func on_intent_canceled(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_remove_from_self_sim(ctx)
