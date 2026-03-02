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
	
	var first := _cursor.peek(_log)
	if first == null:
		return out
	
	# 1) If we are at a sticky scope begin, consume the full subtree.
	if _is_sticky_scope_begin(first):
		return _consume_scope_subtree()
	
	# 2) Otherwise, consume a "run beat" (consecutive related events).
	return _consume_run_beat()

func _is_sticky_scope_begin(e: BattleEvent) -> bool:
	if int(e.type) != BattleEvent.Type.SCOPE_BEGIN:
		return false
	return _sticky_scope_kinds.has(int(e.scope_kind))

func _consume_scope_subtree() -> Array[BattleEvent]:
	var out: Array[BattleEvent] = []
	var first := _cursor.next(_log)
	if first == null:
		return out
	out.append(first)

	var root_scope_id := int(first.data.get(Keys.SCOPE_ID, first.scope_id))
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
			var end_scope_id := int(e.data.get(Keys.SCOPE_ID, e.scope_id))
			if end_scope_id == root_scope_id:
				break

	return out

func _consume_run_beat() -> Array[BattleEvent]:
	var out: Array[BattleEvent] = []
	var saw_any_payload := false
	var in_damage_run := false

	while _cursor.has_next(_log):
		var next := _cursor.peek(_log)
		if next == null:
			break
		
		# If the next thing is a sticky scope begin and we already have payload, stop.
		if saw_any_payload and _is_sticky_scope_begin(next):
			break
		
		# Group consecutive DAMAGE_APPLIED into one beat.
		# If we are in a damage run and the next event is NOT damage, stop.
		if in_damage_run and int(next.type) != BattleEvent.Type.DAMAGE_APPLIED:
			break
		
		# Consume one event.
		var e := _cursor.next(_log)
		out.append(e)
		
		# Update run state.
		if int(e.type) == BattleEvent.Type.DAMAGE_APPLIED:
			in_damage_run = true
			saw_any_payload = true
		elif int(e.type) != BattleEvent.Type.SCOPE_BEGIN and int(e.type) != BattleEvent.Type.SCOPE_END:
			# Anything non-structural counts as payload.
			saw_any_payload = true

	return out
