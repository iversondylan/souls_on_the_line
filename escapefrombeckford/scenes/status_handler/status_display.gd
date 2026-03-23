# status_display.gd

class_name StatusDisplay extends Control

@export var status: Status : set = _set_status

@onready var icon: TextureRect = $Icon
@onready var duration: Label = $Duration
@onready var stacks: Label = $Stacks

var intensity: int = 0
var turns_duration: int = 0
var status_parent: CombatantView : set = _set_status_parent

func _ready() -> void:
	Events.focused_gained.connect(_on_focused_gained)
	_refresh_display()

func _set_status(new_status: Status) -> void:
	if !is_node_ready():
		await ready

	status = new_status
	_refresh_display()

func set_status_state(new_status: Status, new_intensity: int, new_duration: int) -> void:
	if !is_node_ready():
		await ready

	status = new_status
	intensity = maxi(int(new_intensity), 0)
	turns_duration = maxi(int(new_duration), 0)
	_refresh_display()

func _refresh_display() -> void:
	if status == null or !is_node_ready():
		return

	icon.texture = status.icon
	duration.visible = status.number_display_type == Status.NumberDisplayType.DURATION
	stacks.visible = status.number_display_type == Status.NumberDisplayType.INTENSITY
	custom_minimum_size = icon.size

	duration.text = str(turns_duration)
	stacks.text = str(intensity)

	if duration.visible:
		custom_minimum_size = duration.size + duration.position
	elif stacks.visible:
		custom_minimum_size = stacks.size + stacks.position

func _set_status_parent(new_status_parent: CombatantView) -> void:
	status_parent = new_status_parent
	if status != null:
		status.status_parent = status_parent

func _on_focused_gained(marked_status: Status):
	if status == null or marked_status == null:
		return
	if marked_status.status_parent != status_parent and status.get_id() == MarkedStatus.ID:
		queue_free()
