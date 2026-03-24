class_name BattlePreviewCoordinator
extends Node

enum State { DISABLED, HOT, DIRTY }

const FRIENDLY := 0

var sim_host: SimHost
var battle_view: BattleView
var turn_phase_title: TurnPhaseTitle

var _state: int = State.DISABLED


func _ready() -> void:
	Events.turn_status_view_changed.connect(_on_turn_status_view_changed)
	Events.card_played.connect(_on_card_played)
	Events.summon_reserve_card_released.connect(_on_summon_reserve_card_released)
	Events.dead_combatant_data.connect(_on_dead_combatant_data)
	Events.hand_discarded.connect(_on_hand_discarded)
	Events.end_turn_button_pressed.connect(_on_end_turn_button_pressed)


func enable_for_player_turn() -> void:
	if turn_phase_title != null:
		if !turn_phase_title.preview_button_pressed.is_connected(_on_preview_button_pressed):
			turn_phase_title.preview_button_pressed.connect(_on_preview_button_pressed)
		turn_phase_title.enable_button(true)

	if _state == State.DISABLED:
		_state = State.DIRTY


func mark_dirty(reason: String = "") -> void:
	if _state == State.DISABLED:
		return

	_state = State.DIRTY
	if !reason.is_empty():
		print("BattlePreviewCoordinator.mark_dirty(): ", reason)


func disable_and_clear() -> void:
	_state = State.DISABLED
	if turn_phase_title != null:
		turn_phase_title.enable_button(false)

	_clear_all_previews()


func recompute_preview_if_needed() -> void:
	if _state == State.DISABLED:
		return
	if _state == State.HOT:
		return
	if sim_host == null or battle_view == null:
		return

	var main_state := sim_host.get_main_state()
	if main_state == null:
		disable_and_clear()
		return

	sim_host.clone_preview_from_main()
	var preview_runtime := sim_host.get_preview_runtime()
	if preview_runtime != null:
		# Preview from "player presses end turn" forward:
		# 1) finish POST-player friendly phase (player, then friendlies behind player)
		# 2) enemy phase
		# 3) stop when the next player input point is reached
		preview_runtime.start_group_turn(FRIENDLY, false, false)
		preview_runtime.notify_player_discard_animation_finished()

	var preview_state := sim_host.get_preview_state()
	if preview_state == null:
		disable_and_clear()
		return

	_apply_preview_delta(main_state, preview_state)
	_state = State.HOT


func _apply_preview_delta(main_state: BattleState, preview_state: BattleState) -> void:
	if battle_view == null:
		return

	for view in battle_view.get_all_combatant_views():
		if view == null or !is_instance_valid(view):
			continue

		view.clear_combat_preview()

		var cid := int(view.cid)
		var before := main_state.get_unit(cid)
		var after := preview_state.get_unit(cid)
		if before == null or after == null:
			continue

		var before_hp := int(before.health)
		var after_hp := int(after.health)

		if before_hp > 0 and after_hp <= 0:
			view.show_combat_preview_death()
		elif before_hp != after_hp:
			view.show_combat_preview_health(after_hp, before_hp)


func _clear_all_previews() -> void:
	if battle_view == null:
		return

	for view in battle_view.get_all_combatant_views():
		if view != null and is_instance_valid(view):
			view.clear_combat_preview()


func _on_preview_button_pressed() -> void:
	recompute_preview_if_needed()


func _on_turn_status_view_changed(group_index: int, active_id: int, _pending_ids: PackedInt32Array, player_id: int) -> void:
	var is_player_turn := active_id > 0 and active_id == player_id and int(group_index) == FRIENDLY
	if is_player_turn:
		enable_for_player_turn()
		recompute_preview_if_needed()
		return

	disable_and_clear()


func _on_card_played(_usable_card: UsableCard) -> void:
	_refresh_preview("card_played")


func _on_summon_reserve_card_released(_summoned_id: int, _card_uid: String) -> void:
	_refresh_preview("summon_reserve_card_released")


func _on_dead_combatant_data(_combatant_data: CombatantData) -> void:
	_refresh_preview("dead_combatant_data")


func _on_hand_discarded() -> void:
	_refresh_preview("hand_discarded")


func _on_end_turn_button_pressed() -> void:
	disable_and_clear()


func _refresh_preview(reason: String) -> void:
	mark_dirty(reason)
	recompute_preview_if_needed()
