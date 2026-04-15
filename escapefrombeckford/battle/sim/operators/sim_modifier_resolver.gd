# sim_modifier_resolver.gd
class_name SimModifierResolver

static func get_modified_value(
	b: BattleState,
	base: int,
	mod_type: Modifier.Type,
	cid: int
) -> int:
	if !b:
		return base
	if int(mod_type) == int(Modifier.Type.NO_MODIFIER):
		return base
	var u: CombatantState = b.get_unit(cid)
	if u != null:
		return u.modifiers.apply(int(mod_type), base)
	# Fallback for cids not tracked in state (edge case): no modifiers available.
	return base

# Returns the pre-aggregated {flat: int, mult: float} for a token set.
# Used by both apply_tokens and _rebuild_modifier_cache_for so the
# aggregation formula lives in one place.
static func compute_modifier_deltas(
	mod_type: Modifier.Type,
	tokens: Array[ModifierToken]
) -> Dictionary:
	var flat := 0
	var mult := 1.0
	for t: ModifierToken in tokens:
		if !t or t.type != mod_type:
			continue
		flat += int(t.flat_value)
		mult *= (1.0 + float(t.mult_value))
	return {"flat": flat, "mult": mult}

static func apply_tokens(
	base: int,
	mod_type: Modifier.Type,
	tokens: Array[ModifierToken]
) -> int:

	# Optional: stable ordering by priority (match LIVE semantics if you rely on it)
	# If you don't care yet, delete the sort.
	tokens.sort_custom(func(a: ModifierToken, c: ModifierToken) -> bool:
		return int(a.priority) < int(c.priority)
	)

	var d := compute_modifier_deltas(mod_type, tokens)
	# Intent previews should match live modifier rounding while still showing
	# attacker-side damage dealt, not target-side damage taken.
	return int(round((base + int(d["flat"])) * float(d["mult"])))
