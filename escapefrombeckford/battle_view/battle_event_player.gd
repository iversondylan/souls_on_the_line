# battle_event_player.gd
class_name BattleEventPlayer
extends RefCounted

var _log: BattleEventLog
var _cursor: BattleEventCursor = BattleEventCursor.new()

func bind_log(log: BattleEventLog) -> void:
	_log = log
	_cursor.reset()

func has_next() -> bool:
	return _cursor.has_next(_log)

func peek() -> BattleEvent:
	return _cursor.peek(_log)

func next_event() -> BattleEvent:
	return _cursor.next(_log)

func drain(max_n: int = 999999) -> Array[BattleEvent]:
	return _cursor.drain(_log, max_n)

# A "beat" is either:
# - One scoped subtree: SCOPE_BEGIN ... (nested) ... matching SCOPE_END
# - Or one single unscoped event (rare, but keep it robust)
func next_beat() -> Array[BattleEvent]:
	var out: Array[BattleEvent] = []
	if _log == null or !_cursor.has_next(_log):
		return out

	var first := _cursor.next(_log)
	if first == null:
		return out

	out.append(first)

	# If it's not a scope begin, this beat is just that one event.
	if int(first.type) != BattleEvent.Type.SCOPE_BEGIN:
		return out

	# Scoped beat: collect until we close THIS scope_id.
	var root_scope_id := int(first.data.get(Keys.SCOPE_ID, first.scope_id))

	# Track depth for safety (malformed logs) but we primarily key off scope_id.
	var depth := 1

	while _cursor.has_next(_log) and depth > 0:
		var e := _cursor.next(_log)
		if e == null:
			break
		out.append(e)

		if int(e.type) == BattleEvent.Type.SCOPE_BEGIN:
			depth += 1
		elif int(e.type) == BattleEvent.Type.SCOPE_END:
			depth -= 1
			# Prefer scope_id match to terminate exactly at the root.
			var end_scope_id := int(e.data.get(Keys.SCOPE_ID, e.scope_id))
			if end_scope_id == root_scope_id:
				break

	return out
