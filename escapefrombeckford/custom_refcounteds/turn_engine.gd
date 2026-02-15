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


func _init(_api: BattleAPI, _battle_scene: BattleScene) -> void:
	api = _api
	battle_scene = _battle_scene

func _is_player(f: Fighter) -> bool:
	if !f or !is_instance_valid(f):
		return false
	return (f is Player) or (f.get_node_or_null("PlayerBehavior") != null)


func start_group_turn(group: BattleGroup, group_index: int, start_at_player := false) -> void:
	print("turn_engine.gd start_group_turn()")
	if !group or !is_instance_valid(group):
		return
	
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
		print("turn_engine.gd start_group_turn(): actor already running; will continue on completion")
		return

	_advance_to_next_actor()


func resume_after_player_done() -> void:
	# Called by Battle when player turn is complete (Pattern B)
	print("turn_engine.gd resume_after_player_done()")
	if phase == Phase.IDLE:
		print("turn_engine.gd resume_after_player_done(): phase is IDLE")
		_advance_to_next_actor()
	print("turn_engine.gd resume_after_player_done(): end of resume_after_player_done()")



func on_actor_removed(fighter: Fighter) -> void:
	print("turn_engine.gd on_actor_removed()")
	# If current actor got removed mid-turn, push forward.
	if fighter and fighter == current_actor:
		current_actor = null
		phase = Phase.IDLE
		_queue_dirty = true
		if !_running_actor:
			_advance_to_next_actor()

func on_move_executed(ctx: MoveContext) -> void:
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
	print("turn_engine.gd _advance_to_next_actor()")
	
	if _running_actor:
		print("turn_engine.gd _advance_to_next_actor(): ignored (actor running)")
		return
	
	print("turn_engine.gd _advance_to_next_actor(): no _running_actor. Proceeding...")
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
	print("turn_engine.gd _end_group_turn(): ending group ", idx)

	_reset()

	# Hand off to your existing Battle.gd wiring
	# Friendly group (0) -> request enemy turn; Enemy group (1) -> request friendly turn
	if idx == 0:
		Events.request_enemy_turn.emit()
	elif idx == 1:
		Events.request_friendly_turn.emit()
	else:
		# Fallback; shouldn’t happen
		print("turn_engine.gd _end_group_turn(): unknown group index")

func _run_actor_async(actor: Fighter) -> void:
	print("turn_engine.gd _run_actor_async()")
	# Fire-and-forget coroutine
	var my_token := _turn_token
	_run_actor_coroutine(actor, my_token)

func _run_actor_coroutine(actor: Fighter, my_token: int) -> void:
	await _run_actor(actor)
	_running_actor = false

	# stale token guard
	if my_token != _turn_token:
		print("turn_engine.gd _run_actor_coroutine(): stale token; not advancing")
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
	_queue_dirty = false
	_queue.clear()

	if !active_group or !is_instance_valid(active_group):
		return

	# Desired order depends on group type and formation
	var desired := _get_desired_order(active_group, active_group_index, _start_at_player)

	# Filter by: alive, within turn cap, and (already acted) only if restore is allowed
	for f in desired:
		if !f or !is_instance_valid(f) or !f.is_alive():
			continue

		var cid := int(f.combat_id)
		var left := _turns_left_for_fighter(f)
		if left <= 0:
			continue


		var taken := int(_turns_taken.get(cid, 0))
		if taken == 0:
			_queue.append(f)
		else:
			# already took >=1 turn this group turn
			if active_group_index == 0 and _is_player(f):
				# Never restore player turn
				continue
			if bool(_restore_allowed.get(cid, false)):
				_queue.append(f)
				_restore_allowed.erase(cid) # <-- consume here


	# Optional: update glow using group’s own visuals if you want
	if active_group.has_method("_update_pending_turn_glow"):
		active_group.acting_fighters = _queue.duplicate()
		active_group._update_pending_turn_glow()

func _get_desired_order(group: BattleGroup, group_index: int, start_at_player: bool) -> Array[Fighter]:
	# Base list: formation order from the group
	var combatants: Array[Fighter] = group.get_combatants(false) # assumed front->back

	if group_index != 0:
		# Enemy group: everyone in formation order
		return combatants

	# Friendly group: player + behind-player only
	var player_idx := _find_player_index(combatants)
	if player_idx < 0:
		player_idx = 0

	var out: Array[Fighter] = []

	# player always included first (for your first-turn flow)
	if player_idx >= 0 and player_idx < combatants.size():
		out.append(combatants[player_idx])

	# then everyone behind the player
	for i in range(player_idx + 1, combatants.size()):
		out.append(combatants[i])

	# NOTE: start_at_player is currently naturally satisfied by putting player first.
	# If you later want “start at whoever is next after player,” that’s where you’d rotate.

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

	# Only matter if summoned into the currently active group turn
	if fighter.battle_group != active_group:
		return

	# If no current actor (between turns), safest default: don't grant a surprise turn.
	if !current_actor or !is_instance_valid(current_actor):
		return

	# Decide "behind current actor" by formation indices
	var order := active_group.get_combatants(false)
	var cur_i := order.find(current_actor)
	var new_i := order.find(fighter)
	if cur_i == -1 or new_i == -1:
		return

	# If inserted strictly behind current actor, it may act this group turn.
	if new_i > cur_i:
		# Ensure it hasn't hit cap
		var cid := int(fighter.combat_id)
		if !_turns_taken.has(cid):
			_turns_taken[cid] = 0
		_queue_dirty = true
		# If we're idle, rebuild immediately; otherwise rebuild after actor finishes.
		if !_running_actor:
			_rebuild_queue()
