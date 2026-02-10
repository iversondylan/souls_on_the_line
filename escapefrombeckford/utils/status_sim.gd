# status_sim.gd (static helper)

class_name StatusSim extends RefCounted

static func get_modifier_tokens_for_owner(
	status_grid: StatusGridData,
	catalog: StatusCatalog,
	owner_combat_id: int
) -> Array[ModifierToken]:
	var out: Array[ModifierToken] = []

	for s: StatusState in status_grid.get_all():
		var proto := catalog.get_proto(s.id)
		if !proto:
			continue
		if proto.expiration_policy == Status.ExpirationPolicy.DURATION and s.duration <= 0:
			continue
		if !proto.contributes_modifier():
			continue

		var inst: Status = proto.duplicate()
		inst.duration = s.duration
		inst.intensity = s.intensity

		var ctx := StatusTokenContext.new()
		ctx.owner_id = owner_combat_id

		var tokens := inst.get_modifier_tokens(ctx)
		for t in tokens:
			# make sure sim tokens use owner_id (not node owner)
			if t and t.owner_id == 0:
				t.owner_id = owner_combat_id
		out.append_array(tokens)

	return out


static func gather_sim_tokens(owner_state: FighterState, statuses: Array, proto_by_id: Dictionary) -> Array[ModifierToken]:
	var out: Array[ModifierToken] = []
	for s in statuses:
		var proto: Status = proto_by_id.get(s.id, null)
		if !proto or !proto.contributes_modifier():
			continue
		var ctx := proto.make_token_ctx_state(s, owner_state.combat_id)
		out.append_array(proto.get_modifier_tokens(ctx))
	return out
