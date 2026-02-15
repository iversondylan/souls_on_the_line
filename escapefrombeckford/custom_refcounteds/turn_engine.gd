# turn_engine.gd
class_name TurnEngine
extends RefCounted

enum Phase {
	IDLE,
	ACTOR_START,
	WAITING_FOR_ACTION,
	ACTOR_END,
}

var api: BattleAPI
var battle_scene: BattleScene

var active_group: BattleGroup = null
var active_group_index: int = -1

var current_actor: Fighter = null
var phase: int = Phase.IDLE

# Pattern B: if we hit the player, we pause until someone calls resume_after_player_done()
#var waiting_for_player: bool = false


func _init(_api: BattleAPI, _battle_scene: BattleScene) -> void:
	api = _api
	battle_scene = _battle_scene


func start_group_turn(group: BattleGroup, group_index: int, start_at_player := false) -> void:
	if !group or !is_instance_valid(group):
		return

	active_group = group
	active_group_index = group_index
	#waiting_for_player = false
	phase = Phase.IDLE

	# Build acting queue (but do NOT enter anyone here)
	group.build_acting_queue(start_at_player)

	_advance_to_next_actor()


func resume_after_player_done() -> void:
	# Called by Battle when player turn is complete (Pattern B)
	print("turn_engine.gd resume_after_player_done()")
	#if !waiting_for_player:
		#print("wasn't waiting for player")
		#return
	#waiting_for_player = false
	#print("no longer waiting for player")
	# Player’s action resolution should already have happened and signaled.
	# If you want this to be the "go now" lever, just advance.
	if phase == Phase.IDLE:
		print("turn_engine.gd resume_after_player_done(): phase is IDLE")
		_advance_to_next_actor()
	print("turn_engine.gd resume_after_player_done(): end of resume_after_player_done()")


func on_actor_removed(fighter: Fighter) -> void:
	# If current actor got removed mid-turn, push forward.
	if fighter and fighter == current_actor:
		current_actor = null
		phase = Phase.IDLE
		#waiting_for_player = false
		_advance_to_next_actor()


func _advance_to_next_actor() -> void:
	print("turn_engine.gd _advance_to_next_actor()")
	if !active_group or !is_instance_valid(active_group):
		_reset()
		return
	print("turn_engine.gd _advance_to_next_actor(): active group and valid instance")
	# No one left in this group: end group turn using your existing event wiring.
	if active_group.acting_fighters.is_empty():
		print("turn_engine.gd _advance_to_next_actor(): active group is empty")
		_reset()
		active_group.end_turn()
		return
	var actor := active_group.acting_fighters[0]
	if !actor or !is_instance_valid(actor) or !actor.is_alive():
		print("turn_engine.gd _advance_to_next_actor(): actor is invalid, dead, or nonexistent")
		# Skip invalid/dead actor (should be rare; safety)
		active_group.acting_fighters.pop_front()
		active_group._update_pending_turn_glow()
		_advance_to_next_actor()
		return

	current_actor = actor
	_run_actor_async(actor)


func _reset() -> void:
	active_group = null
	active_group_index = -1
	current_actor = null
	phase = Phase.IDLE
	#waiting_for_player = false


func _run_actor_async(actor: Fighter) -> void:
	print("turn_engine.gd _run_actor_async()")
	# Fire-and-forget coroutine
	_run_actor_coroutine(actor)


func _run_actor_coroutine(actor: Fighter) -> void:
	# coroutine
	print("turn_engine.gd _run_actor_coroutine(): awaiting _run_actor(actor)...")
	await _run_actor(actor)
	print("turn_engine.gd _run_actor_coroutine(): _run_actor(actor) complete.")


#func _await_status_proc(actor: Fighter, want_proc: Status.ProcType) -> void:
	## Wait for actor.statuses_applied(proc_type) matching want_proc
	#while actor and is_instance_valid(actor):
		#var got : Status.ProcType = await actor.statuses_applied
		## Signal is (proc_type) on Fighter; your Fighter relays from Combatant
		#if got == want_proc:
			#return


func _await_action_or_removal(actor: Fighter) -> bool:
	# Returns true if action resolved, false if actor vanished/removed
	# Minimal polling approach (keeps it simple and robust)
	while actor and is_instance_valid(actor):
		# If someone removed it out from under us, stop waiting
		if !actor.is_alive():
			# dead-but-not-removed can still resolve action; keep waiting unless it disappears
			pass
		
		# If action resolves, Fighter emits action_resolved(self) and BattleGroup used to listen.
		# We just await the signal directly.
		print("turn_engine.gd _await_action_or_removal() beginning await of action resolved...")
		var resolved : Fighter = await actor.action_resolved
		print("turn_engine.gd _await_action_or_removal() action resolved.")
		# resolved is Fighter (turn_taker)
		if resolved == actor:
			print("turn_engine.gd _await_action_or_removal(): resolved is the actor")
			return true
	print("turn_engine.gd _await_action_or_removal(): resolved is not the actor")
	return false


func _run_actor(actor: Fighter) -> void:
	print("turn_engine.gd _run_actor()")
	if !actor or !is_instance_valid(actor) or !actor.is_alive():
		print("turn_engine.gd _run_actor(): actor is invalid, dead, or nonexistent")
		phase = Phase.IDLE
		_advance_to_next_actor()
		return
	
	# -----------------------
	# ACTOR START
	# -----------------------
	phase = Phase.ACTOR_START
	actor.enter()
	api.run_status_proc(actor.combat_id, Status.ProcType.START_OF_TURN)
	print("turn_engine.gd _run_actor() awaiting START_OF_TURN status proc...")
	await _await_status_proc_finished(actor, Status.ProcType.START_OF_TURN)
	print("turn_engine.gd _run_actor() START_OF_TURN status proc done.")
	
	phase = Phase.WAITING_FOR_ACTION
	actor.do_turn()
	print("turn_engine.gd _run_actor() awaiting action or removal...")
	await _await_action_or_removal(actor)
	print("turn_engine.gd _run_actor() action or removal done.")
	
	phase = Phase.ACTOR_END
	api.run_status_proc(actor.combat_id, Status.ProcType.END_OF_TURN)
	print("turn_engine.gd _run_actor() awaiting END_OF_TURN status proc...")
	await _await_status_proc_finished(actor, Status.ProcType.END_OF_TURN)
	print("turn_engine.gd _run_actor() END_OF_TURN status proc done.")
	actor.exit()
	if active_group and is_instance_valid(active_group):
		print("turn_engine.gd _run_actor(): popping actor")
		active_group.pop_current_actor(actor)
	
	phase = Phase.IDLE
	print("turn_engine.gd _run_actor(): phase is now IDLE")
	_advance_to_next_actor()

func _await_status_proc_finished(actor: Fighter, want_proc: Status.ProcType) -> void:
	print("turn_engine.gd _run_actor(): _await_status_proc_finished()")
	# Wait for actor.status_proc_finished(proc_type) matching want_proc
	while actor and is_instance_valid(actor):
		print("turn_engine.gd _run_actor(): _await_status_proc_finished() awaiting actor.status_proc_finished...")
		var got : Status.ProcType = await actor.status_proc_finished
		print("turn_engine.gd _run_actor(): _await_status_proc_finished() actor.status_proc_finished.")
		if got == want_proc:
			print("turn_engine.gd _run_actor(): _await_status_proc_finished() it's the wanted proc.")
			return
