class_name TurnEngineCore extends RefCounted

# ============================================================================
# TurnEngineCore
# ----------------------------------------------------------------------------
# Purpose
# - Owns intra-group turn flow for one active group phase.
# - Decides which unit should act next.
# - Tracks per-phase pending membership, turns taken, and restore eligibility.
# - Exposes a small handshake surface to SimRuntime:
#		* request player begin
#		* request arcana proc
#		* request actor turn
#		* report group turn end
#
# Relationship to SimRuntime
# - This object does not execute gameplay, open/close scopes, or emit events.
# - SimRuntime owns execution, scope boundaries, and event writing.
# - TurnEngineCore only answers "what should happen next?" and tracks flow state.
#
# Current conceptual model
# - Pending membership is the primary source of truth.
# - Construction sites describe move-time queue mutations explicitly.
# - TurnEngineCore applies those instructions without inferring from formation
#   snapshots or a pivot position.
# ============================================================================


# -------------------------
# Enums
# -------------------------

enum Phase {
	IDLE,
	ACTOR_START,
	WAITING_FOR_ACTION,
	ACTOR_END,
}

enum ArcanaProc {
	BATTLE_START,
	PLAYER_TURN_BEGIN,
	PLAYER_TURN_END,
	BATTLE_END,
}


# -------------------------
# Arcana aliases
# -------------------------

const START_OF_COMBAT := ArcanaProc.BATTLE_START
const START_OF_TURN := ArcanaProc.PLAYER_TURN_BEGIN
const END_OF_TURN := ArcanaProc.PLAYER_TURN_END
const END_OF_COMBAT := ArcanaProc.BATTLE_END


# -------------------------
# Turn limits
# -------------------------

const MAX_TURNS_PER_FIGHTER_PER_GROUP_TURN := 3
const MAX_PLAYER_TURNS_PER_GROUP_TURN := 1
const MAX_RESTORES_PER_FIGHTER_PER_GROUP_TURN := 1


# -------------------------
# External query host
# -------------------------

var host: TurnFlowQueryHost


# -------------------------
# Active flow state
# -------------------------

var active_group_index: int = -1
var current_actor_id: int = 0
var _running_actor: bool = false
var turn_token: int = 0
var phase: int = Phase.IDLE

# Membership in the pending queue for the current group phase.
# Keys are combatant ids; values are effectively booleans.
var _pending_members: Dictionary = {}	# int combat_id -> bool

# Materialized execution queue derived from current order + pending membership.
var _queue: PackedInt32Array = PackedInt32Array()

# Per-phase turn accounting.
var _turns_taken: Dictionary = {}			# int combat_id -> int
var _restore_allowed: Dictionary = {}		# int combat_id -> bool
var _restores_granted: Dictionary = {}		# int combat_id -> int
var _queue_dirty: bool = false

var _start_at_player: bool = false

var _player_start_of_turn_fired: bool = false
var _start_of_combat_fired: bool = false
var _deferred_current_actor_grant: bool = false


# -------------------------
# Handshake state
# -------------------------

# Player-specific flow boundaries.
var _waiting_for_player_begin: bool = false
var _waiting_for_player_end: bool = false

# Arcana proc boundary.
var _waiting_for_arcana: bool = false
var _pending_arcana_proc: int = -1


# -------------------------
# Debug
# -------------------------

var dbg := false


func _init(_host: TurnFlowQueryHost) -> void:
	host = _host


func clone_for_host(new_host: TurnFlowQueryHost) -> TurnEngineCore:
	var c := TurnEngineCore.new(new_host)

	c.active_group_index = active_group_index
	c.current_actor_id = current_actor_id
	c._running_actor = _running_actor
	c.turn_token = turn_token
	c.phase = phase

	c._queue = _queue.duplicate()
	c._turns_taken = _turns_taken.duplicate(true)
	c._restore_allowed = _restore_allowed.duplicate(true)
	c._restores_granted = _restores_granted.duplicate(true)
	c._queue_dirty = _queue_dirty

	c._start_at_player = _start_at_player

	c._player_start_of_turn_fired = _player_start_of_turn_fired
	c._start_of_combat_fired = _start_of_combat_fired
	c._deferred_current_actor_grant = _deferred_current_actor_grant

	c._pending_members = _pending_members.duplicate(true)

	# Preview clones resume from stable flow state but do not inherit live
	# handshake waits from the source runtime.
	c._waiting_for_player_begin = false
	c._waiting_for_player_end = false
	c._waiting_for_arcana = false
	c._pending_arcana_proc = -1

	c.dbg = dbg
	return c


func begin_group_turn_state(group_index: int, start_at_player := false) -> void:
	if dbg:
		print(
			"TurnEngineCore.begin_group_turn_state() group=%s start_at_player=%s"
			% [group_index, start_at_player]
		)

	active_group_index = int(group_index)
	_start_at_player = bool(start_at_player)

	turn_token += 1

	phase = Phase.IDLE
	current_actor_id = 0
	_running_actor = false

	_queue = PackedInt32Array()
	_turns_taken.clear()
	_restore_allowed.clear()
	_restores_granted.clear()
	_pending_members.clear()
	_queue_dirty = true

	_player_start_of_turn_fired = false
	_deferred_current_actor_grant = false

	_seed_pending_members_for_phase()

	if active_group_index == 0 and _start_at_player and !_start_of_combat_fired:
		_start_of_combat_fired = true
		_pending_arcana_proc = ArcanaProc.BATTLE_START


func advance() -> TurnFlowDirective:
	if dbg:
		print("TurnEngineCore.advance()")

	if _waiting_for_player_begin or _waiting_for_player_end or _waiting_for_arcana or _running_actor:
		return TurnFlowDirective.blocked()

	if active_group_index < 0:
		_reset()
		return TurnFlowDirective.idle()

	if _pending_arcana_proc >= 0:
		_waiting_for_arcana = true
		return TurnFlowDirective.request_arcana(_pending_arcana_proc)

	if _queue_dirty:
		_rebuild_queue()

	# Drain dead units from the head of the queue (loop-based, avoids recursion)
	while !_queue.is_empty() and !host.is_alive(int(_queue[0])):
		_pending_members.erase(int(_queue[0]))
		_queue.remove_at(0)
		_queue_dirty = true

	if _queue.is_empty():
		var ended_group := active_group_index
		_reset()
		return TurnFlowDirective.group_turn_ended(ended_group)

	var actor_id := int(_queue[0])

	if active_group_index == 0 and host.is_player(actor_id) and !_player_start_of_turn_fired:
		_player_start_of_turn_fired = true
		_waiting_for_player_begin = true
		return TurnFlowDirective.request_player_begin()

	# This actor is no longer part of the future queue; it becomes the present.
	current_actor_id = actor_id
	_running_actor = true
	phase = Phase.ACTOR_START
	_pending_members.erase(actor_id)
	_queue.remove_at(0)

	return TurnFlowDirective.request_actor(actor_id)


func complete_actor(combat_id: int) -> void:
	if dbg:
		print("TurnEngineCore.complete_actor() cid=%s current=%s" % [combat_id, current_actor_id])

	if int(combat_id) != current_actor_id:
		return

	_running_actor = false
	_mark_turn_taken(int(combat_id))
	if _deferred_current_actor_grant and int(combat_id) == current_actor_id:
		_deferred_current_actor_grant = false
		_grant_pending_turn(int(combat_id))
	else:
		_restore_allowed.erase(int(combat_id))
	_queue_dirty = true
	phase = Phase.IDLE


func notify_actor_removed(combat_id: int) -> void:
	if dbg:
		print("TurnEngineCore.notify_actor_removed() cid=%s current=%s" % [combat_id, current_actor_id])

	if active_group_index < 0:
		return

	var removed_id := int(combat_id)

	_pending_members.erase(removed_id)
	_restore_allowed.erase(removed_id)
	_restores_granted.erase(removed_id)
	_turns_taken.erase(removed_id)
	if removed_id == current_actor_id:
		_deferred_current_actor_grant = false

	_queue_dirty = true


func notify_summon_added(ctx: SummonContext) -> void:
	if dbg:
		print("TurnEngineCore.notify_summon_added()")

	if ctx == null:
		return
	if int(ctx.group_index) != active_group_index:
		return

	var after_order := ctx.after_order_ids
	if after_order.is_empty():
		after_order = _get_current_group_order()

	var summoned_id := int(ctx.summoned_id)
	if summoned_id <= 0:
		_queue_dirty = true
		return
	if after_order.find(summoned_id) == -1:
		_queue_dirty = true
		return

	# If no actor is currently active, the summoned unit joins the continuous
	# group queue as long as it exists in the post-summon order.
	if !_running_actor or current_actor_id <= 0:
		_pending_members[summoned_id] = true
		_queue_dirty = true
		return

	var pivot_idx := after_order.find(current_actor_id)
	var summoned_idx := after_order.find(summoned_id)

	if pivot_idx == -1 or summoned_idx == -1:
		_queue_dirty = true
		return

	# During an active turn, summons only join the future if they land later than
	# the current pivot.
	if summoned_idx > pivot_idx:
		_pending_members[summoned_id] = true
	else:
		_pending_members.erase(summoned_id)

	_queue_dirty = true


func notify_move_executed(ctx: MoveContext) -> void:
	if dbg:
		print("TurnEngineCore.notify_move_executed()")

	if ctx == null:
		return
	if active_group_index < 0:
		return
	if host.get_group_index_of(int(ctx.move_unit_id)) != active_group_index:
		return

	for value in ctx.revoke_turns:
		var revoke_id := int(value)
		_pending_members.erase(revoke_id)
		if _running_actor and revoke_id == current_actor_id:
			_deferred_current_actor_grant = false

	for value in ctx.grant_turns:
		_grant_pending_turn(int(value))

	if bool(ctx.mover_reenters_queue):
		_grant_pending_turn(int(ctx.move_unit_id))

	_queue_dirty = true


func begin_player_end_transition() -> bool:
	if dbg:
		print("TurnEngineCore.begin_player_end_transition()")

	if active_group_index != 0:
		return false
	if !host.is_player(current_actor_id):
		return false
	if !_running_actor:
		return false
	if _waiting_for_player_end:
		push_warning("TurnEngineCore: player_end already pending; ignoring request")
		return false

	_waiting_for_player_end = true
	return true


func complete_player_begin() -> void:
	if dbg:
		print("TurnEngineCore.complete_player_begin()")

	if !_waiting_for_player_begin:
		return

	_waiting_for_player_begin = false
	_pending_arcana_proc = ArcanaProc.PLAYER_TURN_BEGIN


func complete_player_end() -> void:
	if dbg:
		print("TurnEngineCore.complete_player_end()")

	if !_waiting_for_player_end:
		return

	_waiting_for_player_end = false


func complete_arcana() -> void:
	if dbg:
		print("TurnEngineCore.complete_arcana()")

	if !_waiting_for_arcana:
		return

	_waiting_for_arcana = false
	_pending_arcana_proc = -1


func mark_queue_dirty() -> void:
	_queue_dirty = true


func reset_for_new_battle() -> void:
	_start_of_combat_fired = false
	_player_start_of_turn_fired = false

	_waiting_for_arcana = false
	_pending_arcana_proc = -1
	_waiting_for_player_begin = false
	_waiting_for_player_end = false

	_reset()


func _reset() -> void:
	if dbg:
		print("TurnEngineCore._reset()")

	active_group_index = -1
	current_actor_id = 0
	phase = Phase.IDLE

	_queue = PackedInt32Array()
	_turns_taken.clear()
	_restore_allowed.clear()
	_restores_granted.clear()
	_pending_members.clear()
	_queue_dirty = false
	_deferred_current_actor_grant = false

	_running_actor = false


func _rebuild_queue() -> void:
	if dbg:
		print("TurnEngineCore._rebuild_queue()")

	_queue_dirty = false
	_queue = PackedInt32Array()

	var order := _get_current_group_order()

	for value in order:
		var id := int(value)
		if id <= 0:
			continue
		if !_pending_members.has(id):
			continue
		if !host.is_alive(id):
			continue
		if _running_actor and id == current_actor_id:
			continue
		if !_unit_can_take_any_more_turns(id):
			continue

		var taken := int(_turns_taken.get(id, 0))
		if taken <= 0:
			_queue.append(id)
		elif bool(_restore_allowed.get(id, false)):
			_queue.append(id)


func _get_desired_order_ids(group_index: int) -> PackedInt32Array:
	if dbg:
		print("TurnEngineCore._get_desired_order_ids() group=%s" % group_index)

	var out := PackedInt32Array()
	if int(group_index) != int(active_group_index):
		return out

	if _queue_dirty:
		_rebuild_queue()

	return _queue.duplicate()


func build_pending_actor_snapshot() -> TurnPendingSnapshot:
	var snapshot := TurnPendingSnapshot.new()
	if active_group_index < 0:
		return snapshot

	if _queue_dirty:
		_rebuild_queue()

	var active_id := 0
	if _running_actor and current_actor_id > 0:
		active_id = current_actor_id
	elif !_queue.is_empty():
		active_id = int(_queue[0])

	snapshot.active_id = active_id
	snapshot.pending_ids = _queue.duplicate()
	return snapshot


func _mark_turn_taken(combat_id: int) -> void:
	var n := int(_turns_taken.get(combat_id, 0))
	_turns_taken[combat_id] = n + 1

	if bool(_restore_allowed.get(combat_id, false)):
		_restore_allowed.erase(combat_id)


func _turns_left(combat_id: int) -> int:
	if !host.is_alive(combat_id):
		return 0

	var max_turns := MAX_TURNS_PER_FIGHTER_PER_GROUP_TURN
	if host.is_player(combat_id):
		max_turns = MAX_PLAYER_TURNS_PER_GROUP_TURN

	return max_turns - int(_turns_taken.get(combat_id, 0))


func _unit_can_take_any_more_turns(combat_id: int) -> bool:
	return _turns_left(combat_id) > 0


func _seed_pending_members_for_phase() -> void:
	var order := _get_current_group_order()

	_pending_members.clear()

	if order.is_empty():
		return

	# Enemy and friendly turns now both seed one continuous group queue.
	for id_value in order:
		var id := int(id_value)
		if id > 0:
			_pending_members[id] = true

func _grant_pending_turn(combat_id: int) -> void:
	if combat_id <= 0:
		return
	if host.get_group_index_of(combat_id) != active_group_index:
		return
	if !host.is_alive(combat_id):
		return
	if !_unit_can_take_any_more_turns(combat_id):
		return

	if _running_actor and combat_id == current_actor_id:
		_deferred_current_actor_grant = true
		return

	var taken := int(_turns_taken.get(combat_id, 0))
	_pending_members[combat_id] = true
	if taken <= 0:
		return
	if bool(_restore_allowed.get(combat_id, false)):
		return
	if !_can_grant_restore_to(combat_id):
		_pending_members.erase(combat_id)
		return

	_restore_allowed[combat_id] = true
	_restores_granted[combat_id] = int(_restores_granted.get(combat_id, 0)) + 1


func _can_grant_restore_to(combat_id: int) -> bool:
	if combat_id <= 0:
		return false
	if host.is_player(combat_id):
		return false
	if !host.is_alive(combat_id):
		return false
	if !_unit_can_take_any_more_turns(combat_id):
		return false
	if int(_turns_taken.get(combat_id, 0)) <= 0:
		return false
	return int(_restores_granted.get(combat_id, 0)) < MAX_RESTORES_PER_FIGHTER_PER_GROUP_TURN


func _get_current_group_order() -> PackedInt32Array:
	if active_group_index < 0:
		return PackedInt32Array()
	return host.get_group_order_ids(active_group_index)
