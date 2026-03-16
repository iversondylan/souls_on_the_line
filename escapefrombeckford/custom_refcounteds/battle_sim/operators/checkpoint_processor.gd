# checkpoint_processor

class_name CheckpointProcessor extends RefCounted

enum Kind {
	AFTER_ACTOR_TURN,
	AFTER_CARD,
	AFTER_ARCANA,
	AFTER_GROUP_TURN_BEGIN,
	AFTER_GROUP_TURN_END,
}

var dirty_replan_ids: Dictionary = {}          # int -> true
var dirty_replan_all: bool = false

var dirty_intent_refresh_ids: Dictionary = {}  # int -> true
var dirty_intent_refresh_all: bool = false


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


func clear() -> void:
	dirty_replan_ids.clear()
	dirty_replan_all = false
	dirty_intent_refresh_ids.clear()
	dirty_intent_refresh_all = false


func flush(kind: int, sim: Sim, allow_hooks: bool = true) -> void:
	print("checkpoint_processor.gd flush() kind=%s replans=%s refresh=%s" % [
		Kind.keys()[kind] if kind >= 0 and kind < Kind.size() else str(kind),
		str(dirty_replan_ids.keys()),
		str(dirty_intent_refresh_ids.keys())
	])
	if sim == null or sim.api == null or sim.intent_planner == null:
		clear()
		return

	# 1) Replans first
	if dirty_replan_all:
		sim.intent_planner.mark_all_dirty()
	else:
		for cid in dirty_replan_ids.keys():
			sim.intent_planner.mark_dirty(int(cid))

	sim.intent_planner.flush(sim.api, allow_hooks)

	# 2) Intent refresh second
	_flush_intent_refreshes(sim.api)

	clear()


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
#enum Kind {
	#AFTER_HIT,
	#AFTER_ATTACK,
	#AFTER_CARD,
	#AFTER_SUMMON,
	#AFTER_DEATH,
	#AFTER_ACTOR_TURN,
	#AFTER_GROUP_TURN_BEGIN,
	#AFTER_GROUP_TURN_END,
#}
#
#var dirty_intent_ids: Dictionary = {} # int combat_id -> true
#var dirty_all_intents: bool = false
#
#
#func mark_intent_dirty(cid: int) -> void:
	#if cid > 0:
		#dirty_intent_ids[int(cid)] = true
#
#
#func mark_all_intents_dirty() -> void:
	#dirty_all_intents = true
#
#
#func clear() -> void:
	#dirty_intent_ids.clear()
	#dirty_all_intents = false
#
#
#func flush(kind: int, sim: Sim, allow_hooks: bool = true) -> void:
	#if sim == null or sim.api == null or sim.intent_planner == null:
		#clear()
		#return
#
	#if dirty_all_intents:
		#sim.intent_planner.mark_all_dirty()
	#else:
		#for cid in dirty_intent_ids.keys():
			#sim.intent_planner.mark_dirty(int(cid))
#
	#sim.intent_planner.flush(sim.api, allow_hooks)
	#clear()
