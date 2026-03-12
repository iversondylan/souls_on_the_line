# sim_status_lifecycle_runner.gd

class_name SimStatusLifecycleRunner extends RefCounted

static func on_group_turn_begin(api: SimBattleAPI, group_index: int) -> void:
	if api == null or api.state == null:
		return
	_expire_by_policy(api, group_index, Status.ExpirationPolicy.GROUP_TURN_START)

static func on_group_turn_end(api: SimBattleAPI, group_index: int) -> void:
	if api == null or api.state == null:
		return
	_expire_by_policy(api, group_index, Status.ExpirationPolicy.GROUP_TURN_END)

static func on_actor_turn_begin(api: SimBattleAPI, actor_id: int) -> void:
	if api == null or api.state == null:
		return
	_tick_duration_for_proc(api, actor_id, Status.ProcType.START_OF_TURN)

static func on_actor_turn_end(api: SimBattleAPI, actor_id: int) -> void:
	if api == null or api.state == null:
		return
	_tick_duration_for_proc(api, actor_id, Status.ProcType.END_OF_TURN)

# -------------------------
# Internals
# -------------------------

static func _expire_by_policy(api: SimBattleAPI, group_index: int, policy: int) -> void:
	var ids := api.get_combatants_in_group(group_index, true) # include dead if you want cleanup; fine either way
	for cid in ids:
		_expire_unit_by_policy(api, int(cid), policy)

static func _expire_unit_by_policy(api: SimBattleAPI, cid: int, policy: int) -> void:
	var u: CombatantState = api.state.get_unit(cid)
	if u == null or u.statuses == null:
		return
	if u.statuses.by_id.is_empty():
		return

	var to_remove: Array[StringName] = []

	for sid in u.statuses.by_id.keys():
		var proto := _get_proto(api, sid)
		if proto == null:
			continue
		if int(proto.expiration_policy) == policy:
			to_remove.append(sid)

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

	# Collect changes first (don’t mutate dict while iterating)
	var changed: Array = [] # [{sid, new_dur, intensity}]
	var expired: Array[StringName] = []

	for sid in u.statuses.by_id.keys():
		var stack: StatusStack = u.statuses.by_id.get(sid, null)
		if stack == null:
			continue

		var proto := _get_proto(api, sid)
		if proto == null:
			continue

		# Only DURATION policy ticks
		if int(proto.expiration_policy) != Status.ExpirationPolicy.DURATION:
			continue

		# Decide WHEN it ticks: START_OF_TURN vs END_OF_TURN
		if int(proto.proc_type) != proc_type:
			continue

		var dur := int(stack.duration)
		if dur <= 0:
			# already expired in theory; treat as expired
			expired.append(sid)
			continue

		dur -= 1
		stack.duration = dur

		if dur <= 0:
			expired.append(sid)
		else:
			changed.append({ "sid": sid, "dur": dur, "intensity": int(stack.intensity) })

	# Emit changes (STATUS_CHANGED)
	if api.writer != null:
		for item in changed:
			api.writer.emit_status_changed(actor_id, actor_id, item.sid, int(item.intensity), int(item.dur))

	# Remove expired (STATUS_REMOVED + replan dirtied inside remove_status())
	for sid in expired:
		var rc := StatusContext.new()
		rc.source_id = actor_id
		rc.target_id = actor_id
		rc.status_id = sid
		api.remove_status(rc)

static func _get_proto(api: SimBattleAPI, sid: StringName) -> Status:
	if api == null or api.status_catalog == null:
		return null
	return api.status_catalog.get_proto(sid) as Status
