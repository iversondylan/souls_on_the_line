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

static func print_event_log(
	log: BattleEventLog,
	last_n: int = -1,
	sleep_ms_every: int = 50,
	sleep_ms: float = 50.0,
	show_data: bool = true,
	show_empty_data: bool = false,
	extra_keys: Array[StringName] = []
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

	# Only show these common keys if they exist in e.data.
	# (You can add/remove freely; this is just the “useful defaults” set.)
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

		Keys.STATUS_ID,
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

		Keys.INSERT_INDEX,
		Keys.AFTER_ORDER_IDS,
		Keys.BEFORE_ORDER_IDS,
		Keys.MOVE_TYPE,
		Keys.REMOVED_ALL,
		Keys.DEATH_REASON,
		Keys.PROC,
	]

	# Append caller-provided keys (if any)
	for k in extra_keys:
		if k != null and !base_keys.has(k):
			base_keys.append(k)

	for i in range(start, total):
		var e := log.get_event(i)
		if e == null:
			continue

		# Update indent BEFORE printing SCOPE_END
		var etype := int(e.type)
		if etype == BattleEvent.Type.SCOPE_END:
			indent = maxi(indent - 1, 0)

		var type_name := str(etype)
		if etype >= 0 and etype < BattleEvent.Type.size():
			type_name = BattleEvent.Type.keys()[etype]

		# Safe scope kind name
		var kind_name := str(int(e.scope_kind))
		if int(e.scope_kind) >= 0 and int(e.scope_kind) < Scope.Kind.size():
			kind_name = Scope.Kind.keys()[int(e.scope_kind)]

		# Padding
		var pad := ""
		for _k in range(indent):
			pad += "\t"

		# Header: only what actually exists as fields (these always exist on BattleEvent in your writer)
		# Keep it compact.
		var header := "%s[%04d] %s" % [pad, int(e.seq), type_name]

		# Only print ctx fields if they’re meaningful (avoid spam like g=-1 / a=0)
		var ctx_bits: Array[String] = []
		if int(e.turn_id) != 0:
			ctx_bits.append("t=%d" % int(e.turn_id))
		if int(e.group_index) != -1:
			ctx_bits.append("g=%d" % int(e.group_index))
		if int(e.active_actor_id) != 0:
			ctx_bits.append("a=%d" % int(e.active_actor_id))

		# Scope kind is nice, but only if you’re actually scoped
		if int(e.scope_id) != 0:
			ctx_bits.append("kind=%s" % kind_name)

		if ctx_bits.size() > 0:
			header += " " + " ".join(ctx_bits)

		# Data printing: only keys that exist, in a stable order
		var data_bits: Array[String] = []
		var d : Dictionary = e.data if e.data is Dictionary else null

		if show_data and d != null:
			for k in base_keys:
				if d.has(k):
					var v = d[k]
					# keep arrays compact
					if v is PackedInt32Array:
						var arr := Array(v)
						if arr.size() > 12:
							data_bits.append("%s=[%s…](n=%d)" % [str(k), str(arr.slice(0, 12)), arr.size()])
						else:
							data_bits.append("%s=%s" % [str(k), str(arr)])
					elif v is Array:
						if (v as Array).size() > 12:
							data_bits.append("%s=[%s…](n=%d)" % [str(k), str((v as Array).slice(0, 12)), (v as Array).size()])
						else:
							data_bits.append("%s=%s" % [str(k), str(v)])
					# big nested dicts: don’t explode output
					elif v is Dictionary:
						var dk := (v as Dictionary).keys()
						data_bits.append("%s={keys:%d}" % [str(k), dk.size()])
					else:
						data_bits.append("%s=%s" % [str(k), str(v)])

		# If data exists but nothing matched our keys, don’t dump the whole dict by default.
		# (That’s what was killing you.)
		var has_any_data : bool = (d != null and !d.is_empty())
		if show_data:
			if data_bits.size() > 0:
				header += " data{" + ", ".join(data_bits) + "}"
			elif has_any_data and show_empty_data:
				header += " data{keys:%d}" % int(d.keys().size())

		print(header)

		# Update indent AFTER printing SCOPE_BEGIN
		if etype == BattleEvent.Type.SCOPE_BEGIN:
			indent += 1

		printed += 1
		if sleep_ms_every > 0 and (printed % sleep_ms_every) == 0:
			# ~50ms pause to avoid output overflow / editor hang
			await Engine.get_main_loop().create_timer(maxf(sleep_ms / 1000.0, 0.001)).timeout
