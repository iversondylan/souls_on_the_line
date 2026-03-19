# checkpoint_processor.gd

class_name CheckpointProcessor extends RefCounted

enum Kind {
	AFTER_ACTOR_TURN,
	AFTER_CARD,
	AFTER_ARCANA,
	AFTER_GROUP_TURN_BEGIN,
	AFTER_GROUP_TURN_END,
	URGENT_STATUS_LEGALITY,
}

var dirty_replan_ids: Dictionary = {}
var dirty_replan_all: bool = false

var dirty_intent_refresh_ids: Dictionary = {}
var dirty_intent_refresh_all: bool = false

var dirty_turn_order: bool = false
var dirty_outcome: bool = false

var victory_emitted: bool = false
var defeat_emitted: bool = false

var _is_flushing: bool = false
var _needs_another_flush: bool = false


func request_replan(cid: int) -> void:
	if cid > 0:
		dirty_replan_ids[int(cid)] = true


func request_replan_all() -> void:
	dirty_replan_all = true


func request_intent_refresh(cid: int) -> void:
	if cid > 0:
		dirty_intent_refresh_ids[int(cid)] = true


func request_intent_refresh_all() -> void:
	dirty_intent_refresh_all = true


func request_turn_order_rebuild() -> void:
	dirty_turn_order = true


func request_outcome_check() -> void:
	dirty_outcome = true

func request_followup_flush() -> void:
	_needs_another_flush = true

func has_dirty_planning() -> bool:
	return dirty_replan_all \
		or !dirty_replan_ids.is_empty() \
		or dirty_intent_refresh_all \
		or !dirty_intent_refresh_ids.is_empty()


func has_dirty_turn_order() -> bool:
	return dirty_turn_order


func has_dirty_outcome() -> bool:
	return dirty_outcome

func has_terminal_outcome() -> bool:
	return victory_emitted or defeat_emitted

func clear() -> void:
	clear_planning()
	dirty_turn_order = false
	dirty_outcome = false


func clear_planning() -> void:
	dirty_replan_ids.clear()
	dirty_replan_all = false
	dirty_intent_refresh_ids.clear()
	dirty_intent_refresh_all = false


func flush_planning(kind: int, sim: Sim, allow_hooks := true) -> void:
	if _is_flushing:
		_needs_another_flush = true
		return

	_is_flushing = true

	while true:
		_needs_another_flush = false

		if sim == null or sim.api == null:
			clear_planning()
			dirty_outcome = false
			break

		var api := sim.api

		if dirty_replan_all:
			_replan_all(api, allow_hooks)
		else:
			for cid in dirty_replan_ids.keys():
				_replan_if_valid(api, int(cid), allow_hooks)

		if dirty_intent_refresh_all:
			_refresh_all_intents(api)
		else:
			for cid in dirty_intent_refresh_ids.keys():
				_refresh_intent_if_valid(api, int(cid))

		if dirty_outcome:
			_flush_outcome(api)

		clear_planning()
		dirty_outcome = false

		if !_needs_another_flush:
			break

	_is_flushing = false


func consume_dirty_turn_order() -> bool:
	var was_dirty := dirty_turn_order
	dirty_turn_order = false
	return was_dirty


func _replan_all(api: SimBattleAPI, allow_hooks: bool) -> void:
	if api == null or api.state == null:
		return

	for k in api.state.units.keys():
		_replan_if_valid(api, int(k), allow_hooks)


func _replan_if_valid(api: SimBattleAPI, cid: int, allow_hooks: bool) -> void:
	if api == null or api.state == null or cid <= 0:
		return
	if api.state.has_terminal_outcome():
		return

	var u: CombatantState = api.state.get_unit(cid)
	if u == null or !u.is_alive():
		return
	if u.combatant_data == null or u.combatant_data.ai == null:
		return

	api.plan_intent(cid, allow_hooks, true)


func _refresh_all_intents(api: SimBattleAPI) -> void:
	if api == null or api.state == null:
		return

	for k in api.state.units.keys():
		_refresh_intent_if_valid(api, int(k))


func _refresh_intent_if_valid(api: SimBattleAPI, cid: int) -> void:
	if api == null or api.state == null:
		return
	if api.state.has_terminal_outcome():
		return

	var u: CombatantState = api.state.get_unit(cid)
	if u == null or !u.is_alive():
		return

	ActionPlanner.ensure_ai_state_initialized(u)

	if !bool(u.ai_state.get(ActionPlanner.FIRST_INTENTS_READY, false)):
		return
	if bool(u.ai_state.get(ActionPlanner.IS_ACTING, false)):
		return

	ActionIntentPresenter.emit_current_intent(api, cid)


func _flush_outcome(api: SimBattleAPI) -> void:
	if api == null or api.state == null or api.writer == null:
		return
	
	if api.state.has_terminal_outcome():
		return
	
	var player_alive := false
	var player_id := api.get_player_id()
	if player_id > 0:
		player_alive = api.is_alive(player_id)

	var enemies_alive := api.get_n_combatants_in_group(SimBattleAPI.ENEMY, false) > 0

	if !player_alive and !defeat_emitted:
		api.state.set_defeat()
		api.writer.emit_defeat(player_id, "player_missing_or_dead")
		defeat_emitted = true
		return

	if player_alive and !enemies_alive and !victory_emitted:
		api.state.set_victory()
		api.writer.emit_victory(player_id, "enemy_group_empty")
		victory_emitted = true
