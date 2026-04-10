# status_view_grid.gd

class_name StatusViewGrid extends VBoxContainer

const STATUS_DISPLAY_SCN := preload("uid://cd15ukicbp7fj")
const STATUS_ROW_SCN := preload("res://battle/view/scenes/status_view_row.tscn")
const MAX_PER_ROW := 6
const STATUS_SLOT_WIDTH := 68.0
const STATUS_ROW_HEIGHT := 68.0
const ROW_H_SEPARATION := 4
const ROW_V_SEPARATION := 2
const FIXED_ROW_WIDTH := (STATUS_SLOT_WIDTH * MAX_PER_ROW) + (ROW_H_SEPARATION * (MAX_PER_ROW - 1))

# lane-key -> StatusDisplay
var _displays_by_id: Dictionary = {}

# lane-key -> Dictionary state {id, pending, intensity, duration, proto}
var _states_by_id: Dictionary = {}

var _rows: Array[HBoxContainer] = []
var _owner_cid: int = 0
var _catalog: StatusCatalog = null

func _ready() -> void:
	add_theme_constant_override("separation", ROW_V_SEPARATION)
	_ensure_min_row_count(1)
	_rebuild_rows()

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
	_rebuild_rows()

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
		_rebuild_rows()
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

	_rebuild_rows()

func clear_all(duration: float = 0.0) -> void:
	_states_by_id.clear()
	for id in _displays_by_id.keys():
		_remove_display(id, duration)
	_rebuild_rows()

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
		_ensure_min_row_count(1)
		_rows[0].add_child(d)
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

	var old_global := d.global_position
	var old_size := d.size
	var old_parent := d.get_parent()
	if old_parent != null:
		old_parent.remove_child(d)

	if duration > 0.0:
		var fade_parent := get_parent()
		if fade_parent == null:
			d.queue_free()
			return

		fade_parent.add_child(d)
		d.global_position = old_global
		d.size = old_size
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# cheap fade-out
		var t := d.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_property(d, "modulate:a", 0.0, duration * 0.5)
		t.tween_callback(func(): if is_instance_valid(d): d.queue_free())
	else:
		d.queue_free()

func _rebuild_rows() -> void:
	var ids := _get_ordered_state_ids()
	var needed_rows := maxi(1, int(ceil(float(ids.size()) / float(MAX_PER_ROW))))
	_ensure_min_row_count(needed_rows)

	for i in ids.size():
		var id := String(ids[i])
		var row_index := int(i / MAX_PER_ROW)
		var child_index := int(i % MAX_PER_ROW)
		var row := _rows[row_index]
		var d: StatusDisplay = _displays_by_id.get(id, null)
		if d == null or !is_instance_valid(d):
			continue

		if d.get_parent() != row:
			var parent := d.get_parent()
			if parent != null:
				parent.remove_child(d)
			row.add_child(d)
		row.move_child(d, child_index)

	_trim_row_count(needed_rows)
	for i in _rows.size():
		_rows[i].visible = ids.size() > 0 or i == 0

	_update_visuals(needed_rows)

func _ensure_min_row_count(count: int) -> void:
	while _rows.size() < count:
		var row := STATUS_ROW_SCN.instantiate() as HBoxContainer
		_configure_row(row)
		add_child(row)
		_rows.append(row)

func _trim_row_count(count: int) -> void:
	while _rows.size() > count:
		var row := _rows.pop_back() as HBoxContainer
		if row == null or !is_instance_valid(row):
			continue
		for child in row.get_children():
			row.remove_child(child)
		row.queue_free()

func _configure_row(row: HBoxContainer) -> void:
	row.custom_minimum_size = Vector2(FIXED_ROW_WIDTH, STATUS_ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", ROW_H_SEPARATION)

func _update_visuals(row_count: int) -> void:
	var visual_rows := maxi(row_count, 1)
	var total_height := (STATUS_ROW_HEIGHT * visual_rows) + (ROW_V_SEPARATION * maxi(visual_rows - 1, 0))
	custom_minimum_size = Vector2(FIXED_ROW_WIDTH, total_height)
	size = custom_minimum_size
	position.x = -0.5 * size.x

func get_all_statuses() -> Array[StatusDisplay]:
	var out: Array[StatusDisplay] = []
	if _states_by_id.is_empty():
		return out

	var ids := _get_ordered_state_ids()
	for id in ids:
		var st: Dictionary = _states_by_id.get(id, {})
		if st.is_empty():
			continue

		var d: StatusDisplay = _displays_by_id.get(id, null)
		if d == null or !is_instance_valid(d):
			continue

		out.append(d)

	return out

func _get_ordered_state_ids() -> Array:
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
	return ids

func _on_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	if !mb.pressed:
		return
	if int(mb.button_index) != int(MOUSE_BUTTON_LEFT):
		return

	var displays := get_all_statuses()
	if displays.is_empty():
		return
	if !_has_display_under_pointer(displays):
		return

	Events.status_tooltip_requested.emit(displays)
	accept_event()


func _has_display_under_pointer(displays: Array[StatusDisplay]) -> bool:
	var mouse_pos := get_global_mouse_position()
	for display in displays:
		if display == null or !is_instance_valid(display):
			continue
		if display.get_global_rect().has_point(mouse_pos):
			return true
	return false

func _make_state_key(status_id: StringName, pending: bool) -> String:
	return "%s::%s" % [String(status_id), "pending" if pending else "realized"]
