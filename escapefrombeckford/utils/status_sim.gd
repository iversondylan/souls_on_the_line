# status_sim.gd (static helper)

class_name StatusSim extends RefCounted

static func get_modifier_tokens_for_owner(
	status_grid: StatusGridData,
	status_catalog: Dictionary,
	owner_combat_id: int
) -> Array[ModifierToken]:
	var tokens: Array[ModifierToken] = []
	for s in status_grid.get_all():
		var proto: Status = status_catalog.get(s.id, null)
		if !proto:
			continue
		if proto.expiration_policy == Status.ExpirationPolicy.DURATION and s.duration <= 0:
			continue
		if !proto.contributes_modifier():
			continue
		
		# Special-case: if you want to keep logic in Status subclasses,
		# you can add a virtual "get_modifier_tokens_from_state(state, owner_id)" later.
		# For now: handle the common ones directly by id.
		match s.id:
			AmplifyStatus.ID:
				var token := ModifierToken.new()
				token.type = Modifier.Type.DMG_DEALT
				token.mult_value = AmplifyStatus.MULT_VALUE
				token.flat_value = 0
				token.source_id = s.id
				token.owner_id = owner_combat_id # add this field
				token.scope = ModifierToken.Scope.SELF
				tokens.append(token)

			ResonanceSpikeStatus.ID:
				var token := ModifierToken.new()
				token.type = Modifier.Type.DMG_DEALT
				token.flat_value = s.intensity
				token.mult_value = 0
				token.source_id = s.id
				token.owner_id = owner_combat_id
				token.scope = ModifierToken.Scope.TARGET
				tokens.append(token)

			_:
				pass

	return tokens
