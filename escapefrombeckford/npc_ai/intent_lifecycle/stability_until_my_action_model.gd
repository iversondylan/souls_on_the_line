# stability_until_my_action_model.gd
class_name StabilityUntilMyActionModel
extends "res://npc_ai/intent_lifecycle/self_status_lifecycle_model.gd"

func on_opposing_group_start(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_apply_to_self_sim(ctx)

func on_ability_started(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_remove_from_self_sim(ctx)

func on_intent_canceled(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_remove_from_self_sim(ctx)
