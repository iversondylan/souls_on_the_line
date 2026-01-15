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
	
	var grid := ctx.combatant.combatant.status_grid
	if !grid:
		return
	
	# Duplicate so authored resource is not mutated
	grid.add_status(status.duplicate())

func on_ability_started(ctx: NPCAIContext) -> void:
	if !ctx or !ctx.combatant or !status:
		return
	
	var grid := ctx.combatant.combatant.status_grid
	if !grid:
		return
	
	grid.remove_status_by_id(status.id)

func on_intent_canceled(ctx: NPCAIContext) -> void:
	print("status_during_intent_lifecycle_model.gd on_intent_canceled()")
	if !ctx or !ctx.combatant or !status:
		return
	
	var grid := ctx.combatant.combatant.status_grid
	if !grid:
		return
	
	grid.remove_status_by_id(status.id)
