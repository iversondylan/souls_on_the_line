# battle_state.gd

class_name BattleState extends RefCounted

const FRIENDLY := 0
const ENEMY := 1

var battle_seed: int = 0
var run_seed: int = 0

# combat_id -> CombatantState
var units: Dictionary = {}  # int -> CombatantState

# group index -> GroupState
var groups: Array[GroupState] = [GroupState.new(), GroupState.new()]

# Turn model
var turn: TurnState = TurnState.new()

# Shared battle RNG
var rng: RNG

# Arcana (battle-level)
var arcana: ArcanaState = ArcanaState.new()

func init(_battle_seed: int, _run_seed: int) -> void:
	battle_seed = _battle_seed
	run_seed = _run_seed
	rng = RNG.new()
	# Choose whichever you want as the single source seed; battle_seed is fine.
	rng.seed = battle_seed

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

	# RNG: clone by copying seed + internal state-ish.
	# Godot doesn't expose full PRNG state cleanly; for determinism,
	# prefer a custom RNG wrapper later. For now: copy seed + advance count stored externally if needed.
	b.rng = RNG.new()
	b.rng.seed = rng.seed

	# Units
	for id in units.keys():
		var u: CombatantState = units[id]
		if u:
			b.units[id] = u.clone()

	# Groups
	b.groups = [groups[0].clone(), groups[1].clone()]

	# Turn
	b.turn = turn.clone()

	# Arcana
	b.arcana = arcana.duplicate(true)

	return b
