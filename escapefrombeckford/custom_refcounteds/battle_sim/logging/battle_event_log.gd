# battle_event_log.gd

class_name BattleEventLog extends RefCounted


signal appended(new_size: int)

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
	appended.emit(e.seq)
	return e.seq

func get_event(i: int) -> BattleEvent:
	return _events[i]

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


static func print_event_log(
	log: BattleEventLog,
	last_n: int = -1,
	sleep_ms_every: int = 100,
	sleep_ms: float = 500.0,
	show_data: bool = true,
	show_empty_data: bool = false,
	extra_keys: Array[StringName] = [],

	show_ctx: bool = true,
	show_tick: bool = true,
	show_defines_beat: bool = true,
	show_scope_path: bool = false,
	abbrev_arrays_over: int = 10,
	abbrev_string_over: int = 80,
	print_unknown_data_keys: bool = false
) -> void:
	if log == null:
		return

	var total := log.size()
	if total <= 0:
		print("(BattleEventLog) <empty>")
		return

	var start := 0
	if last_n > 0:
		start = maxi(total - last_n, 0)

	var indent := 0
	var printed := 0

	var base_keys: Array[StringName] = [
		Keys.SCOPE_ID,
		Keys.PARENT_SCOPE_ID,
		Keys.SCOPE_KIND,
		Keys.SCOPE_LABEL,

		Keys.ACTOR_ID,
		Keys.SOURCE_ID,
		Keys.TARGET_ID,
		Keys.TARGET_IDS,
		Keys.GROUP_INDEX,
		Keys.TURN_ID,

		Keys.CARD_UID,
		Keys.CARD_NAME,
		Keys.INSERT_INDEX,

		Keys.STATUS_ID,
		Keys.OP,
		Keys.INTENSITY,
		Keys.DURATION,

		Keys.PLANNED_IDX,
		Keys.INTENT_TEXT,
		Keys.IS_RANGED,

		Keys.BEFORE_HEALTH,
		Keys.AFTER_HEALTH,
		Keys.BASE_AMOUNT,
		Keys.FINAL_AMOUNT,
		Keys.HEALTH_DAMAGE,
		Keys.ARMOR_DAMAGE,
		Keys.WAS_LETHAL,

		# mana
		Keys.BEFORE_MANA,
		Keys.AFTER_MANA,
		Keys.BEFORE_MAX_MANA,
		Keys.AFTER_MAX_MANA,

		Keys.BEFORE_ORDER_IDS,
		Keys.AFTER_ORDER_IDS,
		Keys.MOVE_TYPE,

		Keys.PROC,
		Keys.ARCANUM_ID,

		Keys.REASON,
		Keys.DEATH_REASON,
		Keys.PROTO,
		Keys.SUMMONED_ID,
		Keys.SPAWNED_ID,
		Keys.ACTIVE_ID,
		Keys.PLAYER_ID,
		Keys.PENDING_IDS,
		Keys.SUMMON_COUNT,
	]

	for k in extra_keys:
		if k != null and !base_keys.has(k):
			base_keys.append(k)

	var scope_label_stack: Array[String] = []

	for i in range(start, total):
		var e := log.get_event(i)
		if e == null:
			continue

		var etype := int(e.type)

		if etype == BattleEvent.Type.SCOPE_END:
			indent = maxi(indent - 1, 0)
			if scope_label_stack.size() > 0:
				scope_label_stack.pop_back()

		var type_name := str(etype)
		if etype >= 0 and etype < BattleEvent.Type.size():
			type_name = BattleEvent.Type.keys()[etype]

		var kind_name := str(int(e.scope_kind))
		if int(e.scope_kind) >= 0 and int(e.scope_kind) < Scope.Kind.size():
			kind_name = Scope.Kind.keys()[int(e.scope_kind)]

		var pad := ""
		for _k in range(indent):
			pad += "\t"

		var header := "%s[%04d] %s" % [pad, int(e.seq), type_name]

		if show_defines_beat and bool(e.defines_beat):
			header += " *"

		if show_tick:
			header += " tick=%d" % int(e.battle_tick)

		if show_ctx:
			var ctx_bits: Array[String] = []
			if int(e.turn_id) != 0:
				ctx_bits.append("t=%d" % int(e.turn_id))
			if int(e.group_index) != -1:
				ctx_bits.append("g=%d" % int(e.group_index))
			if int(e.active_actor_id) != 0:
				ctx_bits.append("a=%d" % int(e.active_actor_id))
			if int(e.scope_id) != 0:
				ctx_bits.append("kind=%s" % kind_name)
			if ctx_bits.size() > 0:
				header += " " + " ".join(ctx_bits)

		if show_scope_path and scope_label_stack.size() > 0:
			header += " path=" + "/".join(scope_label_stack)

		var d: Dictionary = e.data if (e.data is Dictionary) else {}
		var has_any_data := (d != null and !d.is_empty())
		var data_bits: Array[String] = []

		# Special compact summaries first
		if show_data and d != null:
			var special_summary := _fmt_special_event_data(e, d, abbrev_arrays_over, abbrev_string_over)
			if special_summary != "":
				data_bits.append(special_summary)

			for k in base_keys:
				if !d.has(k):
					continue

				# Skip keys already represented in the special summary for this event type
				if _skip_key_because_specialized(etype, k):
					continue

				var v = d[k]
				data_bits.append("%s=%s" % [str(k), _fmt_value(v, abbrev_arrays_over, abbrev_string_over)])

			if print_unknown_data_keys and has_any_data:
				var unknown: Array[String] = []
				for kk in d.keys():
					if kk is StringName and base_keys.has(kk):
						continue
					if kk is String and base_keys.has(StringName(kk)):
						continue
					unknown.append(String(kk))
				unknown.sort()
				if unknown.size() > 0:
					data_bits.append("extra_keys=%s" % _fmt_value(unknown, abbrev_arrays_over, abbrev_string_over))

		if show_data:
			if data_bits.size() > 0:
				header += " data{" + ", ".join(data_bits) + "}"
			elif has_any_data and show_empty_data:
				header += " data{keys:%d}" % int(d.keys().size())

		print(header)

		if etype == BattleEvent.Type.SCOPE_BEGIN:
			indent += 1
			var lbl := ""
			if d != null and d.has(Keys.SCOPE_LABEL):
				lbl = String(d[Keys.SCOPE_LABEL])
			if lbl == "":
				lbl = "scope"
			scope_label_stack.append(lbl)

		printed += 1
		if sleep_ms_every > 0 and (printed % sleep_ms_every) == 0:
			await Engine.get_main_loop().create_timer(maxf(sleep_ms / 1000.0, 0.001)).timeout


static func _fmt_special_event_data(
	e: BattleEvent,
	d: Dictionary,
	abbrev_arrays_over: int,
	abbrev_string_over: int
) -> String:
	var etype := int(e.type)

	match etype:
		BattleEvent.Type.MANA:
			var source_id := int(d.get(Keys.SOURCE_ID, 0))
			var before_mana := int(d.get(Keys.BEFORE_MANA, 0))
			var after_mana := int(d.get(Keys.AFTER_MANA, 0))
			var before_max := int(d.get(Keys.BEFORE_MAX_MANA, 0))
			var after_max := int(d.get(Keys.AFTER_MAX_MANA, 0))
			var reason := String(d.get(Keys.REASON, ""))

			var mana_delta := after_mana - before_mana
			var max_delta := after_max - before_max

			var bits: Array[String] = []
			if source_id != 0:
				bits.append("src=%d" % source_id)

			bits.append("mana=%d->%d" % [before_mana, after_mana])
			if mana_delta != 0:
				bits.append("Δmana=%+d" % mana_delta)

			bits.append("max=%d->%d" % [before_max, after_max])
			if max_delta != 0:
				bits.append("Δmax=%+d" % max_delta)

			if reason != "":
				bits.append("reason=%s" % _fmt_value(reason, abbrev_arrays_over, abbrev_string_over))

			return " ".join(bits)

		BattleEvent.Type.STATUS:
			var source_id := int(d.get(Keys.SOURCE_ID, 0))
			var target_id := int(d.get(Keys.TARGET_ID, 0))
			var status_id := String(d.get(Keys.STATUS_ID, ""))
			var op := int(d.get(Keys.OP, 0))
			var intensity := int(d.get(Keys.INTENSITY, 0))
			var duration := int(d.get(Keys.DURATION, 0))

			var op_name := str(op)
			if Status.OP.values().has(op):
				op_name = Status.OP.keys()[op]

			var bits: Array[String] = []
			if source_id != 0:
				bits.append("src=%d" % source_id)
			if target_id != 0:
				bits.append("tgt=%d" % target_id)
			if status_id != "":
				bits.append("status=%s" % status_id)
			bits.append("op=%s" % op_name)
			bits.append("int=%d" % intensity)
			bits.append("dur=%d" % duration)
			return " ".join(bits)

		_:
			return ""


static func _skip_key_because_specialized(event_type: int, k: StringName) -> bool:
	match event_type:
		BattleEvent.Type.MANA:
			return k == Keys.SOURCE_ID \
				or k == Keys.BEFORE_MANA \
				or k == Keys.AFTER_MANA \
				or k == Keys.BEFORE_MAX_MANA \
				or k == Keys.AFTER_MAX_MANA \
				or k == Keys.REASON

		BattleEvent.Type.STATUS:
			return k == Keys.SOURCE_ID \
				or k == Keys.TARGET_ID \
				or k == Keys.STATUS_ID \
				or k == Keys.OP \
				or k == Keys.INTENSITY \
				or k == Keys.DURATION

		_:
			return false


static func _fmt_value(v, abbrev_arrays_over: int, abbrev_string_over: int) -> String:
	if v == null:
		return "null"

	if v is PackedInt32Array:
		return _fmt_array(Array(v), abbrev_arrays_over)

	if v is Array:
		return _fmt_array(v as Array, abbrev_arrays_over)

	if v is Dictionary:
		var dd := v as Dictionary
		var ks := dd.keys()
		var names: Array[String] = []
		for k in ks:
			names.append(String(k))
		names.sort()
		if names.size() > 8:
			return "{keys:%d [%s…]}" % [names.size(), ", ".join(names.slice(0, 8))]
		return "{keys:%d [%s]}" % [names.size(), ", ".join(names)]

	if v is String:
		var s := v as String
		if s.length() > abbrev_string_over:
			return "\"%s…\"(len=%d)" % [s.substr(0, abbrev_string_over), s.length()]
		return "\"%s\"" % s

	if v is StringName:
		return String(v)

	if v is bool:
		return "true" if bool(v) else "false"

	if v is float:
		return "%.3f" % float(v)

	return str(v)


static func _fmt_array(arr: Array, abbrev_arrays_over: int) -> String:
	var n := arr.size()
	if n == 0:
		return "[]"
	if n > abbrev_arrays_over:
		var head := arr.slice(0, abbrev_arrays_over)
		var parts: Array[String] = []
		for x in head:
			parts.append(str(x))
		return "[%s…](n=%d)" % [", ".join(parts), n]
	else:
		var parts2: Array[String] = []
		for x2 in arr:
			parts2.append(str(x2))
		return "[%s]" % ", ".join(parts2)
