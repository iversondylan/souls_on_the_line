# status_sim.gd (static helper)

class_name StatusSim extends RefCounted

static func get_tokens_for_emitter(
	emitter: SimFighter,
	status_catalog_by_id: Dictionary
) -> Array[ModifierToken]:
	var out: Array[ModifierToken] = []
	if !emitter or !emitter.statuses:
		return out
	
	for status_state: StatusState in emitter.statuses.get_all():
		var proto_status: Status = status_catalog_by_id.get(status_state.id, null)
		if !proto_status:
			continue

		# IMPORTANT: check expiration using the STATE, not the proto instance.
		if proto_status.expiration_policy == Status.ExpirationPolicy.DURATION and status_state.duration <= 0:
			continue

		if !proto_status.contributes_modifier():
			continue

		var ctx := StatusTokenContext.new()
		ctx.id = status_state.id
		ctx.duration = status_state.duration
		ctx.intensity = status_state.intensity
		ctx.owner = null
		ctx.owner_id = emitter.combat_id

		var tokens := proto_status.get_modifier_tokens(ctx)
		for token in tokens:
			token.owner = null
			token.owner_id = emitter.combat_id
		out.append_array(tokens)

	return out
