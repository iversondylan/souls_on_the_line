# turn_engine_coree.gd

class_name TurnEngineCore extends RefCounted

# ============================================================================
# TurnEngineCore (SIM only)
# ----------------------------------------------------------------------------
# Responsibilities:
# - own intra-group actor queueing
# - request player begin / player end handshakes
# - request arcana timing hooks
# - emit actor_requested / group_turn_ended / pending_view_changed
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
# Signals
# -------------------------

signal actor_requested(combat_id: int)
signal group_turn_ended(group_index: int)
signal arcana_proc_requested(proc: int, token: int)
signal pending_view_changed(active_id: int, pending_ids: PackedInt32Array)

signal player_begin_requested(token: int)
signal player_end_requested(token: int)


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

var host: TurnEngineHostSim


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
var _player_token: int = 0

var _resume_after_player_begin: Callable = Callable()
var _resume_after_player_end: Callable = Callable()


# -------------------------
# Arcana handshake state
# -------------------------

var _waiting_for_arcana: bool = false
var _arcana_token: int = 0
var _resume_after_arcana: Callable = Callable()


# -------------------------
# Debug
# -------------------------

var dbg := false


# ============================================================================
# Init
# ============================================================================

func _init(_host: TurnEngineHostSim) -> void:
	host = _host


# ============================================================================
# Public API
# ============================================================================

func start_group_turn(group_index: int, start_at_player := false, pre_player_friendly := false) -> void:
	if dbg:
		print(
			"TurnEngineCore.start_group_turn() group=%s start_at_player=%s pre_player_friendlies=%s"
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
			_request_arcana(ArcanaProc.START_OF_COMBAT, func():
				_advance_to_next_actor()
			)
			return

	_advance_to_next_actor()


func notify_actor_done(combat_id: int) -> void:
	if dbg:
		print("TurnEngineCore.notify_actor_done() cid=%s current=%s" % [combat_id, current_actor_id])

	if int(combat_id) != current_actor_id:
		return

	_running_actor = false
	_mark_turn_taken(int(combat_id))
	_restore_allowed.erase(int(combat_id))
	_queue_dirty = true
	phase = Phase.IDLE
	_advance_to_next_actor()


func notify_actor_removed(combat_id: int) -> void:
	if dbg:
		print("TurnEngineCore.notify_actor_removed() cid=%s current=%s" % [combat_id, current_actor_id])

	if int(combat_id) == current_actor_id:
		current_actor_id = 0
		phase = Phase.IDLE
		_queue_dirty = true
		if !_running_actor:
			_advance_to_next_actor()
	else:
		_queue_dirty = true


func notify_summon_added(combat_id: int, group_index: int) -> void:
	if dbg:
		print("TurnEngineCore.notify_summon_added() cid=%s group=%s" % [combat_id, group_index])

	if int(group_index) != active_group_index:
		return

	_queue_dirty = true
	_publish_pending_view()


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

	_publish_pending_view()


func request_player_end() -> void:
	if dbg:
		print("TurnEngineCore.request_player_end()")

	# Safety: only valid during the player's actor turn.
	if active_group_index != 0:
		return
	if !host.is_player(current_actor_id):
		return

	_request_player_end(func():
		pass
	)


func notify_player_begin_done(token: int) -> void:
	if dbg:
		print("TurnEngineCore.notify_player_begin_done() token=%s" % token)

	if !_waiting_for_player_begin:
		return
	if int(token) != _player_token:
		return

	_waiting_for_player_begin = false

	var resume := _resume_after_player_begin
	_resume_after_player_begin = Callable()

	if !resume.is_null():
		resume.call()


func notify_player_end_done(token: int) -> void:
	if dbg:
		print("TurnEngineCore.notify_player_end_done() token=%s" % token)

	if !_waiting_for_player_end:
		return
	if int(token) != _player_token:
		return

	_waiting_for_player_end = false

	var resume := _resume_after_player_end
	_resume_after_player_end = Callable()

	if !resume.is_null():
		resume.call()


func notify_arcana_proc_done(token: int) -> void:
	if dbg:
		print("TurnEngineCore.notify_arcana_proc_done() token=%s" % token)

	if !_waiting_for_arcana:
		return
	if int(token) != _arcana_token:
		return

	_waiting_for_arcana = false
	_arcana_token = 0

	var resume := _resume_after_arcana
	_resume_after_arcana = Callable()

	if !resume.is_null():
		resume.call()

func request_queue_rebuild_and_publish() -> void:
	_queue_dirty = true

	# If we're idle, eagerly rebuild so pending view reflects latest truth.
	if !_running_actor:
		_rebuild_queue()

	_publish_pending_view()

func request_end_of_turn_arcana(resume: Callable) -> void:
	_request_arcana(ArcanaProc.END_OF_TURN, resume)


func reset_for_new_battle() -> void:
	_start_of_combat_fired = false
	_player_start_of_turn_fired = false

	_waiting_for_arcana = false
	_arcana_token = 0
	_resume_after_arcana = Callable()

	_waiting_for_player_begin = false
	_waiting_for_player_end = false
	_player_token = 0
	_resume_after_player_begin = Callable()
	_resume_after_player_end = Callable()

	_reset()


# ============================================================================
# Core progression
# ============================================================================

func _advance_to_next_actor() -> void:
	if dbg:
		print("TurnEngineCore._advance_to_next_actor()")

	if _running_actor:
		return

	if active_group_index < 0:
		_reset()
		return

	if _queue_dirty:
		_rebuild_queue()

	if _queue.is_empty():
		_end_group_turn()
		return

	var actor_id := int(_queue[0])

	if !host.is_alive(actor_id):
		_queue.remove_at(0)
		_queue_dirty = true
		_advance_to_next_actor()
		return

	# Player special case:
	# On POST-Player Friendly phase, first hit player_begin, then START_OF_TURN arcana,
	# then continue into actor request.
	if active_group_index == 0 and host.is_player(actor_id):
		if !_player_start_of_turn_fired:
			_player_start_of_turn_fired = true
			_request_player_begin(func():
				_request_arcana(ArcanaProc.START_OF_TURN, func():
					_advance_to_next_actor()
				)
			)
			return

	current_actor_id = actor_id
	_running_actor = true
	_cursor_cid = actor_id
	phase = Phase.ACTOR_START

	_publish_pending_view()
	actor_requested.emit(actor_id)


func _end_group_turn() -> void:
	var ended_group := active_group_index

	if ended_group == 0:
		ended_pre_player_friendly = _is_pre_player_friendlies()
	else:
		ended_pre_player_friendly = false

	_reset()
	group_turn_ended.emit(ended_group)


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


func _publish_pending_view() -> void:
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

	pending_view_changed.emit(active_id, pending)


# ============================================================================
# Turn accounting
# ============================================================================

func _mark_turn_taken(combat_id: int) -> void:
	var n := int(_turns_taken.get(combat_id, 0))
	_turns_taken[combat_id] = n + 1


func _turns_left(combat_id: int) -> int:
	if !host.is_alive(combat_id):
		return 0

	if active_group_index == 0 and host.is_player(combat_id):
		return 1 - int(_turns_taken.get(combat_id, 0))

	return MAX_TURNS_PER_FIGHTER_PER_GROUP_TURN - int(_turns_taken.get(combat_id, 0))


# ============================================================================
# Restore-turn move support
# ============================================================================

func _crossed_behind(cid: int, ctx, before_anchor: int, after_anchor: int) -> bool:
	if cid <= 0:
		return false

	var b: int = ctx.before_order_ids.find(cid)
	var a: int = ctx.after_order_ids.find(cid)

	if b == -1 or a == -1:
		return false

	return (b <= before_anchor) and (a > after_anchor)


# ============================================================================
# Handshake requests
# ============================================================================

func _request_player_begin(resume: Callable) -> void:
	if dbg:
		print("TurnEngineCore._request_player_begin()")

	if _waiting_for_player_begin:
		return

	_waiting_for_player_begin = true
	_player_token += 1
	_resume_after_player_begin = resume
	player_begin_requested.emit(_player_token)


func _request_player_end(resume: Callable) -> void:
	if dbg:
		print("TurnEngineCore._request_player_end()")

	if _waiting_for_player_end:
		push_warning("TurnEngineCore: player_end already pending; ignoring request")
		return

	_waiting_for_player_end = true
	_player_token += 1
	_resume_after_player_end = resume
	player_end_requested.emit(_player_token)


func _request_arcana(proc: int, resume: Callable) -> void:
	if dbg:
		print("TurnEngineCore._request_arcana() proc=%s" % ArcanaProc.keys()[proc])

	if _waiting_for_arcana:
		push_error("TurnEngineCore: arcana request while another arcana request is pending")
		return

	_waiting_for_arcana = true
	_arcana_token += 1
	_resume_after_arcana = resume
	arcana_proc_requested.emit(proc, _arcana_token)


# ============================================================================
# Semantic helpers
# ============================================================================

func _is_pre_player_friendlies() -> bool:
	# Compatibility mapping:
	# old name "pre_player_friendly" now semantically means PRE-Player Friendlies
	return _pre_player_friendly


func _is_post_player_friendlies() -> bool:
	return !_pre_player_friendly


# ============================================================================
# Legacy utility kept for compatibility
# ============================================================================

func _call_hook(h: Callable) -> Signal:
	if h.is_null():
		return Signal()

	var r = h.call()
	if r is Signal and !(r as Signal).is_null():
		return r

	return Signal()
