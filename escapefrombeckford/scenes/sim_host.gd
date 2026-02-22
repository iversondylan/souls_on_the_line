# sim_host.gd

class_name SimHost extends Node

## Owns authoritative headless battle state + the APIs that operate on it.
## - main_state: authoritative sim
## - preview_state: cloned from main for forecasts / UI previews
## - main_api / preview_api: SimBattleAPI instances bound to those states
##
## This is intentionally "thin": catalogs (status/ai/arcana) can be added later.

signal main_state_initialized()
signal preview_state_cloned()
signal combatant_added(combat_id: int, group_index: int, insert_index: int, is_preview: bool)
signal player_input_reached()

const FRIENDLY := 0
const ENEMY := 1

var main_state: BattleState
var preview_state: BattleState

var main_api: SimBattleAPI
var preview_api: SimBattleAPI

var turn_engine: TurnEngineCore
var turn_engine_host_sim: TurnEngineHostSim
var preview_turn_engine: TurnEngineCore
var arcana_resolver: ArcanaResolver
# Optional: if you want the host to be responsible for assigning ids later.
var _next_sim_id: int = 1

# --- optional catalogs (wire later) ---
var status_catalog: StatusCatalog
# var ai_catalog: NPCAIProfileCatalog
var arcana_catalog: ArcanaCatalog


# -------------------------
# Lifecycle / initialization
# -------------------------

func reset() -> void:
	main_state = null
	preview_state = null
	main_api = null
	preview_api = null
	_next_sim_id = 1

func init_from_seeds(battle_seed: int, run_seed: int) -> void:
	main_state = BattleState.new()
	main_state.init(int(battle_seed), int(run_seed))
	
	main_api = SimBattleAPI.new(main_state)
	main_api.status_catalog = status_catalog
	
	# NEW: id allocation + notify turn engine
	main_api.alloc_id = func() -> int:
		return alloc_sim_id()
	
	main_api.on_summoned = func(summoned_id: int, group_index: int) -> void:
		# Let TurnEngineCore rebuild pending view immediately
		if turn_engine != null:
			turn_engine.notify_summon_added(int(summoned_id), int(group_index))
	
	preview_state = null
	preview_api = null
	main_state_initialized.emit()

func ensure_initialized() -> void:
	
	if turn_engine_host_sim == null:
		turn_engine_host_sim = TurnEngineHostSim.new(self)
	if main_state == null:
		# Safe default if caller forgot.
		init_from_seeds(0, 0)
	if arcana_resolver == null and arcana_catalog != null:
		arcana_resolver = ArcanaResolver.new(self, arcana_catalog)

func alloc_sim_id() -> int:
	# Not used yet if you mirror live combat_id, but useful when sim becomes canonical.
	var id := _next_sim_id
	_next_sim_id += 1
	return id

func seed_arcana_from_ids(ids: Array[StringName]) -> void:
	if main_state == null:
		return
	main_state.arcana.clear()
	for id in ids:
		var a := arcana_catalog.get_proto(id)
		if a == null:
			continue
		main_state.arcana.add_arcanum(id, int(a.type))

# -------------------------
# Battle Commands
# -------------------------

func start_group_turn(group_index: int, start_at_player := false) -> void:
	ensure_initialized()

	if turn_engine == null:
		turn_engine = TurnEngineCore.new(turn_engine_host_sim)
		turn_engine.sim = true
		turn_engine.arcana_proc_requested.connect(_on_sim_arcana_proc_requested)
		turn_engine.actor_requested.connect(_on_sim_actor_requested)

	turn_engine.reset_for_new_battle()
	turn_engine.start_group_turn(group_index, start_at_player)

# -------------------------
# Stuff that happens
# -------------------------

func _on_sim_actor_requested(cid: int) -> void:
	# For your current milestone:
	if is_player(cid):
		# We are now at "player gets control" boundary in sim.
		player_input_reached.emit()
		return

	# Later: run headless AI here, call api verbs, then:
	# turn_engine.notify_actor_done(cid)


# -------------------------
# Accessors
# -------------------------

func get_main_api() -> SimBattleAPI:
	return main_api

func get_preview_api() -> SimBattleAPI:
	return preview_api

func get_main_state() -> BattleState:
	return main_state

func get_preview_state() -> BattleState:
	return preview_state

func is_player(combat_id: int) -> bool:
	return turn_engine_host_sim.is_player(combat_id)

# -------------------------
# Combatant bootstrap
# -------------------------

# sim_host.gd

func add_combatant_from_data(
	data: CombatantData,
	group_index: int,
	insert_index: int,
	is_player: bool = false
) -> CombatantState:
	ensure_initialized()

	if data == null:
		push_warning("SimHost.add_combatant_from_data: data is null")
		return null

	var combat_id := int(data.combat_id)
	if combat_id <= 0:
		push_warning("SimHost.add_combatant_from_data: data.combat_id must be > 0 (got %s)" % combat_id)
		return null

	# Don’t “ensure” alignment, just detect & warn.
	if main_state.has_unit(combat_id):
		push_warning("SimHost.add_combatant_from_data: duplicate id %s (data=%s)" % [combat_id, data.resource_path])
		return main_state.get_unit(combat_id)

	# Optional: if you're still tracking _next_sim_id for any reason, keep it loosely in sync.
	_next_sim_id = maxi(_next_sim_id, combat_id + 1)

	var u := CombatantState.new()
	u.id = combat_id
	u.init_from_combatant_data(data)

	if data.resource_path != "":
		u.data_proto_path = String(data.resource_path)

	main_state.add_unit(u, int(group_index), int(insert_index))

	if is_player:
		main_state.groups[FRIENDLY].player_id = combat_id

	combatant_added.emit(combat_id, int(group_index), int(insert_index), false)
	return u

### Add a unit to MAIN state by translating CombatantData -> CombatantState.
### You should call this right after live allocates the combat_id and sets combatant_data.
#func add_combatant_from_data(
	#combat_id: int,
	#data: CombatantData,
	#group_index: int,
	#insert_index: int,
	#is_player: bool = false
#) -> CombatantState:
	#ensure_initialized()
#
	#if combat_id <= 0:
		#push_warning("SimHost.add_combatant_from_data: combat_id must be > 0")
		#return null
#
	## Keep sim id allocator in sync with live ids (helpful while mirroring live ids).
	#_next_sim_id = maxi(_next_sim_id, combat_id + 1)
#
	#if main_state.has_unit(combat_id):
		#push_warning("SimHost.add_combatant_from_data: unit id already exists: %s" % combat_id)
		#return main_state.get_unit(combat_id)
#
	#var u := CombatantState.new()
	#u.id = int(combat_id)
	#u.init_from_combatant_data(data)
#
	## Optional: store reconstruction hints (helpful later)
	## If CombatantData has resource path accessible, keep it.
	#if data and data.resource_path != "":
		#u.data_proto_path = String(data.resource_path)
#
	#main_state.add_unit(u, int(group_index), int(insert_index))
#
	#if is_player:
		#main_state.groups[FRIENDLY].player_id = int(combat_id)
#
	#combatant_added.emit(int(combat_id), int(group_index), int(insert_index), false)
	#return u


# -------------------------
# Preview cloning
# -------------------------

## Create or refresh preview_state as a clone of main_state.
## Call before doing forecast simulations.
func clone_preview_from_main() -> void:
	ensure_initialized()
	if main_state == null:
		return

	preview_state = main_state.clone()
	preview_api = SimBattleAPI.new(preview_state)
	preview_api.status_catalog = status_catalog

	preview_state_cloned.emit()

## Ensures preview exists (cloned from main if missing).
func ensure_preview() -> void:
	if preview_state == null or preview_api == null:
		clone_preview_from_main()


# -------------------------
# Preview-only mutations (optional helpers)
# -------------------------

## Adds a unit to PREVIEW (useful for preview-only summons).
## This expects a fully constructed CombatantState.
func add_preview_unit(u: CombatantState, group_index: int, insert_index: int) -> void:
	ensure_preview()
	if u == null:
		return
	if u.id <= 0:
		push_warning("SimHost.add_preview_unit: unit id must be > 0")
		return
	if preview_state.has_unit(u.id):
		push_warning("SimHost.add_preview_unit: duplicate id %s" % u.id)
		return

	preview_state.add_unit(u, int(group_index), int(insert_index))
	combatant_added.emit(int(u.id), int(group_index), int(insert_index), true)

## Convenience: rebuild preview fresh, then run a closure to mutate it.
func with_fresh_preview(fn: Callable) -> void:
	clone_preview_from_main()
	if fn.is_valid():
		fn.call()

# -------------------------
# Arcana
# -------------------------

func _on_sim_arcana_proc_requested(proc: int, token: int) -> void:
	if arcana_resolver == null:
		if arcana_catalog == null:
			push_warning("SimHost: no arcana_catalog; cannot run arcana")
		else:
			arcana_resolver = ArcanaResolver.new(self, arcana_catalog)
	if arcana_resolver != null:
		arcana_resolver.run_proc(proc)
	turn_engine.notify_arcana_proc_done(token)

func _proc_to_arcanum_type(proc: int) -> int:
	match proc:
		TurnEngineCore.ArcanaProc.START_OF_COMBAT:
			return int(Arcanum.Type.START_OF_COMBAT)
		TurnEngineCore.ArcanaProc.START_OF_TURN:
			return int(Arcanum.Type.START_OF_TURN)
		TurnEngineCore.ArcanaProc.END_OF_TURN:
			return int(Arcanum.Type.END_OF_TURN)
		_:
			return -1

func _run_arcana_headless(proc: int) -> void:
	if main_state == null or main_api == null:
		return
	if arcana_catalog == null:
		push_warning("SimHost._run_arcana_headless: arcana_catalog is null")
		return

	var arcanum_type := _proc_to_arcanum_type(proc)
	if arcanum_type == -1:
		return

	# Deterministic: iterate the ArcanaState ordered list
	for entry: ArcanaState.ArcanumEntry in main_state.arcana.list:
		if entry == null:
			continue
		if int(entry.type) != arcanum_type:
			continue

		var id := entry.id
		if id == &"":
			continue

		var proto: Arcanum = arcana_catalog.get_proto(id)
		if proto == null:
			push_warning("SimHost._run_arcana_headless: missing proto for id=%s" % String(id))
			continue

		var ctx := ArcanumContext.new()
		ctx.api = main_api
		ctx.api = main_api
		ctx.params = {}
		ctx.params["source_id"] = int(main_state.groups[FRIENDLY].player_id)
		# ctx.battle_scene = null (headless)
		# ctx.player = null (headless) unless you add a sim player handle
		# ctx.arcanum_display = null (headless)

		# Optional: if you want arcana to know it’s a forecast/sim.
		# ctx.forecast = false
		
		
		
		## What class should this be? Can't be inferred.
		var r = proto.activate_arcanum(ctx)

		# Headless policy: warn if arcana tries to async.
		if r is Signal and !(r as Signal).is_null():
			push_warning("Sim arcana %s returned Signal; ignoring in headless." % String(id))
		elif typeof(r) == TYPE_OBJECT and r != null and r.get_class() == "GDScriptFunctionState":
			push_warning("Sim arcana %s returned FunctionState; ignoring in headless." % String(id))

# -------------------------
# Debug / sanity
# -------------------------

func debug_dump_orders() -> void:
	if main_state == null:
		print("SimHost: (no main_state)")
		return

	print("SimHost main orders:")
	print("\tFRIENDLY: ", Array(main_state.groups[0].order))
	print("\tENEMY:    ", Array(main_state.groups[1].order))

	if preview_state != null:
		print("SimHost preview orders:")
		print("\tFRIENDLY: ", Array(preview_state.groups[0].order))
		print("\tENEMY:    ", Array(preview_state.groups[1].order))

func debug_dump_units() -> void:
	if main_state == null:
		print("SimHost.debug_dump_units(): (no main_state)")
		return
	
	print("SimHost units dump:")
	for group_index in [FRIENDLY, ENEMY]:
		var gname := "FRIENDLY" if group_index == FRIENDLY else "ENEMY"
		var order := main_state.groups[group_index].order
		print("%s order: %s" % [gname, Array(order)])
		
		for i in range(order.size()):
			var cid := int(order[i])
			var u: CombatantState = main_state.get_unit(cid)
			if u == null:
				print("\t[%d] cid=%d MISSING_UNIT" % [i, cid])
				continue
			
			var uname := _debug_unit_name(u)
			var hp := int(u.health)
			var max_hp := int(u.max_health) if "max_health" in u else int(u.max_hp) if "max_hp" in u else -1
			var alive := bool(u.alive) if "alive" in u else main_state.is_alive(cid)
			
			var hp_str := "%d/%d" % [hp, max_hp] if max_hp >= 0 else "%d" % hp
			print("\t[%d] cid=%d name=%s hp=%s group=%s pos=%d alive=%s" % [
				i, cid, uname, hp_str, gname, i, str(alive)
			])

	# Optional: show any units not present in either group order (diagnostic)
	var seen := {}
	for group_index in [FRIENDLY, ENEMY]:
		for cid in main_state.groups[group_index].order:
			seen[int(cid)] = true

	var extras: Array[int] = []
	for k in main_state.units.keys():
		var cid := int(k)
		if !seen.has(cid):
			extras.append(cid)

	if !extras.is_empty():
		extras.sort()
		print("SimHost units not in any group order: ", extras)


func _debug_unit_name(u: CombatantState) -> String:
	# 1) direct name field (if your CombatantState has it)
	if u != null and ("name" in u):
		var n := String(u.name)
		if n != "":
			return n

	# 2) fall back to proto path file basename
	if u != null and ("data_proto_path" in u):
		var p := String(u.data_proto_path)
		if p != "":
			var base := p.get_file()
			if base != "":
				return base.get_basename()

	return "<unnamed>"
