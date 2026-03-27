# intent_lifecycle_model.gd

class_name IntentLifecycleModel extends Resource

# Intent/action lifecycle hooks.

func on_intent_chosen(_ctx: NPCAIContext) -> void:
	pass

func on_intent_canceled(_ctx: NPCAIContext) -> void:
	pass

func on_opposing_group_start(_ctx: NPCAIContext) -> void:
	pass

func on_my_group_end(_ctx: NPCAIContext) -> void:
	pass

func on_ability_started(_ctx: NPCAIContext) -> void:
	pass

# -------------------------------------------------------------------
# Clearer phase hooks
# -------------------------------------------------------------------

func on_plan_chosen(ctx: NPCAIContext) -> void:
	on_intent_chosen(ctx)

func on_plan_canceled(ctx: NPCAIContext) -> void:
	on_intent_canceled(ctx)

func on_opposing_group_turn_started(ctx: NPCAIContext) -> void:
	on_opposing_group_start(ctx)

func on_owner_group_turn_ended(ctx: NPCAIContext) -> void:
	on_my_group_end(ctx)

func on_action_execution_started(ctx: NPCAIContext) -> void:
	on_ability_started(ctx)
