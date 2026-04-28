# battle_event_player.gd
class_name BattleEventPlayer extends RefCounted

var _log: BattleEventLog
var _cursor: BattleEventCursor = BattleEventCursor.new()


func bind_log(battle_log: BattleEventLog) -> void:
	_log = battle_log
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


func peek_is_compiled_turn_chunk(player_id: int) -> bool:
	if _log == null or !_cursor.has_next(_log):
		return false

	var e := _cursor.peek(_log)
	if !_is_compiled_turn_scope_begin(e):
		return false

	# The player does the first gating pass: only non-player ACTOR_TURN scopes and
	# all CARD_ATTACK_NOW_TURN scopes are diverted into the timeline compiler.
	return _should_compile_scope_begin(e, player_id)


func await_complete_compiled_turn_chunk() -> Array[BattleEvent]:
	var out: Array[BattleEvent] = []
	if _log == null or !_cursor.has_next(_log):
		return out

	var first := _cursor.peek(_log)
	if !_is_compiled_turn_scope_begin(first):
		out.append(_cursor.next(_log))
		return out

	var scan_index := _cursor.index
	var depth := 0
	var started := false

	# This is the concrete "turn finished" checkpoint for compiled playback:
	# wait until the matching SCOPE_END for the currently visible compileable
	# scope appears in the log, then drain that whole nested scope slice.
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
					return _drain_compiled_turn_scope()

		await _log.appended

	return out


func next_raw_chunk(player_id: int = 0) -> Array[BattleEvent]:
	#if _log != null:
		#print(
			#"next_raw_chunk start cursor=%d next=%s" % [
				#_cursor.index,
				#_debug_event_short(_cursor.peek(_log)) if _cursor.has_next(_log) else "<none>"
			#]
		#)

	var out: Array[BattleEvent] = []
	if _log == null or !_cursor.has_next(_log):
		return out

	var first := _cursor.peek(_log)
	if first == null:
		return out

	# If the next thing is a compileable scope, stop and let battle_view take the
	# compiler path instead. Player actor turns are the exception: they stay raw.
	if _is_compiled_turn_scope_begin(first):
		if _should_compile_scope_begin(first, player_id):
			#print(
				#"next_raw_chunk return size=%d first=%s last=%s cursor=%d" % [
					#out.size(),
					#_debug_event_short(out[0]) if out.size() > 0 else "<empty>",
					#_debug_event_short(out[out.size() - 1]) if out.size() > 0 else "<empty>",
					#_cursor.index
				#]
			#)
			return out

		if _is_actor_turn_scope_begin(first):
			out = _drain_compiled_turn_scope()
			#print(
				#"next_raw_chunk return size=%d first=%s last=%s cursor=%d" % [
					#out.size(),
					#_debug_event_short(out[0]) if out.size() > 0 else "<empty>",
					#_debug_event_short(out[out.size() - 1]) if out.size() > 0 else "<empty>",
					#_cursor.index
				#]
			#)
			return out

	while _cursor.has_next(_log):
		var e := _cursor.peek(_log)
		if e == null:
			break

		# Stop before compiled turn scopes so they can be played as timelines.
		if _is_compiled_turn_scope_begin(e):
			if _should_compile_scope_begin(e, player_id):
				break

			if _is_actor_turn_scope_begin(e):
				if !out.is_empty():
					break

				out = _drain_compiled_turn_scope()
				#print(
					#"next_raw_chunk return size=%d first=%s last=%s cursor=%d" % [
						#out.size(),
						#_debug_event_short(out[0]) if out.size() > 0 else "<empty>",
						#_debug_event_short(out[out.size() - 1]) if out.size() > 0 else "<empty>",
						#_cursor.index
					#]
				#)
				return out

		# If we've already started accumulating, stop BEFORE major structural boundaries
		# so they don't get swallowed into giant transition chunks.
		if !out.is_empty() and _is_structural_boundary(e):
			break

		# Consume event
		out.append(_cursor.next(_log))

		# Stop after consuming natural stop events / beat markers
		if _is_stop_event(e):
			break

	#print(
		#"next_raw_chunk return size=%d first=%s last=%s cursor=%d" % [
			#out.size(),
			#_debug_event_short(out[0]) if out.size() > 0 else "<empty>",
			#_debug_event_short(out[out.size() - 1]) if out.size() > 0 else "<empty>",
			#_cursor.index
		#]
	#)
	return out


func _drain_compiled_turn_scope() -> Array[BattleEvent]:
	var out: Array[BattleEvent] = []
	if _log == null or !_cursor.has_next(_log):
		return out

	var root := _cursor.peek(_log)
	if !_is_compiled_turn_scope_begin(root):
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


func _is_card_attack_now_turn_scope_begin(e: BattleEvent) -> bool:
	if e == null:
		return false
	if int(e.type) != BattleEvent.Type.SCOPE_BEGIN:
		return false
	return int(e.scope_kind) == int(Scope.Kind.CARD_ATTACK_NOW_TURN)


func _is_compiled_turn_scope_begin(e: BattleEvent) -> bool:
	return _is_actor_turn_scope_begin(e) or _is_card_attack_now_turn_scope_begin(e)


func _should_compile_scope_begin(e: BattleEvent, player_id: int) -> bool:
	if _is_card_attack_now_turn_scope_begin(e):
		return true
	if !_is_actor_turn_scope_begin(e):
		return false

	# Player actor turns are intentionally not compiled so PLAYER_INPUT_REACHED,
	# discard prompts, end-turn signals, and other UI-facing events can stream out
	# incrementally instead of waiting for the whole scope to close.
	var actor_id := int(e.data.get(Keys.ACTOR_ID, 0)) if e != null and e.data != null else 0
	if actor_id <= 0:
		return false
	return actor_id != player_id

func _debug_event_short(e: BattleEvent) -> String:
	if e == null:
		return "<null>"

	var type_name := str(int(e.type))
	if int(e.type) >= 0 and int(e.type) < BattleEvent.Type.size():
		type_name = BattleEvent.Type.keys()[int(e.type)]

	var actor_id := 0
	var source_id := 0
	var target_id := 0
	var group_index := int(e.group_index)

	if e.data != null:
		if e.data.has(Keys.ACTOR_ID):
			actor_id = int(e.data[Keys.ACTOR_ID])
		if e.data.has(Keys.SOURCE_ID):
			source_id = int(e.data[Keys.SOURCE_ID])
		if e.data.has(Keys.TARGET_ID):
			target_id = int(e.data[Keys.TARGET_ID])
		if e.data.has(Keys.GROUP_INDEX):
			group_index = int(e.data[Keys.GROUP_INDEX])

	return "%s(sk=%s sid=%s a=%s src=%s tgt=%s g=%s seq=%s beat=%s)" % [
		type_name,
		int(e.scope_kind),
		int(e.scope_id),
		actor_id,
		source_id,
		target_id,
		group_index,
		int(e.seq),
		str(bool(e.defines_beat)),
	]

func _is_structural_boundary(e: BattleEvent) -> bool:
	if e == null:
		return false

	match int(e.type):
		BattleEvent.Type.TURN_GROUP_BEGIN, BattleEvent.Type.TURN_GROUP_END, BattleEvent.Type.ARCANA_PROC:
			return true

	if int(e.type) == BattleEvent.Type.SCOPE_BEGIN:
		match int(e.scope_kind):
			Scope.Kind.GROUP_TURN, Scope.Kind.ARCANA, Scope.Kind.CARD_ATTACK_NOW_TURN:
				return true

	return false


func _is_stop_event(e: BattleEvent) -> bool:
	if e == null:
		return false

	if int(e.type) == BattleEvent.Type.PLAYER_INPUT_REACHED:
		return true
	if int(e.type) == BattleEvent.Type.END_TURN_PRESSED:
		return true
	if int(e.type) == BattleEvent.Type.DISCARD_REQUESTED:
		return true
	if int(e.type) == BattleEvent.Type.DISCARD_CARDS:
		return true
	if e.defines_beat:
		return true

	return false
