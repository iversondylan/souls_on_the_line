# battle_event_player.gd
class_name BattleEventPlayer extends RefCounted

var _log: BattleEventLog
var _cursor: BattleEventCursor = BattleEventCursor.new()


func bind_log(log: BattleEventLog) -> void:
	_log = log
	_cursor.reset()

func get_log() -> BattleEventLog:
	return _log

func has_next() -> bool:
	return _cursor.has_next(_log)

func peek() -> BattleEvent:
	return _cursor.peek(_log)

func next_event() -> BattleEvent:
	return _cursor.next(_log)

func drain(max_n: int = 999999) -> Array[BattleEvent]:
	return _cursor.drain(_log, max_n)


func peek_is_npc_actor_turn(player_id: int) -> bool:
	if _log == null or !_cursor.has_next(_log):
		return false

	var e := _cursor.peek(_log)
	if !_is_actor_turn_scope_begin(e):
		return false

	var actor_id := int(e.data.get(Keys.ACTOR_ID, 0)) if e != null and e.data != null else 0
	if actor_id <= 0:
		return false
	if actor_id == player_id:
		return false

	return true


func await_complete_actor_turn_chunk() -> Array[BattleEvent]:
	var out: Array[BattleEvent] = []
	if _log == null or !_cursor.has_next(_log):
		return out

	var first := _cursor.peek(_log)
	if !_is_actor_turn_scope_begin(first):
		out.append(_cursor.next(_log))
		return out

	var scan_index := _cursor.index
	var depth := 0
	var started := false

	while true:
		while scan_index < _log.size():
			var e := _log.get_event(scan_index)
			scan_index += 1

			if e == null:
				continue

			if int(e.type) == BattleEvent.Type.SCOPE_BEGIN:
				depth += 1
				started = true
			elif int(e.type) == BattleEvent.Type.SCOPE_END and started:
				depth -= 1
				if depth <= 0:
					return _drain_actor_turn_scope()

		await _log.appended

	return out


func next_raw_chunk(player_id: int = 0) -> Array[BattleEvent]:
	var out: Array[BattleEvent] = []
	if _log == null or !_cursor.has_next(_log):
		return out

	var first := _cursor.peek(_log)
	if first == null:
		return out

	# Critical:
	# - NPC actor turn: do NOT consume here
	# - Player actor turn: DO consume here, as a full raw scope
	if _is_actor_turn_scope_begin(first):
		var actor_id := int(first.data.get(Keys.ACTOR_ID, 0)) if first.data != null else 0
		if actor_id > 0 and actor_id != player_id:
			return out
		return _drain_actor_turn_scope()

	while _cursor.has_next(_log):
		var e := _cursor.peek(_log)
		if e == null:
			break

		# Stop before an NPC actor-turn scope.
		if _is_actor_turn_scope_begin(e):
			var actor_id2 := int(e.data.get(Keys.ACTOR_ID, 0)) if e.data != null else 0
			if actor_id2 > 0 and actor_id2 != player_id:
				break
			return _drain_actor_turn_scope()

		out.append(_cursor.next(_log))

		if int(e.type) == BattleEvent.Type.PLAYER_INPUT_REACHED:
			break
		if int(e.type) == BattleEvent.Type.END_TURN_PRESSED:
			break
		if int(e.type) == BattleEvent.Type.DISCARD_REQUESTED:
			break
		if e.defines_beat:
			break

	return out


func _drain_actor_turn_scope() -> Array[BattleEvent]:
	var out: Array[BattleEvent] = []
	if _log == null or !_cursor.has_next(_log):
		return out

	var root := _cursor.peek(_log)
	if !_is_actor_turn_scope_begin(root):
		out.append(_cursor.next(_log))
		return out

	var depth := 0

	while _cursor.has_next(_log):
		var e := _cursor.next(_log)
		if e == null:
			continue

		out.append(e)

		if int(e.type) == BattleEvent.Type.SCOPE_BEGIN:
			depth += 1
		elif int(e.type) == BattleEvent.Type.SCOPE_END:
			depth -= 1
			if depth <= 0:
				break

	return out


func _is_actor_turn_scope_begin(e: BattleEvent) -> bool:
	if e == null:
		return false
	if int(e.type) != BattleEvent.Type.SCOPE_BEGIN:
		return false
	return int(e.scope_kind) == int(Scope.Kind.ACTOR_TURN)
