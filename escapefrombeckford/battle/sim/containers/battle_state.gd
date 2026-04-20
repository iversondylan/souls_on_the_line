# battle_state.gd

class_name BattleState extends RefCounted

const FRIENDLY := 0
const ENEMY := 1

enum Outcome {
	NONE,
	VICTORY,
	DEFEAT,
}

var outcome: int = Outcome.NONE

var status_catalog: StatusCatalog
var arcana_catalog: ArcanaCatalog
var transformer_registry: TransformerRegistry = TransformerRegistry.new()

var events: BattleEventLog = BattleEventLog.new()

var battle_seed: int = 0
var run_seed: int = 0
var summon_card_ap_bonus: Dictionary = {} # String(card_uid) -> int
var summon_card_max_health_bonus: Dictionary = {} # String(card_uid) -> int

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
	rng = RNG.new(battle_seed)
	events = BattleEventLog.new()
	summon_card_ap_bonus.clear()
	summon_card_max_health_bonus.clear()

	resource = ResourceState.new()
	resource.max_mana = 3
	resource.mana = 3
	resource.player_turn_draw_amount = 3
	resource.player_turn_use_soulbound_guarantee = true
	resource.hand_mode = ResourceState.HandMode.DISCARD
	resource.shuffle_mode = ResourceState.ShuffleMode.NORMAL


func has_terminal_outcome() -> bool:
	return int(outcome) != int(Outcome.NONE)

func set_victory() -> void:
	outcome = Outcome.VICTORY

func set_defeat() -> void:
	outcome = Outcome.DEFEAT

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
	group_index = clampi(group_index, 0, 1)
	u.team = group_index
	units[u.id] = u
	init_unit_rng_for(u.id)
	groups[group_index].add(u.id, insert_index)

func alloc_id() -> int:
	var id := _next_sim_id
	_next_sim_id += 1
	return id

func sync_next_id_at_least(min_next: int) -> void:
	_next_sim_id = maxi(_next_sim_id, int(min_next))

func remove_unit(id: int) -> void:
	#print("battle_state.gd remove_unit() cid: ", id)
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

#func mark_interceptors_dirty(hook_kind: StringName) -> void:
	#if transformer_registry == null:
		#return
	#transformer_registry.mark_interceptor_hook_dirty(hook_kind)


func get_interceptors_for_hook(hook_kind: StringName) -> Array[Interceptor]:
	if transformer_registry == null:
		return []
	return transformer_registry.get_interceptors_for_hook(self, hook_kind)

func get_front_id(group_index: int) -> int:
	group_index = clampi(group_index, 0, 1)
	return groups[group_index].front_id(units)

# Minimal clone (good enough for early previews; deepen as needed)
func clone() -> BattleState:
	var b := BattleState.new()
	b.battle_seed = battle_seed
	b.run_seed = run_seed
	b.status_catalog = status_catalog
	b.arcana_catalog = arcana_catalog
	b.summon_card_ap_bonus = summon_card_ap_bonus.duplicate(true)
	b.summon_card_max_health_bonus = summon_card_max_health_bonus.duplicate(true)

	b.rng = RNG.new()
	b.rng.rng_seed = rng.rng_seed
	b._next_sim_id = _next_sim_id

	for id in units.keys():
		var u: CombatantState = units[id]
		if u:
			b.units[id] = u.clone()

	b.groups = [groups[0].clone(), groups[1].clone()]
	b.turn = turn.clone()
	b.arcana = arcana.clone() if arcana != null else ArcanaState.new()
	b.transformer_registry = transformer_registry.clone() if transformer_registry != null else TransformerRegistry.new()
	b.resource = resource.clone()

	# Policy: preview clones start with a fresh empty event log.
	b.events = BattleEventLog.new()

	return b

func debug_dump_state(label: String = "") -> void:
	var header := "BattleState dump"
	if !label.is_empty():
		header += " [%s]" % label
	print(header)
	print("  seeds: battle=%d run=%d next_sim_id=%d outcome=%s" % [
		battle_seed,
		run_seed,
		_next_sim_id,
		_debug_outcome_name(outcome),
	])
	print("  turn: round=%d active_group=%s active_id=%d queue=%s actions=%s" % [
		int(turn.round),
		_debug_group_name(int(turn.active_group)),
		int(turn.active_id),
		Array(turn.queue),
		str(turn.actions_this_group_turn),
	])
	print("  resource: mana=%d/%d pending_discard=%s" % [
		int(resource.mana) if resource != null else 0,
		int(resource.max_mana) if resource != null else 0,
		_debug_pending_discard_summary(),
	])
	print("  arcana: %s" % _debug_arcana_summary())

	for group_index in [FRIENDLY, ENEMY]:
		var group := groups[group_index] if group_index < groups.size() else null
		if group == null:
			print("  %s: <missing group>" % _debug_group_name(group_index))
			continue

		print("  %s: player_id=%d order=%s" % [
			_debug_group_name(group_index),
			int(group.player_id),
			Array(group.order),
		])

		for cid in group.order:
			var unit := get_unit(int(cid))
			if unit == null:
				print("    cid=%d <missing unit>" % int(cid))
				continue
			print("    %s" % _debug_unit_summary(unit))

	var ordered_ids := {}
	for group in groups:
		if group == null:
			continue
		for cid in group.order:
			ordered_ids[int(cid)] = true

	var extras: Array[int] = []
	for cid in units.keys():
		var id := int(cid)
		if !ordered_ids.has(id):
			extras.append(id)

	if !extras.is_empty():
		extras.sort()
		print("  units_not_in_order=%s" % [str(extras)])
		for cid in extras:
			var unit := get_unit(int(cid))
			if unit != null:
				print("    %s" % _debug_unit_summary(unit))

func _debug_outcome_name(value: int) -> String:
	if value >= 0 and value < Outcome.keys().size():
		return Outcome.keys()[value]
	return str(value)

func _debug_group_name(group_index: int) -> String:
	match int(group_index):
		FRIENDLY:
			return "FRIENDLY"
		ENEMY:
			return "ENEMY"
		_:
			return "GROUP_%d" % int(group_index)

func _debug_pending_discard_summary() -> String:
	if resource == null or resource.pending_discard == null:
		return "none"

	var req := resource.pending_discard
	return "{source_id=%d amount=%d reason=%s card_uid=%s}" % [
		int(req.source_id),
		int(req.amount),
		String(req.reason),
		String(req.card_uid),
	]

func _debug_arcana_summary() -> String:
	if arcana == null or arcana.list.is_empty():
		return "[]"

	var parts: Array[String] = []
	for entry: ArcanumEntry in arcana.list:
		if entry == null:
			continue

		var extra: Array[String] = []
		if int(entry.stacks) >= 0:
			extra.append("stacks=%d" % int(entry.stacks))
		if !entry.data.is_empty():
			extra.append("data=%s" % str(entry.data))

		var suffix := ""
		if !extra.is_empty():
			suffix = " {%s}" % ", ".join(extra)

		parts.append("%s%s" % [String(entry.id), suffix])

	return "[" + ", ".join(parts) + "]"

func _debug_unit_summary(unit: CombatantState) -> String:
	var team_name := _debug_group_name(int(unit.team))
	var type_name := _debug_combatant_type_name(int(unit.type))
	var mortality_name := _debug_mortality_name(int(unit.mortality))
	var statuses := _debug_status_summary(unit)
	var proto := ""
	if !String(unit.data_proto_path).is_empty():
		proto = " proto=%s" % String(unit.data_proto_path).get_file()

	return "cid=%d name=%s team=%s type=%s mortality=%s alive=%s hp=%d/%d mana=%d/%d ap=%d%s%s" % [
		int(unit.id),
		String(unit.name),
		team_name,
		type_name,
		mortality_name,
		str(bool(unit.alive)),
		int(unit.health),
		int(unit.max_health),
		int(unit.mana),
		int(unit.max_mana),
		int(unit.ap),
		proto,
		statuses,
	]

func _debug_combatant_type_name(value: int) -> String:
	if value >= 0 and value < CombatantView.Type.keys().size():
		return CombatantView.Type.keys()[value]
	return str(value)

func _debug_mortality_name(value: int) -> String:
	if value >= 0 and value < CombatantState.Mortality.keys().size():
		return CombatantState.Mortality.keys()[value]
	return str(value)

func _debug_status_summary(unit: CombatantState) -> String:
	if unit == null or unit.statuses.by_id.is_empty():
		return ""

	var parts: Array[String] = []
	for token: StatusToken in unit.statuses.get_all_tokens(true):
		if token == null:
			continue
		parts.append("%s(i=%d,d=%d)" % [
			("%s[p]" % String(token.id)) if bool(token.pending) else String(token.id),
			int(token.intensity),
			int(token.duration),
		])

	parts.sort()
	return " statuses=[" + ", ".join(parts) + "]"
