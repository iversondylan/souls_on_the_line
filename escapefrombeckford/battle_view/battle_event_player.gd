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
