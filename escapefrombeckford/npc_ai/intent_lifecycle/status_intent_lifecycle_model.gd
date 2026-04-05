# status_intent_lifecycle_model.gd
class_name StatusIntentLifecycleModel
extends "res://npc_ai/intent_lifecycle/self_status_lifecycle_model.gd"

func on_plan_chosen(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_apply_to_self_sim(ctx)

func on_plan_canceled(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_remove_from_self_sim(ctx)

func on_action_execution_completed(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_remove_from_self_sim(ctx)
