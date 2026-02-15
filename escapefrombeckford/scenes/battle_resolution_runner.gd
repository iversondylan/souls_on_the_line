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

func enqueue_status_proc(target_id: int, proc_type: int) -> void:
	print("battle_resolution_runner.gd enqueue_status_proc()")
	_queue.push_back({"op":"status_proc","id":target_id,"proc":proc_type})
	_kick()

func enqueue_move(ctx: MoveContext) -> void:
	_queue.push_back({"op":"move","ctx":ctx})
	_kick()

func enqueue_damage(ctx: DamageContext) -> void:
	print("battle_resolution_runner.gd enqueue-damage()")
	_queue.push_back({
		"op": "damage",
		"ctx": ctx,
	})
	_kick()

func enqueue_summon(ctx: SummonContext) -> void:
	_queue.push_back({"op":"summon","ctx": ctx})
	_kick()

func enqueue_heal(ctx: HealContext) -> void:
	_queue.push_back({"op":"heal","ctx":ctx})
	_kick()

func enqueue_attack_now(ctx: AttackNowContext) -> void:
	_queue.push_back({"op":"attack_now","ctx":ctx})
	_kick()


func _kick() -> void:
	if _busy:
		return
	_busy = true
	call_deferred("_process_queue")

#func _kick() -> void:
	#if _busy:
		#return
	#_busy = true
	#_process_queue()

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
			"status_proc":
				var cid := int(item.get("id", -1))
				var proc := int(item.get("proc", -1))
				if api and cid != -1 and proc != -1:
					await api._run_status_proc_op(cid, proc)
			"summon":
				var ctx: SummonContext = item.get("ctx", null)
				if api and ctx:
					await api._run_summon_op(ctx)
			"heal":
				var ctx: HealContext = item.get("ctx", null)
				if api and ctx:
					await api._run_heal_op(ctx)
			"move":
				var ctx: MoveContext = item.get("ctx", null)
				if api and ctx:
					await api._run_move_op(ctx)
			"attack_now":
				var ctx: AttackNowContext = item.get("ctx", null)
				if api and ctx:
					await api._run_attack_now_op(ctx)
			_:
				push_warning("BattleResolutionRunner: unknown op: %s" % op)

	_busy = false
