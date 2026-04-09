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

static func on_actor_turn_end(api: SimBattleAPI, actor_id: int) -> void:
	if api == null or api.state == null:
		return
	_tick_duration_statuses_for_owner_turn_end(api, actor_id)

static func _expire_by_policy(api: SimBattleAPI, group_index: int, policy: int) -> void:
	var ids := api.get_combatants_in_group(group_index, true)
	for cid in ids:
		_expire_unit_by_policy(api, int(cid), policy)

static func _expire_unit_by_policy(api: SimBattleAPI, cid: int, policy: int) -> void:
	var u: CombatantState = api.state.get_unit(cid)
	if u == null or u.statuses == null:
		return
	if u.statuses.by_id.is_empty():
		return

	var to_remove: Array[StringName] = []

	for sid in u.statuses.get_status_ids(false):
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
		var proto := _get_proto(api, sid)
		if proto == null:
			continue

		if int(proto.expiration_policy) != Status.ExpirationPolicy.DURATION:
			continue

		var before_i := int(stack.intensity)
		var before_d := int(stack.duration)

		if before_d <= 0:
			expired.append(sid)
			continue

		var after_d := before_d - 1
		stack.duration = after_d

		if after_d <= 0:
			expired.append(sid)
		else:
			changed.append({
				"sid": sid,
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

static func _get_proto(api: SimBattleAPI, sid: StringName) -> Status:
	if api == null or api.status_catalog == null:
		return null
	return api.status_catalog.get_proto(sid) as Status
