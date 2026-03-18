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


func has_dirty_planning() -> bool:
	return dirty_replan_all \
		or !dirty_replan_ids.is_empty() \
		or dirty_intent_refresh_all \
		or !dirty_intent_refresh_ids.is_empty()


func has_dirty_turn_order() -> bool:
	return dirty_turn_order


func clear() -> void:
	clear_planning()
	dirty_turn_order = false


func clear_planning() -> void:
	dirty_replan_ids.clear()
	dirty_replan_all = false
	dirty_intent_refresh_ids.clear()
	dirty_intent_refresh_all = false


func flush_planning(kind: int, sim: Sim, allow_hooks := true) -> void:
	if sim == null or sim.api == null:
		clear_planning()
		return

	var api := sim.api

	# 1) Replan first so any subsequent intent refresh reflects the new truth.
	if dirty_replan_all:
		_replan_all(api, allow_hooks)
	else:
		for cid in dirty_replan_ids.keys():
			_replan_if_valid(api, int(cid), allow_hooks)

	# 2) Refresh presented intent second.
	if dirty_intent_refresh_all:
		_refresh_all_intents(api)
	else:
		for cid in dirty_intent_refresh_ids.keys():
			_refresh_intent_if_valid(api, int(cid))

	clear_planning()


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

	var u: CombatantState = api.state.get_unit(cid)
	if u == null or !u.is_alive():
		return

	ActionPlanner.ensure_ai_state_initialized(u)

	if !bool(u.ai_state.get(ActionPlanner.FIRST_INTENTS_READY, false)):
		return
	if bool(u.ai_state.get(ActionPlanner.IS_ACTING, false)):
		return

	ActionIntentPresenter.emit_current_intent(api, cid)
