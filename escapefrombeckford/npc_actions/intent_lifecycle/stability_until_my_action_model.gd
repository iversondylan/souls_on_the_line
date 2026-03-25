# stability_until_my_action_model.gd
class_name StabilityUntilMyActionModel
extends IntentLifecycleModel

@export var status: Status
@export var status_id: StringName
@export var intensity := 0
@export var duration := 0

func _status_id() -> StringName:
	return StringName(status.get_id()) if status != null else status_id

func on_opposing_group_start(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	if ctx.state != null:
		ctx.state[ActionPlanner.STABILITY_BROKEN] = false
	_apply_to_self_sim(ctx)

func on_ability_started(ctx: NPCAIContext) -> void:
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
	if status == null and status_id == &"":
		return false
	return ParamModel._actor_id(ctx) > 0

func _apply_to_self_sim(ctx: NPCAIContext) -> void:
	if ctx.cid <= 0:
		return
	var sc := StatusContext.new()
	sc.source_id = ctx.cid
	sc.target_id = ctx.cid
	sc.status_id = _status_id()
	sc.duration = duration
	sc.intensity = intensity
	ctx.api.apply_status(sc)

func _remove_from_self_sim(ctx: NPCAIContext) -> void:
	var id := ParamModel._actor_id(ctx)
	if id <= 0:
		return
	var rc := StatusContext.new()
	rc.source_id = id
	rc.target_id = id
	rc.status_id = _status_id()
	ctx.api.remove_status(rc)
