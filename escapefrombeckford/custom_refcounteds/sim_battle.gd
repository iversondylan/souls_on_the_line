# sim_battle.gd

class_name SimBattle extends RefCounted

var fighters_by_id: Dictionary = {} # int -> SimFighter
var status_catalog_by_id: Dictionary = {} # String -> Status (prototype resource)

func add_fighter(f: SimFighter) -> void:
	fighters_by_id[f.combat_id] = f

func get_fighter(id: int) -> SimFighter:
	return fighters_by_id.get(id, null)

func get_modifier_tokens_for_target(target_id: int) -> Array[ModifierToken]:
	var target := get_fighter(target_id)
	if !target or !target.is_alive:
		return []

	var tokens: Array[ModifierToken] = []

	# Stable iteration order: sort combat_ids
	var ids: Array[int] = fighters_by_id.keys()
	ids.sort()

	for source_id in ids:
		var source: SimFighter = fighters_by_id[source_id]
		if !source or !source.is_alive:
			continue

		var same_team : bool = source.team == target.team

		var emitted := StatusSim.get_tokens_for_emitter(source, status_catalog_by_id)

		for token: ModifierToken in emitted:
			match token.scope:
				ModifierToken.Scope.GLOBAL:
					tokens.append(token)

				ModifierToken.Scope.SELF:
					if source.combat_id == target_id:
						tokens.append(token)

				ModifierToken.Scope.TARGET:
					# Only support aura routing for now (no explicit-target tokens)
					if token.tags.has(Aura.AURA_SECONDARY_FLAG):
						if token.tags.has(Aura.AURA_ALLIES):
							if same_team:
								tokens.append(token)
						elif token.tags.has(Aura.AURA_ENEMIES):
							if !same_team:
								tokens.append(token)
					else:
						# explicit-target tokens intentionally unsupported
						# (you said none exist; keep it loud if one appears)
						push_warning("SimBattle: explicit TARGET token not supported: %s" % token.source_id)

	# Deterministic token order for modifier math
	tokens.sort_custom(func(a: ModifierToken, b: ModifierToken) -> bool:
		if a.priority != b.priority:
			return a.priority < b.priority
		if a.type != b.type:
			return int(a.type) < int(b.type)
		if a.owner_id != b.owner_id:
			return a.owner_id < b.owner_id
		return a.source_id < b.source_id
	)

	return tokens
