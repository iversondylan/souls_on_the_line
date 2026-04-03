# battle_state.gd

class_name BattleState extends RefCounted

const AuraBankScript = preload("res://battle/sim/containers/aura_bank.gd")

enum Outcome {
	NONE,
	VICTORY,
	DEFEAT,
}

var outcome: int = Outcome.NONE

const FRIENDLY := 0
const ENEMY := 1

var status_catalog: StatusCatalog
var arcana_catalog: ArcanaCatalog
var aura_bank = AuraBankScript.new()

var events: BattleEventLog = BattleEventLog.new()

var battle_seed: int = 0
var run_seed: int = 0
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
	summon_card_max_health_bonus.clear()

	resource = ResourceState.new()
	resource.max_mana = 3
	resource.mana = 3

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

func get_front_id(group_index: int) -> int:
	group_index = clampi(group_index, 0, 1)
	return groups[group_index].front_id(units)

# battle_state.gd (additions)

func get_modifier_tokens_for_cid(target_id: int, mod_type: Modifier.Type, include_pending_sources := {}) -> Array[ModifierToken]:
	var tokens: Array[ModifierToken] = []

	# 0) Battle-level globals (arcana, relic-like systems, etc.)
	tokens.append_array(_get_arcana_tokens_for(target_id))

	var target: CombatantState = units.get(target_id, null)
	if target == null or !target.is_alive():
		return tokens

	tokens.append_array(_get_effective_status_modifier_tokens_for_target(target_id, mod_type, include_pending_sources))
	return tokens

func _get_effective_status_modifier_tokens_for_target(
	target_id: int,
	mod_type: Modifier.Type,
	include_pending_sources := {}
) -> Array[ModifierToken]:
	var out: Array[ModifierToken] = []
	var target: CombatantState = units.get(target_id, null)
	if target == null or target.statuses == null or status_catalog == null:
		return out

	var include_pending_owned := false
	if include_pending_sources is Dictionary:
		include_pending_owned = bool(include_pending_sources.get(int(target_id), false))

	for stack: StatusStack in target.statuses.get_all_stacks(include_pending_owned):
		if stack == null:
			continue
		if bool(stack.pending) and !include_pending_owned:
			continue
		var proto: Status = status_catalog.get_proto(StringName(stack.id))
		if !proto:
			continue
		if mod_type not in proto.get_contributed_modifier_types():
			continue
		if int(proto.expiration_policy) == int(Status.ExpirationPolicy.DURATION) and int(stack.duration) <= 0:
			continue

		var ctx := StatusTokenContext.new()
		ctx.id = StringName(stack.id)
		ctx.pending = bool(stack.pending)
		ctx.duration = stack.duration
		ctx.intensity = stack.intensity
		ctx.owner_id = target_id
		if proto.contributes_modifier():
			var tokens: Array[ModifierToken] = proto.get_modifier_tokens(ctx)
			for token in tokens:
				if _modifier_token_applies_to_target(token, target_id):
					out.append(token)

	if aura_bank == null:
		return out

	for entry: Dictionary in aura_bank.get_entries():
		var source_id := int(entry.get("source_id", 0))
		if source_id <= 0:
			continue

		var pending := bool(entry.get("pending", false))
		var include_pending_source := false
		if include_pending_sources is Dictionary:
			include_pending_source = bool(include_pending_sources.get(source_id, false))
		if pending and !include_pending_source:
			continue

		var source: CombatantState = units.get(source_id, null)
		if source == null or !source.is_alive() or source.statuses == null:
			continue

		var aura_status_id := StringName(entry.get("status_id", &""))
		if aura_status_id == &"":
			continue

		var aura_proto := status_catalog.get_proto(aura_status_id) as Aura
		if aura_proto == null:
			continue

		var aura_stack := source.statuses.get_status_stack(aura_status_id, pending)
		if aura_stack == null:
			continue
		if int(aura_proto.expiration_policy) == int(Status.ExpirationPolicy.DURATION) and int(aura_stack.duration) <= 0:
			continue
		if !aura_proto.affects_target(self, source_id, target_id):
			continue

		for projected_proto: Status in aura_proto.get_projected_statuses():
			if projected_proto == null:
				continue
			if mod_type not in projected_proto.get_contributed_modifier_types():
				continue
			if !projected_proto.contributes_modifier():
				continue

			var projected_ctx := StatusTokenContext.new()
			projected_ctx.id = StringName(projected_proto.get_id())
			projected_ctx.pending = pending
			projected_ctx.duration = int(aura_stack.duration)
			projected_ctx.intensity = int(aura_stack.intensity)
			projected_ctx.owner_id = target_id

			var projected_tokens := projected_proto.get_modifier_tokens(projected_ctx)
			for token in projected_tokens:
				if _modifier_token_applies_to_target(token, target_id):
					out.append(token)

	return out

func _get_arcana_tokens_for(target_id: int) -> Array[ModifierToken]:
	# ArcanaState should be the SIM “ArcanaSystem” data equivalent.
	# If ArcanaState doesn't provide tokens yet, return [] for now.
	if arcana and arcana.has_method("get_modifier_tokens_for_target"):
		return arcana.get_modifier_tokens_for_target(self, target_id)
	return []

func _modifier_token_applies_to_target(token: ModifierToken, target_id: int) -> bool:
	if token == null:
		return false

	match int(token.scope):
		ModifierToken.ModScope.GLOBAL:
			return true
		ModifierToken.ModScope.SELF:
			return int(token.owner_id) == int(target_id)
		ModifierToken.ModScope.TARGET:
			return int(token.owner_id) == int(target_id)
		_:
			return false

# Minimal clone (good enough for early previews; deepen as needed)
func clone() -> BattleState:
	var b := BattleState.new()
	b.battle_seed = battle_seed
	b.run_seed = run_seed
	b.summon_card_max_health_bonus = summon_card_max_health_bonus.duplicate(true)

	b.rng = RNG.new()
	b.rng.seed = rng.seed
	b._next_sim_id = _next_sim_id

	for id in units.keys():
		var u: CombatantState = units[id]
		if u:
			b.units[id] = u.clone()

	b.groups = [groups[0].clone(), groups[1].clone()]
	b.turn = turn.clone()
	b.arcana = arcana.clone() if arcana != null else ArcanaState.new()
	b.aura_bank = aura_bank.clone() if aura_bank != null else AuraBankScript.new()
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
	for entry: ArcanaState.ArcanumEntry in arcana.list:
		if entry == null:
			continue

		var type_name := "type=%d" % int(entry.type)
		if entry.type >= 0 and entry.type < Arcanum.Type.keys().size():
			type_name = Arcanum.Type.keys()[int(entry.type)]

		var extra: Array[String] = []
		if int(entry.charges) != 0:
			extra.append("charges=%d" % int(entry.charges))
		if int(entry.cooldown) != 0:
			extra.append("cooldown=%d" % int(entry.cooldown))
		if !entry.data.is_empty():
			extra.append("data=%s" % str(entry.data))

		var suffix := ""
		if !extra.is_empty():
			suffix = " {%s}" % ", ".join(extra)

		parts.append("%s(%s)%s" % [String(entry.id), type_name, suffix])

	return "[" + ", ".join(parts) + "]"

func _debug_unit_summary(unit: CombatantState) -> String:
	var team_name := _debug_group_name(int(unit.team))
	var type_name := _debug_combatant_type_name(int(unit.type))
	var mortality_name := _debug_mortality_name(int(unit.mortality))
	var statuses := _debug_status_summary(unit)
	var proto := ""
	if !String(unit.data_proto_path).is_empty():
		proto = " proto=%s" % String(unit.data_proto_path).get_file()

	return "cid=%d name=%s team=%s type=%s mortality=%s alive=%s hp=%d/%d armor=%d mana=%d/%d apm=%d apr=%d%s%s" % [
		int(unit.id),
		String(unit.name),
		team_name,
		type_name,
		mortality_name,
		str(bool(unit.alive)),
		int(unit.health),
		int(unit.max_health),
		int(unit.armor),
		int(unit.mana),
		int(unit.max_mana),
		int(unit.apm),
		int(unit.apr),
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
	if unit == null or unit.statuses == null or unit.statuses.by_id.is_empty():
		return ""

	var parts: Array[String] = []
	for stack: StatusStack in unit.statuses.get_all_stacks(true):
		if stack == null:
			continue
		parts.append("%s(i=%d,d=%d)" % [
			("%s[p]" % String(stack.id)) if bool(stack.pending) else String(stack.id),
			int(stack.intensity),
			int(stack.duration),
		])

	parts.sort()
	return " statuses=[" + ", ".join(parts) + "]"
