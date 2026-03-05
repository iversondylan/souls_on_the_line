# battle_state.gd

class_name BattleState extends RefCounted

const FRIENDLY := 0
const ENEMY := 1

var status_catalog: StatusCatalog
var arcana_catalog: ArcanaCatalog

var events: BattleEventLog = BattleEventLog.new()

var battle_seed: int = 0
var run_seed: int = 0

# combat_id -> CombatantState
var units: Dictionary = {}  # int -> CombatantState
var _next_sim_id: int = 1
# group index -> GroupState
var groups: Array[GroupState] = [GroupState.new(), GroupState.new()]

# Turn model
var turn: TurnState = TurnState.new()

# Shared battle RNG
var rng: RNG

# Arcana (battle-level)
var arcana: ArcanaState = ArcanaState.new()

# Resource(s)
var resource: ResourceState = ResourceState.new() 

func init(_battle_seed: int, _run_seed: int) -> void:
	rng = RNG.new(battle_seed)
	events = BattleEventLog.new()

func has_unit(id: int) -> bool:
	return units.has(id)

func get_unit(id: int) -> CombatantState:
	return units.get(id, null)

func init_unit_rng_for(id: int) -> void:
	var s := RNGUtil.mix_seed(battle_seed, id)
	var u := get_unit(id)
	if u:
		u.rng = RNG.new(s)

func add_unit(u: CombatantState, group_index: int, insert_index: int = -1) -> void:
	if !u:
		return
	if u.id <= 0:
		push_warning("BattleState.add_unit: unit id must be > 0")
		return
	if units.has(u.id):
		push_warning("BattleState.add_unit: duplicate id %s" % u.id)
		return
	init_unit_rng_for(u.id)
	group_index = clampi(group_index, 0, 1)
	u.team = group_index
	units[u.id] = u
	groups[group_index].add(u.id, insert_index)

func alloc_id() -> int:
	var id := _next_sim_id
	_next_sim_id += 1
	return id

func sync_next_id_at_least(min_next: int) -> void:
	_next_sim_id = maxi(_next_sim_id, int(min_next))

func remove_unit(id: int) -> void:
	if !units.has(id):
		return
	var u: CombatantState = units[id]
	if u:
		u.alive = false
	# Remove from group order, but keep in units if you want "corpse exists" semantics.
	# For now, remove from order; keep in units to preserve id references.
	var g := -1
	if u:
		g = u.team
	if g != -1:
		groups[g].remove(id)

func is_alive(id: int) -> bool:
	var u: CombatantState = units.get(id, null)
	return u != null and u.alive and u.health > 0

func get_front_id(group_index: int) -> int:
	group_index = clampi(group_index, 0, 1)
	return groups[group_index].front_id(units)

# battle_state.gd (additions)

func get_modifier_tokens_for_cid(target_id: int, mod_type: Modifier.Type) -> Array[ModifierToken]:
	#print("battle_state.gd get_modifier_tokens_for_cid() cid: ", target_id)
	var tokens: Array[ModifierToken] = []

	# 0) Battle-level globals (arcana, relic-like systems, etc.)
	# Keep this centralized so nothing else needs to know “where tokens live”.
	tokens.append_array(_get_arcana_tokens_for(target_id))

	# 1) Per-unit sources (statuses, auras, secondaries, etc.)
	for source_id in units.keys():
		var source: CombatantState = units[source_id]
		if !source or !source.is_alive():
			continue
		
		var same_team := _same_team(int(source_id), target_id)
		
		# 1a) Status tokens (produced by status protos via StatusCatalog)
		var source_tokens := _get_status_tokens_for_source(int(source_id), mod_type)
		for token in source_tokens:
			#print("looking at a token: ", token.owner_id)
			if !token:
				continue
			
			# Safety: aura secondaries must not be GLOBAL (same check as LIVE)
			if token.scope == ModifierToken.ModScope.GLOBAL and token.tags.has(Aura.AURA_SECONDARY_FLAG):
				push_error("SIM: Aura token must not be GLOBAL: %s" % token.source_id)
			
			match token.scope:
				ModifierToken.ModScope.GLOBAL:
					# Always applies to everyone
					tokens.append(token)
				
				ModifierToken.ModScope.SELF:
					# Applies only to the source itself
					if int(source_id) == target_id:
						#print("battle_state.gd get_modifier_tokens_for_cid() appending token source: %s, owner: %s" % [token.source_id, token.owner_id])
						tokens.append(token)
				
				ModifierToken.ModScope.TARGET:
					# Two cases (same as LIVE):
					# 1) Aura-style routing via tags
					# 2) Explicit owner_id match
					if token.tags.has(Aura.AURA_SECONDARY_FLAG):
						if token.tags.has(Aura.AURA_ALLIES):
							if same_team:
								tokens.append(token)
						elif token.tags.has(Aura.AURA_ENEMIES):
							if !same_team:
								tokens.append(token)
					else:
						if int(token.owner_id) == target_id:
							tokens.append(token)

	return tokens

func _get_status_tokens_for_source(source_id: int, mod_type: Modifier.Type) -> Array[ModifierToken]:
	#print("battle_state.gd _get_status_tokens_for_source()")
	var out: Array[ModifierToken] = []
	var u: CombatantState = units.get(source_id, null)
	if !u or !status_catalog:
		return out

	for id_key in u.statuses.by_id.keys():
		var stack: StatusStack = u.statuses.by_id[id_key]
		var id_strn := StringName(id_key)
		var proto: Status = status_catalog.get_proto(id_strn)
		if !proto:
			push_warning("there's no proto")
			continue
		if mod_type not in proto.get_contributed_modifier_types():
			continue
		var ctx := StatusTokenContext.new()#proto.make_token_ctx_state({}, source_id)
		ctx.duration = stack.duration
		ctx.intensity = stack.intensity
		ctx.owner_id = source_id
		if proto.expiration_policy == Status.ExpirationPolicy.DURATION and stack.duration <= 0:
			continue
		if proto.contributes_modifier():
			var tokens: Array[ModifierToken] = proto.get_modifier_tokens(ctx)
			out.append_array(tokens)
	return out

func _get_arcana_tokens_for(target_id: int) -> Array[ModifierToken]:
	# ArcanaState should be the SIM “ArcanaSystem” data equivalent.
	# If ArcanaState doesn't provide tokens yet, return [] for now.
	if arcana and arcana.has_method("get_modifier_tokens_for_target"):
		return arcana.get_modifier_tokens_for_target(self, target_id)
	return []

func _same_team(a: int, b: int) -> bool:
	var ua: CombatantState = units.get(a, null)
	var ub: CombatantState = units.get(b, null)
	if !ua or !ub:
		return false
	return ua.team == ub.team

# Minimal clone (good enough for early previews; deepen as needed)
func clone() -> BattleState:
	var b := BattleState.new()
	b.battle_seed = battle_seed
	b.run_seed = run_seed
	
	b.rng = RNG.new()
	b.rng.seed = rng.seed
	b._next_sim_id = _next_sim_id
	for id in units.keys():
		var u: CombatantState = units[id]
		if u:
			b.units[id] = u.clone()
	
	b.groups = [groups[0].clone(), groups[1].clone()]
	b.turn = turn.clone()
	b.arcana = arcana.duplicate(true)
	
	# Policy: preview clones start with a fresh empty event log.
	b.events = BattleEventLog.new()
	
	return b

func debug_dump_events(last_n: int = 20) -> void:
	if events == null:
		#print("BattleState: no events")
		return
	var n := events.size()
	var start := maxi(n - last_n, 0)
	for i in range(start, n):
		var e := events.get_event(i)
		#print("battle_state.gd debug_dump_events() seq=%d type=%d scope=%d kind=%s data=%s" % [e.seq, e.type, e.scope_id, String(e.scope_kind), str(e.data)])
