# status_view_grid.gd

class_name StatusViewGrid extends GridContainer

const STATUS_DISPLAY_SCN := preload("uid://cd15ukicbp7fj")

# lane-key -> StatusDisplay
var _displays_by_id: Dictionary = {}

# lane-key -> Dictionary state {id, pending, intensity, duration, proto}
var _states_by_id: Dictionary = {}

var _owner_cid: int = 0
var _catalog: StatusCatalog = null

func bind(owner_cid: int, catalog: StatusCatalog) -> void:
	_owner_cid = owner_cid
	_catalog = catalog

func apply_status(order: StatusAppliedOrder) -> void:
	if order == null:
		return
	if int(order.target_id) != int(_owner_cid):
		return
	if order.status_id == &"":
		return
	if _catalog == null:
		push_warning("StatusViewGrid: missing StatusCatalog")
		return

	var proto := _catalog.get_proto(order.status_id)
	if proto == null:
		push_warning("StatusViewGrid: missing status proto for id=%s" % String(order.status_id))
		return

	var before_key := _make_state_key(order.status_id, order.before_pending)
	var after_key := _make_state_key(order.status_id, order.after_pending)

	if order.before_pending != order.after_pending:
		_states_by_id.erase(before_key)
		_remove_display(before_key, 0.0)

	var id := after_key

	var st: Dictionary = _states_by_id.get(id, {})
	if st.is_empty():
		st = {
			"id": order.status_id,
			"pending": bool(order.after_pending),
			"intensity": maxi(int(order.intensity), 1),
			"duration": maxi(int(order.turns_duration), 0), # <-- was 1
			"proto": proto,
		}
	else:
		st["id"] = order.status_id
		st["pending"] = bool(order.after_pending)
		st["intensity"] = maxi(int(order.intensity), 1)
		st["duration"] = maxi(int(order.turns_duration), 0) # <-- was 1
		st["proto"] = proto

	_states_by_id[id] = st
	_add_or_update_display_from_state(st, order.duration)
	_update_visuals()

func remove_status(order: StatusRemovedOrder) -> void:
	if order == null:
		return
	if int(order.target_id) != int(_owner_cid):
		return
	if order.status_id == &"":
		return

	var id := _make_state_key(order.status_id, order.pending)
	if !_states_by_id.has(id):
		return

	if bool(order.removed_all):
		_states_by_id.erase(id)
		_remove_display(id, order.duration)
		_update_visuals()
		return

	var st: Dictionary = _states_by_id[id]
	var cur := maxi(int(st.get("intensity", 1)), 1)
	var dec := maxi(int(order.intensity), 1)
	var next := cur - dec

	if next <= 0:
		_states_by_id.erase(id)
		_remove_display(id, order.duration)
	else:
		st["intensity"] = next
		_states_by_id[id] = st
		_add_or_update_display_from_state(st, order.duration)

	_update_visuals()

func clear_all(duration: float = 0.0) -> void:
	_states_by_id.clear()
	for id in _displays_by_id.keys():
		_remove_display(id, duration)
	_update_visuals()

# -------------------------
# Display plumbing
# -------------------------

func _add_or_update_display_from_state(st: Dictionary, _duration: float) -> void:
	var status_id: StringName = st.get("id", &"")
	var pending := bool(st.get("pending", false))
	var id := _make_state_key(status_id, pending)
	if status_id == &"":
		return

	var d: StatusDisplay = _displays_by_id.get(id, null)
	if d == null or !is_instance_valid(d):
		d = STATUS_DISPLAY_SCN.instantiate() as StatusDisplay
		add_child(d)
		_displays_by_id[id] = d

	var proto: Status = st.get("proto", null)
	if proto == null:
		return

	var intensity := int(st.get("intensity", 1))
	var dur := int(st.get("duration", 0))
	d.set_status_state(proto, intensity, dur, pending)

func _remove_display(id: String, duration: float) -> void:
	if !_displays_by_id.has(id):
		return
	var d: StatusDisplay = _displays_by_id[id]
	if d != null and is_instance_valid(d):
		d.set_status_state(d.status, 0, 0, false)
	_displays_by_id.erase(id)

	if d == null or !is_instance_valid(d):
		return

	if duration > 0.0:
		# cheap fade-out
		var t := d.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_property(d, "modulate:a", 0.0, duration * 0.5)
		t.tween_callback(func(): if is_instance_valid(d): d.queue_free())
	else:
		d.queue_free()

func _update_visuals() -> void:
	# For containers, this is usually what you actually want
	size = get_combined_minimum_size()
	position.x = -0.5 * size.x

func get_all_statuses() -> Array[StatusDisplay]:
	var out: Array[StatusDisplay] = []
	if _states_by_id.is_empty():
		return out

	var ids: Array = _states_by_id.keys()
	ids.sort_custom(func(a, b):
		var a_state: Dictionary = _states_by_id.get(String(a), {})
		var b_state: Dictionary = _states_by_id.get(String(b), {})
		var a_id := String(a_state.get("id", ""))
		var b_id := String(b_state.get("id", ""))
		if a_id == b_id:
			return int(a_state.get("pending", false)) < int(b_state.get("pending", false))
		return a_id < b_id
	)

	for id in ids:
		var st: Dictionary = _states_by_id.get(id, {})
		if st.is_empty():
			continue

		var d: StatusDisplay = _displays_by_id.get(id, null)
		if d == null or !is_instance_valid(d):
			continue

		out.append(d)

	return out

func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click"):
		Events.status_tooltip_requested.emit(get_all_statuses())

func _make_state_key(status_id: StringName, pending: bool) -> String:
	return "%s::%s" % [String(status_id), "pending" if pending else "realized"]
