# turn_engine_core.gd

class_name TurnEngineCore extends RefCounted

signal actor_requested(combat_id: int)
signal group_turn_ended(group_index: int)
signal arcana_proc_requested(proc: int, token: int)
signal pending_view_changed(active_id: int, pending_ids: PackedInt32Array)

signal player_begin_requested(token: int)
signal player_end_requested(token: int)

var _waiting_for_player_begin: bool = false
var _waiting_for_player_end: bool = false
var _player_token: int = 0

var _resume_after_player_begin: Callable = Callable()
var _resume_after_player_end: Callable = Callable()

enum Phase { IDLE, ACTOR_START, WAITING_FOR_ACTION, ACTOR_END }
enum ArcanaProc { START_OF_COMBAT, START_OF_TURN, END_OF_TURN }

var _waiting_for_arcana: bool = false
var _arcana_token: int = 0
var _resume_after_arcana: Callable = Callable()

const MAX_TURNS_PER_FIGHTER_PER_GROUP_TURN := 3

var host: TurnEngineHost

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

var dbg := false

func _init(_host: TurnEngineHost) -> void:
	host = _host

func start_group_turn(group_index: int, start_at_player := false) -> void:
	if dbg: print("turn_engine_core.gd start_group_turn() group index: %s, " % [group_index])
	active_group_index = group_index
	_start_at_player = start_at_player
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

		# Only once per fight
		if _start_at_player and !_start_of_combat_fired:
			_start_of_combat_fired = true
			_request_arcana(ArcanaProc.START_OF_COMBAT, func():
				_advance_to_next_actor()
			)
			return

	_advance_to_next_actor()

func notify_actor_done(combat_id: int) -> void:
	if dbg: print("turn_engine_core.gd notify_actor_done() cid: %s" % [combat_id])
	if combat_id != current_actor_id:
		return

	_running_actor = false
	_mark_turn_taken(combat_id)
	_restore_allowed.erase(combat_id)
	_queue_dirty = true
	phase = Phase.IDLE
	_advance_to_next_actor()

func notify_actor_removed(combat_id: int) -> void:
	#print("TE notify_actor_removed cid=", combat_id, " current=", current_actor_id, " running=", _running_actor)
	if dbg: print("turn_engine_core.gd notify_actor_removed() cid: %s" % [combat_id])
	if combat_id == current_actor_id:
		current_actor_id = 0
		phase = Phase.IDLE
		_queue_dirty = true
		if !_running_actor:
			_advance_to_next_actor()
	else:
		_queue_dirty = true

func notify_summon_added(combat_id: int, group_index: int) -> void:
	if dbg: print("turn_engine_core.gd notify_summon_added() cid: group_idx: %s" % [combat_id, group_index])
	if group_index != active_group_index:
		return
	_queue_dirty = true
	_publish_pending_view()

func notify_move_executed(ctx) -> void:
	if dbg: print("turn_engine_core.gd notify_move_executed()")
	# ctx should be "data only": actor_id, target_id, can_restore_turn, before_order_ids, after_order_ids
	if ctx == null or !ctx.can_restore_turn:
		return
	if active_group_index < 0:
		return
	if current_actor_id <= 0:
		return

	# Only consider if the move affects the active group
	if host.get_group_index_of(current_actor_id) != active_group_index:
		return

	if ctx.before_order_ids.is_empty() or ctx.after_order_ids.is_empty():
		return

	var anchor_id := current_actor_id
	var before_anchor : int = ctx.before_order_ids.find(anchor_id)
	var after_anchor : int = ctx.after_order_ids.find(anchor_id)
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

func _crossed_behind(cid: int, ctx, before_anchor: int, after_anchor: int) -> bool:
	if dbg: print("turn_engine_core.gd _crossed_behind(")
	if cid <= 0:
		return false
	var b : int = ctx.before_order_ids.find(cid)
	var a : int = ctx.after_order_ids.find(cid)
	if b == -1 or a == -1:
		return false
	return (b <= before_anchor) and (a > after_anchor)

func _advance_to_next_actor() -> void:
	if dbg: print("turn_engine_core.gd _advance_to_next_actor()")
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

	# PLAYER SPECIAL CASE
	if active_group_index == 0 and host.is_player(actor_id):
		if !_player_start_of_turn_fired:
			_player_start_of_turn_fired = true
			_request_player_begin(func():
				_request_arcana(ArcanaProc.START_OF_TURN, func():
					_advance_to_next_actor()
				))
			return

		# If already fired, fall through and request actor like normal.

	current_actor_id = actor_id
	_running_actor = true
	_cursor_cid = actor_id
	_publish_pending_view()
	actor_requested.emit(actor_id)

func _request_player_begin(resume: Callable) -> void:
	if dbg: print("turn_engine_core.gd _request_player_begin()")
	if _waiting_for_player_begin:
		return
	_waiting_for_player_begin = true
	_player_token += 1
	_resume_after_player_begin = resume
	player_begin_requested.emit(_player_token)

func notify_player_begin_done(token: int) -> void:
	if dbg: print("turn_engine_core.gd notify_player_begin_done()")
	if !_waiting_for_player_begin:
		return
	if token != _player_token:
		return
	_waiting_for_player_begin = false
	var resume := _resume_after_player_begin
	_resume_after_player_begin = Callable()
	if !resume.is_null():
		resume.call()

func _request_player_end(resume: Callable) -> void:
	if dbg: print("turn_engine_core.gd _request_player_end()")

	# If you want to be strict, warn instead of silently returning.
	if _waiting_for_player_end:
		push_warning("TurnEngineCore: player_end already pending; ignoring request")
		return

	_waiting_for_player_end = true
	_player_token += 1
	_resume_after_player_end = resume
	player_end_requested.emit(_player_token)

func request_player_end() -> void:
	if dbg: print("turn_engine_core.gd request_player_end()")
	# Only valid if the current actor is the player (safety)
	if active_group_index != 0:
		return
	if !host.is_player(current_actor_id):
		return

	_request_player_end(func():
		# After Battle finishes end_player_turn_async and calls notify_player_end_done(token),
		# the engine's resume will run (whatever you set there).
		pass
	)

func notify_player_end_done(token: int) -> void:
	if dbg: print("turn_engine_core.gd notify_player_end_done()")

	if !_waiting_for_player_end:
		return
	if token != _player_token:
		return

	_waiting_for_player_end = false
	var resume := _resume_after_player_end
	_resume_after_player_end = Callable()
	if !resume.is_null():
		resume.call()

func _reset() -> void:
	if dbg: print("turn_engine_core.gd _reset()")
	active_group_index = -1
	current_actor_id = 0
	phase = Phase.IDLE
	_queue = PackedInt32Array()
	_turns_taken.clear()
	_restore_allowed.clear()
	_queue_dirty = false
	_cursor_cid = 0

func _end_group_turn() -> void:
	if dbg: print("turn_engine_core.gd _end_group_turn()")
	var idx := active_group_index
	_reset()
	group_turn_ended.emit(idx)

func _mark_turn_taken(combat_id: int) -> void:
	if dbg: print("turn_engine_core.gd _mark_turn_taken()")
	var n := int(_turns_taken.get(combat_id, 0))
	_turns_taken[combat_id] = n + 1

func _turns_left(combat_id: int) -> int:
	#print("turn_engine_core.gd _turns_left()")
	if !host.is_alive(combat_id):
		return 0
	if active_group_index == 0 and host.is_player(combat_id):
		return 1 - int(_turns_taken.get(combat_id, 0))
	return MAX_TURNS_PER_FIGHTER_PER_GROUP_TURN - int(_turns_taken.get(combat_id, 0))

func _call_hook(h: Callable) -> Signal:
	if h.is_null():
		return Signal()
	var r = h.call()
	if r is Signal and !(r as Signal).is_null():
		return r
	# If you ever return a GDScriptFunctionState in 4.6, you can keep your class-name check here too.
	return Signal()

func _rebuild_queue() -> void:
	if dbg: print("turn_engine_core.gd _rebuild_queue()")
	_queue_dirty = false
	_queue = PackedInt32Array()

	var desired := _get_desired_order_ids(active_group_index)

	# Normal pass
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

	# Restore pass (no lookups needed; ids already known)
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
	if dbg: print("turn_engine_core.gd _get_desired_order_ids()")
	var order := host.get_group_order_ids(group_index)
	#print("TE _get_desired_order_ids group=", group_index, " raw_order=", order, " cursor=", _cursor_cid, " player_id=", _player_id)

	if order.is_empty():
		return PackedInt32Array()

	# Friendly: player + everyone behind
	if group_index == 0:
		var p := _player_id
		if p == 0:
			p = host.get_player_id()
			_player_id = p

		var player_idx := order.find(p)
		if player_idx == -1:
			return PackedInt32Array()

		var out := PackedInt32Array()

		if _start_at_player:
			# Player + everyone behind
			out.append(p)
			for i in range(player_idx + 1, order.size()):
				out.append(order[i])
		else:
			for i in range(0, order.size()):
				out.append(order[i])

		return out

	# Enemy: optionally cursor-based (ID-based)
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
	#print("turn_engine_core.gd _publish_pending_view")
	var active_id := 0
	if _running_actor and current_actor_id > 0:
		active_id = current_actor_id
	elif !_queue.is_empty():
		active_id = int(_queue[0])

	var pending := PackedInt32Array()

	if active_id == 0:
		# best effort: show queue
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
	#print("turn_engine_core.gd _publish_pending_view about to emit pending_view_changed")
	pending_view_changed.emit(active_id, pending)

func notify_arcana_proc_done(token: int) -> void:
	if dbg: print("turn_engine_core.gd notify_arcana_proc_done()")
	if !_waiting_for_arcana:
		return
	if token != _arcana_token:
		return
	_waiting_for_arcana = false
	_arcana_token = 0
	var resume := _resume_after_arcana
	_resume_after_arcana = Callable()
	if !resume.is_null():
		resume.call()

func _request_arcana(proc: int, resume: Callable) -> void:
	if dbg: print("turn_engine_core.gd _request_arcana(), proc: %s" % [ArcanaProc.keys()[proc]])
	if _waiting_for_arcana:
		push_error("_request_arcana _waiting_for_arcana")
		return # or push/queue, but "return" is fine while you debug
	_waiting_for_arcana = true
	_arcana_token += 1
	_resume_after_arcana = resume
	arcana_proc_requested.emit(proc, _arcana_token)

func request_end_of_turn_arcana(resume: Callable) -> void:
	_request_arcana(ArcanaProc.END_OF_TURN, resume)

func reset_for_new_battle() -> void:
	_start_of_combat_fired = false
	_player_start_of_turn_fired = false
	_waiting_for_arcana = false
	_arcana_token = 0
	_resume_after_arcana = Callable()
	_reset()

#func allow_restore_turn(combat_id: int) -> void:
	#_restore_allowed[combat_id] = true
	#_queue_dirty = true
	#_publish_pending_view()
