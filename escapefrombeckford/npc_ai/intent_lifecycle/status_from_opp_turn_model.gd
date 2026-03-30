# status_from_opp_turn_model.gd
class_name StatusFromOppTurnModel
extends IntentLifecycleModel

## The status to apply while this intent is active.
## NOTE: intent-lifecycle statuses must be unique by id per fighter.
@export var status: Status
@export var intensity := 0
@export var duration := 0
@export var pending: bool = false

func _status_id() -> StringName:
	return StringName(status.get_id())

func on_opposing_group_start(ctx: NPCAIContext) -> void:
	#print("uh oh")
	if !_can_run_sim(ctx):
		return
	_apply_to_self_sim(ctx)

func on_intent_canceled(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_remove_from_self_sim(ctx)

func _can_run_sim(ctx: NPCAIContext) -> bool:
	if !ctx or bool(ctx.forecast):
		return false
	if !ctx.api:
		return false
	if !status:
		return false
	return ParamModel._actor_id(ctx) > 0 # <-- infinite recursion stopped here

func _apply_to_self_sim(ctx: NPCAIContext) -> void:
	var id := ParamModel._actor_id(ctx)
	if id <= 0:
		return

	var sc := StatusContext.new()
	sc.source_id = id
	sc.target_id = id
	sc.status_id = _status_id()
	sc.duration = duration
	sc.intensity = intensity
	sc.pending = bool(pending)
	ctx.api.apply_status(sc)

func _remove_from_self_sim(ctx: NPCAIContext) -> void:
	var id := ParamModel._actor_id(ctx)
	if id <= 0:
		return

	var rc := StatusContext.new()
	rc.source_id = id
	rc.target_id = id
	rc.status_id = _status_id()
	rc.pending = bool(pending)
	# rc.intensity_delta default handled in API
	ctx.api.remove_status(rc)
