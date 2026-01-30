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
			print("status_grid.gd a nonexistent status is being skipped")
			continue
		if status.is_expired():
			print("status_grid.gd an expired status is being skipped")
			continue
		if status and status.contributes_modifier():
			tokens.append_array(status.get_modifier_tokens())
	return tokens


#func add_status(status: Status) -> void:
	#
	#var stackable := status.stack_type != Status.StackType.NONE
	#
	#if !_has_status(status.id):
		#var new_status_display := STATUS_DISPLAY_SCN.instantiate() as StatusDisplay
		#add_child(new_status_display)
		#new_status_display.status = status
		#new_status_display.status.status_changed.connect(_on_status_changed.bind(new_status_display.status))
		#new_status_display.status_parent = status_parent
		#new_status_display.status.status_applied.connect(_on_status_applied)
		#new_status_display.status.init_status(status_parent)
		#mark_dirty_for_status(status)
		#_update_visuals()
		#return
	#if status.expiration_policy != Status.ExpirationPolicy.DURATION and !stackable:
		#return
	#
	#if status.expiration_policy == Status.ExpirationPolicy.DURATION and status.stack_type == Status.StackType.DURATION:
		#_get_status(status.id).duration += status.duration
		#mark_dirty_for_status(status)
		#_update_visuals()
		#return
	#
	## If it's intensity-stackable, intensify it
	#if status.stack_type == Status.StackType.INTENSITY:
		#_get_status(status.id).intensity += status.intensity
		#mark_dirty_for_status(status)
		#_update_visuals()

func add_status(status: Status) -> void:
	if !status:
		return
	if status.affects_intent_legality():
		intent_conditions_changed.emit()
	# If status does not exist yet → just add it
	if !_has_status(status.id):
		_add_new_status(status)
		return
	
	var existing := _get_status(status.id)
	if !existing:
		return
	
	match status.reapply_type:
		Status.ReapplyType.REPLACE:
			# Explicit replacement semantics
			remove_status_by_id(status.id)
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

func _has_status(id: String) -> bool:
	for status_display: StatusDisplay in get_children():
		if status_display.status.id == id:
			return true
	return false

func _get_status(id: String) -> Status:
	for status_display: StatusDisplay in get_children():
		if status_display.status.id == id:
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
## StatusGrid enforces uniqueness by (status.id, status_parent).
## Multiple fighters may emit the same aura, but a single fighter
## must not apply the same primary status to itself more than once.
## Intent-lifecycle statuses rely on this contract.
func remove_status_by_id(id: String) -> void:
	if id == "":
		return
	
	for status_display: StatusDisplay in get_children():
		if status_display.status and status_display.status.id == id:
			_remove_status_display(status_display)
			_update_visuals()
			return


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
		# If you later add GROUP_TURN_START, this is where it goes
		if status.expiration_policy == Status.ExpirationPolicy.GROUP_TURN_START:
			to_remove.append(status_display)
	
	for status_display in to_remove:
		_remove_status_display(status_display)
	
	_update_visuals()
