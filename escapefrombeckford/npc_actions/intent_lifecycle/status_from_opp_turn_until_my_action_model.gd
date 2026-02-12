# status_from_opp_turn_to_my_action_model.gd

class_name StatusFromOppTurnUntilMyActionModel
extends IntentLifecycleModel

## The status to apply while this intent is active.
## NOTE: Intent-lifecycle statuses must be unique by id.
## ->don't apply the same status to the same fighter more than once
@export var status: Status

func on_opposing_group_start(ctx: NPCAIContext) -> void:
	if !ctx or !ctx.combatant or !status:
		return
	StatusRuntime.apply_status_to_fighter(ctx.combatant, status)

func on_ability_started(ctx: NPCAIContext) -> void:
	if !ctx or !ctx.combatant or !status:
		return
	StatusRuntime.remove_status_from_fighter(ctx.combatant, status.get_id())

func on_intent_canceled(ctx: NPCAIContext) -> void:
	if !ctx or !ctx.combatant or !status:
		return
	StatusRuntime.remove_status_from_fighter(ctx.combatant, status.get_id())
