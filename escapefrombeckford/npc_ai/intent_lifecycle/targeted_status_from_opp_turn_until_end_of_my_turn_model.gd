# targeted_status_from_opp_turn_until_end_of_my_turn_model.gd
class_name TargetedStatusFromOppTurnUntilEndOfMyTurnModel
extends IntentLifecycleModel

@export var status: Status
@export var status_id: StringName
@export var intensity := 1
@export var duration := 0
@export var pending: bool = false
@export var target_model: ParamModel
@export var reapply_target_model: ParamModel
@export var targeting_flag_key: StringName = &""

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
	_apply_targeted_status_sim(ctx, target_model)

func on_action_execution_started(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	if reapply_target_model == null:
		return
	if _status_exists_on_opposing_team(ctx):
		return
	_apply_targeted_status_sim(ctx, reapply_target_model)

func on_action_execution_completed(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_clear_targeted_status_sim(ctx)

func on_plan_canceled(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_clear_targeted_status_sim(ctx)

func on_intent_canceled(ctx: NPCAIContext) -> void:
	if !_can_run_sim(ctx):
		return
	_clear_targeted_status_sim(ctx)

func _apply_targeted_status_sim(ctx: NPCAIContext, model: ParamModel) -> void:
	var target_ids := _resolve_target_ids(ctx, model)
	if target_ids.is_empty():
		_clear_flag(ctx)
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
		ctx.api.apply_status(sc)

	_set_flag(ctx, true)

func _clear_targeted_status_sim(ctx: NPCAIContext) -> void:
	var actor_id := ctx.get_actor_id()
	_set_flag(ctx, false)
	if _has_any_other_flagged_attacker(ctx, actor_id):
		return

	var actor_group := int(ctx.api.get_group(actor_id))
	if actor_group < 0:
		return

	var defending_group := int(ctx.api.get_opposing_group(actor_group))
	for cid in ctx.api.get_combatants_in_group(defending_group, true):
		var rc := StatusContext.new()
		rc.source_id = actor_id
		rc.target_id = int(cid)
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

func _status_exists_on_opposing_team(ctx: NPCAIContext) -> bool:
	if ctx == null or ctx.api == null:
		return false

	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		return false

	var actor_group := int(ctx.api.get_group(actor_id))
	if actor_group < 0:
		return false

	var defending_group := int(ctx.api.get_opposing_group(actor_group))
	for cid in ctx.api.get_combatants_in_group(defending_group, false):
		var target_id := int(cid)
		if target_id <= 0:
			continue
		if ctx.api.has_status(target_id, _status_id()):
			return true
	return false

func _set_flag(ctx: NPCAIContext, value: bool) -> void:
	if targeting_flag_key == &"" or ctx == null or ctx.combatant_state == null:
		return
	ActionPlanner.ensure_ai_state_initialized(ctx.combatant_state)
	ctx.combatant_state.ai_state[targeting_flag_key] = bool(value)
	if ctx.state != null:
		ctx.state[targeting_flag_key] = bool(value)

func _clear_flag(ctx: NPCAIContext) -> void:
	_set_flag(ctx, false)

func _has_any_other_flagged_attacker(ctx: NPCAIContext, actor_id: int) -> bool:
	if targeting_flag_key == &"" or ctx == null or ctx.api == null:
		return false

	var actor_group := int(ctx.api.get_group(actor_id))
	if actor_group < 0:
		return false

	for cid in ctx.api.get_combatants_in_group(actor_group, false):
		var other_id := int(cid)
		if other_id <= 0 or other_id == actor_id:
			continue
		var unit: CombatantState = ctx.api.state.get_unit(other_id)
		if unit == null or unit.ai_state == null:
			continue
		if bool(unit.ai_state.get(targeting_flag_key, false)):
			return true
	return false
