# self_status_lifecycle_model.gd
class_name SelfStatusLifecycleModel
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

func _can_run_sim(ctx: NPCAIContext) -> bool:
	if !ctx or bool(ctx.forecast):
		return false
	if !ctx.api:
		return false
	if _status_id() == &"":
		return false
	return ctx.get_actor_id() > 0

func _apply_to_self_sim(ctx: NPCAIContext) -> void:
	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		return

	var sc := StatusContext.new()
	sc.source_id = actor_id
	sc.target_id = actor_id
	sc.status_id = _status_id()
	sc.duration = duration
	sc.intensity = intensity
	sc.pending = bool(pending)
	ctx.api.apply_status(sc)

func _remove_from_self_sim(ctx: NPCAIContext) -> void:
	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		return

	var rc := StatusContext.new()
	rc.source_id = actor_id
	rc.target_id = actor_id
	rc.status_id = _status_id()
	rc.pending = bool(pending)
	ctx.api.remove_status(rc)
