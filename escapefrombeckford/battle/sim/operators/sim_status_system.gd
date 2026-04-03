# sim_status_system.gd

class_name SimStatusSystem extends RefCounted

const SimAuraStatusContextScript = preload("res://battle/sim/containers/sim_aura_status_context.gd")

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

	_tick_duration_for_proc(api, actor_id, Status.ProcType.START_OF_TURN)

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

static func on_actor_turn_end(api: SimBattleAPI, actor_id: int) -> void:
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return

	_for_each_effective_status_on_unit(api, actor_id, func(ctx: SimStatusContext) -> void:
		if ctx.proto != null:
			ctx.proto.on_actor_turn_end(ctx)
	)

	_tick_duration_for_proc(api, actor_id, Status.ProcType.END_OF_TURN)

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

static func on_death(api: SimBattleAPI, dead_id: int, killer_id: int, reason: String) -> void:
	if api == null or api.state == null or dead_id <= 0 or api.state.has_terminal_outcome():
		return

	var fn := func(ctx: SimStatusContext) -> void:
		if ctx.proto != null:
			ctx.proto.on_death(ctx, dead_id, killer_id, reason)

	_for_each_effective_status_on_unit(api, dead_id, fn, true)

static func unit_grants_attack_spillthrough(api: SimBattleAPI, owner_id: int) -> bool:
	return _unit_grants_spillthrough_internal(api, owner_id, true)

static func unit_grants_received_spillthrough(api: SimBattleAPI, owner_id: int) -> bool:
	return _unit_grants_spillthrough_internal(api, owner_id, false)

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
	_append_projected_aura_status_contexts(
		out,
		api,
		target_id,
		include_pending_sources,
		allow_dead_self_aura_source
	)
	return out


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


static func _unit_grants_spillthrough_internal(
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
				proto.grants_attack_spillthrough(ctx)
				if attack_side
				else proto.grants_received_spillthrough(ctx)
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


static func _append_projected_aura_status_contexts(
	out: Array[SimStatusContext],
	api: SimBattleAPI,
	target_id: int,
	include_pending_sources := {},
	allow_dead_self_aura_source := false
) -> void:
	if api == null or api.state == null or api.state.aura_bank == null:
		return

	var target: CombatantState = api.state.get_unit(target_id)
	if target == null:
		return

	for entry: Dictionary in api.state.aura_bank.get_entries():
		var source_id := int(entry.get("source_id", 0))
		if source_id <= 0:
			continue

		var pending := bool(entry.get("pending", false))
		var include_pending_source := false
		if include_pending_sources is Dictionary:
			include_pending_source = bool(include_pending_sources.get(source_id, false))
		if pending and !include_pending_source:
			continue

		var source: CombatantState = api.state.get_unit(source_id)
		if source == null:
			continue
		if !source.is_alive() and !(allow_dead_self_aura_source and int(source_id) == int(target_id)):
			continue

		var aura_status_id := StringName(entry.get("status_id", &""))
		var aura_proto := get_proto(api, aura_status_id) as Aura
		if aura_proto == null:
			continue

		var aura_stack := source.statuses.get_status_stack(aura_status_id, pending) if source.statuses != null else null
		if aura_stack == null:
			continue
		if int(aura_proto.expiration_policy) == int(Status.ExpirationPolicy.DURATION) and int(aura_stack.duration) <= 0:
			continue
		if !aura_proto.affects_target(api.state, source_id, target_id):
			continue

		for projected_proto: Status in aura_proto.get_projected_statuses():
			if projected_proto == null:
				continue

			var projected_ctx: SimStatusContext = SimAuraStatusContextScript.new(
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

static func _tick_duration_for_proc(api: SimBattleAPI, actor_id: int, proc_type: int) -> void:
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
		if int(proto.proc_type) != proc_type:
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
