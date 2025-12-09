class_name StatusGrid extends GridContainer

signal statuses_applied(proc_type: Status.ProcType)
signal modifier_tokens_changed()

const STATUS_APPLY_INTERVAL := 0.25
const STATUS_DISPLAY_SCN = preload("res://scenes/status_handler/status_display.tscn")

var status_parent: Fighter
var battle_scene: BattleScene
var inactive_aura_secondaries: Array[AuraSecondary] = []

func _ready() -> void:
	Events.auras_requested.connect(_on_auras_requested)
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

#func add_and_get_aura_secondary(status: AuraSecondary) -> AuraSecondary:
	##this currently has no safety check that the status is an aura secondary status
	#aura_registry[source] = status
	#
	#var most_intense_status: Status = null
	#
	#for key in aura_registry:
		#if !most_intense_status and (aura_registry[key] as Status).id == status.id:
			#most_intense_status = aura_registry[key]
		#elif aura_registry[key] > most_intense_status and (aura_registry[key] as Status).id == status.id:
			#most_intense_status = aura_registry[key]
	#return most_intense_status

func get_aura_primaries() -> Array[Status]:
	var aura_primaries: Array[Status] = []
	for status_display: StatusDisplay in get_children():
		if status_display.status is AuraPrimary:
			aura_primaries.push_back(status_display.status)
	return aura_primaries

func get_modifier_tokens() -> Array[ModifierToken]:
	var tokens: Array[ModifierToken] = []
	
	for status in _get_all_statuses():
		if status and status.contributes_modifier():
			tokens.append_array(status.get_modifier_tokens())
	if tokens:
		print("status_grid.gd get_modifier_tokens tokens: %s" % tokens[0].source_id)
	#else:
		#print("status_grid.gd get_modifier_tokens no tokens")
	return tokens

func add_status(status: Status) -> void:
	
	#status.battle_scene = battle_scene
	var stackable := status.stack_type != Status.StackType.NONE
	
	# Add it if it's new
	if !_has_status(status.id):
		var new_status_display := STATUS_DISPLAY_SCN.instantiate() as StatusDisplay
		add_child(new_status_display)
		new_status_display.status = status
		new_status_display.status_parent = status_parent
		new_status_display.status.status_applied.connect(_on_status_applied)
		new_status_display.status.init_status(status_parent)
		_update_visuals()
		return
	elif status is AuraSecondary:
		add_or_replace_aura_secondary(status)
		var most_intense_aura_secondary := get_most_intense_aura_secondary(status)
		reconfigure_aura_secondaries_and_init(most_intense_aura_secondary)
	
	# If it's unique and exists, there's no effect
	if !status.can_expire and !stackable:
		return
	
	# If it's an aura secondary, intensity must be replaced, not added
	# and only the most intense should be active and visible
	if status is AuraSecondary:
		_get_status(status.id).intensity = status.intensity
		_update_visuals()
		return
	
	# If it's duration-stackable, extend it
	if status.can_expire and status.stack_type == Status.StackType.DURATION:
		_get_status(status.id).duration += status.duration
		_update_visuals()
		return
	
	# If it's intensity-stackable, intensify it
	if status.stack_type == Status.StackType.INTENSITY:
		_get_status(status.id).intensity += status.intensity
		_update_visuals()

func get_most_intense_aura_secondary(new_aura_secondary: AuraSecondary) -> AuraSecondary:
	var most_intense_aura_secondary: AuraSecondary = new_aura_secondary
	for aura_secondary in inactive_aura_secondaries:
		if new_aura_secondary.id == new_aura_secondary.id and aura_secondary.intensity > most_intense_aura_secondary.intensity:
			most_intense_aura_secondary = aura_secondary
	for status_display: StatusDisplay in get_children():
		if status_display.status.id == new_aura_secondary.id and status_display.status.intensity > most_intense_aura_secondary.intensity:
			most_intense_aura_secondary = status_display.status
	return most_intense_aura_secondary

func add_or_replace_aura_secondary(new_aura_secondary: AuraSecondary) -> void:
	var auras_with_same_source: Array[AuraSecondary] = []
	for aura_secondary in inactive_aura_secondaries:
		if aura_secondary.source == new_aura_secondary.source:
			auras_with_same_source.push_back(aura_secondary)
	for aura_secondary in auras_with_same_source:
		inactive_aura_secondaries.erase(aura_secondary)
	
	var status_display_with_this_aura := get_status_display_with_this_aura_id(new_aura_secondary)
	if new_aura_secondary.source == (status_display_with_this_aura.status as AuraSecondary).source:
		status_display_with_this_aura.status = new_aura_secondary
	else:
		inactive_aura_secondaries.push_back(new_aura_secondary)

func get_status_display_with_this_aura_id(aura_secondary: AuraSecondary) -> StatusDisplay:
	var status_display_with_this_aura: StatusDisplay = null
	for status_dislay: StatusDisplay in get_children():
		if !status_dislay.status:
			continue
		if status_dislay.status.id == aura_secondary.id:
			assert(not status_display_with_this_aura, "status_grid.gd reconfigure_aura_secondaries() ERROR: there are multiple status displays of this status id")
			status_display_with_this_aura = status_dislay
	return status_display_with_this_aura

func reconfigure_aura_secondaries_and_init(most_intense_aura_secondary: AuraSecondary) -> void:
	var status_display_with_this_aura := get_status_display_with_this_aura_id(most_intense_aura_secondary)
	if most_intense_aura_secondary == status_display_with_this_aura.status:
		status_display_with_this_aura.status.init_status(status_parent)
		return
	inactive_aura_secondaries.erase(most_intense_aura_secondary)
	status_display_with_this_aura.status = most_intense_aura_secondary
	status_display_with_this_aura.status.init_status(status_parent)

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
	if status.can_expire:
		status.duration -= 1
	_update_visuals()

func _update_visuals() -> void:
	reset_size()
	position.x = -0.5 * size.x

func _on_auras_requested(requester: Fighter) -> void:
	for aura_primary: Status in get_aura_primaries():
		requester.on_aura_changed(status_parent, aura_primary)


func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click"):
		Events.status_tooltip_requested.emit(_get_all_statuses())

func _on_status_changed(_status: Status) -> void:
	if status_parent and status_parent.modifier_system:
		status_parent.modifier_system.mark_dirty()
