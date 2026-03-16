# checkpoint_processor

class_name CheckpointProcessor extends RefCounted

enum Kind {
	AFTER_HIT,
	AFTER_ATTACK,
	AFTER_CARD,
	AFTER_SUMMON,
	AFTER_DEATH,
	AFTER_ACTOR_TURN,
	AFTER_GROUP_TURN_BEGIN,
	AFTER_GROUP_TURN_END,
}

var dirty_intent_ids: Dictionary = {} # int combat_id -> true
var dirty_all_intents: bool = false


func mark_intent_dirty(cid: int) -> void:
	if cid > 0:
		dirty_intent_ids[int(cid)] = true


func mark_all_intents_dirty() -> void:
	dirty_all_intents = true


func clear() -> void:
	dirty_intent_ids.clear()
	dirty_all_intents = false


func flush(kind: int, sim: Sim, allow_hooks: bool = true) -> void:
	if sim == null or sim.api == null or sim.intent_planner == null:
		clear()
		return

	if dirty_all_intents:
		sim.intent_planner.mark_all_dirty()
	else:
		for cid in dirty_intent_ids.keys():
			sim.intent_planner.mark_dirty(int(cid))

	sim.intent_planner.flush(sim.api, allow_hooks)
	clear()
