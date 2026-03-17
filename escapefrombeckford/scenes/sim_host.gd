# sim_host.gd

class_name SimHost extends Node

# SimHost currently serves two roles:
# 1) structural host for main/preview sims
# 2) temporary runtime orchestrator for the MAIN sim
#
# Long-term direction:
# - keep SimHost as structural/preview owner
# - move per-sim runtime orchestration (turn flow, actor begin/end, arcana boundaries)
#   into a dedicated per-sim runtime object owned by Sim

signal main_state_initialized()
signal preview_state_cloned()
signal combatant_added(combat_id: int, group_index: int, insert_index: int, is_preview: bool)
signal player_input_reached()

const FRIENDLY := 0
const ENEMY := 1

# Temporary runtime orchestration state for MAIN sim only.
# Long-term candidate to move into a per-sim runtime/orchestrator object.
var turn_engine: TurnEngineCore
var turn_engine_host_sim: TurnEngineHostSim
var arcana_resolver: ArcanaResolver
var card_executor: CardExecutor

var status_catalog: StatusCatalog : set = _set_status_catalog
var arcana_catalog: ArcanaCatalog : set = _set_arcana_catalog

# Firm structural elements for sim architecture
var main: Sim : set = _set_main
var preview: Sim


# -------------------------
# Small helpers
# -------------------------

func has_main() -> bool:
	return main != null and main.state != null and main.api != null

func get_main_writer() -> BattleEventWriter:
	if main == null or main.api == null:
		return null
	return main.api.writer


# -------------------------
# Structural wiring
# -------------------------

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

	if main.runtime != null:
		main.runtime.bind(main, self)

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


# -------------------------
# Lifecycle
# -------------------------

func reset() -> void:
	main = null
	preview = null
	turn_engine = null
	arcana_resolver = null
	card_executor = null

func init_from_seeds(battle_seed: int, run_seed: int) -> void:
	main = Sim.new()
	main.status_catalog = status_catalog
	main.arcana_catalog = arcana_catalog
	main.is_preview = false
	main.init_from_seeds(int(battle_seed), int(run_seed))

	if main.runtime != null:
		main.runtime.bind(main, self)

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
	main.api.on_unit_removed = func(cid: int, group_index: int, reason: String) -> void:
		if turn_engine != null:
			turn_engine.notify_actor_removed(int(cid))
	main_state_initialized.emit()

func ensure_initialized() -> void:
	if turn_engine_host_sim == null:
		turn_engine_host_sim = TurnEngineHostSim.new(self)

	if !has_main():
		init_from_seeds(0, 0)

	if arcana_resolver == null and arcana_catalog != null:
		arcana_resolver = ArcanaResolver.new(self, arcana_catalog)


# -------------------------
# Setup / seeding
# -------------------------

func start_setup() -> void:
	var writer := get_main_writer()
	if writer == null:
		return
	writer.scope_begin(Scope.Kind.SETUP, "setup", 0)

func end_setup() -> void:
	var writer := get_main_writer()
	if !has_main() or writer == null:
		return

	writer.emit_formation_set(
		main.state.groups[0].order.duplicate(),
		main.state.groups[1].order.duplicate(),
		main.state.groups[0].player_id
	)
	writer.scope_end() # setup

	if main.intent_planner != null:
		main.intent_planner.ensure_valid_plans(main.api, true)

func seed_arcana_from_ids(ids: Array[StringName]) -> void:
	if !has_main():
		return

	main.state.arcana.clear()

	for id in ids:
		var proto := arcana_catalog.get_proto(id)
		if proto == null:
			continue

		main.state.arcana.add_arcanum(id, int(proto.type))


# -------------------------
# Public accessors
# -------------------------

func get_event_log() -> BattleEventLog:
	if !has_main():
		return null
	return main.state.events

func get_main_api() -> SimBattleAPI:
	return main.api if main != null else null

func get_preview_api() -> SimBattleAPI:
	return preview.api if preview != null else null

func get_main_state() -> BattleState:
	return main.state if main != null else null

func get_preview_state() -> BattleState:
	return preview.state if preview != null else null

func is_player(combat_id: int) -> bool:
	return turn_engine_host_sim != null and turn_engine_host_sim.is_player(combat_id)


# -------------------------
# Turn flow orchestration (temporary here)
# -------------------------

func start_group_turn(group_index: int, start_at_player := false, friendly_post_enemy := false) -> void:
	ensure_initialized()

	if turn_engine == null:
		turn_engine = TurnEngineCore.new(turn_engine_host_sim)
		turn_engine.group_turn_ended.connect(_on_sim_group_turn_ended)
		turn_engine.arcana_proc_requested.connect(_on_sim_arcana_proc_requested)
		turn_engine.actor_requested.connect(_on_sim_actor_requested)
		turn_engine.player_begin_requested.connect(_on_sim_player_begin_requested)
		turn_engine.player_end_requested.connect(_on_sim_player_end_requested)
		turn_engine.pending_view_changed.connect(_on_pending_view_changed)

	# NOTE: starting at player should only occur on the first turn of the battle
	# but I don't know if this is the right solution
	if start_at_player:
		turn_engine.reset_for_new_battle()

	var writer := get_main_writer()
	if writer != null:
		writer.set_turn_context(turn_engine._turn_token, group_index, 0)
		writer.scope_begin(Scope.Kind.GROUP_TURN, "group=%d" % group_index, 0)
		writer.emit_group_turn_begin(group_index)

	if has_main():
		main.api.on_group_turn_begin(group_index)

	turn_engine.start_group_turn(group_index, start_at_player, friendly_post_enemy)

func _on_sim_group_turn_ended(gi: int) -> void:
	if has_main():
		main.api.on_group_turn_end(gi)

	var writer := get_main_writer()
	if writer != null:
		writer.emit_group_turn_end(gi)
		writer.scope_end() # group_turn

	# --- NEW ROUND SCHEDULING ---
	if gi == 0:
		# Friendly ended. Decide whether we just finished pre or post.
		var finished_post := (turn_engine != null and turn_engine.ended_friendly_post_enemy)

		if !finished_post:
			# finished friendly PRE -> go to enemies
			start_group_turn(1, false)
		else:
			# finished friendly POST -> start next round friendly PRE
			start_group_turn(0, false, false)
		return

	# gi == 1 (enemy ended) -> go to friendly POST
	start_group_turn(0, false, true)

func _on_pending_view_changed(active_id: int, pending_ids: PackedInt32Array) -> void:
	var writer := get_main_writer()
	if writer == null or turn_engine == null:
		return

	# Make sure the writer's context is up-to-date for group/turn.
	# (It should be, but this is cheap & safe.)
	writer.set_turn_context(turn_engine._turn_token, turn_engine.active_group_index, int(active_id))
	writer.emit_turn_status(int(active_id), pending_ids, int(turn_engine.active_group_index))

func _on_sim_player_begin_requested(token: int) -> void:
	var player_id := turn_engine_host_sim.get_player_id()

	if has_main() and player_id > 0:
		SimStatusLifecycleRunner.on_actor_turn_begin(main.api, player_id)

	if turn_engine_host_sim != null and sim_host_has_begin_player_turn():
		_call_sim_begin_player_turn()

	turn_engine.notify_player_begin_done(token)

func request_player_end() -> void:
	var writer := get_main_writer()
	if writer == null or !has_main():
		return
	writer.emit_end_turn_pressed(main.api.get_player_id())

func hand_discarded() -> void:
	if turn_engine != null:
		turn_engine.request_player_end()

func _on_sim_player_end_requested(token: int) -> void:
	# 1) end-of-player bookkeeping (discard, etc.)
	if turn_engine_host_sim != null and sim_host_has_end_player_turn():
		_call_sim_end_player_turn()

	# 2) END_OF_TURN arcana occurs at player-end resolution
	var player_id := turn_engine_host_sim.get_player_id()
	turn_engine.request_end_of_turn_arcana(func():
		# IMPORTANT ordering:
		# - First satisfy the player_end token handshake
		turn_engine.notify_player_end_done(token)

		# - Then end the actor turn (this advances the queue / group)
		#   Also closes the actor scope in the event writer.
		if has_main():
			SimStatusLifecycleRunner.on_actor_turn_end(main.api, player_id)
			if main.checkpoint_processor != null:
				main.checkpoint_processor.flush(CheckpointProcessor.Kind.AFTER_ACTOR_TURN, main, true)
		sim_notify_actor_done(player_id)
	)

func sim_notify_actor_done(cid: int) -> void:
	var writer := get_main_writer()
	if writer != null:
		writer.emit_actor_end(cid)
		writer.scope_end() # actor_turn

	if turn_engine != null:
		turn_engine.notify_actor_done(cid)


# -------------------------
# Player turn bridge hooks
# -------------------------

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
# Actor / arcana runtime callbacks
# -------------------------

func _on_sim_actor_requested(cid: int) -> void:
	if main == null or main.runtime == null:
		return
	main.runtime.handle_actor_requested(cid)

func _on_sim_arcana_proc_requested(proc: int, token: int) -> void:
	var writer := get_main_writer()
	if writer != null:
		writer.scope_begin(Scope.Kind.ARCANA, "proc=%d" % int(proc), 0)
		writer.emit_arcana_proc(proc)

	if arcana_resolver == null:
		if arcana_catalog == null:
			push_warning("SimHost: no arcana_catalog; cannot run arcana")
		else:
			arcana_resolver = ArcanaResolver.new(self, arcana_catalog)

	if main != null and main.resolver != null and arcana_resolver != null:
		main.resolver.resolve_arcana_proc(main, proc, arcana_resolver)

	if writer != null:
		writer.scope_end() # arcana

	if turn_engine != null:
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


# -------------------------
# External battle commands
# -------------------------

func add_combatant_from_data(data: CombatantData, group_index: int, insert_index: int = -1, is_player := false) -> int:
	ensure_initialized()
	if !has_main():
		return 0
	return main.api.spawn_from_data(data, group_index, insert_index, is_player)

func apply_player_card(req: CardPlayRequest) -> bool:
	ensure_initialized()
	if !has_main():
		return false

	if card_executor == null:
		card_executor = CardExecutor.new()

	if main.resolver == null:
		return false

	return main.resolver.resolve_player_card(main, req, card_executor)


# -------------------------
# Preview management
# -------------------------

func clone_preview_from_main() -> void:
	ensure_initialized()
	if !has_main():
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


# -------------------------
# Debug
# -------------------------

func debug_dump_orders() -> void:
	if !has_main():
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
	if !has_main():
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

	if u.statuses == null:
		return ""

	var by_id: Dictionary = u.statuses.by_id if ("by_id" in u.statuses) else null
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
			intensity = int(stack.intensity)

		if "duration" in stack:
			dur = int(stack.duration)

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
	if u != null and ("name" in u):
		var n := String(u.name)
		if n != "":
			return n

	if u != null and ("data_proto_path" in u):
		var p := String(u.data_proto_path)
		if p != "":
			var base := p.get_file()
			if base != "":
				return base.get_basename()

	return "<unnamed>"

func debug_dump_events() -> void:
	if !has_main():
		return
	BattleEventLog.print_event_log(main.state.events)
