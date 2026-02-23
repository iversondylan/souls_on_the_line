# battle_event_log.gd

class_name BattleEventLog extends RefCounted

var _events: Array[BattleEvent] = []
var _next_seq: int = 1

func clear() -> void:
	_events.clear()
	_next_seq = 1

func size() -> int:
	return _events.size()

func next_seq() -> int:
	return _next_seq

func append(e: BattleEvent) -> int:
	if e == null:
		return 0
	e.seq = _next_seq
	e.battle_tick = _next_seq
	_next_seq += 1
	_events.append(e)
	return e.seq

func get_event(i: int) -> BattleEvent:
	if i < 0 or i >= _events.size():
		return null
	return _events[i]

# Read a slice (inclusive start, exclusive end)
func read_range(start_index: int, end_index: int) -> Array[BattleEvent]:
	start_index = clampi(start_index, 0, _events.size())
	end_index = clampi(end_index, 0, _events.size())
	if end_index <= start_index:
		return []
	var out: Array[BattleEvent] = []
	out.resize(end_index - start_index)
	var k := 0
	for i in range(start_index, end_index):
		out[k] = _events[i]
		k += 1
	return out
