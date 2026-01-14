# status_during_intent_lifecycle_model.gd
class_name StatusDuringIntentLifecycleModel
extends IntentLifecycleModel

## The status to apply while this intent is active.
## NOTE: Intent-lifecycle statuses must be unique by id.
## ->don't apply the same status to the same fighter more than once
@export var status: Status

func on_intent_chosen(ctx: NPCAIContext) -> void:
	if !ctx or !ctx.combatant or !status:
		return

	var grid := ctx.combatant.combatant.status_grid
	if !grid:
		return

	# Duplicate so authored resource is not mutated
	grid.add_status(status.duplicate())

## NOTE:
## StatusGrid enforces uniqueness by (status.id, status_parent).
## Multiple fighters may emit the same aura, but a single fighter
## must not apply the same primary status to itself more than once.
## Intent-lifecycle statuses rely on this contract.

## Called when this action stops being the planned intent
## due to reprioritization or interruption
func on_intent_canceled(ctx: NPCAIContext) -> void:
	if !ctx or !ctx.combatant or !status:
		return

	var grid := ctx.combatant.combatant.status_grid
	if !grid:
		return

	grid.remove_status_by_id(status.id)
