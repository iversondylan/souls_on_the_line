# battle_state.gd

class_name BattleState extends RefCounted

const FRIENDLY := 0
const ENEMY := 1

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
	battle_seed = _battle_seed
	run_seed = _run_seed
	rng = RNG.new()
	rng.seed = battle_seed
	events = BattleEventLog.new()

func has_unit(id: int) -> bool:
	return units.has(id)

func get_unit(id: int) -> CombatantState:
	return units.get(id, null)

func add_unit(u: CombatantState, group_index: int, insert_index: int = -1) -> void:
	if !u:
		return
	if u.id <= 0:
		push_warning("BattleState.add_unit: unit id must be > 0")
		return
	if units.has(u.id):
		push_warning("BattleState.add_unit: duplicate id %s" % u.id)
		return

	group_index = clampi(group_index, 0, 1)
	u.team = group_index
	units[u.id] = u
	groups[group_index].add(u.id, insert_index)

func alloc_id() -> int:
	var id := _next_sim_id
	print("[SIM][ID] alloc -> ", id)
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
		print("BattleState: no events")
		return
	var n := events.size()
	var start := maxi(n - last_n, 0)
	for i in range(start, n):
		var e := events.get_event(i)
		print("[EV] #%d type=%d scope=%d kind=%s data=%s" % [e.seq, e.type, e.scope_id, String(e.scope_kind), str(e.data)])
