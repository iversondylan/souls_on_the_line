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
	attack_ctx: AttackContext
) -> void:
	if api == null or api.state == null or attack_ctx == null or api.state.has_terminal_outcome():
		return

	var attacker_id := int(attack_ctx.attacker_id)
	if attacker_id <= 0:
		return

	var fn := func(ctx: SimStatusContext) -> void:
		if ctx.proto != null:
			ctx.proto.on_attack_will_run(ctx, attack_ctx)

	_for_each_effective_status_on_unit(api, attacker_id, fn)

static func on_strike_resolved(
	api: SimBattleAPI,
	attacker_id: int,
	attack_ctx: AttackContext,
	strike_index: int,
	target_ids: Array[int]
) -> void:
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return
	if int(attacker_id) <= 0 or attack_ctx == null or target_ids.is_empty():
		return

	_for_each_effective_status_on_unit(api, attacker_id, func(ctx: SimStatusContext) -> void:
		if ctx.proto != null:
			ctx.proto.on_strike_resolved(ctx, attack_ctx, strike_index, target_ids)
	)

static func on_summon_will_resolve(
	api: SimBattleAPI,
	source_id: int,
	summon_ctx: SummonContext,
	summoned: CombatantState
) -> void:
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return
	if int(source_id) <= 0 or summon_ctx == null or summoned == null:
		return

	_for_each_effective_status_on_unit(api, source_id, func(ctx: SimStatusContext) -> void:
		if ctx.proto != null:
			ctx.proto.on_summon_will_resolve(ctx, summon_ctx, summoned)
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

	_for_each_effective_status_on_unit(api, removed_id, fn)

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

# Daddy's favorite function
static func get_effective_status_contexts_for_unit(
	api: SimBattleAPI,
	target_id: int
) -> Array[SimStatusContext]:
	var owned: Array[SimStatusContext] = []
	var projected: Array[SimStatusContext] = []
	if api == null or api.state == null or target_id <= 0:
		return owned
	var target: CombatantState = api.state.get_unit(int(target_id))
	var unit_status_version := 0
	if target != null and target.statuses != null:
		unit_status_version = int(target.statuses.get_effective_context_version())
	if api.has_cached_effective_status_contexts_for_unit(
		int(target_id),
		unit_status_version
	):
		return api._get_cached_effective_status_contexts_for_unit(
			int(target_id),
			unit_status_version
		)

	# Pending owned stacks are fully live, so effective status queries always
	# report both owned lanes and the collapsed projected cache with no preview-only
	# inclusion path.
	_append_owned_status_contexts(owned, api, target_id)
	refresh_cached_projected_statuses_for_unit(api, target_id)
	_append_cached_projected_status_contexts(projected, api, target_id)
	var merged := _merge_owned_and_projected_contexts(owned, projected)
	api._set_cached_effective_status_contexts_for_unit(
		int(target_id),
		unit_status_version,
		merged
	)
	return merged

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

	var any_changed := false
	var src_id := int(source_id if source_id > 0 else target_id)
	var changed_aura_ids: Array[StringName] = []

	for status_id in pending_ids:
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

		if is_aura_proto(proto):
			changed_aura_ids.append(status_id)

	if !any_changed:
		return

	api._refresh_projected_status_cache_for(int(target_id))
	for aura_status_id in changed_aura_ids:
		api._refresh_status_aura_projection(int(target_id), aura_status_id)


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

	for stack: StatusStack in u.statuses.get_all_stacks(true):
		if stack == null:
			continue

		var ctx := make_context(api, owner_id, stack)
		if ctx == null or !ctx.is_valid():
			continue

		fn.call(ctx)

static func _for_each_effective_status_on_unit(
	api: SimBattleAPI,
	owner_id: int,
	fn: Callable
) -> void:
	if api == null or api.state == null or owner_id <= 0 or !fn.is_valid():
		return

	for ctx: SimStatusContext in get_effective_status_contexts_for_unit(api, owner_id):
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
	target_id: int
) -> void:
	if api == null or api.state == null:
		return

	var u: CombatantState = api.state.get_unit(target_id)
	if u == null or u.statuses == null or u.statuses.by_id == null:
		return
	if u.statuses.by_id.is_empty():
		return

	for stack: StatusStack in u.statuses.get_all_stacks(true):
		if stack == null:
			continue

		var ctx := make_context(api, target_id, stack)
		if ctx == null or !ctx.is_valid():
			continue
		out.append(ctx)

static func _append_cached_projected_status_contexts(
	out: Array[SimStatusContext],
	api: SimBattleAPI,
	target_id: int
) -> void:
	if api == null or api.state == null:
		return
	var target: CombatantState = api.state.get_unit(target_id)
	if target == null or target.statuses == null:
		return
	for projected_stack: StatusStack in target.statuses.get_all_projected_stacks():
		if projected_stack == null:
			continue
		var projected_ctx := make_context(api, target_id, projected_stack)
		if projected_ctx == null or !projected_ctx.is_valid():
			continue
		out.append(projected_ctx)



static func _merge_owned_and_projected_contexts(
	owned_contexts: Array[SimStatusContext],
	projected_contexts: Array[SimStatusContext]
) -> Array[SimStatusContext]:
	if projected_contexts.is_empty():
		return owned_contexts
	if owned_contexts.is_empty():
		return projected_contexts

	var projected_totals_by_key: Dictionary = {}
	for projected_ctx in projected_contexts:
		var ctx := projected_ctx as SimStatusContext
		if ctx == null or !ctx.is_valid() or ctx.proto == null:
			continue
		var key := _make_effective_status_merge_key(ctx.get_status_id(), ctx.is_pending())
		projected_totals_by_key[key] = int(projected_totals_by_key.get(key, 0)) + int(ctx.get_intensity())

	if projected_totals_by_key.is_empty():
		var passthrough: Array[SimStatusContext] = []
		passthrough.append_array(owned_contexts)
		passthrough.append_array(projected_contexts)
		return passthrough

	var owned_by_key: Dictionary = {}
	for i in range(owned_contexts.size()):
		var ctx := owned_contexts[i]
		if ctx == null or !ctx.is_valid() or ctx.proto == null:
			continue

		var key := _make_effective_status_merge_key(ctx.get_status_id(), ctx.is_pending())
		if int(ctx.proto.reapply_type) != int(Status.ReapplyType.INTENSITY):
			continue

		owned_by_key[key] = {
			"index": i,
			"ctx": ctx,
		}

	if owned_by_key.is_empty():
		var concatenated: Array[SimStatusContext] = []
		concatenated.append_array(owned_contexts)
		concatenated.append_array(projected_contexts)
		return concatenated

	var mergeable_keys: Dictionary = {}
	for key in owned_by_key.keys():
		if projected_totals_by_key.has(key):
			mergeable_keys[key] = true

	if mergeable_keys.is_empty():
		var untouched: Array[SimStatusContext] = []
		untouched.append_array(owned_contexts)
		untouched.append_array(projected_contexts)
		return untouched

	var out: Array[SimStatusContext] = []
	for i in range(owned_contexts.size()):
		var ctx := owned_contexts[i]
		if ctx == null or !ctx.is_valid():
			continue

		var key := _make_effective_status_merge_key(ctx.get_status_id(), ctx.is_pending())
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

	for projected_ctx in projected_contexts:
		var ctx := projected_ctx as SimStatusContext
		if ctx == null or !ctx.is_valid():
			continue
		var key := _make_effective_status_merge_key(ctx.get_status_id(), ctx.is_pending())
		if mergeable_keys.has(key):
			continue
		out.append(ctx)

	return out

static func refresh_cached_projected_statuses_for_unit(
	api: SimBattleAPI,
	target_id: int,
	source_keys: Array[String] = [],
	full_rebuild := false
) -> void:
	if api == null or api.state == null or target_id <= 0:
		return
	var target: CombatantState = api.state.get_unit(target_id)
	if target == null or target.statuses == null:
		return

	var entries_by_key := _collect_projection_entries_by_source_key(api)
	if full_rebuild:
		target.statuses.clear_projected()
		for source_key in entries_by_key.get_source_keys():
			var entry := entries_by_key.get_entry(source_key)
			target.statuses.upsert_projected_source(source_key, _build_projected_stacks_for_entry(api, target_id, entry))
		target.statuses.set_projected_cache_ready(true)
		return

	if source_keys.is_empty():
		if !target.statuses.is_projected_cache_ready():
			refresh_cached_projected_statuses_for_unit(api, target_id, [], true)
		return

	var unique_source_keys := {}
	for source_key in source_keys:
		if String(source_key).is_empty():
			continue
		unique_source_keys[String(source_key)] = true

	for source_key_variant in unique_source_keys.keys():
		var source_key := String(source_key_variant)
		if !entries_by_key.has_entry(source_key):
			target.statuses.remove_projected_source(source_key)
			continue
		var entry := entries_by_key.get_entry(source_key)
		target.statuses.upsert_projected_source(
			source_key,
			_build_projected_stacks_for_entry(api, target_id, entry)
		)
	target.statuses.set_projected_cache_ready(true)

static func _collect_projection_entries_by_source_key(api: SimBattleAPI) -> ProjectionSourceEntryLookup:
	var out := ProjectionSourceEntryLookup.new()
	if api == null or api.state == null or api.state.projection_bank == null:
		return out

	# This is a source-keyed lookup over the full projection bank.
	# Per-target relevance is checked later when each source is materialized.
	for entry: ProjectionSourceEntry in api.state.projection_bank.get_entries():
		out.set_entry(entry)
	return out

static func _build_projected_stacks_for_entry(
	api: SimBattleAPI,
	target_id: int,
	entry: ProjectionSourceEntry
) -> Array[StatusStack]:
	var out: Array[StatusStack] = []
	if entry == null:
		return out
	var source_kind := entry.source_kind
	match source_kind:
		ProjectionBank.SOURCE_KIND_STATUS_AURA:
			_append_status_aura_projected_stacks(out, api, target_id, entry)
		ProjectionBank.SOURCE_KIND_ARCANUM:
			_append_arcanum_projected_stacks(out, api, target_id, entry)
		_:
			return out
	return out

static func _append_status_aura_projected_stacks(
	out: Array[StatusStack],
	api: SimBattleAPI,
	target_id: int,
	entry: ProjectionSourceEntry
) -> void:
	if api == null or api.state == null:
		return

	var source_id := int(entry.source_owner_id)
	if source_id <= 0:
		return
	var source: CombatantState = api.state.get_unit(source_id)
	if source == null or !source.is_alive():
		return

	var aura_status_id := StringName(entry.source_id)
	var aura_proto := get_proto(api, aura_status_id) as Aura
	if aura_proto == null:
		return
	if source.statuses == null:
		return
	if !aura_proto.affects_target(api.state, source_id, target_id):
		return

	var total_intensity := 0
	var max_duration := 0
	for aura_stack: StatusStack in source.statuses.get_all_stacks(true):
		if aura_stack == null or StringName(aura_stack.id) != aura_status_id:
			continue
		if int(aura_proto.expiration_policy) == int(Status.ExpirationPolicy.DURATION) and int(aura_stack.duration) <= 0:
			continue
		total_intensity += maxi(int(aura_stack.intensity), 0)
		max_duration = maxi(max_duration, int(aura_stack.duration))

	if total_intensity <= 0:
		return

	for projected_proto: Status in aura_proto.get_projected_statuses():
		if projected_proto == null:
			continue
		# Pending aura stacks are fully live, but targets only ever see the combined
		# projected result as a single non-pending stack.
		var projected_stack := StatusStack.new(StringName(projected_proto.get_id()))
		projected_stack.pending = false
		projected_stack.intensity = total_intensity
		projected_stack.duration = max_duration
		out.append(projected_stack)

static func _append_arcanum_projected_stacks(
	out: Array[StatusStack],
	api: SimBattleAPI,
	target_id: int,
	entry: ProjectionSourceEntry
) -> void:
	if api == null or api.state == null or api.state.arcana == null or api.state.arcana_catalog == null:
		return
	var arcanum_owner_id := int(entry.source_owner_id)
	var arcanum_id := StringName(entry.source_id)
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

	var arcanum_ctx := SimArcanumContext.new(
		api,
		arcanum_owner_id,
		SimBattleAPI.FRIENDLY,
		arcanum_entry,
		arcanum_proto
	)
	if arcanum_ctx == null or !arcanum_ctx.is_valid():
		return

	var projection_intensity := maxi(int(arcanum_proto.get_projection_intensity(arcanum_ctx)), 0)
	var projection_duration := maxi(int(arcanum_proto.get_projection_duration(arcanum_ctx)), 0)
	if projection_intensity <= 0:
		return

	for projected_proto: Status in arcanum_proto.get_projected_statuses():
		if projected_proto == null:
			continue
		if (
			int(projected_proto.expiration_policy) == int(Status.ExpirationPolicy.DURATION)
			and projection_duration <= 0
		):
			continue
		var projected_stack := StatusStack.new(StringName(projected_proto.get_id()))
		projected_stack.pending = false
		projected_stack.intensity = projection_intensity
		projected_stack.duration = projection_duration
		out.append(projected_stack)

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

	var to_remove: Array[Dictionary] = []

	for stack: StatusStack in u.statuses.get_all_stacks(true):
		if stack == null:
			continue
		var sid := StringName(stack.id)
		var proto := get_proto(api, sid)
		if proto == null:
			continue
		if int(proto.expiration_policy) == policy:
			to_remove.append({
				"status_id": sid,
				"pending": bool(stack.pending),
			})

	for item in to_remove:
		var rc := StatusContext.new()
		rc.source_id = cid
		rc.target_id = cid
		rc.status_id = StringName(item.status_id)
		rc.pending = bool(item.pending)
		api.remove_status(rc)

static func _tick_duration_statuses_for_owner_turn_end(api: SimBattleAPI, actor_id: int) -> void:
	var u: CombatantState = api.state.get_unit(actor_id)
	if u == null or u.statuses == null:
		return
	if u.statuses.by_id.is_empty():
		return

	var changed: Array[Dictionary] = []
	var expired: Array[Dictionary] = []

	for stack: StatusStack in u.statuses.get_all_stacks(true):
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
		var pending := bool(stack.pending)

		if before_d <= 0:
			expired.append({
				"sid": StringName(sid),
				"pending": pending,
			})
			continue

		var after_d := before_d - 1
		u.statuses.set_stack(sid, before_i, after_d, pending)

		if after_d <= 0:
			expired.append({
				"sid": StringName(sid),
				"pending": pending,
			})
		else:
			changed.append({
				"sid": StringName(sid),
				"pending": pending,
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
					Keys.STATUS_PENDING: bool(item.pending),
					Keys.BEFORE_PENDING: bool(item.pending),
					Keys.AFTER_PENDING: bool(item.pending),
					Keys.BEFORE_INTENSITY: int(item.before_intensity),
					Keys.BEFORE_DURATION: int(item.before_duration),
					Keys.AFTER_INTENSITY: int(item.after_intensity),
					Keys.AFTER_DURATION: int(item.after_duration),
					Keys.DELTA_INTENSITY: int(item.delta_intensity),
					Keys.DELTA_DURATION: int(item.delta_duration),
					Keys.REASON: "duration_tick",
				}
			)

	for item in expired:
		var rc := StatusContext.new()
		rc.source_id = actor_id
		rc.target_id = actor_id
		rc.status_id = StringName(item.sid)
		rc.pending = bool(item.pending)
		api.remove_status(rc)
