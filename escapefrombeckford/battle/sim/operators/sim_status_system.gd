# sim_status_system.gd

class_name SimStatusSystem extends RefCounted

# Owns status lifecycle and event dispatch.
# Turn progression belongs to SimRuntime.
# Atomistic mutations belong to SimBattleAPI.

static func on_group_turn_begin(api: SimBattleAPI, group_index: int) -> void:
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return

	for interceptor: Interceptor in api.get_interceptors_for_hook(Interceptor.HOOK_ON_GROUP_TURN_BEGIN):
		if interceptor != null:
			interceptor.dispatch(api, int(group_index))

	_auto_remove_for_group(api, group_index, Status.AutoRemove.GROUP_TURN_START)
	_tick_down_for_group(api, group_index, Status.AutoTickDown.GROUP_TURN_START)

static func on_group_turn_end(api: SimBattleAPI, group_index: int) -> void:
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return

	for interceptor: Interceptor in api.get_interceptors_for_hook(Interceptor.HOOK_ON_GROUP_TURN_END):
		if interceptor != null:
			interceptor.dispatch(api, int(group_index))

	_auto_remove_for_group(api, group_index, Status.AutoRemove.GROUP_TURN_END)
	_tick_down_for_group(api, group_index, Status.AutoTickDown.GROUP_TURN_END)

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

	for interceptor: Interceptor in api.get_interceptors_for_hook(Interceptor.HOOK_ON_PLAYER_TURN_BEGIN):
		if interceptor != null:
			interceptor.dispatch(api, int(player_id))

	_auto_remove_all(api, Status.AutoRemove.PLAYER_TURN_START)
	_tick_down_all(api, Status.AutoTickDown.PLAYER_TURN_START)

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

	_tick_down_for_actor_turn_end(api, actor_id)

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

static func on_card_played(
	api: SimBattleAPI,
	source_id: int,
	card: CardData
) -> void:
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return
	if int(source_id) <= 0 or card == null:
		return

	for unit_id in api.state.units.keys():
		var owner_id := int(unit_id)
		var owner := api.state.get_unit(owner_id)
		if owner == null or !owner.is_alive():
			continue

		_for_each_effective_status_on_unit(api, owner_id, func(ctx: SimStatusContext) -> void:
			if ctx.proto == null:
				return
			if !ctx.proto.listens_for_card_played():
				return
			ctx.proto.on_card_played(ctx, int(source_id), card)
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

static func on_any_death(
	api: SimBattleAPI,
	removal_ctx: RemovalContext,
	_listener_owner_ids: Array[int]
) -> void:
	if api == null or api.state == null or removal_ctx == null or api.state.has_terminal_outcome():
		return
	if int(removal_ctx.removal_type) != int(Removal.Type.DEATH):
		return
	for interceptor: Interceptor in api.get_interceptors_for_hook(Interceptor.HOOK_ON_ANY_DEATH):
		if interceptor != null:
			interceptor.dispatch(api, removal_ctx)

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

static func make_context(api: SimBattleAPI, owner_id: int, token: StatusToken) -> SimStatusContext:
	if api == null or api.state == null or owner_id <= 0 or token == null:
		return null

	var owner: CombatantState = api.state.get_unit(owner_id)
	if owner == null:
		return null

	var proto := get_proto(api, token.id)
	if proto == null:
		return null

	return SimStatusContext.new(api, owner_id, owner, token, proto)


static func make_projected_context(api: SimBattleAPI, owner_id: int, token: StatusToken) -> SimStatusContext:
	if api == null or api.state == null or owner_id <= 0 or token == null:
		return null

	var owner: CombatantState = api.state.get_unit(owner_id)
	if owner == null:
		return null

	var proto := get_proto(api, token.id)
	if proto == null:
		return null

	return SimStatusContext.new(api, owner_id, owner, token, proto, true)

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
	if target != null and target.statuses != null and target.statuses.has_cached_effective_contexts(
		unit_status_version
	):
		return target.statuses.get_cached_effective_contexts(unit_status_version)

	# Pending owned tokens are fully live, so effective status queries always
	# report both owned lanes and the collapsed projected cache with no preview-only
	# inclusion path.
	_append_owned_status_contexts(owned, api, target_id)
	refresh_cached_projected_statuses_for_unit(api, target_id)
	_append_cached_projected_status_contexts(projected, api, target_id)
	var merged := _merge_owned_and_projected_contexts(owned, projected)
	if target != null and target.statuses != null:
		target.statuses.set_cached_effective_contexts(unit_status_version, merged)
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
	if u == null or !u.is_alive():
		return

	var pending_ids := u.statuses.get_status_ids(true, true)
	if pending_ids.is_empty():
		return

	var any_changed := false
	var src_id := int(source_id if source_id > 0 else target_id)
	var mutation_results: Array[StatusMutationResult] = []

	for status_id in pending_ids:
		var proto := get_proto(api, status_id)
		var status_max_stacks := int(proto.get_max_stacks()) if proto != null else 0

		var ctx := StatusContext.new()
		ctx.actor_id = int(target_id)
		ctx.source_id = src_id
		ctx.target_id = int(target_id)
		ctx.status_id = status_id
		ctx.pending = true
		ctx.reason = reason

		var mutation := u.statuses.realize_pending_ctx(ctx, status_max_stacks)
		mutation.apply_to_status_context(ctx)
		if !mutation.changed:
			continue

		any_changed = true
		mutation_results.append(mutation)
		if api.writer != null:
			api.writer.emit_status(
				int(ctx.source_id),
				int(ctx.target_id),
				ctx.status_id,
				int(ctx.op),
				int(ctx.stacks),
				{
					Keys.STATUS_PENDING: bool(ctx.after_pending),
					Keys.DELTA_STACKS: int(ctx.delta_stacks),
					Keys.BEFORE_PENDING: bool(ctx.before_pending),
					Keys.AFTER_PENDING: bool(ctx.after_pending),
					Keys.BEFORE_TOKEN_ID: int(ctx.before_token_id),
					Keys.AFTER_TOKEN_ID: int(ctx.after_token_id),
					Keys.BEFORE_STACKS: int(ctx.before_stacks),
					Keys.AFTER_STACKS: int(ctx.after_stacks),
					Keys.REASON: String(reason),
				}
			)

	if !any_changed:
		return

	api._refresh_projected_status_cache_for(int(target_id))
	for mutation: StatusMutationResult in mutation_results:
		api._sync_status_transformers_from_mutation(
			int(target_id),
			mutation.status_id,
			int(mutation.before_token_id),
			int(mutation.after_token_id)
		)


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
	if u == null:
		return
	if u.statuses.by_id.is_empty():
		return

	for token: StatusToken in u.statuses.get_all_tokens(true):
		if token == null:
			continue

		var ctx := make_context(api, owner_id, token)
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
	if u == null:
		return
	if u.statuses.by_id.is_empty():
		return

	for token: StatusToken in u.statuses.get_all_tokens(true):
		if token == null:
			continue

		var ctx := make_context(api, target_id, token)
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
	if target == null:
		return
	for projected_token: StatusToken in target.statuses.get_all_projected_tokens():
		if projected_token == null:
			continue
		var projected_ctx := make_projected_context(api, target_id, projected_token)
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
		projected_totals_by_key[key] = int(projected_totals_by_key.get(key, 0)) + int(ctx.get_stacks())

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
		if int(ctx.proto.get_effective_reapply_type()) != int(Status.ReapplyType.ADD):
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
	if target == null:
		return

	var proto_resolver := func(status_id: StringName):
		return get_proto(api, status_id)
	var entries_by_key := _collect_projection_entries_by_source_key(api)
	if full_rebuild:
		target.statuses.clear_projected()
		for source_key in entries_by_key.get_source_keys():
			var record := entries_by_key.get_record(source_key)
			target.statuses.upsert_projected_source(
				source_key,
				_build_projected_tokens_for_entry(api, target_id, record),
				{
					"priority": int(record.priority) if record != null else 0,
					"tid": int(record.tid) if record != null else 0,
				},
				proto_resolver
			)
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
		if !entries_by_key.has_record(source_key):
			target.statuses.remove_projected_source(source_key, proto_resolver)
			continue
		var record := entries_by_key.get_record(source_key)
		target.statuses.upsert_projected_source(
			source_key,
			_build_projected_tokens_for_entry(api, target_id, record),
			{
				"priority": int(record.priority) if record != null else 0,
				"tid": int(record.tid) if record != null else 0,
			},
			proto_resolver
		)
	target.statuses.set_projected_cache_ready(true)

static func _collect_projection_entries_by_source_key(api: SimBattleAPI) -> TransformerRecordLookup:
	var out := TransformerRecordLookup.new()
	if api == null or api.state == null or api.state.transformer_registry == null:
		return out

	# This is a source-keyed lookup over the full projection transformer slice.
	# Per-target relevance is checked later when each source is materialized.
	for record: TransformerRecord in api.state.transformer_registry.get_projection_records():
		out.set_record(record)
	return out

static func _build_projected_tokens_for_entry(
	api: SimBattleAPI,
	target_id: int,
	record: TransformerRecord
) -> Array[StatusToken]:
	var out: Array[StatusToken] = []
	if record == null:
		return out
	var source_kind := record.source_kind
	match source_kind:
		TransformerRecord.SOURCE_KIND_STATUS_TOKEN:
			_append_status_aura_projected_tokens(out, api, target_id, record)
		TransformerRecord.SOURCE_KIND_ARCANUM_ENTRY:
			_append_arcanum_projected_tokens(out, api, target_id, record)
		_:
			return out
	return out

static func _append_status_aura_projected_tokens(
	out: Array[StatusToken],
	api: SimBattleAPI,
	target_id: int,
	record: TransformerRecord
) -> void:
	if api == null or api.state == null:
		return

	var source_id := int(record.source_owner_id)
	if source_id <= 0:
		return
	var source: CombatantState = api.state.get_unit(source_id)
	if source == null or !source.is_alive():
		return

	var aura_status_id := StringName(record.source_id)
	var aura_proto := get_proto(api, aura_status_id) as Aura
	if aura_proto == null:
		return
	if !aura_proto.affects_target(api.state, source_id, target_id):
		return

	var aura_token := source.statuses.get_status_token_by_token_id(int(record.source_instance_id), true)
	if aura_token == null or StringName(aura_token.id) != aura_status_id:
		return
	var aura_stacks := maxi(int(aura_token.stacks), 0)

	if aura_stacks <= 0 and bool(aura_proto.numerical):
		return

	for projected_proto: Status in aura_proto.get_projected_statuses():
		if projected_proto == null:
			continue
		# Pending aura tokens are fully live, but targets only ever see the combined
		# projected result as a single non-pending token.
		var projected_token := StatusToken.new(StringName(projected_proto.get_id()))
		projected_token.pending = false
		projected_token.stacks = aura_stacks
		out.append(projected_token)

static func _append_arcanum_projected_tokens(
	out: Array[StatusToken],
	api: SimBattleAPI,
	target_id: int,
	record: TransformerRecord
) -> void:
	if api == null or api.state == null or api.state.arcana == null or api.state.arcana_catalog == null:
		return
	var arcanum_owner_id := int(record.source_owner_id)
	var arcanum_id := StringName(record.source_id)
	if arcanum_owner_id <= 0 or arcanum_id == &"":
		return

	var arcanum_entry: ArcanumEntry = api.state.arcana.get_entry(arcanum_id)
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

	for projected_proto: Status in arcanum_proto.get_projected_statuses():
		if projected_proto == null:
			continue
		var projected_token := StatusToken.new(StringName(projected_proto.get_id()))
		projected_token.pending = false
		projected_token.stacks = _resolve_projected_stacks(projected_proto, projection_intensity, projection_duration)
		if projected_proto != null and bool(projected_proto.numerical) and int(projected_token.stacks) <= 0:
			continue
		out.append(projected_token)

static func _make_effective_status_merge_key(status_id: StringName, pending: bool) -> String:
	return "%s::%s" % [String(status_id), "pending" if pending else "realized"]


# -------------------------------------------------------------------
# Generic expiration / ticking
# -------------------------------------------------------------------

static func _resolve_projected_stacks(projected_proto: Status, projection_intensity: int, projection_duration: int) -> int:
	if projected_proto == null:
		return 0
	if int(projected_proto.auto_tick_down) != int(Status.AutoTickDown.NEVER):
		return projection_duration
	if !bool(projected_proto.numerical):
		return 1 if projection_intensity > 0 or projection_duration > 0 else 0
	return projection_intensity

static func _auto_remove_for_group(api: SimBattleAPI, group_index: int, policy: int) -> void:
	var ids := api.get_combatants_in_group(group_index, true)
	for cid in ids:
		_auto_remove_unit(api, int(cid), policy)

static func _auto_remove_all(api: SimBattleAPI, policy: int) -> void:
	if api == null or api.state == null:
		return
	for group_index in [SimBattleAPI.FRIENDLY, SimBattleAPI.ENEMY]:
		_auto_remove_for_group(api, int(group_index), policy)

static func _auto_remove_unit(api: SimBattleAPI, cid: int, policy: int) -> void:
	var u: CombatantState = api.state.get_unit(cid)
	if u == null or u.statuses.by_id.is_empty():
		return

	var to_remove: Array[Dictionary] = []
	for token: StatusToken in u.statuses.get_all_tokens(true):
		if token == null:
			continue
		var sid := StringName(token.id)
		var proto := get_proto(api, sid)
		if proto == null:
			continue
		if int(proto.auto_remove) == policy:
			to_remove.append({
				"status_id": sid,
				"pending": bool(token.pending),
			})

	for item in to_remove:
		var rc := StatusContext.new()
		rc.source_id = cid
		rc.target_id = cid
		rc.status_id = StringName(item.status_id)
		rc.pending = bool(item.pending)
		api.remove_status(rc)

static func _tick_down_for_actor_turn_end(api: SimBattleAPI, actor_id: int) -> void:
	_tick_down_unit(api, actor_id, Status.AutoTickDown.ACTOR_TURN_END, "auto_tick_down")

static func _tick_down_for_group(api: SimBattleAPI, group_index: int, policy: int) -> void:
	var ids := api.get_combatants_in_group(group_index, true)
	for cid in ids:
		_tick_down_unit(api, int(cid), policy, "auto_tick_down")

static func _tick_down_all(api: SimBattleAPI, policy: int) -> void:
	if api == null or api.state == null:
		return
	for group_index in [SimBattleAPI.FRIENDLY, SimBattleAPI.ENEMY]:
		_tick_down_for_group(api, int(group_index), policy)

static func _tick_down_unit(api: SimBattleAPI, owner_id: int, policy: int, reason: String) -> void:
	var u: CombatantState = api.state.get_unit(owner_id)
	if u == null or u.statuses.by_id.is_empty():
		return

	var changed: Array[Dictionary] = []
	var removed: Array[Dictionary] = []

	for token: StatusToken in u.statuses.get_all_tokens(true):
		if token == null:
			continue
		var sid := StringName(token.id)
		var proto := get_proto(api, sid)
		if proto == null:
			continue
		if int(proto.auto_tick_down) != policy:
			continue

		var before_stacks := int(token.stacks)
		var pending := bool(token.pending)
		var after_stacks := before_stacks - 1
		u.statuses.set_token(sid, after_stacks, pending)

		if bool(proto.numerical) and after_stacks <= 0:
			removed.append({"sid": sid, "pending": pending})
		else:
			changed.append({
				"sid": sid,
				"pending": pending,
				"token_id": int(token.token_id),
				"before_stacks": before_stacks,
				"after_stacks": after_stacks,
				"delta_stacks": -1,
			})

	if api.writer != null:
		for item in changed:
			api.writer.emit_status(
				owner_id,
				owner_id,
				item.sid,
				int(Status.OP.CHANGE),
				int(item.delta_stacks),
				{
					Keys.STATUS_PENDING: bool(item.pending),
					Keys.BEFORE_PENDING: bool(item.pending),
					Keys.AFTER_PENDING: bool(item.pending),
					Keys.BEFORE_TOKEN_ID: int(item.token_id),
					Keys.AFTER_TOKEN_ID: int(item.token_id),
					Keys.BEFORE_STACKS: int(item.before_stacks),
					Keys.AFTER_STACKS: int(item.after_stacks),
					Keys.DELTA_STACKS: int(item.delta_stacks),
					Keys.REASON: reason,
				}
			)

	for item in removed:
		var rc := StatusContext.new()
		rc.source_id = owner_id
		rc.target_id = owner_id
		rc.status_id = StringName(item.sid)
		rc.pending = bool(item.pending)
		api.remove_status(rc)
