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

	var tokens := b.get_modifier_tokens_for_cid(cid)

	var flat := 0
	var mult := 1.0

	# Optional: stable ordering by priority (match LIVE semantics if you rely on it)
	# If you don’t care yet, delete the sort.
	tokens.sort_custom(func(a: ModifierToken, c: ModifierToken) -> bool:
		return int(a.priority) < int(c.priority)
	)

	for t in tokens:
		if !t or t.type != mod_type:
			continue
		flat += int(t.flat_value)
		mult *= (1.0 + float(t.mult_value))

	return floori((base + flat) * mult)
