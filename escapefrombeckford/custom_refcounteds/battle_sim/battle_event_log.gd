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

# battle_event_log.gd (or wherever you keep your printer)

static func print_event_log(
	log: BattleEventLog,
	last_n: int = -1,
	sleep_ms_every: int = 100,
	sleep_ms: float = 100.0,
	show_data: bool = true,
	show_empty_data: bool = false,
	extra_keys: Array[StringName] = [],
	# new knobs:
	show_ctx: bool = true,
	show_scope_path: bool = false,          # show nested scope labels
	abbrev_arrays_over: int = 10,
	abbrev_string_over: int = 80,
	print_unknown_data_keys: bool = false   # dump keys you didn't whitelist
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

	# “useful defaults” – add Keys.OP here for your STATUS change
	var base_keys: Array[StringName] = [
		# scope metadata
		Keys.SCOPE_ID,
		Keys.PARENT_SCOPE_ID,
		Keys.SCOPE_KIND,
		Keys.SCOPE_LABEL,

		# identity / routing
		Keys.ACTOR_ID,
		Keys.SOURCE_ID,
		Keys.TARGET_ID,
		Keys.TARGET_IDS,
		Keys.GROUP_INDEX,
		Keys.TURN_ID,

		# cards
		Keys.CARD_UID,
		Keys.CARD_NAME,
		Keys.INSERT_INDEX,

		# status
		Keys.STATUS_ID,
		Keys.OP,                # IMPORTANT for your new STATUS event
		Keys.INTENSITY,
		Keys.DURATION,

		# intent
		Keys.PLANNED_IDX,
		Keys.INTENT_TEXT,
		Keys.IS_RANGED,

		# damage
		Keys.BEFORE_HEALTH,
		Keys.AFTER_HEALTH,
		Keys.BASE_AMOUNT,
		Keys.FINAL_AMOUNT,
		Keys.HEALTH_DAMAGE,
		Keys.ARMOR_DAMAGE,
		Keys.WAS_LETHAL,

		# formation / layout
		Keys.BEFORE_ORDER_IDS,
		Keys.AFTER_ORDER_IDS,
		Keys.MOVE_TYPE,

		# arcana
		Keys.PROC,
		Keys.ARCANUM_ID,

		# misc reasons
		Keys.REASON,
		Keys.DEATH_REASON,
		Keys.PROTO,
		Keys.SUMMONED_ID,
		Keys.SPAWNED_ID,
		Keys.ACTIVE_ID,
		Keys.PENDING_IDS,
	]

	for k in extra_keys:
		if k != null and !base_keys.has(k):
			base_keys.append(k)

	# Track scope labels for optional "path" printing
	var scope_label_stack: Array[String] = []

	for i in range(start, total):
		var e := log.get_event(i)
		if e == null:
			continue

		var etype := int(e.type)

		# Indent BEFORE printing SCOPE_END
		if etype == BattleEvent.Type.SCOPE_END:
			indent = maxi(indent - 1, 0)
			if scope_label_stack.size() > 0:
				scope_label_stack.pop_back()

		# Names
		var type_name := str(etype)
		if etype >= 0 and etype < BattleEvent.Type.size():
			type_name = BattleEvent.Type.keys()[etype]

		var kind_name := str(int(e.scope_kind))
		if int(e.scope_kind) >= 0 and int(e.scope_kind) < Scope.Kind.size():
			kind_name = Scope.Kind.keys()[int(e.scope_kind)]

		# Pad
		var pad := ""
		for _k in range(indent):
			pad += "\t"

		# Header
		var header := "%s[%04d] %s" % [pad, int(e.seq), type_name]

		# Compact ctx fields
		if show_ctx:
			var ctx_bits: Array[String] = []
			# These are "context on event", not necessarily duplicated in data
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

		# Optional scope path (nice when you're debugging your scopes changing t/g/a)
		if show_scope_path and scope_label_stack.size() > 0:
			header += " path=" + "/".join(scope_label_stack)

		# Data
		var d: Dictionary = e.data if e.data is Dictionary else {}
		var has_any_data := (d != null and !d.is_empty())
		var data_bits: Array[String] = []

		if show_data and d != null:
			for k in base_keys:
				if !d.has(k):
					continue
				var v = d[k]
				data_bits.append("%s=%s" % [str(k), _fmt_value(v, abbrev_arrays_over, abbrev_string_over)])

			# Optionally show keys not in base_keys (sorted, but compact)
			if print_unknown_data_keys and has_any_data:
				var unknown: Array[String] = []
				for kk in d.keys():
					var sk := String(kk)
					# Keys are StringName usually, but keep robust
					if kk is StringName and base_keys.has(kk):
						continue
					if kk is String and base_keys.has(StringName(kk)):
						continue
					# ignore extremely noisy nested specs by default
					unknown.append(sk)
				unknown.sort()
				if unknown.size() > 0:
					data_bits.append("extra_keys=%s" % _fmt_value(unknown, abbrev_arrays_over, abbrev_string_over))

		if show_data:
			if data_bits.size() > 0:
				header += " data{" + ", ".join(data_bits) + "}"
			elif has_any_data and show_empty_data:
				header += " data{keys:%d}" % int(d.keys().size())

		print(header)

		# Indent AFTER printing SCOPE_BEGIN, and track labels
		if etype == BattleEvent.Type.SCOPE_BEGIN:
			indent += 1
			# Try to capture a nice label to show in path
			var lbl := ""
			if d != null and d.has(Keys.SCOPE_LABEL):
				lbl = String(d[Keys.SCOPE_LABEL])
			if lbl == "":
				lbl = "scope"
			scope_label_stack.append(lbl)

		printed += 1
		if sleep_ms_every > 0 and (printed % sleep_ms_every) == 0:
			await Engine.get_main_loop().create_timer(maxf(sleep_ms / 1000.0, 0.001)).timeout


static func _fmt_value(v, abbrev_arrays_over: int, abbrev_string_over: int) -> String:
	if v == null:
		return "null"

	# Packed arrays
	if v is PackedInt32Array:
		var arr := Array(v)
		return _fmt_array(arr, abbrev_arrays_over)

	# Generic arrays
	if v is Array:
		return _fmt_array(v as Array, abbrev_arrays_over)

	# Dicts (don’t explode)
	if v is Dictionary:
		var dd := v as Dictionary
		# Special-case: spec dicts can be huge; show key count + maybe a few keys
		var ks := dd.keys()
		var ksn: Array[String] = []
		for k in ks:
			ksn.append(String(k))
		ksn.sort()
		if ksn.size() > 8:
			return "{keys:%d [%s…]}" % [ksn.size(), ", ".join(ksn.slice(0, 8))]
		return "{keys:%d [%s]}" % [ksn.size(), ", ".join(ksn)]

	# String / StringName
	if v is String:
		var s := v as String
		if s.length() > abbrev_string_over:
			return "\"%s…\"(len=%d)" % [s.substr(0, abbrev_string_over), s.length()]
		return "\"%s\"" % s

	if v is StringName:
		return String(v)

	# Enums: optionally pretty-print Status.OP if you’re passing it
	# (only if you use Keys.OP and store ints)
	if v is int:
		return str(int(v))

	if v is bool:
		return "true" if bool(v) else "false"

	if v is float:
		# avoid long float spam
		return "%.3f" % float(v)

	return str(v)


static func _fmt_array(arr: Array, abbrev_arrays_over: int) -> String:
	var n := arr.size()
	if n == 0:
		return "[]"
	if n > abbrev_arrays_over:
		return "[%s…](n=%d)" % [", ".join(arr.slice(0, abbrev_arrays_over).map(func(x): return str(x))), n]
	return "[%s]" % ", ".join(arr.map(func(x): return str(x)))
