# battle_event_player.gd

class_name BattleEventPlayer extends RefCounted

var _log: BattleEventLog
var _cursor: BattleEventCursor = BattleEventCursor.new()

# These scope kinds define "presentation units" that should be consumed as whole subtrees.
# DO NOT include GROUP_TURN.
var _sticky_scope_kinds := PackedInt32Array([
	Scope.Kind.SETUP,	 # optional: setup as one chunk
	Scope.Kind.ARCANA,	 # each proc scope is a beat
	Scope.Kind.STRIKE,	 # each strike is a beat
	Scope.Kind.CARD,	 # later, when you add card scopes
])

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

func next_beat() -> Array[BattleEvent]:
	var out: Array[BattleEvent] = []
	if _log == null or !_cursor.has_next(_log):
		return out

	# 1) Collect leading events until the next beat marker.
	while _cursor.has_next(_log):
		var p := _cursor.peek(_log)
		if p == null:
			return out
		if p.defines_beat:
			break
		out.append(_cursor.next(_log))

	# IMPORTANT: if we collected any leading events and the next event is a beat marker,
	# return the leading chunk as its own beat (prelude). Do NOT consume the marker yet.
	if !out.is_empty() and _cursor.has_next(_log):
		var nextp := _cursor.peek(_log)
		if nextp != null and nextp.defines_beat:
			return out

	# If EOF and we had only leading events, return them.
	if !_cursor.has_next(_log):
		return out

	# 2) Now we are at a beat marker: start the beat at the marker.
	var marker := _cursor.next(_log)
	if marker != null:
		out.append(marker)

	# 3) Consume until the next beat marker (do not consume it).
	while _cursor.has_next(_log):
		var n := _cursor.peek(_log)
		if n == null:
			break
		if n.defines_beat:
			break
		out.append(_cursor.next(_log))

	return out
