# battle_event_queue.gd
class_name BattleEventQueue extends RefCounted

var _events: Array[BattleEvent] = []
var _seq: int = 0

func push(e: BattleEvent) -> void:
	if e == null:
		return
	_seq += 1
	e.t = _seq
	_events.append(e)

func drain() -> Array[BattleEvent]:
	var out := _events
	_events = []
	return out

func peek_all() -> Array[BattleEvent]:
	return _events.duplicate()
