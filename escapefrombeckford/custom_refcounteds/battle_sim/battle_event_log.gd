# battle_event_log.gd

class_name BattleEventLog extends RefCounted

var _events: Array[BattleEvent] = []
var _next_seq: int = 0

func clear() -> void:
	_events.clear()
	_next_seq = 0

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

static func print_event_log(log: BattleEventLog) -> void:
	if log == null:
		return
	var indent := 0
	for i in range(log.size()):
		var e := log.get_event(i)
		if e == null:
			continue
		
		var type_name = BattleEvent.Type.keys()[int(e.type)] if int(e.type) >= 0 and int(e.type) < BattleEvent.Type.size() else str(e.type)
		
		if int(e.type) == BattleEvent.Type.SCOPE_END:
			indent = maxi(indent - 1, 0)
		
		var pad := ""
		for _k in range(indent):
			pad += "\t"
		
		print("%s[%04d] %s t=%d g=%d a=%d kind=%s data=%s" % [
			pad,
			int(e.seq),
			type_name,
			int(e.turn_id),
			int(e.group_index),
			int(e.active_actor_id),
			Scope.Kind.keys()[e.scope_kind],
			str(e.data)
		])
		
		if int(e.type) == BattleEvent.Type.SCOPE_BEGIN:
			indent += 1
