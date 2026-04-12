# sim_status_system.gd

class_name SimStatusSystem extends RefCounted


# Owns status lifecycle and event dispatch.
# Turn progression belongs to SimRuntime.
# Atomistic mutations belong to SimBattleAPI.

static func on_group_turn_begin(api: SimBattleAPI, group_index: int) -> void:
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return

	_for_each_effective_status_on_group(api, group_index, func(ctx: SimStatusContext) -> void:
		if ctx.proto != null:
			ctx.proto.on_group_turn_begin(ctx, group_index)
	)

	_expire_by_policy(api, group_index, Status.ExpirationPolicy.GROUP_TURN_START)

static func on_group_turn_end(api: SimBattleAPI, group_index: int) -> void:
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return

	_for_each_effective_status_on_group(api, group_index, func(ctx: SimStatusContext) -> void:
		if ctx.proto != null:
			ctx.proto.on_group_turn_end(ctx, group_index)
	)

	_expire_by_policy(api, group_index, Status.ExpirationPolicy.GROUP_TURN_END)

static func on_actor_turn_begin(api: SimBattleAPI, actor_id: int) -> void:
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return

	_for_each_effective_status_on_unit(api, actor_id, func(ctx: SimStatusContext) -> void:
		if ctx.proto != null:
			ctx.proto.on_actor_turn_begin(ctx)
	)

static func on_player_turn_begin(api: SimBattleAPI, player_id: int) -> void:
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return
	if int(player_id) <= 0:
		return

	_for_each_effective_status_in_battle(api, func(ctx: SimStatusContext) -> void:
		if ctx == null or !ctx.is_valid() or !ctx.is_alive():
			return
		if ctx.proto != null:
			ctx.proto.on_player_turn_begin(ctx, player_id)
	)

	_expire_all_by_policy(api, Status.ExpirationPolicy.PLAYER_TURN_START)

static func on_draw_context(_api: SimBattleAPI, _ctx: DrawContext) -> void:
	return

static func on_player_turn_end_discard(_api: SimBattleAPI, _ctx: DiscardContext) -> void:
	return

static func on_actor_turn_end(api: SimBattleAPI, actor_id: int) -> void:
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return

	_for_each_effective_status_on_unit(api, actor_id, func(ctx: SimStatusContext) -> void:
		if ctx.proto != null:
			ctx.proto.on_actor_turn_end(ctx)
	)

	_tick_duration_statuses_for_owner_turn_end(api, actor_id)

static func on_damage_taken(api: SimBattleAPI, damage_ctx: DamageContext) -> void:
	if api == null or api.state == null or damage_ctx == null or api.state.has_terminal_outcome():
		return

	var target_id := int(damage_ctx.target_id)
	if target_id <= 0:
		return

	_for_each_effective_status_on_unit(api, target_id, func(ctx: SimStatusContext) -> void:
		if ctx.proto != null:
			ctx.proto.on_damage_taken(ctx, damage_ctx)
	)

static func on_damage_will_be_taken(api: SimBattleAPI, damage_ctx: DamageContext) -> void:
	if api == null or api.state == null or damage_ctx == null or api.state.has_terminal_outcome():
		return

	var target_id := int(damage_ctx.target_id)
	if target_id <= 0:
		return

	_for_each_effective_status_on_unit(api, target_id, func(ctx: SimStatusContext) -> void:
		if ctx.proto != null:
			ctx.proto.on_damage_will_be_taken(ctx, damage_ctx)
	)

static func on_attack_will_run(
	api: SimBattleAPI,
	attack_ctx: AttackContext,
	include_pending_sources := {}
) -> void:
	if api == null or api.state == null or attack_ctx == null or api.state.has_terminal_outcome():
		return

	var attacker_id := int(attack_ctx.attacker_id)
	if attacker_id <= 0:
		return

	var fn := func(ctx: SimStatusContext) -> void:
		if ctx.proto != null:
			ctx.proto.on_attack_will_run(ctx, attack_ctx)

	_for_each_effective_status_on_unit(
		api,
		attacker_id,
		fn,
		false,
		include_pending_sources
	)

static func on_removal(api: SimBattleAPI, removal_ctx) -> void:
	if api == null or api.state == null or removal_ctx == null or api.state.has_terminal_outcome():
		return

	var removed_id := int(removal_ctx.target_id)
	if removed_id <= 0:
		return

	var fn := func(ctx: SimStatusContext) -> void:
		if ctx.proto != null:
			ctx.proto.on_removal(ctx, removal_ctx)

	_for_each_effective_status_on_unit(api, removed_id, fn, true)

static func should_skip_npc_action(api: SimBattleAPI, actor_id: int) -> bool:
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return false
	if int(actor_id) <= 0:
		return false

	for ctx: SimStatusContext in get_effective_status_contexts_for_unit(api, int(actor_id)):
		var proto := ctx.proto if ctx != null else null
		if proto != null and bool(proto.should_skip_npc_action(ctx)):
			return true

	return false

static func unit_grants_attack_cleave(api: SimBattleAPI, owner_id: int) -> bool:
	return _unit_grants_cleave_internal(api, owner_id, true)

static func unit_grants_received_cleave(api: SimBattleAPI, owner_id: int) -> bool:
	return _unit_grants_cleave_internal(api, owner_id, false)

static func unit_get_attack_self_damage_on_strike(
	api: SimBattleAPI,
	owner_id: int,
	attack_ctx: AttackContext
) -> int:
	if api == null or api.state == null or owner_id <= 0 or attack_ctx == null:
		return 0

	var total := 0
	for ctx: SimStatusContext in get_effective_status_contexts_for_unit(api, owner_id):
		var proto := ctx.proto if ctx != null else null
		if proto == null:
			continue

		total += maxi(int(proto.get_attack_self_damage_on_strike(ctx, attack_ctx)), 0)

	return maxi(total, 0)


# -------------------------------------------------------------------
# Proto helpers
# -------------------------------------------------------------------

static func get_proto(api: SimBattleAPI, status_id: StringName) -> Status:
	if api == null or api.state == null:
		return null

	if api.state.status_catalog != null:
		return api.state.status_catalog.get_proto(status_id)

	return null

static func is_aura_proto(proto: Status) -> bool:
	return proto is Aura

static func make_context(api: SimBattleAPI, owner_id: int, stack: StatusStack) -> SimStatusContext:
	if api == null or api.state == null or owner_id <= 0 or stack == null:
		return null

	var owner: CombatantState = api.state.get_unit(owner_id)
	if owner == null:
		return null

	var proto := get_proto(api, stack.id)
	if proto == null:
		return null

	return SimStatusContext.new(api, owner_id, owner, stack, proto)


static func get_effective_status_contexts_for_unit(
	api: SimBattleAPI,
	target_id: int,
	include_pending_sources := {},
	allow_dead_self_aura_source := false
) -> Array[SimStatusContext]:
	var out: Array[SimStatusContext] = []
	if api == null or api.state == null or target_id <= 0:
		return out

	_append_owned_status_contexts(out, api, target_id, include_pending_sources)
	_append_projected_status_contexts(
		out,
		api,
		target_id,
		include_pending_sources,
		allow_dead_self_aura_source
	)
	return _merge_owned_and_projected_intensity_contexts(out)


# -------------------------------------------------------------------
# Pending-status helpers
# -------------------------------------------------------------------

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

static func collect_pending_realization_sources(ctx: NPCAIContext, source_id: int) -> Dictionary:
	# Historical name kept for callers; keys are status-owner IDs whose pending lane
	# should be included in intent preview because a realize package runs first.
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
		_append_pending_realization_targets_for_action(out, api, ctx, earlier_id)

	var preview_package_index := int(ctx.preview_package_index)
	if preview_package_index >= 0:
		_append_pending_realization_targets_for_action(
			out,
			api,
			ctx,
			int(source_id),
			preview_package_index
		)

	return out

static func _append_pending_realization_targets_for_action(
	out: Dictionary,
	api: SimBattleAPI,
	base_ctx: NPCAIContext,
	actor_id: int,
	before_package_index: int = -1
) -> void:
	if out == null or api == null or api.state == null or actor_id <= 0:
		return

	var action := _get_planned_action_for_pending(api, actor_id)
	if action == null:
		return

	var limit := action.effect_packages.size()
	if before_package_index >= 0:
		limit = mini(int(before_package_index), limit)

	for i in range(limit):
		var pkg: NPCEffectPackage = action.effect_packages[i]
		if !package_realizes_pending_statuses(pkg):
			continue
		var target_ids := _resolve_pending_realization_targets_for_package(api, base_ctx, actor_id, pkg)
		for tid in target_ids:
			out[int(tid)] = true

static func _resolve_pending_realization_targets_for_package(
	api: SimBattleAPI,
	base_ctx: NPCAIContext,
	actor_id: int,
	pkg: NPCEffectPackage
) -> PackedInt32Array:
	var target_ids := PackedInt32Array()
	if api == null or api.state == null or actor_id <= 0 or pkg == null:
		return target_ids

	var actor: CombatantState = api.state.get_unit(actor_id)
	if actor == null or !actor.is_alive() or actor.combatant_data == null:
		return target_ids

	ActionPlanner.ensure_ai_state_initialized(actor)
	var work_ctx := ActionPlanner.make_context(api, actor)
	work_ctx.runtime = base_ctx.runtime if base_ctx != null and base_ctx.runtime != null else api.runtime
	work_ctx.forecast = true
	work_ctx.state = actor.ai_state.duplicate(true) if actor.ai_state != null else {}
	work_ctx.rng = actor.rng.clone() if actor.rng != null else null
	work_ctx.params.clear()

	for pm: ParamModel in pkg.param_models:
		if pm != null:
			pm.change_params_sim(work_ctx)

	var has_explicit_targets := work_ctx.params != null and work_ctx.params.has(Keys.TARGET_IDS)
	if has_explicit_targets:
		var raw_value = work_ctx.params.get(Keys.TARGET_IDS, PackedInt32Array())
		if raw_value is PackedInt32Array:
			target_ids = raw_value
		elif raw_value is Array:
			target_ids = PackedInt32Array(raw_value)
	else:
		target_ids.append(actor_id)

	var filtered := PackedInt32Array()
	for tid in target_ids:
		var target_id := int(tid)
		if target_id <= 0:
			continue
		if !api.is_alive(target_id):
			continue
		filtered.append(target_id)
	return filtered

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
	var any_non_aura := false
	var src_id := int(source_id if source_id > 0 else target_id)

	for status_id in pending_ids:
		var had_realized := u.statuses.has(status_id, false)
		var proto := get_proto(api, status_id)
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

		any_aura = any_aura or is_aura_proto(proto)
		any_non_aura = any_non_aura or !is_aura_proto(proto)
		if is_aura_proto(proto):
			api._swap_status_aura_projection_lane(int(target_id), status_id, true, false)

		if !had_realized:
			var status_ctx := make_context(
				api,
				int(target_id),
				u.statuses.get_status_stack(status_id, false)
			)
			if status_ctx != null and status_ctx.proto != null:
				status_ctx.proto.on_apply(status_ctx, ctx)

		if !is_aura_proto(proto):
			api._request_immediate_planning_flush_if_needed(int(target_id), proto)

	if !any_changed:
		return

	api._rebuild_modifier_cache_for(int(target_id))
	if !any_aura:
		api._request_intent_refresh(int(target_id))
	if any_non_aura:
		api._on_status_changed(int(target_id))

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

static func _get_planned_action_for_pending(api: SimBattleAPI, source_id: int) -> NPCAction:
	if api == null or api.state == null:
		return null

	var unit: CombatantState = api.state.get_unit(source_id)
	if unit == null or !unit.is_alive() or unit.combatant_data == null or unit.combatant_data.ai == null:
		return null

	ActionPlanner.ensure_ai_state_initialized(unit)
	var planned_idx := int(unit.ai_state.get(ActionPlanner.KEY_PLANNED_IDX, -1))
	return ActionPlanner.get_action_by_idx(unit.combatant_data.ai, planned_idx)


# -------------------------------------------------------------------
# Internal iteration
# -------------------------------------------------------------------

static func _for_each_status_on_group(api: SimBattleAPI, group_index: int, fn: Callable) -> void:
	if api == null or api.state == null or !fn.is_valid():
		return

	var ids := api.get_combatants_in_group(group_index, true)
	for cid in ids:
		_for_each_status_on_unit(api, int(cid), fn)

static func _for_each_status_in_battle(api: SimBattleAPI, fn: Callable) -> void:
	if api == null or api.state == null or !fn.is_valid():
		return

	for group_index in [SimBattleAPI.FRIENDLY, SimBattleAPI.ENEMY]:
		_for_each_status_on_group(api, int(group_index), fn)

static func _for_each_effective_status_on_group(api: SimBattleAPI, group_index: int, fn: Callable) -> void:
	if api == null or api.state == null or !fn.is_valid():
		return

	var ids := api.get_combatants_in_group(group_index, true)
	for cid in ids:
		_for_each_effective_status_on_unit(api, int(cid), fn)

static func _for_each_effective_status_in_battle(api: SimBattleAPI, fn: Callable) -> void:
	if api == null or api.state == null or !fn.is_valid():
		return

	for group_index in [SimBattleAPI.FRIENDLY, SimBattleAPI.ENEMY]:
		_for_each_effective_status_on_group(api, int(group_index), fn)

static func _for_each_status_on_unit(api: SimBattleAPI, owner_id: int, fn: Callable) -> void:
	if api == null or api.state == null or owner_id <= 0 or !fn.is_valid():
		return

	var u: CombatantState = api.state.get_unit(owner_id)
	if u == null or u.statuses == null or u.statuses.by_id == null:
		return
	if u.statuses.by_id.is_empty():
		return

	for stack: StatusStack in u.statuses.get_all_stacks(false):
		if stack == null:
			continue

		var ctx := make_context(api, owner_id, stack)
		if ctx == null or !ctx.is_valid():
			continue

		fn.call(ctx)

static func _for_each_effective_status_on_unit(
	api: SimBattleAPI,
	owner_id: int,
	fn: Callable,
	allow_dead_self_aura_source := false,
	include_pending_sources := {}
) -> void:
	if api == null or api.state == null or owner_id <= 0 or !fn.is_valid():
		return

	for ctx: SimStatusContext in get_effective_status_contexts_for_unit(
		api,
		owner_id,
		include_pending_sources,
		allow_dead_self_aura_source
	):
		if ctx == null or !ctx.is_valid():
			continue
		fn.call(ctx)


static func _unit_grants_cleave_internal(
	api: SimBattleAPI,
	owner_id: int,
	attack_side: bool
) -> bool:
	if api == null or api.state == null or owner_id <= 0:
		return false

	var u: CombatantState = api.state.get_unit(owner_id)
	if u == null:
		return false

	var stack_notes: Array[String] = []
	for ctx: SimStatusContext in get_effective_status_contexts_for_unit(api, owner_id):
		var sid := ctx.get_status_id() if ctx != null else &""
		var proto := ctx.proto if ctx != null else null
		var grants := false
		if proto != null:
			grants = bool(
				proto.grants_attack_cleave(ctx)
				if attack_side
				else proto.grants_received_cleave(ctx)
			)

			stack_notes.append(
				"%s(proto=%s grants=%s)" % [
					String(sid),
					str(proto != null),
					str(grants),
				]
			)
		if grants:
			return true
	return false


static func _append_owned_status_contexts(
	out: Array[SimStatusContext],
	api: SimBattleAPI,
	target_id: int,
	include_pending_sources := {}
) -> void:
	if api == null or api.state == null:
		return

	var u: CombatantState = api.state.get_unit(target_id)
	if u == null or u.statuses == null or u.statuses.by_id == null:
		return
	if u.statuses.by_id.is_empty():
		return

	var include_pending_owned := false
	if include_pending_sources is Dictionary:
		include_pending_owned = bool(include_pending_sources.get(int(target_id), false))

	for stack: StatusStack in u.statuses.get_all_stacks(include_pending_owned):
		if stack == null:
			continue
		if bool(stack.pending) and !include_pending_owned:
			continue

		var ctx := make_context(api, target_id, stack)
		if ctx == null or !ctx.is_valid():
			continue
		out.append(ctx)


static func _append_projected_status_contexts(
	out: Array[SimStatusContext],
	api: SimBattleAPI,
	target_id: int,
	include_pending_sources := {},
	allow_dead_self_aura_source := false
) -> void:
	if api == null or api.state == null or api.state.projection_bank == null:
		return

	var target: CombatantState = api.state.get_unit(target_id)
	if target == null:
		return

	for entry: Dictionary in api.state.projection_bank.get_entries():
		var source_kind := StringName(entry.get("source_kind", &""))
		match source_kind:
			ProjectionBank.SOURCE_KIND_STATUS_AURA:
				_append_status_aura_projected_contexts(
					out,
					api,
					target,
					target_id,
					entry,
					include_pending_sources,
					allow_dead_self_aura_source
				)
			ProjectionBank.SOURCE_KIND_ARCANUM:
				_append_arcanum_projected_contexts(out, api, target, target_id, entry)
			_:
				continue


static func _append_status_aura_projected_contexts(
	out: Array[SimStatusContext],
	api: SimBattleAPI,
	target: CombatantState,
	target_id: int,
	entry: Dictionary,
	include_pending_sources := {},
	allow_dead_self_aura_source := false
) -> void:
	var source_id := int(entry.get("source_owner_id", 0))
	if source_id <= 0:
		return

	var pending := bool(entry.get("pending", false))
	var include_pending_source := false
	if include_pending_sources is Dictionary:
		include_pending_source = bool(include_pending_sources.get(source_id, false))
	if pending and !include_pending_source:
		return

	var source: CombatantState = api.state.get_unit(source_id)
	if source == null:
		return
	if !source.is_alive() and !(allow_dead_self_aura_source and int(source_id) == int(target_id)):
		return

	var aura_status_id := StringName(entry.get("source_id", &""))
	var aura_proto := get_proto(api, aura_status_id) as Aura
	if aura_proto == null:
		return

	var aura_stack := source.statuses.get_status_stack(aura_status_id, pending) if source.statuses != null else null
	if aura_stack == null:
		return
	if int(aura_proto.expiration_policy) == int(Status.ExpirationPolicy.DURATION) and int(aura_stack.duration) <= 0:
		return
	if !aura_proto.affects_target(api.state, source_id, target_id):
		return

	for projected_proto: Status in aura_proto.get_projected_statuses():
		if projected_proto == null:
			continue

		var projected_ctx: SimStatusContext = SimAuraStatusContext.new(
			api,
			target_id,
			target,
			source_id,
			source,
			aura_status_id,
			pending,
			aura_proto,
			projected_proto
		)
		if projected_ctx == null or !projected_ctx.is_valid():
			continue

		out.append(projected_ctx)


static func _append_arcanum_projected_contexts(
	out: Array[SimStatusContext],
	api: SimBattleAPI,
	target: CombatantState,
	target_id: int,
	entry: Dictionary
) -> void:
	if api == null or api.state == null or api.state.arcana == null or api.state.arcana_catalog == null:
		return

	var arcanum_owner_id := int(entry.get("source_owner_id", 0))
	var arcanum_id := StringName(entry.get("source_id", &""))
	if arcanum_owner_id <= 0 or arcanum_id == &"":
		return

	var arcanum_entry: ArcanaState.ArcanumEntry = api.state.arcana.get_entry(arcanum_id)
	if arcanum_entry == null:
		return

	var arcanum_proto: Arcanum = api.state.arcana_catalog.get_proto(arcanum_id)
	if arcanum_proto == null or !arcanum_proto.affects_others():
		return
	if !arcanum_proto.affects_target(api.state, arcanum_owner_id, target_id):
		return

	for projected_proto: Status in arcanum_proto.get_projected_statuses():
		if projected_proto == null:
			continue
		if (
			int(projected_proto.expiration_policy) == int(Status.ExpirationPolicy.DURATION)
			and int(arcanum_proto.get_projection_duration(
				SimArcanumContext.new(
					api,
					arcanum_owner_id,
					SimBattleAPI.FRIENDLY,
					arcanum_entry,
					arcanum_proto
				)
			)) <= 0
		):
			continue

		var projected_ctx: SimStatusContext = SimProjectedArcanumStatusContext.new(
			api,
			target_id,
			target,
			arcanum_owner_id,
			arcanum_entry,
			arcanum_proto,
			projected_proto
		)
		if projected_ctx == null or !projected_ctx.is_valid():
			continue

		out.append(projected_ctx)


static func _merge_owned_and_projected_intensity_contexts(
	contexts: Array[SimStatusContext]
) -> Array[SimStatusContext]:
	if contexts.size() < 2:
		return contexts

	var owned_by_key: Dictionary = {}
	var projected_totals_by_key: Dictionary = {}

	for i in range(contexts.size()):
		var ctx := contexts[i]
		if ctx == null or !ctx.is_valid() or ctx.proto == null:
			continue

		var key := _make_effective_status_merge_key(ctx.get_status_id(), ctx.is_pending())
		if ctx is SimAuraStatusContext or ctx is SimProjectedArcanumStatusContext:
			projected_totals_by_key[key] = int(projected_totals_by_key.get(key, 0)) + int(ctx.get_intensity())
			continue

		if int(ctx.proto.reapply_type) != int(Status.ReapplyType.INTENSITY):
			continue

		owned_by_key[key] = {
			"index": i,
			"ctx": ctx,
		}

	if owned_by_key.is_empty() or projected_totals_by_key.is_empty():
		return contexts

	var mergeable_keys: Dictionary = {}
	for key in owned_by_key.keys():
		if projected_totals_by_key.has(key):
			mergeable_keys[key] = true

	if mergeable_keys.is_empty():
		return contexts

	var out: Array[SimStatusContext] = []
	for i in range(contexts.size()):
		var ctx := contexts[i]
		if ctx == null or !ctx.is_valid():
			continue

		var key := _make_effective_status_merge_key(ctx.get_status_id(), ctx.is_pending())
		if (ctx is SimAuraStatusContext or ctx is SimProjectedArcanumStatusContext) and mergeable_keys.has(key):
			continue

		var owned_info: Dictionary = owned_by_key.get(key, {})
		if !owned_info.is_empty() and int(owned_info.get("index", -1)) == i and mergeable_keys.has(key):
			var owned_ctx := owned_info.get("ctx", null) as SimStatusContext
			var merged_ctx := SimMergedIntensityStatusContext.new(
				owned_ctx,
				int(projected_totals_by_key.get(key, 0))
			) as SimStatusContext
			if merged_ctx != null and merged_ctx.is_valid():
				out.append(merged_ctx)
				continue

		out.append(ctx)

	return out


static func _make_effective_status_merge_key(status_id: StringName, pending: bool) -> String:
	return "%s::%s" % [String(status_id), "pending" if pending else "realized"]


# -------------------------------------------------------------------
# Generic expiration / ticking
# -------------------------------------------------------------------

static func _expire_by_policy(api: SimBattleAPI, group_index: int, policy: int) -> void:
	var ids := api.get_combatants_in_group(group_index, true)
	for cid in ids:
		_expire_unit_by_policy(api, int(cid), policy)

static func _expire_all_by_policy(api: SimBattleAPI, policy: int) -> void:
	if api == null or api.state == null:
		return

	for group_index in [SimBattleAPI.FRIENDLY, SimBattleAPI.ENEMY]:
		_expire_by_policy(api, int(group_index), policy)

static func _expire_unit_by_policy(api: SimBattleAPI, cid: int, policy: int) -> void:
	var u: CombatantState = api.state.get_unit(cid)
	if u == null or u.statuses == null:
		return
	if u.statuses.by_id.is_empty():
		return

	var to_remove: Array[StringName] = []

	for sid in u.statuses.get_status_ids(false):
		var proto := get_proto(api, sid)
		if proto == null:
			continue
		if int(proto.expiration_policy) == policy:
			to_remove.append(StringName(sid))

	for sid in to_remove:
		var rc := StatusContext.new()
		rc.source_id = cid
		rc.target_id = cid
		rc.status_id = sid
		api.remove_status(rc)

static func _tick_duration_statuses_for_owner_turn_end(api: SimBattleAPI, actor_id: int) -> void:
	var u: CombatantState = api.state.get_unit(actor_id)
	if u == null or u.statuses == null:
		return
	if u.statuses.by_id.is_empty():
		return

	var changed: Array[Dictionary] = []
	var expired: Array[StringName] = []

	for stack: StatusStack in u.statuses.get_all_stacks(false):
		if stack == null:
			continue

		var sid := StringName(stack.id)
		var proto := get_proto(api, sid)
		if proto == null:
			continue

		if int(proto.expiration_policy) != Status.ExpirationPolicy.DURATION:
			continue

		var before_i := int(stack.intensity)
		var before_d := int(stack.duration)

		if before_d <= 0:
			expired.append(StringName(sid))
			continue

		var after_d := before_d - 1
		stack.duration = after_d

		if after_d <= 0:
			expired.append(StringName(sid))
		else:
			changed.append({
				"sid": StringName(sid),
				"before_intensity": before_i,
				"before_duration": before_d,
				"after_intensity": before_i,
				"after_duration": after_d,
				"delta_intensity": 0,
				"delta_duration": -1,
			})

	if api.writer != null:
		for item in changed:
			api.writer.emit_status(
				actor_id,
				actor_id,
				item.sid,
				int(Status.OP.CHANGE),
				int(item.delta_intensity),
				int(item.delta_duration),
				{
					Keys.BEFORE_INTENSITY: int(item.before_intensity),
					Keys.BEFORE_DURATION: int(item.before_duration),
					Keys.AFTER_INTENSITY: int(item.after_intensity),
					Keys.AFTER_DURATION: int(item.after_duration),
					Keys.DELTA_INTENSITY: int(item.delta_intensity),
					Keys.DELTA_DURATION: int(item.delta_duration),
					Keys.REASON: "duration_tick",
				}
			)

	for sid in expired:
		var rc := StatusContext.new()
		rc.source_id = actor_id
		rc.target_id = actor_id
		rc.status_id = sid
		api.remove_status(rc)
