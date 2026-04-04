# pending_status_system.gd

class_name PendingStatusSystem
extends RefCounted


static func apply_lifecycle_status(
	ctx: NPCAIContext,
	status_id: StringName,
	intensity: int,
	duration: int,
	pending: bool
) -> void:
	if ctx == null or ctx.api == null or status_id == &"":
		return

	var actor_id := _get_actor_id(ctx)
	if actor_id <= 0:
		return

	var sc := StatusContext.new()
	sc.source_id = actor_id
	sc.target_id = actor_id
	sc.status_id = status_id
	sc.duration = int(duration)
	sc.intensity = int(intensity)
	sc.pending = bool(pending)
	ctx.api.apply_status(sc)


static func remove_lifecycle_status(
	ctx: NPCAIContext,
	status_id: StringName,
	pending: bool
) -> void:
	if ctx == null or ctx.api == null or status_id == &"":
		return

	var actor_id := _get_actor_id(ctx)
	if actor_id <= 0:
		return

	var rc := StatusContext.new()
	rc.source_id = actor_id
	rc.target_id = actor_id
	rc.status_id = status_id
	rc.pending = bool(pending)
	ctx.api.remove_status(rc)


static func action_realizes_pending_statuses(action: NPCAction) -> bool:
	if action == null:
		return false

	for pkg: NPCEffectPackage in action.effect_packages:
		if package_realizes_pending_statuses(pkg):
			return true
	return false


static func package_realizes_pending_statuses(pkg: NPCEffectPackage) -> bool:
	return (
		pkg != null
		and pkg.effect != null
		and bool(pkg.effect.realizes_pending_statuses())
	)


static func collect_realizing_sources(ctx: NPCAIContext, source_id: int) -> Dictionary:
	var out := {}
	if ctx == null or ctx.api == null or !(ctx.api is SimBattleAPI):
		return out

	var api: SimBattleAPI = ctx.api
	var group_index := int(api.get_group(source_id))
	if group_index < 0:
		return out

	var order := _get_relevant_group_order(ctx, group_index)
	var source_pos := order.find(int(source_id))
	if source_pos == -1:
		return out

	for i in range(source_pos):
		var earlier_id := int(order[i])
		if earlier_id <= 0:
			continue
		if action_realizes_pending_statuses(_get_planned_action(api, earlier_id)):
			out[earlier_id] = true

	if _self_action_realizes_before_preview_package(api, ctx, int(source_id)):
		out[int(source_id)] = true

	return out


static func realize_pending_statuses(
	api: SimBattleAPI,
	target_id: int,
	source_id: int = 0,
	reason: String = ""
) -> void:
	if api == null or api.state == null or target_id <= 0:
		return

	var u: CombatantState = api.state.get_unit(int(target_id))
	if u == null or !u.is_alive() or u.statuses == null:
		return

	var pending_ids := u.statuses.get_status_ids(true, true)
	if pending_ids.is_empty():
		return

	var any_aura := false
	var any_changed := false
	var src_id := int(source_id if source_id > 0 else target_id)

	for status_id in pending_ids:
		var had_realized := u.statuses.has(status_id, false)
		var proto := SimStatusSystem.get_proto(api, status_id)
		var status_max_intensity := int(proto.get_max_intensity()) if proto != null else 0

		var ctx := StatusContext.new()
		ctx.actor_id = int(target_id)
		ctx.source_id = src_id
		ctx.target_id = int(target_id)
		ctx.status_id = status_id
		ctx.pending = true
		ctx.reason = reason

		if !u.statuses.realize_pending_ctx(ctx, status_max_intensity):
			continue

		any_changed = true
		if api.writer != null:
			api.writer.emit_status(
				int(ctx.source_id),
				int(ctx.target_id),
				ctx.status_id,
				int(ctx.op),
				int(ctx.intensity),
				int(ctx.duration),
				{
					Keys.STATUS_PENDING: bool(ctx.after_pending),
					Keys.DELTA_INTENSITY: int(ctx.delta_intensity),
					Keys.DELTA_DURATION: int(ctx.delta_duration),
					Keys.BEFORE_PENDING: bool(ctx.before_pending),
					Keys.AFTER_PENDING: bool(ctx.after_pending),
					Keys.BEFORE_INTENSITY: int(ctx.before_intensity),
					Keys.BEFORE_DURATION: int(ctx.before_duration),
					Keys.AFTER_INTENSITY: int(ctx.after_intensity),
					Keys.AFTER_DURATION: int(ctx.after_duration),
					Keys.REASON: String(reason),
				}
			)

		if proto == null:
			continue

		any_aura = any_aura or SimStatusSystem.is_aura_proto(proto)
		if SimStatusSystem.is_aura_proto(proto) and api.state.projection_bank != null:
			api.state.projection_bank.untrack_status_aura(int(target_id), status_id, true)
			api.state.projection_bank.track_status_aura(int(target_id), status_id, false)

		if !had_realized:
			var status_ctx := SimStatusSystem.make_context(
				api,
				int(target_id),
				u.statuses.get_status_stack(status_id, false)
			)
			if status_ctx != null and status_ctx.proto != null:
				status_ctx.proto.on_apply(status_ctx, ctx)

		api._request_immediate_planning_flush_if_needed(int(target_id), proto)

	if !any_changed:
		return

	api._rebuild_modifier_cache_for(int(target_id))
	if any_aura:
		api._request_intent_refresh_all()
	else:
		api._request_intent_refresh(int(target_id))
	api._on_status_changed(int(target_id))


static func _get_actor_id(ctx: NPCAIContext) -> int:
	if ctx == null:
		return 0

	var actor_id := int(ParamModel._actor_id(ctx))
	if actor_id > 0:
		return actor_id
	return int(ctx.cid)


static func _get_relevant_group_order(ctx: NPCAIContext, group_index: int) -> Array[int]:
	var out: Array[int] = []
	if ctx == null or ctx.api == null or !(ctx.api is SimBattleAPI):
		return out

	var api: SimBattleAPI = ctx.api
	var runtime := ctx.runtime if ctx.runtime != null else api.runtime
	if runtime != null and runtime.turn_engine != null and int(runtime.turn_engine.active_group_index) == int(group_index):
		var snapshot := runtime.turn_engine.build_pending_actor_snapshot()
		if int(snapshot.active_id) > 0:
			out.append(int(snapshot.active_id))
		for cid in snapshot.pending_ids:
			var id := int(cid)
			if id > 0 and !out.has(id):
				out.append(id)
		return out

	return api.get_combatants_in_group(group_index, false)


static func _self_action_realizes_before_preview_package(
	api: SimBattleAPI,
	ctx: NPCAIContext,
	source_id: int
) -> bool:
	if ctx == null:
		return false

	var preview_package_index := int(ctx.preview_package_index)
	if preview_package_index <= 0:
		return false

	var action := _get_planned_action(api, source_id)
	if action == null:
		return false

	var last_index := mini(preview_package_index, action.effect_packages.size())
	for i in range(last_index):
		if package_realizes_pending_statuses(action.effect_packages[i]):
			return true
	return false


static func _get_planned_action(api: SimBattleAPI, source_id: int) -> NPCAction:
	if api == null or api.state == null:
		return null

	var unit: CombatantState = api.state.get_unit(source_id)
	if unit == null or !unit.is_alive() or unit.combatant_data == null or unit.combatant_data.ai == null:
		return null

	ActionPlanner.ensure_ai_state_initialized(unit)
	var planned_idx := int(unit.ai_state.get(ActionPlanner.KEY_PLANNED_IDX, -1))
	return ActionPlanner.get_action_by_idx(unit.combatant_data.ai, planned_idx)
