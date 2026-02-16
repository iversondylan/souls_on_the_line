# turn_engine.gd

class_name TurnEngine extends RefCounted

enum Phase {
	IDLE,
	ACTOR_START,
	WAITING_FOR_ACTION,
	ACTOR_END,
}

const MAX_TURNS_PER_FIGHTER_PER_GROUP_TURN := 3

var api: BattleAPI
var battle_scene: BattleScene

var active_group: BattleGroup = null
var active_group_index: int = -1

var current_actor: Fighter = null
var _running_actor: bool = false
var _turn_token: int = 0
var phase: int = Phase.IDLE

var _queue: Array[Fighter] = []
var _turns_taken: Dictionary = {}			# int combat_id -> int
var _restore_allowed: Dictionary = {}		# int combat_id -> bool
var _queue_dirty: bool = false
var _start_at_player: bool = false
var _cursor_rank: int = -1	# formation index of the most recently STARTED actor (snapshot)



func _init(_api: BattleAPI, _battle_scene: BattleScene) -> void:
	api = _api
	battle_scene = _battle_scene

func _is_player(f: Fighter) -> bool:
	return f != null and is_instance_valid(f) and (f is Player)


func start_group_turn(group: BattleGroup, group_index: int, start_at_player := false) -> void:
	#print("turn_engine.gd start_group_turn()")
	if !group or !is_instance_valid(group):
		return
	
	_cursor_rank = -1
	_turn_token += 1
	active_group = group
	active_group_index = group_index
	_start_at_player = start_at_player
	
	phase = Phase.IDLE
	current_actor = null
	
	_queue.clear()
	_turns_taken.clear()
	_restore_allowed.clear()
	_queue_dirty = true
	
	# If something is still running, let it finish; the coroutine token guard will prevent stale advancement.
	if _running_actor:
		#print("turn_engine.gd start_group_turn(): actor already running; will continue on completion")
		return

	_advance_to_next_actor()


func resume_after_player_done() -> void:
	# Called by Battle when player turn is complete (Pattern B)
	#print("turn_engine.gd resume_after_player_done()")
	if phase == Phase.IDLE:
		#print("turn_engine.gd resume_after_player_done(): phase is IDLE")
		_advance_to_next_actor()
	#print("turn_engine.gd resume_after_player_done(): end of resume_after_player_done()")



func on_actor_removed(fighter: Fighter) -> void:
	#print("turn_engine.gd on_actor_removed()")
	# If current actor got removed mid-turn, push forward.
	if fighter and fighter == current_actor:
		current_actor = null
		phase = Phase.IDLE
		_queue_dirty = true
		if !_running_actor:
			_advance_to_next_actor()

func on_move_executed(ctx: MoveContext) -> void:
	#print("turn_engine.gd on_move_executed()")
	if !ctx or !ctx.can_restore_turn:
		return
	if !active_group or !is_instance_valid(active_group):
		return
	if !current_actor or !is_instance_valid(current_actor):
		return
	# Only consider moves affecting the currently active group.
	if current_actor.battle_group != active_group:
		return
	
	# Need snapshots
	if ctx.before_order_ids.is_empty() or ctx.after_order_ids.is_empty():
		return
	var anchor_id := int(current_actor.combat_id)

	var before_anchor := ctx.before_order_ids.find(anchor_id)
	var after_anchor := ctx.after_order_ids.find(anchor_id)
	if before_anchor == -1 or after_anchor == -1:
		return
	# Only the units that actually crossed behind get restore eligibility.
	var granted := false
	if crossed_behind(int(ctx.actor_id), ctx, before_anchor, after_anchor):
		_restore_allowed[int(ctx.actor_id)] = true
		granted = true
	
	if crossed_behind(int(ctx.target_id), ctx, before_anchor, after_anchor):
		_restore_allowed[int(ctx.target_id)] = true
		granted = true

	if granted:
		_queue_dirty = true
		
		if !_running_actor:
			_rebuild_queue()
	_apply_pending_turn_glow_view()
		

	# helper local
func crossed_behind(cid: int, ctx: MoveContext, before_anchor: int, after_anchor: int) -> bool:
	if cid <= 0:
		return false
	var b := ctx.before_order_ids.find(cid)
	var a := ctx.after_order_ids.find(cid)
	if b == -1 or a == -1:
		return false
	# Restore rule: was not behind anchor, now is behind anchor.
	return (b <= before_anchor) and (a > after_anchor)

func _advance_to_next_actor() -> void:
	#print("turn_engine.gd _advance_to_next_actor()")
	
	if _running_actor:
		#print("turn_engine.gd _advance_to_next_actor(): ignored (actor running)")
		return
	
	#print("turn_engine.gd _advance_to_next_actor(): no _running_actor. Proceeding...")
	if !active_group or !is_instance_valid(active_group):
		_reset()
		return
	
	# Recompute queue whenever needed (moves/summons/removals can make it stale)
	if _queue_dirty:
		_rebuild_queue()
	
	# If still empty, end this group turn
	if _queue.is_empty():
		_end_group_turn()
		return
	var actor := _queue[0]
	if !actor or !is_instance_valid(actor) or !actor.is_alive():
		_queue.pop_front()
		_queue_dirty = true
		_advance_to_next_actor()
		return
	
	current_actor = actor
	_running_actor = true
	# Snapshot the actor's formation position at start-of-turn.
	# This is the "cursor" we use to decide who is still eligible later.
	var order_now := active_group.get_combatants(false)
	_cursor_rank = order_now.find(actor)
	_run_actor_async(actor)


func _reset() -> void:
	active_group = null
	active_group_index = -1
	current_actor = null
	phase = Phase.IDLE
	_queue.clear()
	_turns_taken.clear()
	_restore_allowed.clear()
	_queue_dirty = false

func _end_group_turn() -> void:
	# IMPORTANT: copy index before reset
	var idx := active_group_index
	#print("turn_engine.gd _end_group_turn(): ending group ", idx)

	_reset()

	# Hand off to your existing Battle.gd wiring
	# Friendly group (0) -> request enemy turn; Enemy group (1) -> request friendly turn
	if idx == 0:
		Events.request_enemy_turn.emit()
	elif idx == 1:
		Events.request_friendly_turn.emit()
	else:
		# Fallback; shouldn’t happen
		push_warning("turn_engine.gd _end_group_turn(): unknown group index")

func _run_actor_async(actor: Fighter) -> void:
	#print("turn_engine.gd _run_actor_async()")
	# Fire-and-forget coroutine
	var my_token := _turn_token
	_run_actor_coroutine(actor, my_token)

func _run_actor_coroutine(actor: Fighter, my_token: int) -> void:
	await _run_actor(actor)
	_running_actor = false

	# stale token guard
	if my_token != _turn_token:
		#print("turn_engine.gd _run_actor_coroutine(): stale token; not advancing")
		return

	# Consume the actor from the queue (if still at front)
	if !_queue.is_empty() and _queue[0] == actor:
		_queue.pop_front()

	# Mark that actor has taken a turn
	_mark_turn_taken(actor)
	# Consume restore allowance once it has been used to schedule a turn.
	# (Prevents "sticky restore" producing multiple re-adds across rebuilds.)
	var cid := int(actor.combat_id)
	_restore_allowed.erase(cid)
	# Queue likely changed legality/order due to moves/summons/deaths during the action
	_queue_dirty = true
	_advance_to_next_actor()

func _mark_turn_taken(actor: Fighter) -> void:
	if !actor:
		return
	var cid := int(actor.combat_id)
	var n := int(_turns_taken.get(cid, 0))
	_turns_taken[cid] = n + 1

func _turns_left_for_fighter(f: Fighter) -> int:
	if !f or !is_instance_valid(f):
		return 0
	if active_group_index == 0 and _is_player(f):
		# Player gets exactly one turn per friendly group turn.
		return 1 - int(_turns_taken.get(int(f.combat_id), 0))
	return MAX_TURNS_PER_FIGHTER_PER_GROUP_TURN - int(_turns_taken.get(int(f.combat_id), 0))

func _rebuild_queue() -> void:
	#print("turn_engine.gd _rebuild_queue()")
	_queue_dirty = false
	_queue.clear()

	if !active_group or !is_instance_valid(active_group):
		return

	var desired := _get_desired_order(active_group, active_group_index, _start_at_player)

	# Normal pass (cursor-based)
	for f in desired:
		if !f or !is_instance_valid(f) or !f.is_alive():
			continue

		var left := _turns_left_for_fighter(f)
		if left <= 0:
			continue

		var cid := int(f.combat_id)
		var taken := int(_turns_taken.get(cid, 0))

		if taken == 0:
			_queue.append(f)
		else:
			if active_group_index == 0 and _is_player(f):
				continue
			if bool(_restore_allowed.get(cid, false)):
				_queue.append(f)
				_restore_allowed.erase(cid)

	# Restore pass: if a fighter is marked restore_allowed but got excluded by cursor slicing,
	# allow them in anyway (they *should* be behind now if your crossed_behind test is correct).
	for cid in _restore_allowed.keys():
		var id := int(cid)
		var f := battle_scene.get_combatant_by_id(id, true)
		if !f or !is_instance_valid(f) or !f.is_alive():
			continue
		if f.battle_group != active_group:
			continue
		if active_group_index == 0 and _is_player(f):
			continue
		if _turns_left_for_fighter(f) <= 0:
			continue
		if !_queue.has(f):
			_queue.append(f)
	
	# publish queue view to group for UI only
	_apply_pending_turn_glow_view()

func _get_desired_order(group: BattleGroup, group_index: int, start_at_player: bool) -> Array[Fighter]:
	# formation order front->back
	var combatants: Array[Fighter] = group.get_combatants(false)

	if combatants.is_empty():
		return []

	# Figure out "hard floor" start for this group
	var start_idx := 0

	if group_index == 0:
		# Friendly: nothing in front of player is ever eligible.
		var player_idx := _find_player_index(combatants)
		if player_idx < 0:
			player_idx = 0

		# Cursor says "we already passed through <= cursor"
		# So for friendly, start is max(player_idx, cursor+1) once cursor reaches player.
		var cursor_start := _cursor_rank + 1
		start_idx = maxi(player_idx, cursor_start)

	else:
		# Enemy: normal front->back, but respect cursor
		start_idx = maxi(0, _cursor_rank + 1)

	# Slice from start_idx to end
	var out: Array[Fighter] = []
	for i in range(start_idx, combatants.size()):
		out.append(combatants[i])

	return out

func _find_player_index(combatants: Array[Fighter]) -> int:
	# Prefer a robust check: class type or a behavior node.
	for i in range(combatants.size()):
		var f := combatants[i]
		if !f or !is_instance_valid(f):
			continue
		if f is Player:
			return i
		# fallback heuristic: has PlayerBehavior child
		if f.get_node_or_null("PlayerBehavior") != null:
			return i
	return -1


func _await_action_or_removal(actor: Fighter) -> bool:
	while actor and is_instance_valid(actor):
		var resolved: Fighter = await actor.action_resolved
		if resolved == actor:
			return true
	return false

func _run_actor(actor: Fighter) -> void:
	if !actor or !is_instance_valid(actor) or !actor.is_alive():
		return

	phase = Phase.ACTOR_START
	actor.enter()
	api.run_status_proc(actor.combat_id, Status.ProcType.START_OF_TURN)
	await _await_status_proc_finished(actor, Status.ProcType.START_OF_TURN)

	phase = Phase.WAITING_FOR_ACTION
	actor.do_turn()
	await _await_action_or_removal(actor)

	phase = Phase.ACTOR_END
	api.run_status_proc(actor.combat_id, Status.ProcType.END_OF_TURN)
	await _await_status_proc_finished(actor, Status.ProcType.END_OF_TURN)

	actor.exit()
	phase = Phase.IDLE


func _await_status_proc_finished(actor: Fighter, want_proc: Status.ProcType) -> void:
	var start_tick := actor.last_status_proc_tick
	if actor.last_status_proc_finished == want_proc and actor.last_status_proc_tick != start_tick:
		return

	while actor and is_instance_valid(actor):
		var got: int = await actor.status_proc_finished
		if got == want_proc:
			return

func on_summon_added(fighter: Fighter) -> void:
	if !fighter or !is_instance_valid(fighter):
		return
	if !active_group or !is_instance_valid(active_group):
		return
	if fighter.battle_group != active_group:
		return

	# Just mark dirty. Cursor-aware desired order will do the right thing.
	_queue_dirty = true
	_apply_pending_turn_glow_view()

func _publish_pending_turn_view(queue_view: Array[Fighter]) -> void:
	if !active_group or !is_instance_valid(active_group):
		return
	active_group.pending_turn_queue_view = queue_view
	if active_group.has_method("_update_pending_turn_glow"):
		active_group._update_pending_turn_glow()

func _apply_pending_turn_glow_view() -> void:
	if !active_group or !is_instance_valid(active_group):
		return

	# ----------------------------
	# Pick the active actor for glow
	# ----------------------------
	var active: Fighter = null
	if _running_actor and current_actor and is_instance_valid(current_actor):
		active = current_actor
	elif !_queue.is_empty() and _queue[0] and is_instance_valid(_queue[0]):
		active = _queue[0]

	# ----------------------------
	# Build pending list (view-only)
	# Pending = eligible fighters strictly behind active in desired order.
	# If no active, pending = _queue (best-effort).
	# ----------------------------
	var pending: Array[Fighter] = []
	if active == null:
		pending = _queue.duplicate()
	else:
		var desired := _get_desired_order(active_group, active_group_index, _start_at_player)

		# Find anchor index robustly (don’t trust object identity if you’ve had weirdness)
		var start_i := 0
		var anchor_id := int(active.combat_id)
		var idx := -1
		for j in range(desired.size()):
			var d := desired[j]
			if d and is_instance_valid(d) and int(d.combat_id) == anchor_id:
				idx = j
				break
		if idx != -1:
			start_i = idx + 1 # strictly behind

		for i in range(start_i, desired.size()):
			var f := desired[i]
			if !f or !is_instance_valid(f) or !f.is_alive():
				continue

			var left := _turns_left_for_fighter(f)
			if left <= 0:
				continue

			var cid := int(f.combat_id)
			var taken := int(_turns_taken.get(cid, 0))

			if taken == 0:
				pending.append(f)
			else:
				# already acted once this group turn
				if active_group_index == 0 and _is_player(f):
					continue
				if bool(_restore_allowed.get(cid, false)):
					pending.append(f)
					# NOTE: do NOT erase restore flags here (view-only)

	# ----------------------------
	# Apply glow
	# ----------------------------
	for f: Fighter in active_group.get_combatants(false):
		if !f or !is_instance_valid(f):
			continue

		if active and f == active:
			f.set_pending_turn_glow(Fighter.TurnStatus.TURN_ACTIVE)
		elif pending.has(f):
			f.set_pending_turn_glow(Fighter.TurnStatus.TURN_PENDING)
		else:
			f.set_pending_turn_glow(Fighter.TurnStatus.NONE)
