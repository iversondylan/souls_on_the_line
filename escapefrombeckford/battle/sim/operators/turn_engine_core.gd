# turn_engine_coree.gd

class_name TurnEngineCore extends RefCounted

# ============================================================================
# TurnEngineCore (SIM only)
# ----------------------------------------------------------------------------
# Responsibilities:
# - own intra-group actor queueing
# - own turn-flow state and handshake state
# - answer "what needs to happen next?" via TurnFlowDirective
# - provide pending-actor snapshots for runtime-owned publication
#
# Relationship to SimRuntime:
# - SimRuntime is the flow owner and side-effect owner.
# - TurnEngineCore never runs gameplay, writes log events, or opens scopes.
# - SimRuntime mutates the outside world, then calls back into this object to
#   record that the requested step has completed.
#
# The normal handshake looks like this:
# 1) SimRuntime calls begin_group_turn_flow(...).
# 2) SimRuntime tells TurnEngineCore to begin_group_turn_state(...).
# 3) SimRuntime repeatedly calls advance().
# 4) advance() returns a TurnFlowDirective describing the next required step.
# 5) SimRuntime performs that step:
#    - player begin bookkeeping
#    - arcana proc execution
#    - actor turn execution
#    - group-end lifecycle work
# 6) SimRuntime calls the matching completion method here:
#    - complete_player_begin()
#    - complete_arcana()
#    - complete_actor()
#    - complete_player_end()
# 7) SimRuntime calls advance() again until the flow blocks or goes idle.
#
# Friendly phase semantics in THIS FILE:
# - POST-Player Friendlies:
#		player, then friendlies behind player
# - PRE-Player Friendlies:
#		friendlies in front of player
#
# Compatibility note:
# - The existing external flag name `pre_player_friendly` is preserved so other
#	scripts do not break.
# - But semantically:
#		pre_player_friendly == false -> POST-Player Friendlies
#		pre_player_friendly == true	-> PRE-Player Friendlies
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
	START_OF_COMBAT,
	START_OF_TURN,
	END_OF_TURN,
}


# -------------------------
# Constants
# -------------------------

const MAX_TURNS_PER_FIGHTER_PER_GROUP_TURN := 3


# -------------------------
# External host
# -------------------------

# Query-only host used to inspect BattleState-derived facts such as order,
# liveness, and player identity. This object is intentionally not a flow owner.
var host: TurnFlowQueryHost


# -------------------------
# Runtime state
# -------------------------

var active_group_index: int = -1
var current_actor_id: int = 0
var _running_actor: bool = false
var _turn_token: int = 0
var phase: int = Phase.IDLE

var _queue: PackedInt32Array = PackedInt32Array()
var _turns_taken: Dictionary = {}		# int combat_id -> int
var _restore_allowed: Dictionary = {}	# int combat_id -> bool
var _queue_dirty: bool = false

var _start_at_player: bool = false
var _player_id: int = 0
var _cursor_cid: int = 0

var _player_start_of_turn_fired: bool = false
var _start_of_combat_fired: bool = false

# Compatibility name retained.
# Semantic translation:
#	false -> POST-Player Friendlies
#	true	-> PRE-Player Friendlies
var _pre_player_friendly: bool = false

# Used externally by scheduling code after a friendly group turn ends.
# Meaning:
#	true  -> the just-finished friendly phase was PRE-Player Friendlies
#	false -> otherwise
var ended_pre_player_friendly: bool = false


# -------------------------
# Player handshake state
# -------------------------

var _waiting_for_player_begin: bool = false
var _waiting_for_player_end: bool = false


# -------------------------
# Arcana handshake state
# -------------------------

var _waiting_for_arcana: bool = false
var _pending_arcana_proc: int = -1


# -------------------------
# Debug
# -------------------------

var dbg := false


# ============================================================================
# Init
# ============================================================================

# Inject the query host used by queue-building and actor classification.
func _init(_host: TurnFlowQueryHost) -> void:
	host = _host

# Clone turn-state into a new query host. Preview uses this to resume from the
# main runtime's flow position without inheriting live wait-state handshakes.
func clone_for_host(new_host: TurnFlowQueryHost) -> TurnEngineCore:
	var c := TurnEngineCore.new(new_host)

	c.active_group_index = active_group_index
	c.current_actor_id = current_actor_id
	c._running_actor = _running_actor
	c._turn_token = _turn_token
	c.phase = phase

	c._queue = _queue.duplicate()
	c._turns_taken = _turns_taken.duplicate(true)
	c._restore_allowed = _restore_allowed.duplicate(true)
	c._queue_dirty = _queue_dirty

	c._start_at_player = _start_at_player
	c._player_id = _player_id
	c._cursor_cid = _cursor_cid

	c._player_start_of_turn_fired = _player_start_of_turn_fired
	c._start_of_combat_fired = _start_of_combat_fired
	c._pre_player_friendly = _pre_player_friendly
	c.ended_pre_player_friendly = ended_pre_player_friendly

	# Preview snapshots resume from a stable execution point and should not inherit
	# pending handshakes from the source runtime.
	c._waiting_for_player_begin = false
	c._waiting_for_player_end = false
	c._waiting_for_arcana = false
	c._pending_arcana_proc = -1

	c.dbg = dbg

	return c


# ============================================================================
# Public API
# ============================================================================

# Reset this state machine for a new group-turn phase.
# SimRuntime calls this exactly once at the start of a group flow before it
# performs group-start lifecycle work and begins polling advance().
func begin_group_turn_state(group_index: int, start_at_player := false, pre_player_friendly := false) -> void:
	if dbg:
		print(
			"TurnEngineCore.begin_group_turn_state() group=%s start_at_player=%s pre_player_friendlies=%s"
			% [group_index, start_at_player, pre_player_friendly]
		)

	active_group_index = int(group_index)
	_start_at_player = bool(start_at_player)
	_pre_player_friendly = bool(pre_player_friendly)
	ended_pre_player_friendly = false

	_turn_token += 1

	phase = Phase.IDLE
	current_actor_id = 0
	_running_actor = false

	_queue = PackedInt32Array()
	_turns_taken.clear()
	_restore_allowed.clear()
	_queue_dirty = true
	_cursor_cid = 0

	if active_group_index == 0:
		_player_id = host.get_player_id()
		_player_start_of_turn_fired = false

		# Only once per battle, and only when explicitly starting at player.
		if _start_at_player and !_start_of_combat_fired:
			_start_of_combat_fired = true
			_pending_arcana_proc = ArcanaProc.START_OF_COMBAT


# Return the next required step in the turn flow, without performing side
# effects. SimRuntime owns the loop that repeatedly calls this method.
#
# `BLOCKED` means runtime is waiting for an external completion signal such as:
# - player input / end-turn confirmation
# - arcana completion
# - actor completion
#
# `IDLE` means no active group flow exists.
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

	if _queue.is_empty():
		var ended_group := active_group_index
		if ended_group == 0:
			ended_pre_player_friendly = _is_pre_player_friendlies()
		else:
			ended_pre_player_friendly = false
		_reset()
		return TurnFlowDirective.group_turn_ended(ended_group)

	var actor_id := int(_queue[0])
	if !host.is_alive(actor_id):
		_queue.remove_at(0)
		_queue_dirty = true
		return advance()

	if active_group_index == 0 and host.is_player(actor_id):
		if !_player_start_of_turn_fired:
			_player_start_of_turn_fired = true
			_waiting_for_player_begin = true
			return TurnFlowDirective.request_player_begin()

	current_actor_id = actor_id
	_running_actor = true
	_cursor_cid = actor_id
	phase = Phase.ACTOR_START
	return TurnFlowDirective.request_actor(actor_id)


# Mark the current actor as fully resolved. SimRuntime calls this only after it
# has already handled actor-end bookkeeping, scope closure, and any side effects
# caused by the actor's action.
func complete_actor(combat_id: int) -> void:
	if dbg:
		print("TurnEngineCore.complete_actor() cid=%s current=%s" % [combat_id, current_actor_id])

	if int(combat_id) != current_actor_id:
		return

	_running_actor = false
	_mark_turn_taken(int(combat_id))
	_restore_allowed.erase(int(combat_id))
	_queue_dirty = true
	phase = Phase.IDLE


# Notify the state machine that an actor disappeared from battle state. This is
# a structural update only; SimRuntime remains responsible for any resulting
# flow advancement and status publication.
func notify_actor_removed(combat_id: int) -> void:
	if dbg:
		print("TurnEngineCore.notify_actor_removed() cid=%s current=%s" % [combat_id, current_actor_id])

	if int(combat_id) == current_actor_id:
		phase = Phase.IDLE
		_queue_dirty = true
	else:
		_queue_dirty = true


# Notify the state machine that a new combatant joined the active group so the
# next queue rebuild includes them when appropriate.
func notify_summon_added(combat_id: int, group_index: int) -> void:
	if dbg:
		print("TurnEngineCore.notify_summon_added() cid=%s group=%s" % [combat_id, group_index])

	if int(group_index) != active_group_index:
		return

	_queue_dirty = true


# Feed a completed move back into turn accounting. Some moves can grant a
# restored turn when a unit crosses behind the active anchor; this method only
# computes that allowance and marks the queue dirty.
func notify_move_executed(ctx) -> void:
	if dbg:
		print("TurnEngineCore.notify_move_executed()")

	if ctx == null or !ctx.can_restore_turn:
		return
	if active_group_index < 0:
		return
	if current_actor_id <= 0:
		return

	# Only consider moves that affect the active group.
	if host.get_group_index_of(current_actor_id) != active_group_index:
		return

	if ctx.before_order_ids.is_empty() or ctx.after_order_ids.is_empty():
		return

	var anchor_id := current_actor_id
	var before_anchor: int = ctx.before_order_ids.find(anchor_id)
	var after_anchor: int = ctx.after_order_ids.find(anchor_id)

	if before_anchor == -1 or after_anchor == -1:
		return

	var granted := false

	if _crossed_behind(int(ctx.actor_id), ctx, before_anchor, after_anchor):
		_restore_allowed[int(ctx.actor_id)] = true
		granted = true

	if _crossed_behind(int(ctx.target_id), ctx, before_anchor, after_anchor):
		_restore_allowed[int(ctx.target_id)] = true
		granted = true

	if granted:
		_queue_dirty = true


# Begin the player's end-turn handshake. SimRuntime calls this after the UI has
# requested end turn and the discard animation / hand cleanup is ready to let
# flow continue.
func begin_player_end_transition() -> bool:
	if dbg:
		print("TurnEngineCore.begin_player_end_transition()")

	# Safety: only valid during the player's actor turn.
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


# Complete the player-begin boundary. SimRuntime calls this after running
# player-turn-start sim bookkeeping, which unlocks the START_OF_TURN arcana step.
func complete_player_begin() -> void:
	if dbg:
		print("TurnEngineCore.complete_player_begin()")

	if !_waiting_for_player_begin:
		return

	_waiting_for_player_begin = false
	_pending_arcana_proc = ArcanaProc.START_OF_TURN


# Complete the player-end boundary after SimRuntime has already serviced
# end-of-turn arcana and any other player-end lifecycle work.
func complete_player_end() -> void:
	if dbg:
		print("TurnEngineCore.complete_player_end()")

	if !_waiting_for_player_end:
		return

	_waiting_for_player_end = false


# Complete whichever arcana proc was requested by advance(). SimRuntime calls
# this after run_arcana_proc(proc) finishes.
func complete_arcana() -> void:
	if dbg:
		print("TurnEngineCore.complete_arcana()")

	if !_waiting_for_arcana:
		return

	_waiting_for_arcana = false
	_pending_arcana_proc = -1


# Tell the state machine that turn order may have changed. SimRuntime uses this
# after checkpoint flushing and other structural mutations so the next advance()
# or pending snapshot rebuilds queue truth from current battle state.
func mark_queue_dirty() -> void:
	_queue_dirty = true


# Reset one-battle-only handshake state. SimRuntime uses this when a live flow
# is being started from the initial battle entrypoint.
func reset_for_new_battle() -> void:
	_start_of_combat_fired = false
	_player_start_of_turn_fired = false

	_waiting_for_arcana = false
	_pending_arcana_proc = -1

	_waiting_for_player_begin = false
	_waiting_for_player_end = false

	_reset()


# Internal hard reset for "no active group flow".
func _reset() -> void:
	if dbg:
		print("TurnEngineCore._reset()")

	active_group_index = -1
	current_actor_id = 0
	phase = Phase.IDLE

	_queue = PackedInt32Array()
	_turns_taken.clear()
	_restore_allowed.clear()
	_queue_dirty = false

	_cursor_cid = 0
	_running_actor = false


# ============================================================================
# Queue construction
# ============================================================================

# Rebuild the current in-group execution queue from BattleState-derived order
# plus this object's local turn-accounting rules.
func _rebuild_queue() -> void:
	if dbg:
		print("TurnEngineCore._rebuild_queue()")

	_queue_dirty = false
	_queue = PackedInt32Array()

	var desired := _get_desired_order_ids(active_group_index)

	# Normal pass.
	for cid in desired:
		var id := int(cid)

		if !host.is_alive(id):
			continue
		if _turns_left(id) <= 0:
			continue

		var taken := int(_turns_taken.get(id, 0))

		if taken == 0:
			_queue.append(id)
		else:
			if active_group_index == 0 and host.is_player(id):
				continue
			if bool(_restore_allowed.get(id, false)):
				_queue.append(id)
				_restore_allowed.erase(id)

	# Restore pass for any remaining granted restores.
	for k in _restore_allowed.keys():
		var id := int(k)

		if !host.is_alive(id):
			continue
		if host.get_group_index_of(id) != active_group_index:
			continue
		if active_group_index == 0 and host.is_player(id):
			continue
		if _turns_left(id) <= 0:
			continue
		if !_queue.has(id):
			_queue.append(id)


# Produce the semantic order for the active phase before turn limits and restore
# allowances are applied:
# - friendlies are partitioned around the player
# - enemies continue forward from the current cursor for stable progression
func _get_desired_order_ids(group_index: int) -> PackedInt32Array:
	if dbg:
		print("TurnEngineCore._get_desired_order_ids() group=%s" % group_index)

	var order := host.get_group_order_ids(group_index)
	if order.is_empty():
		return PackedInt32Array()

	# Friendly phases are partitioned around the player.
	if group_index == 0:
		var p := _player_id
		if p == 0:
			p = host.get_player_id()
			_player_id = p

		var player_idx := order.find(p)
		if player_idx == -1:
			return PackedInt32Array()

		var out := PackedInt32Array()

		if _is_post_player_friendlies():
			# POST-Player Friendlies:
			# player, then everyone behind the player
			out.append(p)
			for i in range(player_idx + 1, order.size()):
				out.append(order[i])
			return out

		# PRE-Player Friendlies:
		# everyone in front of the player
		for i in range(0, player_idx):
			out.append(order[i])
		return out

	# Enemy phase:
	# walk forward from the cursor so re-entry after completed actions/moves
	# remains stable.
	var start_idx := 0
	if _cursor_cid != 0:
		var idx := order.find(_cursor_cid)
		if idx != -1:
			start_idx = idx + 1

	var out := PackedInt32Array()
	for i in range(start_idx, order.size()):
		out.append(order[i])

	return out


# Build the snapshot used by SimRuntime for TURN_STATUS publication. This method
# is intentionally pure from the runtime's point of view: it only reads local
# flow state plus BattleState queries and returns the active actor + pending ids.
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

	var pending := PackedInt32Array()

	if active_id == 0:
		pending = _queue.duplicate()
	else:
		var desired := _get_desired_order_ids(active_group_index)
		var idx := desired.find(active_id)
		var start_i := idx + 1 if idx != -1 else 0

		for i in range(start_i, desired.size()):
			var id := int(desired[i])

			if !host.is_alive(id):
				continue
			if _turns_left(id) <= 0:
				continue

			var taken := int(_turns_taken.get(id, 0))
			if taken == 0:
				pending.append(id)
			else:
				if active_group_index == 0 and host.is_player(id):
					continue
				if bool(_restore_allowed.get(id, false)):
					pending.append(id)

	if active_group_index == 0 and _is_pre_player_friendlies():
		var player_id := _player_id
		if player_id == 0:
			player_id = host.get_player_id()
			_player_id = player_id

		if player_id > 0:
			var friendly_order := host.get_group_order_ids(0)
			var player_idx := friendly_order.find(player_id)

			# During PRE-player friendlies, the pending view should also include
			# the player and friendlies behind the player.
			if player_idx != -1:
				for i in range(player_idx, friendly_order.size()):
					var id := int(friendly_order[i])
					if id == active_id:
						continue
					if !host.is_alive(id):
						continue
					if _turns_left(id) <= 0:
						continue
					if !pending.has(id):
						pending.append(id)

	snapshot.active_id = active_id
	snapshot.pending_ids = pending
	return snapshot


# ============================================================================
# Turn accounting
# ============================================================================

# Record that an actor has spent one of its allowed turns in the current group
# phase. Player turns are capped differently from NPC/friendly extra turns.
func _mark_turn_taken(combat_id: int) -> void:
	var n := int(_turns_taken.get(combat_id, 0))
	_turns_taken[combat_id] = n + 1


# Return how many executions this actor still has available in the current group
# phase, after considering special player rules and restore-turn grants.
func _turns_left(combat_id: int) -> int:
	if !host.is_alive(combat_id):
		return 0

	if active_group_index == 0 and host.is_player(combat_id):
		return 1 - int(_turns_taken.get(combat_id, 0))

	return MAX_TURNS_PER_FIGHTER_PER_GROUP_TURN - int(_turns_taken.get(combat_id, 0))


# ============================================================================
# Restore-turn move support
# ============================================================================

# Return true when a moved unit crossed from at-or-before the active anchor to
# behind it, which is the condition used to grant a restored turn.
func _crossed_behind(cid: int, ctx, before_anchor: int, after_anchor: int) -> bool:
	if cid <= 0:
		return false

	var b: int = ctx.before_order_ids.find(cid)
	var a: int = ctx.after_order_ids.find(cid)

	if b == -1 or a == -1:
		return false

	return (b <= before_anchor) and (a > after_anchor)


# ============================================================================
# Semantic helpers
# ============================================================================

# Compatibility wrapper around the old external flag naming.
func _is_pre_player_friendlies() -> bool:
	# Compatibility mapping:
	# old name "pre_player_friendly" now semantically means PRE-Player Friendlies
	return _pre_player_friendly


# Convenience opposite of `_is_pre_player_friendlies()`.
func _is_post_player_friendlies() -> bool:
	return !_pre_player_friendly
