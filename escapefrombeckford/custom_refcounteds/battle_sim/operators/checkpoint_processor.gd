# checkpoint_processor.gd

class_name CheckpointProcessor extends RefCounted

enum Kind {
	AFTER_ACTOR_TURN,
	AFTER_CARD,
	AFTER_ARCANA,
	AFTER_GROUP_TURN_BEGIN,
	AFTER_GROUP_TURN_END,
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
	dirty_replan_ids.clear()
	dirty_replan_all = false
	dirty_intent_refresh_ids.clear()
	dirty_intent_refresh_all = false
	dirty_turn_order = false


func clear_planning() -> void:
	dirty_replan_ids.clear()
	dirty_replan_all = false
	dirty_intent_refresh_ids.clear()
	dirty_intent_refresh_all = false


func flush_planning(kind: int, sim: Sim, allow_hooks := true) -> void:
	#print("checkpoint_processor.gd flush_planning() kind=%s replans=%s refresh=%s" % [
		#Kind.keys()[kind] if kind >= 0 and kind < Kind.size() else str(kind),
		#str(dirty_replan_ids.keys()),
		#str(dirty_intent_refresh_ids.keys()),
	#])

	if sim == null or sim.api == null or sim.intent_planner == null:
		clear_planning()
		return

	if dirty_replan_all:
		sim.intent_planner.mark_all_dirty()
	else:
		for cid in dirty_replan_ids.keys():
			sim.intent_planner.mark_dirty(int(cid))

	sim.intent_planner.flush(sim.api, allow_hooks)
	_flush_intent_refreshes(sim.api)

	clear_planning()


func consume_dirty_turn_order() -> bool:
	var was_dirty := dirty_turn_order
	dirty_turn_order = false
	return was_dirty


func _flush_intent_refreshes(api: SimBattleAPI) -> void:
	if api == null or api.state == null:
		return

	if dirty_intent_refresh_all:
		for k in api.state.units.keys():
			_emit_current_if_valid(api, int(k))
		return

	for cid in dirty_intent_refresh_ids.keys():
		_emit_current_if_valid(api, int(cid))


func _emit_current_if_valid(api: SimBattleAPI, cid: int) -> void:
	if api == null or api.state == null:
		return

	var u: CombatantState = api.state.get_unit(cid)
	if u == null or !u.is_alive():
		return

	ActionPlanner._ensure_ai_state_initialized(u)

	if !bool(u.ai_state.get(ActionPlanner.FIRST_INTENTS_READY, false)):
		return
	if bool(u.ai_state.get(ActionPlanner.IS_ACTING, false)):
		return

	ActionPlanner.emit_current_intent_sim(api, cid)
