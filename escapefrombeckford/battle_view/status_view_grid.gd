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
			"duration": maxi(int(order.turns_duration), 0),
			"proto": proto,
		}
	else:
		# View-side policy: just set to whatever SIM says.
		# (You can later mimic reapply rules if you want, but SIM already resolved it.)
		st["intensity"] = maxi(int(order.intensity), 1)
		st["duration"] = maxi(int(order.turns_duration), 0)
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

	# Partial remove: decrease intensity.
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

	# IMPORTANT: StatusDisplay expects a Status resource and listens to status_changed,
	# which we *don't* want to rely on.
	# So we give it a *duplicate* proto and set values, then we call its update method.
	var proto: Status = st.get("proto", null)
	if proto == null:
		return

	var view_status := proto.duplicate(true) as Status
	view_status.intensity = int(st.get("intensity", 1))
	view_status.duration = int(st.get("duration", 0))

	d.status = view_status

	# Optional: you can tween icon scale/alpha here based on duration (punch-in).
	# Keep it simple for now.

func _remove_display(id: StringName, duration: float) -> void:
	if !_displays_by_id.has(id):
		return
	var d: StatusDisplay = _displays_by_id[id]
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
	print("status_view_grid.gd get_all_statuses()")
	var out: Array[Status] = []
	if _catalog == null:
		return out

	# Stable order (optional but nice): sort by id string
	var ids: Array = _states_by_id.keys()
	ids.sort_custom(func(a, b):
		return String(a) < String(b)
	)

	for id in ids:
		var st: Dictionary = _states_by_id.get(id, {})
		if st.is_empty():
			continue

		var sid: StringName = st.get("id", &"")
		if sid == &"":
			continue

		# Prefer cached proto, but fall back to catalog lookup
		var proto: Status = st.get("proto", null)
		if proto == null:
			proto = _catalog.get_proto(sid)
		if proto == null:
			continue
	
		var view_status := proto.duplicate(true) as Status
		view_status.intensity = int(st.get("intensity", 1))
		view_status.duration = int(st.get("duration", 0))

		# Optional: if your tooltip logic expects status_parent sometimes, you can set it later.
		# view_status.status_parent = null

		out.append(view_status)

	return out

func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click"):
		Events.status_tooltip_requested.emit(get_all_statuses())
