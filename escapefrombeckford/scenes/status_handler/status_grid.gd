class_name StatusGrid extends GridContainer

signal statuses_applied(proc_type: Status.ProcType)

const STATUS_APPLY_INTERVAL := 0.25
const STATUS_DISPLAY_SCN = preload("res://scenes/status_handler/status_display.tscn")

var status_parent: Fighter

func _ready() -> void:
	_update_visuals()
	#var test := load("res://statuses/pinpoint.tres")
	#await get_tree().create_timer(1.5).timeout
	#add_status(test)
	#await get_tree().create_timer(1.5).timeout
	#add_status(test)
	#await get_tree().create_timer(1.5).timeout
	#_get_status(test.id).apply_status(null)
	#await get_tree().create_timer(1.5).timeout
	#_get_status(test.id).apply_status(null)

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

func add_status(status: Status) -> void:
	var stackable := status.stack_type != Status.StackType.NONE
	
	# Add it if it's new
	if !_has_status(status.id):
		var new_status_display := STATUS_DISPLAY_SCN.instantiate() as StatusDisplay
		add_child(new_status_display)
		new_status_display.status = status
		new_status_display.status.status_applied.connect(_on_status_applied)
		new_status_display.status.init_status(status_parent)
		_update_visuals()
		return
	
	# If it's unique and exists, there's no effect
	if !status.can_expire and !stackable:
		return
	
	# If it's duration-stackable, extend it
	if status.can_expire and status.stack_type == Status.StackType.DURATION:
		_get_status(status.id).duration += status.duration
		_update_visuals()
		return
	
	# If it's intensity-stackable, intensify it
	if status.stack_type == Status.StackType.INTENSITY:
		_get_status(status.id).stacks += status.stacks
		_update_visuals()

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
