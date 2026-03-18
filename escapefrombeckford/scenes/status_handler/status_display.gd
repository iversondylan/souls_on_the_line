# status_display.gd

class_name StatusDisplay extends Control

@export var status: Status : set = _set_status

@onready var icon: TextureRect = $Icon
@onready var duration: Label = $Duration
@onready var stacks: Label = $Stacks

var status_parent: CombatantView : set = _set_status_parent

func _ready() -> void:
	Events.focused_gained.connect(_on_focused_gained)

func _set_status(new_status) -> void:
	if !is_node_ready():
		await ready
	
	status = new_status
	icon.texture = status.icon
	duration.visible = status.number_display_type == Status.NumberDisplayType.DURATION
	stacks.visible = status.number_display_type == Status.NumberDisplayType.INTENSITY
	custom_minimum_size = icon.size
	
	if duration.visible:
		custom_minimum_size = duration.size + duration.position
	elif stacks.visible:
		custom_minimum_size = stacks.size + stacks.position

func _set_status_parent(new_status_parent: CombatantView) -> void:
	status_parent = new_status_parent
	status.status_parent = status_parent

func _on_focused_gained(marked_status: Status):
	if marked_status.status_parent != status_parent and status.get_id() == MarkedStatus.ID:
		queue_free()
