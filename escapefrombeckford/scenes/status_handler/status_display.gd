class_name StatusDisplay extends Control

@export var status: Status : set = _set_status

@onready var icon: TextureRect = $Icon
@onready var duration: Label = $Duration
@onready var intensity: Label = $Stacks

var status_parent: Fighter : set = _set_status_parent

func _ready() -> void:
	Events.focused_gained.connect(_on_focused_gained)

func _set_status(new_status) -> void:
	if !is_node_ready():
		await ready
	
	status = new_status
	icon.texture = status.icon
	duration.visible = status.number_display_type == Status.NumberDisplayType.DURATION
	intensity.visible = status.number_display_type == Status.NumberDisplayType.INTENSITY
	custom_minimum_size = icon.size
	
	if duration.visible:
		custom_minimum_size = duration.size + duration.position
	elif intensity.visible:
		custom_minimum_size = intensity.size + intensity.position
	
	if !status.status_changed.is_connected(_on_status_changed):
		status.status_changed.connect(_on_status_changed)
	
	_on_status_changed()

func _set_status_parent(new_status_parent: Fighter) -> void:
	status_parent = new_status_parent
	status.status_parent = status_parent

func _on_status_changed() -> void:
	if !status:
		return
	
	#if status.can_expire and status.duration <= 0:
		#queue_free()
	#
	#if status.stack_type == Status.StackType.INTENSITY and status.intensity == 0:
		#queue_free()
	
	duration.text = str(status.duration)
	intensity.text = str(status.intensity)

func _on_focused_gained(focused_status: Status):
	if focused_status.status_parent != status_parent and status.id == MarkedStatus.MARKED_ID:
		queue_free()
