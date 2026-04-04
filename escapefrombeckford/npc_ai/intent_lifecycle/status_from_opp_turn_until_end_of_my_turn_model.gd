# status_from_opp_turn_until_end_of_my_turn_model.gd
class_name StatusFromOppTurnUntilEndOfMyTurnModel
extends IntentLifecycleModel

const PendingStatusSystemScript = preload("res://battle/sim/operators/pending_status_system.gd")

@export var status: Status
@export var status_id: StringName
@export var intensity := 0
@export var duration := 0
# Pending means "show/apply the pending telegraph lane" for this lifecycle status.
@export var pending: bool = false


func _status_id() -> StringName:
	if status_id != &"":
		return StringName(status_id)
	return StringName(status.get_id()) if status != null else &""


func on_opposing_group_start(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_apply_to_self_sim(ctx)


func on_action_execution_completed(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_remove_from_self_sim(ctx)


func on_intent_canceled(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_remove_from_self_sim(ctx)


func _can_run_sim(ctx: NPCAIContext) -> bool:
	if !ctx or bool(ctx.forecast):
		return false
	if !ctx.api:
		return false
	if _status_id() == &"":
		return false
	return ParamModel._actor_id(ctx) > 0


func _apply_to_self_sim(ctx: NPCAIContext) -> void:
	PendingStatusSystemScript.apply_lifecycle_status(
		ctx,
		_status_id(),
		intensity,
		duration,
		pending
	)


func _remove_from_self_sim(ctx: NPCAIContext) -> void:
	PendingStatusSystemScript.remove_lifecycle_status(ctx, _status_id(), pending)
