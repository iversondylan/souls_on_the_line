class_name BattlePreviewCoordinator
extends Node

enum State { DISABLED, HOT, DIRTY }

const FRIENDLY := 0
const PREVIEW_DISPLAY_DELAY_SEC := 1.5

var sim_host: SimHost : set = _set_sim_host
var battle_view: BattleView
var turn_phase_title: TurnPhaseTitle

var _state: int = State.DISABLED
var _player_input_ready: bool = false
var _view_is_player_turn: bool = false
var _preview_display_request_id: int = 0
var _card_scope_depth: int = 0


func _ready() -> void:
	#print("battle_preview_coordinator.gd _ready()")
	Events.turn_status_view_changed.connect(_on_turn_status_view_changed)
	Events.player_input_view_reached.connect(_on_player_input_view_reached)
	Events.card_scope_view_started.connect(_on_card_scope_view_started)
	Events.card_scope_view_finished.connect(_on_card_scope_view_finished)
	Events.card_played.connect(_on_card_played)
	Events.summon_reserve_card_released.connect(_on_summon_reserve_card_released)
	Events.dead_combatant_data.connect(_on_dead_combatant_data)
	Events.player_end_cleanup_completed.connect(_on_player_end_cleanup_completed)
	Events.end_turn_button_pressed.connect(_on_end_turn_button_pressed)

func _set_sim_host(new_sim_host: SimHost) -> void:
	#print("battle_preview_coordinator.gd _set_sim_host()")
	sim_host = new_sim_host


func enable_for_player_turn() -> void:
	#print("battle_preview_coordinator.gd enable_for_player_turn()")
	if turn_phase_title != null:
		if !turn_phase_title.preview_button_pressed.is_connected(_on_preview_button_pressed):
			turn_phase_title.preview_button_pressed.connect(_on_preview_button_pressed)
		turn_phase_title.enable_button(true)


func mark_dirty(reason: String = "") -> void:
	#print("battle_preview_coordinator.gd mark_dirty()")
	if _state != State.DIRTY:
		_state = State.DIRTY
	#if !reason.is_empty():
		#print("battle_preview_coordinator.gd mark_dirty(): ", reason)


func disable_and_clear() -> void:
	#print("battle_preview_coordinator.gd disable_and_clear()")
	_state = State.DISABLED
	_preview_display_request_id += 1
	if turn_phase_title != null:
		turn_phase_title.enable_button(false)

	_clear_all_previews()


func display_preview_now(reason: String = "") -> void:
	#print("battle_preview_coordinator.gd display_preview_now()")
	if !_can_preview():
		return

	enable_for_player_turn()
	#if !reason.is_empty():
		#print("battle_preview_coordinator.gd display_preview_now(): ", reason)
	_preview_display_request_id += 1
	recompute_preview_if_needed()


func recompute_preview_if_needed() -> void:
	#print("battle_preview_coordinator.gd recompute_preview_if_needed()")
	if _state == State.DISABLED:
		return
	if _state == State.HOT:
		return
	if _card_scope_depth > 0:
		return
	if sim_host == null or battle_view == null:
		return

	var main_state := sim_host.get_main_state()
	if main_state == null:
		disable_and_clear()
		return

	sim_host.clone_preview_from_main()
	var main_runtime := sim_host.get_main_runtime()
	var preview_runtime := sim_host.get_preview_runtime()
	if preview_runtime != null:
		# Preview from "player presses end turn" forward:
		# 1) finish POST-player friendly phase (player, then friendlies behind player)
		# 2) enemy phase
		# 3) stop when the next player input point is reached
		var resumed_from_live_turn := false
		if main_runtime != null and main_runtime.has_runtime_initialized():
			resumed_from_live_turn = preview_runtime.clone_turn_flow_from(main_runtime)
		if !resumed_from_live_turn:
			preview_runtime.begin_group_turn_flow(FRIENDLY, false, false)
		preview_runtime.confirm_player_end_ready()

	var preview_state := sim_host.get_preview_state()
	if preview_state == null:
		disable_and_clear()
		return

	_apply_preview_delta(main_state, preview_state)
	_state = State.HOT


func _apply_preview_delta(main_state: BattleState, preview_state: BattleState) -> void:
	#print("battle_preview_coordinator.gd _apply_preview_delta()")
	if battle_view == null:
		return

	for view in battle_view.get_all_combatant_views():
		if view == null or !is_instance_valid(view):
			continue

		view.clear_combat_preview()

		var cid := int(view.cid)
		var before := main_state.get_unit(cid)
		var after := preview_state.get_unit(cid)
		if before == null:
			continue

		var before_hp := int(before.health)
		var after_hp := int(after.health) if after != null else 0
		var before_alive := main_state.is_alive(cid)
		var after_alive := preview_state.is_alive(cid) if after != null else false

		if before_alive and !after_alive:
			view.show_combat_preview_death()
		elif before_hp != after_hp:
			view.show_combat_preview_health(after_hp, before_hp)


func _clear_all_previews() -> void:
	#print("battle_preview_coordinator.gd _clear_all_previews()")
	if battle_view == null:
		return

	for view in battle_view.get_all_combatant_views():
		if view != null and is_instance_valid(view):
			view.clear_combat_preview()


func _on_preview_button_pressed() -> void:
	#print("battle_preview_coordinator.gd _on_preview_button_pressed()")
	display_preview_now("preview_button_pressed")


func _restart_preview_display_timer(delay_sec: float = PREVIEW_DISPLAY_DELAY_SEC) -> void:
	#print("battle_preview_coordinator.gd _restart_preview_display_timer()")
	_preview_display_request_id += 1
	var request_id := _preview_display_request_id
	_wait_for_preview_display_delay(request_id, delay_sec)


func _get_battle_clock() -> BattleClock:
	if battle_view == null:
		return null
	return battle_view.clock


func _wait_for_preview_display_delay(request_id: int, delay_sec: float) -> void:
	var clock := _get_battle_clock()
	if clock == null:
		push_warning("BattlePreviewCoordinator: missing battle clock; skipping preview display delay")
		_on_preview_display_delay_elapsed(request_id)
		return
	await clock.wait_seconds(delay_sec)
	_on_preview_display_delay_elapsed(request_id)


func _on_preview_display_delay_elapsed(request_id: int) -> void:
	#print("battle_preview_coordinator.gd _on_preview_display_delay_elapsed()")
	if request_id != _preview_display_request_id:
		return
	if !_can_preview():
		return

	display_preview_now("preview_display_delay_elapsed")


func _on_turn_status_view_changed(group_index: int, active_id: int, _pending_ids: PackedInt32Array, player_id: int) -> void:
	#print("battle_preview_coordinator.gd _on_turn_status_view_changed()")
	_view_is_player_turn = active_id > 0 and active_id == player_id and int(group_index) == FRIENDLY
	if _view_is_player_turn:
		if _player_input_ready:
			if _card_scope_depth == 0:
				enable_for_player_turn()
				mark_dirty("turn_status_view_changed")
				_restart_preview_display_timer()
		return

	_player_input_ready = false
	_card_scope_depth = 0
	disable_and_clear()

func _on_player_input_view_reached(player_id: int) -> void:
	#print("battle_preview_coordinator.gd _on_player_input_view_reached()")
	if player_id <= 0:
		return
	_player_input_ready = true
	if !_view_is_player_turn:
		#print("battle_preview_coordinator.gd _on_player_input_view_reached() it is not player turn")
		return

	if _card_scope_depth > 0:
		return

	enable_for_player_turn()
	mark_dirty("player_input_view_reached")
	_restart_preview_display_timer()


func _on_card_scope_view_started(_scope_id: int, _actor_id: int) -> void:
	#print("battle_preview_coordinator.gd _on_card_scope_view_started()")
	if _player_input_ready and _view_is_player_turn:
		mark_dirty("card_scope_view_started")

	_card_scope_depth += 1
	disable_and_clear()


func _on_card_scope_view_finished(_scope_id: int, _actor_id: int) -> void:
	#print("battle_preview_coordinator.gd _on_card_scope_view_finished()")
	_card_scope_depth = maxi(0, _card_scope_depth - 1)
	if _card_scope_depth > 0:
		return
	if !_player_input_ready or !_view_is_player_turn:
		return

	enable_for_player_turn()
	mark_dirty("card_scope_view_finished")
	_restart_preview_display_timer()


func _on_card_played(_usable_card: UsableCard) -> void:
	#print("battle_preview_coordinator.gd _on_card_played()")
	return


func _on_summon_reserve_card_released(_summoned_id: int, _card_uid: String) -> void:
	#print("battle_preview_coordinator.gd _on_summon_reserve_card_released()")
	_refresh_preview("summon_reserve_card_released")


func _on_dead_combatant_data(_combatant_data: CombatantData) -> void:
	#print("battle_preview_coordinator.gd _on_dead_combatant_data()")
	_refresh_preview("dead_combatant_data")


func _on_player_end_cleanup_completed(_ctx: HandCleanupContext) -> void:
	_refresh_preview("player_end_cleanup_completed")


func _on_end_turn_button_pressed() -> void:
	#print("battle_preview_coordinator.gd _on_end_turn_button_pressed()")
	_player_input_ready = false
	_view_is_player_turn = false
	_card_scope_depth = 0
	disable_and_clear()


func _refresh_preview(reason: String) -> void:
	#print("battle_preview_coordinator.gd _refresh_preview()")
	if !_can_preview():
		return
	mark_dirty(reason)


func _can_preview() -> bool:
	return _player_input_ready and _view_is_player_turn and _card_scope_depth == 0
