# status_grid_data.gd

class_name StatusGridData extends RefCounted

# enforce uniqueness by id
var by_id: Dictionary = {} # String -> StatusState

func clone() -> StatusGridData:
	var c := StatusGridData.new()
	for id in by_id.keys():
		c.by_id[id] = (by_id[id] as StatusState).clone()
	return c

func has_status(id: String) -> bool:
	return by_id.has(id)

func get_status(id: String) -> StatusState:
	return by_id.get(id, null)

func get_all() -> Array[StatusState]:
	var out: Array[StatusState] = []
	for s in by_id.values():
		out.append(s)
	return out

func remove_status(id: String) -> void:
	by_id.erase(id)

func add_or_reapply(proto: Status, incoming: StatusState) -> void:
	# incoming carries desired duration/intensity; proto carries authored semantics
	if !by_id.has(incoming.id):
		by_id[incoming.id] = incoming.clone()
		return

	var existing := by_id[incoming.id] as StatusState
	match proto.reapply_type:
		Status.ReapplyType.REPLACE:
			by_id[incoming.id] = incoming.clone()
		Status.ReapplyType.DURATION:
			if proto.expiration_policy == Status.ExpirationPolicy.DURATION:
				existing.duration += incoming.duration
		Status.ReapplyType.INTENSITY:
			existing.intensity += incoming.intensity
		Status.ReapplyType.IGNORE:
			pass

func tick_duration_statuses() -> void:
	# mirrors your _on_status_applied duration-- logic for ProcType durations,
	# but keep it explicit so sim can call it at the right time.
	var to_remove: Array[String] = []
	for id in by_id.keys():
		var s := by_id[id] as StatusState
		# expiration policy is authored; sim will check it via proto when needed.
		if s.duration <= 0:
			# do nothing here; removal is done by policy check
			pass

func remove_expired(status_catalog: Dictionary) -> void:
	# status_catalog: id -> Status (prototype resource)
	var to_remove: Array[String] = []
	for id in by_id.keys():
		var proto: Status = status_catalog.get(id, null)
		if !proto:
			to_remove.append(id)
			continue
		if proto.expiration_policy == Status.ExpirationPolicy.DURATION:
			var s := by_id[id] as StatusState
			if s.duration <= 0:
				to_remove.append(id)
	for id in to_remove:
		by_id.erase(id)

# is this supposed to go here?
func gather_sim_tokens(owner_state: FighterState, statuses: Array, proto_by_id: Dictionary) -> Array[ModifierToken]:
	var out: Array[ModifierToken] = []
	for s in statuses:
		var proto: Status = proto_by_id.get(s.id, null)
		if !proto or !proto.contributes_modifier():
			continue
		var ctx := proto.make_token_ctx_state(s, owner_state.combat_id)
		out.append_array(proto.get_modifier_tokens(ctx))
	return out
