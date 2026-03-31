# status_intent_lifecycle_model.gd
class_name StatusIntentLifecycleModel
extends IntentLifecycleModel

@export var status: Status
@export var status_id: StringName
@export var intensity := 0
@export var duration := 0
@export var pending: bool = false

func _status_id() -> StringName:
	if status_id != &"":
		return StringName(status_id)
	return StringName(status.get_id()) if status != null else &""

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

func _can_run_sim(ctx: NPCAIContext) -> bool:
	if !ctx or bool(ctx.forecast):
		return false
	if !ctx.api:
		return false
	if _status_id() == &"":
		return false
	return ParamModel._actor_id(ctx) > 0

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
	ctx.api.remove_status(rc)
