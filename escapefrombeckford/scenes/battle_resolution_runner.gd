# battle_resolution_runner.gd

class_name BattleResolutionRunner extends Node

enum LifeState { ALIVE, DYING, REMOVED }

# combat_id -> LifeState

var _pending_deaths := {} # int combat_id -> true
var _removed := {} # int combat_id -> true


#var _life: Dictionary = {}

var api: LiveBattleAPI

var _queue: Array[Dictionary] = []
var _busy: bool = false

func is_removed(combat_id: int) -> bool:
	return _removed.has(combat_id)

func mark_removed(combat_id: int) -> void:
	_removed[combat_id] = true
	_pending_deaths.erase(combat_id)

func enqueue_death(combat_id: int, reason: String = "") -> void:
	if combat_id <= 0:
		return
	if _removed.has(combat_id):
		return
	if _pending_deaths.has(combat_id):
		return
	_pending_deaths[combat_id] = true
	_queue.push_back({"op":"death","combat_id":combat_id,"reason":reason})
	_kick()

func enqueue_apply_status(ctx: StatusContext) -> void:
	_queue.push_back({
		"op": "apply_status",
		"ctx": ctx,
	})
	_kick()

func enqueue_remove_status(ctx: RemoveStatusContext) -> void:
	_queue.push_back({
		"op": "remove_status",
		"ctx": ctx,
	})
	_kick()

#func get_life_state(combat_id: int) -> int:
	#return int(_life.get(combat_id, LifeState.ALIVE))

#func is_dying(combat_id: int) -> bool:
	#return get_life_state(combat_id) == LifeState.DYING

#func is_removed(combat_id: int) -> bool:
	#return get_life_state(combat_id) == LifeState.REMOVED

#func mark_dying(combat_id: int) -> void:
	#if combat_id <= 0:
		#return
	#if is_removed(combat_id):
		#return
	#_life[combat_id] = LifeState.DYING

#func mark_removed(combat_id: int) -> void:
	#if combat_id <= 0:
		#return
	#_life[combat_id] = LifeState.REMOVED

func enqueue_damage(ctx: DamageContext) -> void:
	_queue.push_back({
		"op": "damage",
		"ctx": ctx,
	})
	_kick()

func enqueue_summon(ctx: SummonContext) -> void:
	_queue.push_back({"op":"summon","ctx": ctx})
	_kick()
#func enqueue_death(combat_id: int, reason: String = "") -> void:
	#if combat_id <= 0:
		#return
	## Don’t enqueue death repeatedly
	#if is_dying(combat_id) or is_removed(combat_id):
		#return
	#mark_dying(combat_id)
	#_queue.push_back({
		#"op": "death",
		#"combat_id": combat_id,
		#"reason": reason,
	#})
	#_kick()


func _kick() -> void:
	if _busy:
		return
	_busy = true
	_process_queue()

func _process_queue() -> void:
	# coroutine
	await _run()

func _run() -> void:
	while !_queue.is_empty():
		var item = _queue.pop_front()# := _queue.pop_front()
		var op := str(item.get("op", ""))
		match op:
			"damage":
				var ctx: DamageContext = item.get("ctx", null)
				if api and ctx:
					await api._run_damage_op(ctx)
			"death":
				var cid := int(item.get("combat_id", -1))
				var reason := str(item.get("reason", ""))
				if api and cid != -1:
					await api._run_death_op(cid, reason)
			"apply_status":
				var ctx: StatusContext = item.get("ctx", null)
				if api and ctx:
					await api._run_apply_status_op(ctx)
			"remove_status":
				var ctx: RemoveStatusContext = item.get("ctx", null)
				if api and ctx:
					await api._run_remove_status_op(ctx)
			"summon":
				var ctx: SummonContext = item.get("ctx", null)
				if api and ctx:
					await api._run_summon_op(ctx)
			_:
				push_warning("BattleResolutionRunner: unknown op: %s" % op)

	_busy = false
