# status_view_grid.gd

class_name StatusViewGrid extends GridContainer

const STATUS_DISPLAY_SCN := preload("res://scenes/status_handler/status_display.tscn")

# id -> StatusDisplay
var _displays_by_id: Dictionary = {}

# id -> Dictionary state {id, intensity, duration, proto}
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

	var id := order.status_id

	var st: Dictionary = _states_by_id.get(id, {})
	if st.is_empty():
		st = {
			"id": id,
			"intensity": maxi(int(order.intensity), 1),
			"duration": maxi(int(order.turns_duration), 0), # <-- was 1
			"proto": proto,
		}
	else:
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

	var id := order.status_id
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

func _add_or_update_display_from_state(st: Dictionary, duration: float) -> void:
	var id: StringName = st.get("id", &"")
	if id == &"":
		return

	var d: StatusDisplay = _displays_by_id.get(id, null)
	if d == null or !is_instance_valid(d):
		d = STATUS_DISPLAY_SCN.instantiate() as StatusDisplay
		add_child(d)
		_displays_by_id[id] = d

	var proto: Status = st.get("proto", null)
	if proto == null:
		return

	# Status has no state now, so do NOT duplicate.
	# Just assign the proto so StatusDisplay can set icon + which label is visible.
	d.status = proto

	var intensity := int(st.get("intensity", 1))
	var dur := int(st.get("duration", 0))

	# IMPORTANT: write text to whichever label is visible for this status type
	# - StatusDisplay.duration label is for NumberDisplayType.DURATION
	# - StatusDisplay.stacks label is for NumberDisplayType.INTENSITY
	if d.duration.visible:
		d.duration.text = str(dur)
	if d.stacks.visible:
		d.stacks.text = str(intensity)

	print("_add_or_update_display_from_state() int: %s, dur: %s" % [str(intensity), str(dur)])

func _remove_display(id: StringName, duration: float) -> void:
	if !_displays_by_id.has(id):
		return
	var d: StatusDisplay = _displays_by_id[id]
	d.duration.text = "0"
	d.stacks.text = "0"
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

func get_all_statuses() -> Array[Status]:
	var out: Array[Status] = []
	if _catalog == null:
		return out

	var ids: Array = _states_by_id.keys()
	ids.sort_custom(func(a, b): return String(a) < String(b))

	for id in ids:
		var st: Dictionary = _states_by_id.get(id, {})
		if st.is_empty():
			continue

		var proto: Status = st.get("proto", null)
		if proto == null:
			proto = _catalog.get_proto(StringName(id))
		if proto == null:
			continue

		out.append(proto)

	return out

func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click"):
		Events.status_tooltip_requested.emit(get_all_statuses())
