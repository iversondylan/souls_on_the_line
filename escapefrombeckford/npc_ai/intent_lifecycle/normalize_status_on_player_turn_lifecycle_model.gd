class_name NormalizeStatusOnPlayerTurnLifecycleModel
extends "res://npc_ai/intent_lifecycle/self_status_lifecycle_model.gd"

func on_player_turn_started(ctx: NPCAIContext, _player_id: int) -> void:
	if !_can_run_sim(ctx):
		return
	_normalize_self_status_sim(ctx)

func _normalize_self_status_sim(ctx: NPCAIContext) -> void:
	var actor_id := ctx.get_actor_id()
	if actor_id <= 0 or ctx.api == null or ctx.api.state == null:
		return

	var owner: CombatantState = ctx.api.state.get_unit(actor_id)
	if owner == null or !owner.is_alive() or owner.statuses == null:
		return

	var sid := _status_id()
	if sid == &"":
		return

	var desired_intensity := maxi(int(intensity), 0)
	var desired_duration := maxi(int(duration), 0)
	var desired_pending := bool(pending)
	var current_token: StatusToken = owner.statuses.get_status_token(sid, desired_pending)
	var other_token: StatusToken = owner.statuses.get_status_token(sid, !desired_pending)
	var proto := SimStatusSystem.get_proto(ctx.api, sid)
	var max_intensity := int(proto.get_max_intensity()) if proto != null else 0
	if max_intensity > 0:
		desired_intensity = mini(desired_intensity, max_intensity)

	if other_token != null:
		_remove_status_from_self_sim(ctx, sid, !desired_pending)

	if desired_intensity <= 0:
		if current_token != null:
			_remove_status_from_self_sim(ctx, sid, desired_pending)
		return

	if current_token == null:
		_apply_to_self_sim(ctx)
		return

	var before_i := int(current_token.intensity)
	var before_d := int(current_token.duration)
	if before_i == desired_intensity and before_d == desired_duration:
		return

	if before_i < desired_intensity and before_d == desired_duration:
		var apply_ctx := StatusContext.new()
		apply_ctx.source_id = actor_id
		apply_ctx.target_id = actor_id
		apply_ctx.status_id = sid
		apply_ctx.pending = desired_pending
		apply_ctx.intensity = desired_intensity - before_i
		apply_ctx.reason = "normalize_status_on_player_turn"
		ctx.api.apply_status(apply_ctx)
		return

	_remove_status_from_self_sim(ctx, sid, desired_pending)
	_apply_to_self_sim(ctx)

func _remove_status_from_self_sim(ctx: NPCAIContext, sid: StringName, lane_pending: bool) -> void:
	if ctx == null or ctx.api == null:
		return
	var actor_id := ctx.get_actor_id()
	if actor_id <= 0 or sid == &"":
		return

	var rc := StatusContext.new()
	rc.source_id = actor_id
	rc.target_id = actor_id
	rc.status_id = sid
	rc.pending = lane_pending
	ctx.api.remove_status(rc)
