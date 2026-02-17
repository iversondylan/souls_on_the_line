# turn_engine_core.gd
class_name TurnEngineCore
extends RefCounted

signal actor_requested(combat_id: int)
signal group_turn_ended(group_index: int)
signal pending_view_changed(active_id: int, pending_ids: PackedInt32Array)

enum Phase { IDLE, ACTOR_START, WAITING_FOR_ACTION, ACTOR_END }

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

func _init(_host: TurnEngineHost) -> void:
	host = _host

func start_group_turn(group_index: int, start_at_player := false) -> void:
	#print("turn_engine_core.gd start_group_turn()")
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

	_advance_to_next_actor()

func resume_after_player_done() -> void:
	#print("turn_engine_core.gd resume_after_player_done()")
	if phase == Phase.IDLE:
		_advance_to_next_actor()

func notify_actor_done(combat_id: int) -> void:
	#print("TE notify_actor_done cid=", combat_id, " current=", current_actor_id, " running=", _running_actor)
	#print("turn_engine_core.gd notify_actor_done()")
	# Called by host after it finishes running the actor.
	if combat_id != current_actor_id:
		# stale / ignored
		return

	_running_actor = false
	_mark_turn_taken(combat_id)
	_restore_allowed.erase(combat_id)
	_queue_dirty = true
	phase = Phase.IDLE
	_advance_to_next_actor()

func notify_actor_removed(combat_id: int) -> void:
	#print("TE notify_actor_removed cid=", combat_id, " current=", current_actor_id, " running=", _running_actor)
		#print("turn_engine_core.gd notify_actor_removed()")
	if combat_id == current_actor_id:
		current_actor_id = 0
		phase = Phase.IDLE
		_queue_dirty = true
		if !_running_actor:
			_advance_to_next_actor()
	else:
		_queue_dirty = true

func notify_summon_added(combat_id: int, group_index: int) -> void:
	#print("turn_engine_core.gd notify_summon_added()")
	if group_index != active_group_index:
		return
	_queue_dirty = true
	_publish_pending_view()

func notify_move_executed(ctx) -> void:
	#print("turn_engine_core.gd notify_move_executed()")
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
	#print("turn_engine_core.gd _crossed_behind()")
	if cid <= 0:
		return false
	var b : int = ctx.before_order_ids.find(cid)
	var a : int = ctx.after_order_ids.find(cid)
	if b == -1 or a == -1:
		return false
	return (b <= before_anchor) and (a > after_anchor)

func _advance_to_next_actor() -> void:
	#print("turn_engine_core.gd _advance_to_next_actor()")
	if _running_actor:
		return
	if active_group_index < 0:
		_reset()
		return

	if _queue_dirty:
		#print("turn_engine_core.gd _advance_to_next_actor() rebuilding queue")
		_rebuild_queue()
	print("queue is ", _queue)
	if _queue.is_empty():
		#print("turn_engine_core.gd _advance_to_next_actor() queue is empty")
		_end_group_turn()
		return
	
	var actor_id := int(_queue[0])
	if !host.is_alive(actor_id):
		#print("turn_engine_core.gd _advance_to_next_actor() first in queue is dead")
		_queue.remove_at(0)
		_queue_dirty = true
		_advance_to_next_actor()
		return

	current_actor_id = actor_id
	_running_actor = true
	_cursor_cid = actor_id

	_publish_pending_view()
	actor_requested.emit(actor_id)

func _reset() -> void:
	#print("turn_engine_core.gd _reset()")
	active_group_index = -1
	current_actor_id = 0
	phase = Phase.IDLE
	_queue = PackedInt32Array()
	_turns_taken.clear()
	_restore_allowed.clear()
	_queue_dirty = false
	_cursor_cid = 0

func _end_group_turn() -> void:
	#print("turn_engine_core.gd _end_group_turn()")
	var idx := active_group_index
	_reset()
	group_turn_ended.emit(idx)

func _mark_turn_taken(combat_id: int) -> void:
	#print("turn_engine_core.gd _mark_turn_taken()")
	var n := int(_turns_taken.get(combat_id, 0))
	_turns_taken[combat_id] = n + 1

func _turns_left(combat_id: int) -> int:
	#print("turn_engine_core.gd _turns_left()")
	if !host.is_alive(combat_id):
		return 0
	if active_group_index == 0 and host.is_player(combat_id):
		return 1 - int(_turns_taken.get(combat_id, 0))
	return MAX_TURNS_PER_FIGHTER_PER_GROUP_TURN - int(_turns_taken.get(combat_id, 0))

func _rebuild_queue() -> void:
	#print("turn_engine_core.gd _rebuild_queue()")
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
	#print("turn_engine_core.gd _get_desired_order_ids()")
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
		out.append(p)
		for i in range(player_idx + 1, order.size()):
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
