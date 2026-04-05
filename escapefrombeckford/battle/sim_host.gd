# sim_host.gd

class_name SimHost extends Node

# SimHost is the structural owner of:
# - the main Sim
# - the preview Sim
# - shared catalogs
# - host-side bridge methods used by runtimes
#
# Runtime execution belongs to SimRuntime.
# SimHost should not own TurnEngineCore or TurnFlowQueryHost.

signal main_state_initialized()
signal preview_state_cloned()
signal combatant_added(combat_id: int, group_index: int, insert_index: int, is_preview: bool)
signal player_input_reached()

const FRIENDLY := 0
const ENEMY := 1

var status_catalog: StatusCatalog : set = _set_status_catalog
var arcana_catalog: ArcanaCatalog : set = _set_arcana_catalog

var main: Sim : set = _set_main
var preview: Sim
var _battle_scope_handle: ScopeHandle = null
var _setup_scope_handle: ScopeHandle = null


# -------------------------
# Small helpers
# -------------------------

func has_main() -> bool:
	return main != null and main.state != null and main.api != null


func get_main_writer() -> BattleEventWriter:
	if main == null or main.api == null:
		return null
	return main.api.writer


func get_main_runtime() -> SimRuntime:
	if main == null:
		return null
	return main.runtime


func _refresh_main_arcanum_projection_entries() -> void:
	if !has_main() or main.state.projection_bank == null:
		return

	var player_id := int(main.api.get_player_id())
	if player_id <= 0:
		return

	main.state.projection_bank.rebuild_arcanum_entries(main.state, player_id)


# -------------------------
# Structural wiring
# -------------------------

func _set_main(new_sim: Sim) -> void:
	main = new_sim
	if main == null:
		return

	main.status_catalog = status_catalog
	main.arcana_catalog = arcana_catalog

	if main.state != null:
		main.state.status_catalog = status_catalog
		main.state.arcana_catalog = arcana_catalog

	if main.runtime != null:
		main.runtime.bind(main, self)


func _set_status_catalog(catalog: StatusCatalog) -> void:
	status_catalog = catalog

	if main != null:
		main.status_catalog = catalog
		if main.state != null:
			main.state.status_catalog = catalog

	if preview != null:
		preview.status_catalog = catalog
		if preview.state != null:
			preview.state.status_catalog = catalog


func _set_arcana_catalog(catalog: ArcanaCatalog) -> void:
	arcana_catalog = catalog

	if main != null:
		main.arcana_catalog = catalog
		if main.state != null:
			main.state.arcana_catalog = catalog

	if preview != null:
		preview.arcana_catalog = catalog
		if preview.state != null:
			preview.state.arcana_catalog = catalog


# -------------------------
# Lifecycle
# -------------------------

func reset() -> void:
	if main != null and main.runtime != null:
		main.runtime.reset_runtime_state()

	_battle_scope_handle = null
	_setup_scope_handle = null
	main = null
	preview = null


func init_from_seeds(battle_seed: int, run_seed: int) -> void:
	reset()

	var s := Sim.new()
	s.status_catalog = status_catalog
	s.arcana_catalog = arcana_catalog
	s.is_preview = false
	s.init_from_seeds(int(battle_seed), int(run_seed))

	main = s

	if main.runtime != null:
		#print("binding runtime")
		main.runtime.bind(main, self)

	_configure_main_api_logging()

	main.api.writer.set_turn_context(0, -1, 0)
	_battle_scope_handle = main.api.writer.scope_begin(Scope.Kind.BATTLE, "battle_seed=%d run_seed=%d" % [battle_seed, run_seed], 0)

	_bind_runtime_callbacks(main)

	main_state_initialized.emit()


func ensure_initialized() -> void:
	if !has_main():
		init_from_seeds(0, 0)


# -------------------------
# Setup / seeding
# -------------------------

func start_setup() -> void:
	var writer := get_main_writer()
	if writer == null:
		return
	_setup_scope_handle = writer.scope_begin(Scope.Kind.SETUP, "setup", 0)


func end_setup() -> void:
	if !has_main():
		return
	var writer := get_main_writer()

	if writer != null:
		writer.emit_formation_set(
			main.state.groups[0].order.duplicate(),
			main.state.groups[1].order.duplicate(),
			main.state.groups[0].player_id
		)
		if _setup_scope_handle != null:
			writer.scope_end(_setup_scope_handle) # setup
			_setup_scope_handle = null

	_refresh_main_arcanum_projection_entries()

	# Initialize NPC plans and intent presentation directly.
	for cid in main.state.units.keys():
		var combat_id := int(cid)
		main.api.plan_intent(combat_id, true, true)
		ActionIntentPresenter.emit_current_intent(main.api, combat_id)


func seed_arcana_from_ids(ids: Array[StringName]) -> void:
	if !has_main():
		return

	main.state.arcana.clear()
	if main.state.projection_bank != null:
		main.state.projection_bank.clear_arcanum_entries()

	for id in ids:
		var proto := arcana_catalog.get_proto(id)
		if proto == null:
			continue

		var entry := main.state.arcana.add_arcanum(id, int(proto.type))
		if entry != null:
			proto.seed_battle_entry(entry)


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



func get_preview_runtime() -> SimRuntime:
	return preview.runtime if preview != null else null

# -------------------------
# Preview management
# -------------------------

func clone_preview_from_main() -> void:
	ensure_initialized()
	if !has_main():
		return

	preview = main.clone_for_preview()
	if preview != null and preview.runtime != null:
		preview.runtime.bind(preview, self)
	_configure_preview_api_logging()
	_bind_runtime_callbacks(preview)

	preview_state_cloned.emit()


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


func with_fresh_preview(fn: Callable) -> void:
	clone_preview_from_main()
	if fn.is_valid():
		fn.call()


func _configure_main_api_logging() -> void:
	if main == null or main.api == null or main.state == null:
		return

	var scopes := BattleScopeManager.new()
	scopes.reset()

	main.api.scopes = scopes
	main.api.writer = BattleEventWriter.new(EventSinkMain.new(main.state.events), scopes)
	main.api.writer.allow_unscoped_events = false


func _configure_preview_api_logging() -> void:
	if preview == null or preview.api == null:
		return

	var scopes := BattleScopeManager.new()
	scopes.reset()

	preview.api.scopes = scopes
	preview.api.writer = BattleEventWriter.new(EventSinkPreview.new(), scopes)
	# Preview logging is discarded, so cloned runtime resumes should not warn
	# when the preview writer does not inherit the live scope stack.
	preview.api.writer.allow_unscoped_events = true


func _bind_runtime_callbacks(sim: Sim) -> void:
	if sim == null or sim.api == null:
		return
	if sim.runtime == null:
		sim.api.on_summoned = Callable()
		sim.api.on_unit_removed = Callable()
		sim.api.on_urgent_planning_requested = Callable()
		return

	sim.api.on_summoned = Callable(sim.runtime, "on_summoned")
	sim.api.on_unit_removed = Callable(sim.runtime, "on_unit_removed")
	sim.api.on_urgent_planning_requested = Callable(sim.runtime, "request_urgent_planning_flush")


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
	for stack in u.statuses.get_all_stacks(true):
		if stack == null:
			continue

		var sid := String(stack.id)
		var intensity := 0
		var dur := 0
		var pending := false

		if "intensity" in stack:
			intensity = int(stack.intensity)

		if "duration" in stack:
			dur = int(stack.duration)
		if "pending" in stack:
			pending = bool(stack.pending)

		var show_bits: Array[String] = []
		if dur > 0:
			show_bits.append("dur=%d" % dur)
		if intensity != 1 and intensity != 0:
			show_bits.append("stk=%d" % intensity)
		if pending:
			show_bits.append("pending")

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
