# sim_host.gd

class_name SimHost extends Node

signal main_state_initialized()
signal preview_state_cloned()
signal combatant_added(combat_id: int, group_index: int, insert_index: int, is_preview: bool)
signal player_input_reached()

const FRIENDLY := 0
const ENEMY := 1

#var main_state: BattleState : set = _set_main_state
#var preview_state: BattleState
#
#var main_api: SimBattleAPI
#var preview_api: SimBattleAPI

var turn_engine: TurnEngineCore
var turn_engine_host_sim: TurnEngineHostSim
var preview_turn_engine: TurnEngineCore
var arcana_resolver: ArcanaResolver
var card_executor: CardExecutor

var status_catalog: StatusCatalog : set = _set_status_catalog
var arcana_catalog: ArcanaCatalog : set = _set_arcana_catalog

# new structural elements for sim architecture
var main: Sim : set = _set_main
var preview: Sim

func _set_main(new_sim: Sim) -> void:
	main = new_sim
	if main == null:
		return

	main.status_catalog = status_catalog
	main.arcana_catalog = arcana_catalog

	if main.state:
		main.state.status_catalog = status_catalog
		main.state.arcana_catalog = arcana_catalog

	if main.api:
		main.api.status_catalog = status_catalog

func _set_status_catalog(catalog: StatusCatalog) -> void:
	status_catalog = catalog

	if main != null:
		main.status_catalog = catalog
		if main.state:
			main.state.status_catalog = catalog
		if main.api:
			main.api.status_catalog = catalog

	if preview != null:
		preview.status_catalog = catalog
		if preview.state:
			preview.state.status_catalog = catalog
		if preview.api:
			preview.api.status_catalog = catalog

func _set_arcana_catalog(catalog: ArcanaCatalog) -> void:
	arcana_catalog = catalog

	if main != null:
		main.arcana_catalog = catalog
		if main.state:
			main.state.arcana_catalog = catalog

	if preview != null:
		preview.arcana_catalog = catalog
		if preview.state:
			preview.state.arcana_catalog = catalog

func reset() -> void:
	main = null
	preview = null
	turn_engine = null
	preview_turn_engine = null
	arcana_resolver = null
	card_executor = null

func init_from_seeds(battle_seed: int, run_seed: int) -> void:
	main = Sim.new()
	main.status_catalog = status_catalog
	main.arcana_catalog = arcana_catalog
	main.is_preview = false
	main.init_from_seeds(int(battle_seed), int(run_seed))

	var scopes := BattleScopeManager.new()
	scopes.reset()
	main.api.scopes = scopes
	main.api.writer = BattleEventWriter.new(main.state.events, scopes)
	main.api.writer.allow_unscoped_events = false

	# Root scope: battle
	main.api.writer.set_turn_context(0, -1, 0)
	main.api.writer.scope_begin(Scope.Kind.BATTLE, "battle_seed=%d run_seed=%d" % [battle_seed, run_seed], 0)

	main.api.on_summoned = func(summoned_id: int, group_index: int) -> void:
		if turn_engine != null:
			turn_engine.notify_summon_added(int(summoned_id), int(group_index))

	main_state_initialized.emit()

func ensure_initialized() -> void:
	if turn_engine_host_sim == null:
		turn_engine_host_sim = TurnEngineHostSim.new(self)

	if main == null or main.state == null or main.api == null:
		init_from_seeds(0, 0)

	if arcana_resolver == null and arcana_catalog != null:
		arcana_resolver = ArcanaResolver.new(self, arcana_catalog)

func start_setup() -> void:
	if main == null or main.api == null or main.api.writer == null:
		return
	main.api.writer.scope_begin(Scope.Kind.SETUP, "setup", 0)


func end_setup() -> void:
	if main == null or main.state == null or main.api == null or main.api.writer == null:
		return

	main.api.writer.emit_formation_set(
		main.state.groups[0].order.duplicate(),
		main.state.groups[1].order.duplicate(),
		main.state.groups[0].player_id
	)
	main.api.writer.scope_end() # setup

	if main.intent_planner != null:
		main.intent_planner.ensure_valid_plans(main.api, true)

func get_event_log() -> BattleEventLog:
	if main == null or main.state == null:
		return null
	return main.state.events

func seed_arcana_from_ids(ids: Array[StringName]) -> void:
	if main.state == null:
		return

	#print("[SIM][SEED] ids=%s" % str(ids))
	main.state.arcana.clear()

	for id in ids:
		var proto := arcana_catalog.get_proto(id)
		#print("[SIM][SEED] id=%s proto=%s" % [String(id), proto])

		if proto == null:
			continue

		#print("[SIM][SEED]  -> type=%s (%d)" % [Arcanum.Type.keys()[int(proto.type)], int(proto.type)])

		main.state.arcana.add_arcanum(id, int(proto.type))

		#print("[SIM][SEED]  -> after add: list_size=%d list=%s" % [
			#main_state.arcana.list.size(),
			#str(main_state.arcana.list.map(func(e): return String(e.id)))
		#])

func start_group_turn(group_index: int, start_at_player := false) -> void:
	ensure_initialized()

	if turn_engine == null:
		turn_engine = TurnEngineCore.new(turn_engine_host_sim)
		turn_engine.sim = true
		turn_engine.group_turn_ended.connect(_on_sim_group_turn_ended)
		turn_engine.arcana_proc_requested.connect(_on_sim_arcana_proc_requested)
		turn_engine.actor_requested.connect(_on_sim_actor_requested)
		turn_engine.player_begin_requested.connect(_on_sim_player_begin_requested)
		turn_engine.player_end_requested.connect(_on_sim_player_end_requested)

	# NOTE: starting at player should only occur on the first turn of the battle
	# but I don't know if this is the right solution
	if start_at_player:
		turn_engine.reset_for_new_battle()
	
	if main != null and main.api != null and main.api.writer != null:
		main.api.writer.set_turn_context(turn_engine._turn_token, group_index, 0)
		main.api.writer.scope_begin(Scope.Kind.GROUP_TURN, "group=%d" % group_index, 0)
		main.api.writer.emit_group_turn_begin(group_index)
	if main != null and main.api != null:
		main.api.on_group_turn_begin(group_index)
	
	turn_engine.start_group_turn(group_index, start_at_player)

func _on_sim_group_turn_ended(gi: int) -> void:
	
	if main != null and main.api != null:
		main.api.on_group_turn_end(gi)

	if main != null and main.api != null and main.api.writer != null:
		main.api.writer.emit_group_turn_end(gi)
		main.api.writer.scope_end() # group_turn
	
	if gi == 0:
		start_group_turn(1, false) # enemy group
	else:
		start_group_turn(0, false)  # friendly group, start at player

func _on_sim_player_begin_requested(token: int) -> void:
	if turn_engine_host_sim != null:
		if sim_host_has_begin_player_turn():
			_call_sim_begin_player_turn()

	turn_engine.notify_player_begin_done(token)

func request_player_end() -> void:
	turn_engine.request_player_end()

func _on_sim_player_end_requested(token: int) -> void:
	# 1) end-of-player bookkeeping (discard, etc.)
	if turn_engine_host_sim != null and sim_host_has_end_player_turn():
		_call_sim_end_player_turn()
	
	# 2) END_OF_TURN arcana occurs at player-end resolution
	var player_id := turn_engine_host_sim.get_player_id()
	print("[SIM] player_end_requested token=%d -> running END_OF_TURN arcana, then actor_done(player=%d)" % [token, player_id])
	turn_engine.request_end_of_turn_arcana(func():
		# IMPORTANT ordering:
		# - First satisfy the player_end token handshake
		turn_engine.notify_player_end_done(token)
		
		# - Then end the actor turn (this advances the queue / group)
		#   Also closes the actor scope in the event writer.
		sim_notify_actor_done(player_id)
	)

func sim_notify_actor_done(cid: int) -> void:
	if main != null and main.api != null and main.api.writer != null:
		main.api.writer.emit_actor_end(cid)
		main.api.writer.scope_end() # actor_turn
	turn_engine.notify_actor_done(cid)

func sim_host_has_begin_player_turn() -> bool:
	return has_method("begin_player_turn_sim") or has_method("begin_player_turn_headless") or has_method("begin_player_turn")

func sim_host_has_end_player_turn() -> bool:
	return has_method("end_player_turn_sim") or has_method("end_player_turn_headless") or has_method("end_player_turn")

func _call_sim_begin_player_turn() -> void:
	if has_method("begin_player_turn_sim"):
		call("begin_player_turn_sim")
	elif has_method("begin_player_turn_headless"):
		call("begin_player_turn_headless")
	elif has_method("begin_player_turn"):
		call("begin_player_turn")

func _call_sim_end_player_turn() -> void:
	if has_method("end_player_turn_sim"):
		call("end_player_turn_sim")
	elif has_method("end_player_turn_headless"):
		call("end_player_turn_headless")
	elif has_method("end_player_turn"):
		call("end_player_turn")

# -------------------------
# Stuff that happens
# -------------------------

func _on_sim_actor_requested(cid: int) -> void:
	print("sim_host() _on_sim_actor_requested() cid: ", cid)
	if main != null and main.api != null and main.api.writer != null:
		main.api.writer.set_turn_context(turn_engine._turn_token, turn_engine.active_group_index, cid)
		main.api.writer.scope_begin(Scope.Kind.ACTOR_TURN, "actor=%d" % cid, cid)
		main.api.writer.emit_actor_begin(cid)
	
	if is_player(cid):
		player_input_reached.emit()
		return
	
	## NPC SIM turn (sync)
	#ActionPlanner.run_turn(main.api, cid)
	
	# NPC SIM turn (sync)
	if main != null and main.resolver != null:
		main.resolver.resolve_npc_turn(main, cid)
	
	if main != null and main.api != null and main.api.writer != null:
		main.api.writer.emit_actor_end(cid)
		main.api.writer.scope_end()
	
	turn_engine.notify_actor_done(cid)

func get_main_api() -> SimBattleAPI:
	return main.api if main != null else null

func get_preview_api() -> SimBattleAPI:
	return preview.api if preview != null else null

func get_main_state() -> BattleState:
	return main.state if main != null else null

func get_preview_state() -> BattleState:
	return preview.state if preview != null else null

func is_player(combat_id: int) -> bool:
	return turn_engine_host_sim.is_player(combat_id)

func add_combatant_from_data(data: CombatantData, group_index: int, insert_index: int = -1, is_player := false) -> int:
	ensure_initialized()
	if main == null or main.api == null:
		return 0
	return main.api.spawn_from_data(data, group_index, insert_index, is_player)

func apply_player_card(req: CardPlayRequest) -> bool:
	ensure_initialized()
	if main == null or main.api == null:
		return false
	if card_executor == null:
		card_executor = CardExecutor.new()
	
	if main == null or main.resolver == null:
		return false
	
	return main.resolver.resolve_player_card(main, req, card_executor)

func clone_preview_from_main() -> void:
	ensure_initialized()
	if main == null or main.state == null:
		return
	
	preview = main.clone_for_preview()
	
	preview_state_cloned.emit()

## Ensures preview exists (cloned from main if missing).
func ensure_preview() -> void:
	if preview == null or preview.state == null or preview.api == null:
		clone_preview_from_main()

func add_preview_unit(u: CombatantState, group_index: int, insert_index: int) -> void:
	ensure_preview()
	if u == null:
		return
	if u.id <= 0:
		push_warning("SimHost.add_preview_unit: unit id must be > 0")
		return
	if preview == null or preview.state == null:
		return
	if preview.state.has_unit(u.id):
		push_warning("SimHost.add_preview_unit: duplicate id %s" % u.id)
		return
	
	preview.state.add_unit(u, int(group_index), int(insert_index))
	combatant_added.emit(int(u.id), int(group_index), int(insert_index), true)

## Convenience: rebuild preview fresh, then run a closure to mutate it.
func with_fresh_preview(fn: Callable) -> void:
	clone_preview_from_main()
	if fn.is_valid():
		fn.call()

func _on_sim_arcana_proc_requested(proc: int, token: int) -> void:
	if main != null and main.api != null and main.api.writer != null:
		main.api.writer.scope_begin(Scope.Kind.ARCANA, "proc=%d" % int(proc), 0)
		main.api.writer.emit_arcana_proc(proc)
	
	if arcana_resolver == null:
		if arcana_catalog == null:
			push_warning("SimHost: no arcana_catalog; cannot run arcana")
		else:
			arcana_resolver = ArcanaResolver.new(self, arcana_catalog)
	
	if main != null and main.resolver != null and arcana_resolver != null:
		main.resolver.resolve_arcana_proc(main, proc, arcana_resolver)
	
	if main != null and main.api != null and main.api.writer != null:
		main.api.writer.scope_end() # arcana
	
	turn_engine.notify_arcana_proc_done(token)

#func _on_sim_arcana_proc_requested(proc: int, token: int) -> void:
	#if main != null and main.api != null and main.api.writer != null:
		#main.api.writer.scope_begin(Scope.Kind.ARCANA, "proc=%d" % int(proc), 0)
		#main.api.writer.emit_arcana_proc(proc)
	#if arcana_resolver == null:
		#if arcana_catalog == null:
			#push_warning("SimHost: no arcana_catalog; cannot run arcana")
		#else:
			#arcana_resolver = ArcanaResolver.new(self, arcana_catalog)
	#if arcana_resolver != null:
		#arcana_resolver.run_proc(proc)
	#turn_engine.notify_arcana_proc_done(token)

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

func debug_dump_orders() -> void:
	if main.state == null:
		push_warning("SimHost: (no main.state)")
		return
	
	print("SimHost main orders:")
	print("\tFRIENDLY: ", Array(main.state.groups[0].order))
	print("\tENEMY:    ", Array(main.state.groups[1].order))
	
	if preview != null and preview.state != null:
		print("SimHost preview orders:")
		print("\tFRIENDLY: ", Array(preview.state.groups[0].order))
		print("\tENEMY:    ", Array(preview.state.groups[1].order))

func debug_dump_units() -> void:
	if main.state == null:
		print("SimHost.debug_dump_units(): (no main.state)")
		return
	
	print("SimHost units dump:")
	for group_index in [FRIENDLY, ENEMY]:
		var gname := "FRIENDLY" if group_index == FRIENDLY else "ENEMY"
		var order := main.state.groups[group_index].order
		print("%s order: %s" % [gname, Array(order)])
		
		for i in range(order.size()):
			var cid := int(order[i])
			var u: CombatantState = main.state.get_unit(cid)
			if u == null:
				print("\t[%d] cid=%d MISSING_UNIT" % [i, cid])
				continue
			
			var uname := _debug_unit_name(u)
			var hp := int(u.health)
			var max_hp := int(u.max_health) if "max_health" in u else int(u.max_hp) if "max_hp" in u else -1
			var alive := bool(u.alive) if "alive" in u else main.state.is_alive(cid)
			
			var hp_str := "%d/%d" % [hp, max_hp] if max_hp >= 0 else "%d" % hp
			
			var statuses_str := _format_sim_statuses(u)
			
			print("\t[%d] cid=%d name=%s hp=%s group=%s pos=%d alive=%s%s" % [
				i, cid, uname, hp_str, gname, i, str(alive), statuses_str
			])

	# Optional: show any units not present in either group order (diagnostic)
	var seen := {}
	for group_index in [FRIENDLY, ENEMY]:
		for cid in main.state.groups[group_index].order:
			seen[int(cid)] = true

	var extras: Array[int] = []
	for k in main.state.units.keys():
		var cid := int(k)
		if !seen.has(cid):
			extras.append(cid)

	if !extras.is_empty():
		extras.sort()
		print("SimHost units not in any group order: ", extras)

func _format_sim_statuses(u: CombatantState) -> String:
	if u == null:
		return ""
	
	# CombatantState.statuses is StatusState
	if u.statuses == null:
		return ""
	
	var by_id : Dictionary = u.statuses.by_id if ("by_id" in u.statuses) else null
	if by_id == null or by_id.size() == 0:
		return ""
	
	var parts: Array[String] = []
	for k in by_id.keys():
		var sid := String(k)
		var stack = by_id[k]
		if stack == null:
			continue
		
		var intensity := 0
		var dur := 0
		
		if "intensity" in stack:
			intensity = int(stack.intensity)
		elif "intensity" in stack:
			intensity = int(stack.intensity) # just in case older shape
		
		if "duration" in stack:
			dur = int(stack.duration)
		
		# Display:
		# - if duration > 0, show dur
		# - always show intensity if != 1 (or if you want always, remove the condition)
		var show_bits: Array[String] = []
		if dur > 0:
			show_bits.append("dur=%d" % dur)
		if intensity != 1 and intensity != 0:
			show_bits.append("stk=%d" % intensity)
		
		if show_bits.is_empty():
			parts.append("%s" % sid)
		else:
			parts.append("%s(%s)" % [sid, ", ".join(show_bits)])
		
	return " [" + ", ".join(parts) + "]"

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


func debug_dump_events() -> void:
	if main == null or main.state == null:
		return
	BattleEventLog.print_event_log(main.state.events)
