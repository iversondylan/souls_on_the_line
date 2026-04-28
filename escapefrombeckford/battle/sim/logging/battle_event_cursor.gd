# battle_event_cursor.gd

class_name BattleEventCursor extends RefCounted

var index: int = 0

func reset() -> void:
	index = 0

func has_next(_log: BattleEventLog) -> bool:
	if _log == null:
		return false
	return index < _log.size()

func peek(_log: BattleEventLog) -> BattleEvent:
	if _log == null or index < 0 or index >= _log.size():
		return null
	return _log.get_event(index)

func next(_log: BattleEventLog) -> BattleEvent:
	if _log == null or index < 0 or index >= _log.size():
		return null
	var e := _log.get_event(index)
	index += 1
	return e

func drain(_log: BattleEventLog, max_n: int = 999999) -> Array[BattleEvent]:
	if _log == null:
		return []
	max_n = maxi(max_n, 0)
	var out: Array[BattleEvent] = []
	var n := 0
	while n < max_n and index < _log.size():
		out.append(_log.get_event(index))
		index += 1
		n += 1
	return out
