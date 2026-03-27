class_name StatusEntryRow extends HBoxContainer

@export var source_display: StatusDisplay : set = _set_source_display

@onready var status_display: StatusDisplay = $StatusDisplay

@onready var description: RichTextLabel = $Description

func _set_source_display(new_source_display: StatusDisplay) -> void:
	if !is_node_ready():
		await ready
	source_display = new_source_display
	if source_display == null or source_display.status == null:
		return
	status_display.set_status_state(
		source_display.status,
		source_display.intensity,
		source_display.turns_duration
	)
	description.text = source_display.status.get_tooltip(
		source_display.intensity,
		source_display.turns_duration
	)
