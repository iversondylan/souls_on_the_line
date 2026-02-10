# modifier_token_util.gd

class_name ModifierTokenUtil extends RefCounted

static func to_id_token(t: ModifierToken) -> ModifierToken:
	var out := ModifierToken.new()
	out.type = t.type
	out.flat_value = t.flat_value
	out.mult_value = t.mult_value
	out.source_id = t.source_id
	out.priority = t.priority
	out.scope = t.scope
	out.tags = t.tags.duplicate()

	# Convert Node owner -> owner_id when possible
	out.owner = null
	out.owner_id = -1
	if t.owner and t.owner is Fighter:
		out.owner_id = (t.owner as Fighter).combat_id

	# If token already uses owner_id, preserve it
	if t.owner_id != 0 and t.owner_id != -1:
		out.owner_id = t.owner_id

	return out
