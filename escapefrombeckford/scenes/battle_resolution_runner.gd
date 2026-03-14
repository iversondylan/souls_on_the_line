# battle_resolution_runner.gd

class_name BattleResolutionRunner extends Node
#
#signal scope_drained(scope_id:int)
#
#enum LifeState { ALIVE, DYING, REMOVED }
#
#var _pending_deaths := {} # int combat_id -> true
#var _removed := {} # int combat_id -> true
#
#
#var api: LiveBattleAPI
#
#var _queue: Array[Dictionary] = []
#var _busy: bool = false
#
#var _scope_stack: Array[int] = []
#var _scope_next: int = 1
#var _closed_scopes := {} # scope_id -> true
#var _scope_pending_counts := {} # scope_id -> int
#var _scope_actor := {} # scope_id -> actor_id
#
#var _in_run: bool = false
#var _insert_after_current: Array[Dictionary] = []
#
#
#func begin_scope(actor_id:int) -> int:
	#
	#var s := _scope_next
	##print("battle_resolution_runner.gd begin_scope() actor_id: %s, s: %s" % [actor_id, s])
	#_scope_next += 1
	#_scope_stack.push_back(s)
	#_scope_actor[s] = actor_id
	#_closed_scopes.erase(s)
	#_scope_pending_counts[s] = 0
	#return s
#
#func end_scope(scope_id:int) -> void:
	##print("battle_resolution_runner.gd end_scope() s: %s" % scope_id)
	#if _scope_stack.size() > 0 and _scope_stack.back() == scope_id:
		#_scope_stack.pop_back()
	#_scope_actor.erase(scope_id)
	#_closed_scopes.erase(scope_id)
	#_scope_pending_counts.erase(scope_id)
#
#func current_scope() -> int:
	#var curr_scope : int = _scope_stack.back() if _scope_stack.size() > 0 else 0
	##print("battle_resolution_runner.gd current_scope() s: %s" % curr_scope)
	#return curr_scope
#
#func close_scope(scope_id:int) -> void:
	##print("battle_resolution_runner.gd close_scope() s: %s" % scope_id)
	#_closed_scopes[scope_id] = true
#
#func pop_scope(scope_id: int) -> void:
	## Detach the "current scope" label without destroying bookkeeping.
	##print("battle_resolution_runner.gd pop_scope() s: %s" % scope_id)
	#if _scope_stack.size() > 0 and _scope_stack.back() == scope_id:
		#_scope_stack.pop_back()
#
#func await_scope_drained(scope_id:int) -> bool:
	##print("battle_resolution_runner.gd await_scope_drained() s: %s" % scope_id)
	#while true:
		#var n := int(_scope_pending_counts.get(scope_id, 0))
		## IMPORTANT: if closed + no pending + not busy, done.
		##print("battle_resolution_runner.gd await_scope_drained() s: %s. n = %s. _closed_scopes.has(scope_id) = %s" % [scope_id, n, _closed_scopes.has(scope_id)])
		#if n <= 0 and _closed_scopes.has(scope_id):# and !_busy:
			##print("battle_resolution_runner.gd await_scope_drained() s: %s. Returning." % scope_id)
			#return true
		## Wait for *any* drain/busy transition; loop re-checks.
		#await scope_drained
		##print("battle_resolution_runner.gd await_scope_drained() s: %s. Scope Drained." % scope_id)
	#return false
#
#func retain_scope(scope_id:int, why:="") -> void:
	##print("battle_resolution_runner.gd retain_scope() scope: %s, because: %s" % [scope_id, why])
	#if scope_id == 0:
		#
		#return
	#_scope_pending_counts[scope_id] = int(_scope_pending_counts.get(scope_id, 0)) + 1
#
#func release_scope(scope_id:int, why:="") -> void:
	##print("battle_resolution_runner.gd release_scope() scope: %s, because: %s" % [scope_id, why])
	#if scope_id == 0:
		#return
	#_scope_pending_counts[scope_id] = int(_scope_pending_counts.get(scope_id, 0)) - 1
	#_maybe_release_scope(scope_id)
#
#func _maybe_release_scope(scope_id:int) -> void:
	##print("battle_resolution_runner.gd _maybe_release_scope() scope: %s" % scope_id)
	#var n := int(_scope_pending_counts.get(scope_id, 0))
	## Emit whenever the scope is "count-drained" and closed.
	## We don't require !_busy here; the waiter will loop until !_busy too.
	#if n <= 0 and _closed_scopes.has(scope_id):
		#scope_drained.emit(scope_id)
#
#func enqueue_op(op: BattleOp) -> void:
	#if !op:
		#return
	#var s := current_scope()
	#if s == 0:
		#push_warning("RUNNER WARN enqueue with scope=0 op=BattleOp id= %s (no active scope)" % op.get_id())
	#var item := {"op_obj": op, "scope": s}
	#_enqueue_item(item)
#
#func _enqueue_item(item: Dictionary) -> void:
	#var s := int(item.get("scope", 0))
	#if s != 0:
		##print("battle_resolution_runner.gd _enqueue_item() adding +1 to _scope_pending_counts[%s]" % s)
		#_scope_pending_counts[s] = int(_scope_pending_counts.get(s, 0)) + 1
#
	#if _in_run:
		#_insert_after_current.push_back(item)
	#else:
		#_queue.push_back(item)
#
	#_kick()
#
#
#func is_removed(combat_id: int) -> bool:
	#return _removed.has(combat_id)
#
#func mark_removed(combat_id: int) -> void:
	#_removed[combat_id] = true
	#_pending_deaths.erase(combat_id)
#
#func enqueue_death(combat_id: int, reason: String = "") -> void:
	#if combat_id <= 0:
		#return
	#if _removed.has(combat_id):
		#return
	#if _pending_deaths.has(combat_id):
		#return
	#_pending_deaths[combat_id] = true
	#var s := current_scope()
	#if s == 0:
		#push_warning("RUNNER WARN enqueue with scope=0 op=death (no active scope)")
	#_enqueue_item({"op":"death","combat_id":combat_id,"reason":reason,"scope":s})
#
#func enqueue_apply_status(ctx: StatusContext) -> void:
	#var s := current_scope()
	#if s == 0:
		#push_warning("RUNNER WARN enqueue with scope=0 op=apply_status (no active scope)")
	#_enqueue_item({"op":"apply_status","ctx":ctx,"scope":s})
#
##func enqueue_remove_status(ctx: RemoveStatusContext) -> void:
	##var s := current_scope()
	##if s == 0:
		##push_warning("RUNNER WARN enqueue with scope=0 op=remove_status (no active scope)")
	##_enqueue_item({"op":"remove_status","ctx":ctx,"scope":s})
#
#func enqueue_status_proc(target_id: int, proc_type: int) -> void:
	#var s := current_scope()
	#if s == 0:
		#push_warning("RUNNER WARN enqueue with scope=0 op=status_proc (no active scope)")
	#_enqueue_item({"op":"status_proc","id":target_id,"proc":proc_type,"scope":s})
#
#func enqueue_move(ctx: MoveContext) -> void:
	#var s := current_scope()
	#if s == 0:
		#push_warning("RUNNER WARN enqueue with scope=0 op=move (no active scope)")
	#_enqueue_item({"op":"move","ctx":ctx,"scope":s})
#
#func enqueue_damage(ctx: DamageContext) -> void:
	#var s := current_scope()
	#if s == 0:
		#push_warning("RUNNER WARN enqueue with scope=0 op=damage (no active scope)")
	#_enqueue_item({"op":"damage","ctx":ctx,"scope":s})
#
#func enqueue_summon(ctx: SummonContext) -> void:
	#var s := current_scope()
	#if s == 0:
		#push_warning("RUNNER WARN enqueue with scope=0 op=summon (no active scope)")
	#_enqueue_item({"op":"summon","ctx":ctx,"scope":s})
#
#func enqueue_heal(ctx: HealContext) -> void:
	#var s := current_scope()
	#if s == 0:
		#push_warning("RUNNER WARN enqueue with scope=0 op=heal (no active scope)")
	#_enqueue_item({"op":"heal","ctx":ctx,"scope":s})
#
#func enqueue_attack_now(ctx: AttackNowContext) -> void:
	#var s := current_scope()
	#if s == 0:
		#push_warning("RUNNER WARN enqueue with scope=0 op=attack_now (no active scope)")
	#_enqueue_item({"op":"attack_now","ctx":ctx,"scope":s})
#
#func _kick() -> void:
	#if _busy:
		#return
	#_busy = true
	#call_deferred("_process_queue")
#
#func _process_queue() -> void:
	## coroutine
	#await _run()
#
#func _run() -> void:
	#_in_run = true
	#while !_queue.is_empty():
		#var item = _queue.pop_front()
#
		## --- Run op ---
		#if item.has("op_obj"):
			#var op_obj: BattleOp = item.get("op_obj", null)
			#if api and op_obj:
				#var r = op_obj.run(api, self)
				#if typeof(r) == TYPE_OBJECT and r != null and r.get_class() == "GDScriptFunctionState":
					#await r
				#elif r is Signal and !(r as Signal).is_null():
					#await r
		#else:
			#var op := str(item.get("op", ""))
#
			#match op:
				#"damage":
					#var ctx: DamageContext = item.get("ctx", null)
					#if api and ctx:
						#await api._run_damage_op(ctx)
				#"death":
					#var cid := int(item.get("combat_id", -1))
					#var reason := str(item.get("reason", ""))
					#if api and cid != -1:
						#await api._run_death_op(cid, reason)
				#"apply_status":
					#var ctx: StatusContext = item.get("ctx", null)
					#if api and ctx:
						#await api._run_apply_status_op(ctx)
				##"remove_status":
					##var ctx: RemoveStatusContext = item.get("ctx", null)
					##if api and ctx:
						##await api._run_remove_status_op(ctx)
				#"status_proc":
					#var cid := int(item.get("id", -1))
					#var proc := int(item.get("proc", -1))
					#if api and cid != -1 and proc != -1:
						#await api._run_status_proc_op(cid, proc)
				#"summon":
					#var ctx: SummonContext = item.get("ctx", null)
					#if api and ctx:
						#await api._run_summon_op(ctx)
				#"heal":
					#var ctx: HealContext = item.get("ctx", null)
					#if api and ctx:
						#await api._run_heal_op(ctx)
				#"move":
					#var ctx: MoveContext = item.get("ctx", null)
					#if api and ctx:
						#await api._run_move_op(ctx)
				#"attack_now":
					#var ctx: AttackNowContext = item.get("ctx", null)
					#if api and ctx:
						#await api._run_attack_now_op(ctx)
				#_:
					#push_warning("BattleResolutionRunner: unknown op: %s" % op)
#
		## --- Scope accounting ---
		#var s := int(item.get("scope", 0))
		#if s != 0:
			#_scope_pending_counts[s] = int(_scope_pending_counts.get(s, 0)) - 1
			#_maybe_release_scope(s)
#
		## --- Insert children produced by this op to run next ---
		#if !_insert_after_current.is_empty():
			## Prepend in the same order they were enqueued
			#var next_batch := _insert_after_current
			#_insert_after_current = []
			#_queue = next_batch + _queue
#
	#_busy = false
	#_in_run = false
	#scope_drained.emit(-1)
