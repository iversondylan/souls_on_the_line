# battle_resolver.gd
class_name BattleResolver extends RefCounted

# -----------------------------
# Tunables / policies
# -----------------------------

const FRIENDLY := 0
const ENEMY := 1

# Mirrors your TurnEngineCore policy:
# - Player: 1 action per friendly group turn
# - Enemies: N actions per enemy group turn (or per group turn generally)
const MAX_ENEMY_ACTIONS_PER_GROUP_TURN := 3
const MAX_FRIENDLY_NONPLAYER_ACTIONS_PER_GROUP_TURN := 3
const MAX_PLAYER_ACTIONS_PER_GROUP_TURN := 1


# ============================================================
#	BATTLE-LEVEL FLOW
# ============================================================

static func begin_group_turn(state: BattleState, group_index: int, start_at_player := false) -> Array:
	var ops: Array = []

	if !state:
		return ops

	group_index = clampi(group_index, 0, 1)
	state.turn.active_group = group_index
	state.turn.reset_group_turn()

	# Optional: you can choose to rotate ENEMY order via a cursor later.
	# For now, we just rebuild from current group order.
	rebuild_queue(state, start_at_player)

	# Hooks (headless): emit ops instead of awaiting anything.
	ops.append_array(_emit_group_turn_start_hooks(state, group_index))

	# If you want START_OF_TURN arcana to behave like “it happened before anyone acts”,
	# do it here by emitting ops. (No waiting; runner will animate later.)
	# Note: your live flow does START_OF_COMBAT/START_OF_TURN gating; headless should emit,
	# and the driver decides when it must block interaction.
	ops.append_array(_emit_arcana_proc(state, _arcana_proc_for_group_start(group_index)))

	return ops


static func end_group_turn(state: BattleState) -> Array:
	var ops: Array = []
	if !state:
		return ops

	var ended := int(state.turn.active_group)

	ops.append_array(_emit_group_turn_end_hooks(state, ended))

	# END_OF_TURN boundary: most games tie this to FRIENDLY end, but you can choose.
	# I’m mirroring your current live semantics: END_OF_TURN arcana happens when player finishes.
	# At pure group-end we’ll emit a proc too (caller can ignore if redundant).
	ops.append_array(_emit_arcana_proc(state, Arcanum.Type.END_OF_TURN))

	# Advance group / round bookkeeping
	if ended == ENEMY:
		state.turn.round += 1

	state.turn.active_group = -1
	state.turn.queue = PackedInt32Array()
	state.turn.active_id = 0
	state.turn.actions_this_group_turn.clear()

	return ops


static func advance_to_next_actor(state: BattleState, start_at_player := false) -> int:
	# Returns next actor id (and sets state.turn.active_id),
	# or 0 if group turn is over.
	if !state:
		return 0

	# Ensure queue exists
	if state.turn.queue.is_empty():
		rebuild_queue(state, start_at_player)

	# Pop dead/invalid until we find someone
	while !state.turn.queue.is_empty():
		var id := int(state.turn.queue[0])
		state.turn.queue.remove_at(0)

		if is_alive(state, id) and get_group_index_of(state, id) == state.turn.active_group:
			state.turn.active_id = id
			return id

	# Nobody left
	state.turn.active_id = 0
	return 0


static func mark_action_taken(state: BattleState, combat_id: int, n := 1) -> void:
	if !state:
		return
	if combat_id <= 0:
		return
	n = maxi(int(n), 1)

	var cur := int(state.turn.actions_this_group_turn.get(combat_id, 0))
	state.turn.actions_this_group_turn[combat_id] = cur + n


# ============================================================
#	TURN / QUEUE (TURN RESOLVER)
# ============================================================

static func rebuild_queue(state: BattleState, start_at_player := false) -> void:
	if !state:
		return

	var gi := int(state.turn.active_group)
	if gi < 0:
		state.turn.queue = PackedInt32Array()
		return

	var desired := _get_desired_order_ids(state, gi, start_at_player)

	var out := PackedInt32Array()
	for cid in desired:
		var id := int(cid)
		if !is_alive(state, id):
			continue
		if _actions_left_this_group_turn(state, id, gi) <= 0:
			continue
		out.append(id)

	state.turn.queue = out


static func _actions_left_this_group_turn(state: BattleState, combat_id: int, group_index: int) -> int:
	if !is_alive(state, combat_id):
		return 0

	var taken := int(state.turn.actions_this_group_turn.get(combat_id, 0))

	# Player special-case
	if group_index == FRIENDLY and is_player(state, combat_id):
		return MAX_PLAYER_ACTIONS_PER_GROUP_TURN - taken

	# Non-player in friendly group (summons etc.)
	if group_index == FRIENDLY:
		return MAX_FRIENDLY_NONPLAYER_ACTIONS_PER_GROUP_TURN - taken

	# Enemy group
	return MAX_ENEMY_ACTIONS_PER_GROUP_TURN - taken


static func _get_desired_order_ids(state: BattleState, group_index: int, start_at_player := false) -> PackedInt32Array:
	var order := get_group_order_ids(state, group_index)
	if order.is_empty():
		return PackedInt32Array()

	# Friendly: player first, then everyone behind them (mirrors your TurnEngineCore).
	if group_index == FRIENDLY:
		var p := get_player_id(state)
		if p <= 0:
			return PackedInt32Array()

		var player_idx := order.find(p)
		if player_idx == -1:
			return PackedInt32Array()

		var out := PackedInt32Array()
		out.append(p)

		# Behind player only (skip anyone “in front” if that ever exists)
		for i in range(player_idx + 1, order.size()):
			out.append(order[i])

		return out

	# Enemy: front->back (simple, deterministic).
	# If you later want cursor-rotation, add a TurnState.cursor_id and rotate here.
	return order.duplicate()


# ============================================================
#	GROUP / FORMATION (GROUP RESOLVER)
# ============================================================

static func add_unit(state: BattleState, unit: CombatantState, group_index: int, insert_index := -1) -> void:
	if !state or !unit:
		return

	group_index = clampi(group_index, 0, 1)
	unit.team = group_index

	state.units[unit.id] = unit

	var g: GroupState = state.groups[group_index]
	if insert_index < 0:
		insert_index = g.order.size()
	insert_index = clampi(insert_index, 0, g.order.size())

	var new_order := PackedInt32Array()
	for i in range(0, g.order.size()):
		if i == insert_index:
			new_order.append(unit.id)
		new_order.append(int(g.order[i]))

	if insert_index == g.order.size():
		new_order.append(unit.id)

	g.order = new_order

	# Maintain player_id anchor if needed
	if group_index == FRIENDLY and g.player_id == 0:
		g.player_id = unit.id


static func remove_unit_from_group(state: BattleState, combat_id: int) -> void:
	if !state:
		return
	if combat_id <= 0:
		return

	var gi := get_group_index_of(state, combat_id)
	if gi < 0:
		return

	var g: GroupState = state.groups[gi]
	var idx := g.order.find(combat_id)
	if idx != -1:
		var new_order := g.order.duplicate()
		new_order.remove_at(idx)
		g.order = new_order


static func move_within_group(state: BattleState, combat_id: int, new_index: int) -> Dictionary:
	# Returns { before_order_ids, after_order_ids } for “restore turn” logic later.
	var out := {
		"before_order_ids": PackedInt32Array(),
		"after_order_ids": PackedInt32Array(),
	}

	if !state or combat_id <= 0:
		return out

	var gi := get_group_index_of(state, combat_id)
	if gi < 0:
		return out

	var g: GroupState = state.groups[gi]
	out.before_order_ids = g.order.duplicate()

	var idx := g.order.find(combat_id)
	if idx == -1:
		return out

	var arr := g.order.duplicate()
	arr.remove_at(idx)

	new_index = clampi(int(new_index), 0, arr.size())
	arr.insert(new_index, combat_id)

	g.order = arr
	out.after_order_ids = g.order.duplicate()
	return out


static func swap_within_group(state: BattleState, a: int, b: int) -> Dictionary:
	var out := {
		"before_order_ids": PackedInt32Array(),
		"after_order_ids": PackedInt32Array(),
	}

	if !state:
		return out
	if a <= 0 or b <= 0 or a == b:
		return out

	var ga := get_group_index_of(state, a)
	var gb := get_group_index_of(state, b)
	if ga < 0 or ga != gb:
		return out

	var g: GroupState = state.groups[ga]
	out.before_order_ids = g.order.duplicate()

	var ia := g.order.find(a)
	var ib := g.order.find(b)
	if ia == -1 or ib == -1:
		return out

	var arr := g.order.duplicate()
	arr[ia] = b
	arr[ib] = a
	g.order = arr

	out.after_order_ids = g.order.duplicate()
	return out


static func get_group_order_ids(state: BattleState, group_index: int) -> PackedInt32Array:
	if !state:
		return PackedInt32Array()
	group_index = clampi(group_index, 0, 1)
	var g: GroupState = state.groups[group_index]
	return g.order


static func get_group_index_of(state: BattleState, combat_id: int) -> int:
	if !state:
		return -1
	var u: CombatantState = state.units.get(combat_id, null)
	if !u:
		return -1
	return int(u.team)


static func get_front_id(state: BattleState, group_index: int) -> int:
	if !state:
		return 0
	group_index = clampi(group_index, 0, 1)
	return state.groups[group_index].front_id(state.units)


# ============================================================
#	QUERIES
# ============================================================

static func is_alive(state: BattleState, combat_id: int) -> bool:
	if !state:
		return false
	var u: CombatantState = state.units.get(combat_id, null)
	return u != null and u.is_alive()


static func is_player(state: BattleState, combat_id: int) -> bool:
	return combat_id > 0 and combat_id == get_player_id(state)


static func get_player_id(state: BattleState) -> int:
	if !state:
		return 0
	var g: GroupState = state.groups[FRIENDLY]
	return int(g.player_id)


# ============================================================
#	HOOKS / ARCANA (HEADLESS EMIT-ONLY)
# ============================================================

static func _emit_group_turn_start_hooks(state: BattleState, active_group_index: int) -> Array:
	# For now: just return ops that describe what should happen.
	# Later: status procs, aura refresh, etc.
	var ops: Array = []
	ops.append({
		"op": "group_turn_start",
		"group": int(active_group_index),
	})
	return ops


static func _emit_group_turn_end_hooks(state: BattleState, ended_group_index: int) -> Array:
	var ops: Array = []
	ops.append({
		"op": "group_turn_end",
		"group": int(ended_group_index),
	})
	return ops


static func _arcana_proc_for_group_start(group_index: int) -> int:
	#return 0
	# Mirror your live semantics loosely:
	# - Returning to friendly typically means START_OF_TURN matters for player.
	# - Enemy start could also be START_OF_TURN if you want symmetric procs later.
	# For now: always emit START_OF_TURN.
	return Arcanum.Type.START_OF_TURN


static func _emit_arcana_proc(state: BattleState, proc: int) -> Array:
	# This is intentionally “emit-only”; the driver decides whether to block input
	# until these ops are presented/consumed.
	var ops: Array = []
	ops.append({
		"op": "arcana_proc",
		"proc": int(proc),
	})
	return ops

# ============================================================
#	LIVE DAMAGE RESOLUTION (DamageContext)
#	Canonical numeric rules + triggers, presentation stays in API.
# ============================================================

static func resolve_damage_live(api: BattleAPI, ctx: DamageContext) -> void:
	if !api or !ctx:
		return

	# Ensure nodes exist if caller didn't hydrate
	if ctx.target == null and ctx.target_id != 0 and api.has_method("battle_scene"):
		# can't assume; LiveBattleAPI hydrates earlier anyway
		pass

	if !ctx.target or !is_instance_valid(ctx.target):
		return
	if !ctx.target.is_alive():
		return
	
	
	#print("DAMAGE ctx.amount=", ctx.amount, " params_keys=", (ctx.params.keys() if ctx.params else null))
	#print("has StringName? ", (ctx.params.has(NPCKeys.DAMAGE) if ctx.params else false),
		#" has String? ", (ctx.params.has(String(NPCKeys.DAMAGE)) if ctx.params else false))
	# Determine raw base damage
	# Prefer ctx.amount / ctx.base_amount if you have them; otherwise use ctx.params.
	var base := 0
	if ctx.has_method("get_base_amount"):
		base = int(ctx.get_base_amount())
	elif ctx.params != null and ctx.params.has(NPCKeys.DAMAGE):
		base = int(ctx.params[NPCKeys.DAMAGE])
	else:
		base = int(ctx.amount)

	base = maxi(base, 0)

	# Phase: modifiers
	var final_amount := base
	if api.has_method("modify_damage_amount"):
		final_amount = int(api.modify_damage_amount(ctx, base))
	final_amount = maxi(final_amount, 0)

	# Phase: apply to data, fill ctx outputs
	if api.has_method("apply_damage_amount"):
		api.apply_damage_amount(ctx, final_amount)
	else:
		# If you ever run in pure headless without LiveBattleAPI, you'd implement
		# a BattleState version elsewhere.
		return

	# Phase: triggers/reactions (gameplay + presentation)
	if api.has_method("on_damage_applied"):
		api.on_damage_applied(ctx)
