# sim_battle.gd

class_name SimBattle extends RefCounted



var fighters_by_id: Dictionary = {} # int -> SimFighter
var fighters: Array[SimFighter] = []
var status_catalog_by_id: Dictionary # String -> Status (proto)

var group_order := {
	0: PackedInt32Array(),
	1: PackedInt32Array(),
}


func _init(_status_catalog_by_id: Dictionary) -> void:
	status_catalog_by_id = _status_catalog_by_id

#func add_fighter(f: SimFighter) -> void:
	#fighters_by_id[f.combat_id] = f
	#fighters.append(f)
	#f.modifier_system = SimModifierSystem.new(self, f.combat_id)

func get_fighter(id: int) -> SimFighter:
	return fighters_by_id.get(id, null)

func get_group_order(group_index: int) -> PackedInt32Array:
	group_index = clampi(group_index, 0, 1)
	return group_order[group_index]

func set_group_order(group_index: int, ids: Array[int]) -> void:
	group_index = clampi(group_index, 0, 1)
	var arr := PackedInt32Array()
	for id in ids:
		arr.append(id)
	group_order[group_index] = arr

func get_rank_in_group(combat_id: int) -> int:
	var f := get_fighter(combat_id)
	if !f:
		return -1
	var arr: PackedInt32Array = get_group_order(f.group)
	for i in range(arr.size()):
		if arr[i] == combat_id:
			return i
	return -1

func add_fighter(f: SimFighter) -> void:
	fighters_by_id[f.combat_id] = f
	fighters.append(f)
	f.modifier_system = SimModifierSystem.new(self, f.combat_id)

	# Insert into ordering at the back by default (front->back list)
	var arr: PackedInt32Array = get_group_order(f.group)
	arr.append(f.combat_id)
	group_order[f.group] = arr

func remove_fighter(combat_id: int) -> void:
	var f := get_fighter(combat_id)
	if !f:
		return
	fighters_by_id.erase(combat_id)
	fighters.erase(f)

	var arr: PackedInt32Array = get_group_order(f.group)
	var out := PackedInt32Array()
	for id in arr:
		if id != combat_id:
			out.append(id)
	group_order[f.group] = out

func get_modifier_tokens_for_target(target_id: int, mod_type: Modifier.Type = Modifier.Type.NO_MODIFIER) -> Array[ModifierToken]:
	var target := get_fighter(target_id)
	if !target or !target.is_alive():
		return []
	
	var tokens: Array[ModifierToken] = []
	
	# Stable iteration order: sort combat_ids
	var ids: Array[int] = to_array_int(fighters_by_id.keys())
	ids.sort()
	
	for source_id in ids:
		var source: SimFighter = fighters_by_id[source_id]
		if !source or !source.is_alive():
			continue
		
		var same_team : bool = source.team == target.team
		
		var emitted := StatusSim.get_tokens_for_emitter(source, status_catalog_by_id)
		
		for token: ModifierToken in emitted:
			# Early filter by requested type
			if mod_type != Modifier.Type.NO_MODIFIER and token.type != mod_type:
				continue
			
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

func get_modified_value(target_id: int, base: int, mod_type: Modifier.Type) -> int:
	var f := get_fighter(target_id)
	if !f or !f.is_alive():
		return base
	var mod := f.modifier_system.get_resolved_modifier(mod_type)
	return floori((base + mod.flat) * mod.mult)

static func from_battle_scene(battle_scene: BattleScene, status_catalog: StatusCatalog) -> SimBattle:
	var sim := SimBattle.new(status_catalog.by_id)

	# 1) build fighters + add them
	var all_live := battle_scene.get_all_combatants()
	for f: Fighter in all_live:
		if !f:
			continue
		var sf := SimFighter.new()
		sf.combat_id = f.combat_id
		sf.group = battle_scene.get_index_of_parent_group(f)
		sf.team = sf.group
		sf.alive = f.is_alive()
		sf.statuses = _extract_statuses_as_data(f)
		# also clone stats here (health/armor/max mana etc.)
		# sf.stats = SimStats.from_combatant_data(f.combatant_data)
		sim.add_fighter(sf)

	# 2) capture formation order (front->back) directly from the live groups
	var friendly_ids: Array[int] = []
	for f: Fighter in battle_scene.groups[0].get_combatants(true):
		if f and is_instance_valid(f):
			friendly_ids.append(f.combat_id)

	var enemy_ids: Array[int] = []
	for f: Fighter in battle_scene.groups[1].get_combatants(true):
		if f and is_instance_valid(f):
			enemy_ids.append(f.combat_id)

	sim.set_group_order(0, friendly_ids)
	sim.set_group_order(1, enemy_ids)

	return sim


#static func from_battle_scene(
	#battle_scene: BattleScene,
	#status_catalog: StatusCatalog
#) -> SimBattle:
	## IMPORTANT: status_catalog.build_index() should already have run.
	#var sim := SimBattle.new(status_catalog.by_id)
#
	## Stable order for determinism
	#var fighters := battle_scene.get_all_combatants()
	#fighters.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		#return a.combat_id < b.combat_id
	#)
#
	#for f: Fighter in fighters:
		#if !f:
			#continue
#
		#var sf := SimFighter.new()
		#sf.combat_id = f.combat_id
		#
		#sf.debug_name = f.name
#
		#if f is Player:
			#sf.role = "player"
		#elif f is Enemy:
			#sf.role = "enemy"
		#elif f is SummonedAlly:
			#sf.role = "summon"
		#else:
			#sf.role = "fighter"
		## “team” should match whatever your routing expects.
		## If you use group index (0 friendly / 1 enemy), do that:
		#sf.group = battle_scene.get_index_of_parent_group(f)
		#sf.team = sf.group
#
		#sf.alive = f.is_alive()
#
		## Pull from your data-side statuses (preferred), or convert node grid -> data
		## If you already store StatusGridData on FighterState, use that:
		##	sf.statuses = f.state.statuses.clone()
		##
		## If you DON'T yet: make a helper that converts node status_grid to StatusGridData.
		#sf.statuses = _extract_statuses_as_data(f)
#
		#sim.add_fighter(sf)
#
	#return sim

# Later, I’ll delete _extract_statuses_as_data once FighterState 
# owns StatusGridData and live StatusGrid becomes just a view/sync.
static func _extract_statuses_as_data(f: Fighter) -> StatusGridData:
	var data := StatusGridData.new()
	if !f or !f.status_system:
		return data

	for s: Status in f.status_system._get_all_statuses():
		if !s:
			continue
		var st := StatusState.new(s.get_id(), s.duration, s.intensity)
		data.by_id[st.id] = st

	return data


func to_array_int(arr: Array) -> Array[int]:
	var arrint: Array[int] = []
	for element in arr:
		if element is int:
			arrint.push_back(element)
	return arrint






func print_sim_snapshot(print_tokens: bool = true, print_resolved_mods: bool = true) -> void:
	print("")
	print("=== SimBattle Snapshot ===")
	print("fighters: %s" % fighters_by_id.size())

	# Deterministic order
	var ids: Array[int] = to_array_int(fighters_by_id.keys())
	ids.sort()

	for id in ids:
		var f: SimFighter = fighters_by_id[id]
		if !f:
			continue

		var header := "- Fighter #%s (%s:%s) | team=%s group=%s alive=%s" % [
	f.combat_id,
	f.role,
	f.debug_name,
	f.team,
	f.group,
	f.is_alive()
]
		print(header)

		_print_statuses_for(f)

		if print_tokens:
			_print_emitted_tokens_for(f)
			_print_tokens_applying_to_target(f.combat_id)


		if print_resolved_mods:
			_print_resolved_modifiers_for(f)
	#must restore this
	_print_damage_sanity_check()
	
	print("=== End SimBattle Snapshot ===")
	print("")


func _print_statuses_for(f: SimFighter) -> void:
	if !f.statuses:
		print("\tstatuses: <none>")
		return

	var all := f.statuses.get_all()
	if all.is_empty():
		print("\tstatuses: <none>")
		return

	# Stable: sort by id
	all.sort_custom(func(a: StatusState, b: StatusState) -> bool:
		return a.id < b.id
	)

	print("\tstatuses:")
	for s: StatusState in all:
		var proto: Status = status_catalog_by_id.get(s.id, null)
		var exp := "<no-proto>"
		if proto:
			if proto.expiration_policy == Status.ExpirationPolicy.DURATION:
				exp = "DURATION"
			elif proto.expiration_policy == Status.ExpirationPolicy.GROUP_TURN_START:
				exp = "GROUP_TURN_START"
			elif proto.expiration_policy == Status.ExpirationPolicy.GROUP_TURN_END:
				exp = "GROUP_TURN_END"
			else:
				exp = "EVENT_OR_NEVER"

		print("\t\t- %s dur=%s int=%s policy=%s" % [s.id, s.duration, s.intensity, exp])


func _print_emitted_tokens_for(f: SimFighter) -> void:
	var emitted := StatusSim.get_tokens_for_emitter(f, status_catalog_by_id)
	if emitted.is_empty():
		print("\ttokens_emitted: <none>")
		return

	# Deterministic token order
	emitted.sort_custom(func(a: ModifierToken, b: ModifierToken) -> bool:
		if a.priority != b.priority:
			return a.priority < b.priority
		if a.type != b.type:
			return int(a.type) < int(b.type)
		if a.owner_id != b.owner_id:
			return a.owner_id < b.owner_id
		return a.source_id < b.source_id
	)

	print("\ttokens_emitted:")
	for t: ModifierToken in emitted:
		var scope_str := _scope_to_string(t.scope)
		var type_str := _mod_type_to_string(t.type)

		var tags_str := ""
		if t.tags and !t.tags.is_empty():
			tags_str = " tags=%s" % str(t.tags)

		print("\t\t- type=%s scope=%s flat=%s mult=%s src=%s owner_id=%s prio=%s%s" % [
			type_str,
			scope_str,
			t.flat_value,
			t.mult_value,
			t.source_id,
			t.owner_id,
			t.priority,
			tags_str
		])


func _print_resolved_modifiers_for(f: SimFighter) -> void:
	if !f.modifier_system:
		print("\tresolved_mods: <no modifier system>")
		return

	# Print only the ones you currently use, plus any others you care about.
	var types_to_print: Array = [
		Modifier.Type.DMG_DEALT,
		Modifier.Type.DMG_TAKEN,
	]

	print("\tresolved_mods:")
	for t in types_to_print:
		var r := f.modifier_system.get_resolved_modifier(t)
		print("\t\t- %s: flat=%s mult=%s" % [_mod_type_to_string(t), r.flat, r.mult])


func _scope_to_string(scope: int) -> String:
	match scope:
		ModifierToken.Scope.GLOBAL:
			return "GLOBAL"
		ModifierToken.Scope.SELF:
			return "SELF"
		ModifierToken.Scope.TARGET:
			return "TARGET"
	return "?"


func _mod_type_to_string(t: int) -> String:
	# If you have Modifier.Type.keys(), you can use that; otherwise match the ones you care about.
	# This avoids crashing if keys() isn’t available for your enum.
	match t:
		Modifier.Type.DMG_DEALT:
			return "DMG_DEALT"
		Modifier.Type.DMG_TAKEN:
			return "DMG_TAKEN"
		Modifier.Type.NO_MODIFIER:
			return "NO_MODIFIER"
	return str(t)


func _print_tokens_applying_to_target(target_id: int) -> void:
	var routed := get_modifier_tokens_for_target(target_id)
	if routed.is_empty():
		print("\ttokens_routed_to_me: <none>")
		return

	print("\ttokens_routed_to_me:")
	for t: ModifierToken in routed:
		var tags_str := ""
		if t.tags and !t.tags.is_empty():
			tags_str = " tags=%s" % str(t.tags)
		print("\t\t- type=%s scope=%s flat=%s mult=%s src=%s owner_id=%s%s" % [
			_mod_type_to_string(t.type),
			_scope_to_string(t.scope),
			t.flat_value,
			t.mult_value,
			t.source_id,
			t.owner_id,
			tags_str
		])

func _print_damage_sanity_check() -> void:
	var base := 10

	var player_id := _find_first_id_with_role("player")
	var enemy_id := _find_first_id_with_role("enemy")
	var buffed_enemy_id := _find_first_id_with_role("enemy") # (same as enemy_id; #2 is buffed in your example)
	var buffed_summon_id := _find_first_id_with_status("amplify")
	var aura_enemy_id := _find_first_id_with_status("resonance_spike")
	var pinpointed_enemy_id := _find_first_id_with_status("pinpoint")

	if player_id != -1 and enemy_id != -1:
		print("damage_check: P->E | %s -> %s | base=%s => %s" % [
			player_id, enemy_id, base,
			SimDamage.compute_damage(self, player_id, enemy_id, base)
		])
	
	if buffed_enemy_id != -1 and player_id != -1:
		print("damage_check: E->P | %s -> %s | base=%s => %s" % [
			buffed_enemy_id, player_id, base,
			SimDamage.compute_damage(self, buffed_enemy_id, player_id, base)
		])
	
	if buffed_summon_id != -1 and enemy_id != -1:
		print("damage_check: AmpSummon->E | %s -> %s | base=%s => %s" % [
			buffed_summon_id, enemy_id, base,
			SimDamage.compute_damage(self, buffed_summon_id, enemy_id, base)
		])
	
	if aura_enemy_id != -1 and player_id != -1:
		print("damage_check: AuraEnemy->P | %s -> %s | base=%s => %s" % [
			aura_enemy_id, player_id, base,
			SimDamage.compute_damage(self, aura_enemy_id, player_id, base)
		])
	if player_id != -1 and pinpointed_enemy_id != -1:
		print("damage_check: P->PinpointE | %s -> %s | base=%s => %s" % [
			player_id, pinpointed_enemy_id, base,
			SimDamage.compute_damage(self, player_id, pinpointed_enemy_id, base)
		])

func _find_first_id_with_status(status_id: String) -> int:
	var ids: Array[int] = to_array_int(fighters_by_id.keys())
	ids.sort()
	for id in ids:
		var f: SimFighter = fighters_by_id[id]
		if !f or !f.is_alive() or !f.statuses:
			continue
		if f.statuses.has_status(status_id):
			return id
	return -1

func _find_first_id_with_role(role: String) -> int:
	var ids: Array[int] = to_array_int(fighters_by_id.keys())
	ids.sort()
	for id in ids:
		var f: SimFighter = fighters_by_id[id]
		if !f or !f.is_alive():
			continue
		if f.role == role:
			return id
	return -1
