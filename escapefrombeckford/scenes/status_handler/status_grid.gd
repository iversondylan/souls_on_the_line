# status_grid.gd

class_name StatusGrid extends GridContainer

signal statuses_applied(proc_type: Status.ProcType)
signal modifier_tokens_changed(type: Modifier.Type)
signal intent_conditions_changed()

const STATUS_APPLY_INTERVAL := 0.25
const STATUS_DISPLAY_SCN = preload("res://scenes/status_handler/status_display.tscn")

var status_parent: Fighter
var battle_scene: BattleScene

func _ready() -> void:
	_update_visuals()

func apply_statuses_by_type(proc_type: Status.ProcType) -> void:
	if proc_type == Status.ProcType.EVENT_BASED:
		return
	
	var status_queue: Array[Status] = _get_all_statuses().filter(
		func(status: Status):
			return status.proc_type == proc_type
	)
	if status_queue.is_empty():
		statuses_applied.emit(proc_type)
		return
	
	var tween := create_tween()
	for status: Status in status_queue:
		tween.tween_callback(status.apply_status.bind(status_parent))
		tween.tween_interval(STATUS_APPLY_INTERVAL)
	
	tween.finished.connect(func(): statuses_applied.emit(proc_type))

func get_modifier_tokens() -> Array[ModifierToken]:
	var tokens: Array[ModifierToken] = []

	for status in _get_all_statuses():
		if !status:
			continue
		if status.is_expired():
			continue
		if status.contributes_modifier():
			var ctx := status.make_token_ctx_node(status_parent)
			tokens.append_array(status.get_modifier_tokens(ctx))

	return tokens


func add_status(status: Status) -> void:
	if !status:
		return
	if status.affects_intent_legality():
		intent_conditions_changed.emit()
	# If status does not exist yet → just add it
	if !_has_status(status.get_id()):
		_add_new_status(status)
		return
	
	var existing := _get_status(status.get_id())
	if !existing:
		return
	
	match status.reapply_type:
		Status.ReapplyType.REPLACE:
			# Explicit replacement semantics
			remove_status_by_id(status.get_id())
			_add_new_status(status)
			return
		
		Status.ReapplyType.DURATION:
			if status.expiration_policy == Status.ExpirationPolicy.DURATION:
				existing.duration += status.duration
				mark_dirty_for_status(existing)
				_update_visuals()
			return
		
		Status.ReapplyType.INTENSITY:
			existing.intensity += status.intensity
			mark_dirty_for_status(existing)
			_update_visuals()
			return
		Status.ReapplyType.IGNORE:
			return
	

func _add_new_status(status: Status) -> void:
	var new_status_display := STATUS_DISPLAY_SCN.instantiate() as StatusDisplay
	add_child(new_status_display)
	
	new_status_display.status = status
	new_status_display.status_parent = status_parent
	
	status.status_changed.connect(_on_status_changed.bind(status))
	status.status_applied.connect(_on_status_applied)
	
	status.init_status(status_parent)
	
	mark_dirty_for_status(status)
	_update_visuals()


func mark_dirty_for_status(status: Status) -> void:
	if !status.contributes_modifier():
		return
	
	for mod_type in status.get_contributed_modifier_types():
		status_parent.modifier_system.mark_dirty(mod_type)
		if status.affects_others():
			modifier_tokens_changed.emit(mod_type)

func has_status(id: StringName) -> bool:
	if id == &"":
		return false
	return _has_status(String(id))

func _has_status(id: String) -> bool:
	for status_display: StatusDisplay in get_children():
		if status_display.status.get_id() == id:
			return true
	return false

func _get_status(id: String) -> Status:
	for status_display: StatusDisplay in get_children():
		if status_display.status.get_id() == id:
			return status_display.status
	return null

func _get_all_statuses() -> Array[Status]:
	var statuses: Array[Status] = []
	for status_display: StatusDisplay in get_children():
		statuses.append(status_display.status)
	return statuses

func _on_status_applied(status: Status) -> void:
	if status.expiration_policy == Status.ExpirationPolicy.DURATION:
		status.duration -= 1
	_remove_expired_statuses()
	_update_visuals()

func _update_visuals() -> void:
	reset_size()
	position.x = -0.5 * size.x

func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click"):
		Events.status_tooltip_requested.emit(_get_all_statuses())

func _on_status_changed(status: Status) -> void:
	if status.is_expired():
		_remove_expired_statuses()
		return
	if !status.contributes_modifier():
		return
	for mod_type in status.get_contributed_modifier_types():
		status_parent.modifier_system.mark_dirty(mod_type)
		if status.affects_others():
			modifier_tokens_changed.emit(mod_type)

func on_damage_taken(ctx: DamageContext) -> void:
	for status in _get_all_statuses():
		if status and status.proc_type == Status.ProcType.EVENT_BASED:
			status.on_damage_taken(ctx)

func _remove_expired_statuses() -> void:
	#print("status_grid.gd _remove_expired_statuses")
	var to_remove: Array[StatusDisplay] = []
	
	for status_display: StatusDisplay in get_children():
		var status := status_display.status
		if status and status.is_expired():
			to_remove.append(status_display)
	
	for status_display in to_remove:
		_remove_status_display(status_display)

func _remove_status_display(status_display: StatusDisplay) -> void:
	#print("status_grid.gd _remove_status_display")
	var status := status_display.status
	status.on_removed()
	remove_child(status_display)
	status_display.queue_free()
	
	if status.contributes_modifier():
		for mod_type in status.get_contributed_modifier_types():
			#print("contributing mod type: %s" % Modifier.Type.keys()[mod_type])
			status_parent.modifier_system.mark_dirty(mod_type)
			if status.affects_others():
				#print("and emitting modifier_tokens_changed")
				modifier_tokens_changed.emit(mod_type)
	if status.affects_intent_legality():
		intent_conditions_changed.emit()


## NOTE:
## StatusGrid enforces uniqueness by (status.get_id(), status_parent).
## Multiple fighters may emit the same aura, but a single fighter
## must not apply the same primary status to itself more than once.
## Intent-lifecycle statuses rely on this contract.
func remove_status_by_id(id: String) -> int:
	if id == "":
		return 0
	
	for status_display: StatusDisplay in get_children():
		if status_display.status and status_display.status.get_id() == id:
			_remove_status_display(status_display)
			_update_visuals()
			return 1
	return 0


func remove_status(id: StringName, _remove_all_stacks: bool = true) -> int:
	# currently _remove_all_stacks unused
	return remove_status_by_id(String(id))

func end_non_self_statuses() -> void:
	var to_end: Array[StatusDisplay] = []
	for status_display: StatusDisplay in get_children():
		var status := status_display.status
		if !status:
			continue
		if !status.affects_others():
			continue
		to_end.append(status_display)
	for status_display in to_end:
		_force_expire_status(status_display)
	# If ever this is used not upon death, will need to call _update_visuals()

func _force_expire_status(status_display: StatusDisplay) -> void:
	var status := status_display.status
	if !status:
		return
	
	# Force it into an expired state
	if status.expiration_policy == Status.ExpirationPolicy.DURATION:
		status.duration = 0
	else:
		# Non-expiring but non-self (e.g. aura-style permanent effects)
		# We still want proper removal + dirtying
		_remove_status_display(status_display)

func clear_group_turn_end_statuses() -> void:
	var to_remove: Array[StatusDisplay] = []
	
	for status_display: StatusDisplay in get_children():
		var status := status_display.status
		if !status:
			continue
		if status.expiration_policy == Status.ExpirationPolicy.GROUP_TURN_END:
			to_remove.append(status_display)
	
	for status_display in to_remove:
		_remove_status_display(status_display)

	_update_visuals()


func clear_group_turn_start_statuses() -> void:
	var to_remove: Array[StatusDisplay] = []
	
	for status_display: StatusDisplay in get_children():
		var status := status_display.status
		if !status:
			continue
		# If later I add GROUP_TURN_START, this is where it goes
		if status.expiration_policy == Status.ExpirationPolicy.GROUP_TURN_START:
			to_remove.append(status_display)
	
	for status_display in to_remove:
		_remove_status_display(status_display)
	
	_update_visuals()

func export_to_data() -> StatusGridData:
	var data := StatusGridData.new()
	for status: Status in _get_all_statuses():
		if !status:
			continue
		var sid := status.get_id()
		var s := StatusState.new(sid, status.duration, status.intensity)
		data.by_id[s.id] = s
	return data


func sync_from_data(data: StatusGridData, catalog: StatusCatalog) -> void:
	if !data or !catalog:
		return

	# Clear visuals + statuses
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame

	for s: StatusState in data.get_all():
		var proto := catalog.get_proto(s.id)
		if !proto:
			continue

		# Make an instance (resource copy) that holds runtime numbers
		var inst: Status = proto.duplicate()
		inst.duration = s.duration
		inst.intensity = s.intensity

		# Add using existing pipeline (creates StatusDisplay, connects signals,
		# calls init_status, marks dirty, updates visuals)
		add_status(inst)
