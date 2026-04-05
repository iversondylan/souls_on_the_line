# checkpoint_processor.gd

class_name CheckpointProcessor extends RefCounted

enum Kind {
	AFTER_ACTOR_TURN,
	AFTER_CARD,
	AFTER_ARCANA,
	AFTER_GROUP_TURN_BEGIN,
	AFTER_GROUP_TURN_END,
	AFTER_PROJECTION_CLEANUP,
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
		if _is_flushing:
			_needs_another_flush = true


func request_replan_all() -> void:
	dirty_replan_all = true
	if _is_flushing:
		_needs_another_flush = true


func request_intent_refresh(cid: int) -> void:
	if cid > 0:
		dirty_intent_refresh_ids[int(cid)] = true
		if _is_flushing:
			_needs_another_flush = true


func request_intent_refresh_all() -> void:
	dirty_intent_refresh_all = true
	if _is_flushing:
		_needs_another_flush = true


func request_turn_order_rebuild() -> void:
	dirty_turn_order = true


func request_outcome_check() -> void:
	dirty_outcome = true
	if _is_flushing:
		_needs_another_flush = true

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
		var replan_all_now := bool(dirty_replan_all)
		var replan_ids_now := dirty_replan_ids.duplicate()
		var intent_refresh_all_now := bool(dirty_intent_refresh_all)
		var intent_refresh_ids_now := dirty_intent_refresh_ids.duplicate()
		var outcome_now := bool(dirty_outcome)

		clear_planning()
		dirty_outcome = false

		var cids_to_publish := _collect_cids_to_publish(
			api,
			replan_all_now,
			replan_ids_now,
			intent_refresh_all_now,
			intent_refresh_ids_now
		)

		if replan_all_now:
			_replan_all(api, allow_hooks)
		else:
			for cid in replan_ids_now.keys():
				_replan_if_valid(api, int(cid), allow_hooks)

		_publish_actor_intents(api, cids_to_publish)

		if outcome_now:
			_flush_outcome(api)

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

	if !bool(u.ai_state.get(Keys.FIRST_INTENTS_READY, false)):
		return
	if bool(u.ai_state.get(Keys.IS_ACTING, false)):
		return

	ActionIntentPresenter.emit_current_intent(api, cid)

func _collect_cids_to_publish(
	api: SimBattleAPI,
	replan_all_now: bool,
	replan_ids_now: Dictionary,
	intent_refresh_all_now: bool,
	intent_refresh_ids_now: Dictionary
) -> Dictionary:
	var out := {}
	if api == null or api.state == null:
		return out

	if replan_all_now or intent_refresh_all_now:
		for unit in api.state.units.values():
			if unit is CombatantState and unit.is_alive() and unit.combatant_data != null and unit.combatant_data.ai != null:
				out[int(unit.id)] = true
		return out

	for cid in replan_ids_now.keys():
		_add_cid_if_valid(api, int(cid), out)
	for cid in intent_refresh_ids_now.keys():
		_add_cid_if_valid(api, int(cid), out)
	return out

func _add_cid_if_valid(api: SimBattleAPI, cid: int, out: Dictionary) -> void:
	if api == null or api.state == null or cid <= 0:
		return
	var u: CombatantState = api.state.get_unit(cid)
	if u == null or !u.is_alive() or u.combatant_data == null or u.combatant_data.ai == null:
		return
	out[int(cid)] = true

func _publish_actor_intents(api: SimBattleAPI, cids_to_publish: Dictionary) -> void:
	if api == null or api.state == null:
		return
	for cid in cids_to_publish.keys():
		_refresh_intent_if_valid(api, int(cid))


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
