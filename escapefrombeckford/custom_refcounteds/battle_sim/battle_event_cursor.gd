# battle_event_cursor.gd

class_name BattleEventCursor extends RefCounted

var index: int = 0

func reset() -> void:
	index = 0

func has_next(log: BattleEventLog) -> bool:
	return log != null and index < log.size()

func peek(log: BattleEventLog) -> BattleEvent:
	if log == null:
		return null
	return log.get_event(index)

func next(log: BattleEventLog) -> BattleEvent:
	if log == null:
		return null
	var e := log.get_event(index)
	if e != null:
		index += 1
	return e

func drain(log: BattleEventLog, max_n: int = 999999) -> Array[BattleEvent]:
	if log == null:
		return []
	max_n = maxi(max_n, 0)
	var out: Array[BattleEvent] = []
	var n := 0
	while n < max_n and index < log.size():
		out.append(log.get_event(index))
		index += 1
		n += 1
	return out
