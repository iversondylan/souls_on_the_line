# targeted_status_from_opp_turn_model.gd

class_name TargetedStatusFromOppTurnModel extends IntentLifecycleModel

@export var status: Status
@export var status_id: StringName
@export var intensity := 1
@export var duration := 0
@export var pending: bool = false
@export var target_model: ParamModel
@export var state_key: StringName = &"targeted_status_targets"

func _status_id() -> StringName:
	if status_id != &"":
		return StringName(status_id)
	return StringName(status.get_id()) if status != null else &""

func _can_run_sim(ctx: NPCAIContext) -> bool:
	if !ctx or bool(ctx.forecast):
		return false
	if ctx.api == null:
		return false
	return ctx.get_actor_id() > 0 and _status_id() != &""

func on_opposing_group_turn_started(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_apply_targeted_status_sim(ctx)

func on_plan_canceled(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_clear_pending_status_sim(ctx)

func on_intent_canceled(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_clear_pending_status_sim(ctx)

func on_action_execution_skipped(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_clear_pending_status_sim(ctx)

func on_action_execution_completed(ctx: NPCAIContext) -> void:
	if ctx != null and ctx.state != null and state_key != &"":
		ctx.state.erase(state_key)

func on_combatant_removal(ctx: NPCAIContext, removal_ctx: RemovalContext) -> void:
	if !_can_run_sim(ctx):
		return
	if removal_ctx == null or int(removal_ctx.target_id) != ctx.get_actor_id():
		return
	_clear_pending_status_sim(ctx)

func _apply_targeted_status_sim(ctx: NPCAIContext) -> void:
	var target_ids := _resolve_target_ids(ctx, target_model)
	_store_target_ids(ctx, target_ids)
	if target_ids.is_empty():
		return

	var actor_id := ctx.get_actor_id()
	for target_id in target_ids:
		var sc := StatusContext.new()
		sc.source_id = actor_id
		sc.target_id = int(target_id)
		sc.status_id = _status_id()
		sc.duration = int(duration)
		sc.intensity = int(intensity)
		sc.pending = bool(pending)
		sc.reason = "npc_pending_status_intent"
		ctx.api.apply_status(sc)

func _clear_pending_status_sim(ctx: NPCAIContext) -> void:
	var target_ids := _get_stored_target_ids(ctx)
	_store_target_ids(ctx, PackedInt32Array())
	if target_ids.is_empty():
		return

	var actor_id := ctx.get_actor_id()
	for target_id in target_ids:
		var rc := StatusContext.new()
		rc.source_id = actor_id
		rc.target_id = int(target_id)
		rc.status_id = _status_id()
		rc.pending = bool(pending)
		ctx.api.remove_status(rc)

func _resolve_target_ids(ctx: NPCAIContext, model: ParamModel) -> PackedInt32Array:
	var target_ids := PackedInt32Array()
	if model == null:
		return target_ids

	var work_ctx := ActionPlanner.make_context(ctx.api, ctx.combatant_state)
	work_ctx.runtime = ctx.runtime
	work_ctx.forecast = bool(ctx.forecast)
	work_ctx.params = ctx.params.duplicate(true) if ctx.params != null else {}
	work_ctx.summoned_ids = ctx.summoned_ids.duplicate()
	work_ctx.affected_ids = ctx.affected_ids.duplicate()
	work_ctx.action_name = String(ctx.action_name)

	work_ctx = model.change_params_sim(work_ctx)
	if work_ctx == null or work_ctx.params == null:
		return target_ids

	var raw_value = work_ctx.params.get(Keys.TARGET_IDS, PackedInt32Array())
	if raw_value is PackedInt32Array:
		target_ids = raw_value
	elif raw_value is Array:
		target_ids = PackedInt32Array(raw_value)
	return target_ids

func _store_target_ids(ctx: NPCAIContext, target_ids: PackedInt32Array) -> void:
	if ctx == null or ctx.state == null or state_key == &"":
		return
	if target_ids.is_empty():
		ctx.state.erase(state_key)
	else:
		ctx.state[state_key] = target_ids

func _get_stored_target_ids(ctx: NPCAIContext) -> PackedInt32Array:
	if ctx == null or ctx.state == null or state_key == &"":
		return PackedInt32Array()

	var stored = ctx.state.get(state_key, PackedInt32Array())
	if stored is PackedInt32Array:
		return stored
	if stored is Array:
		return PackedInt32Array(stored)
	var single_id := int(stored)
	if single_id > 0:
		return PackedInt32Array([single_id])
	return PackedInt32Array()
