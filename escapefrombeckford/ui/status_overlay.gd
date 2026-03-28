class_name StatusOverlay extends Control

const STATUS_ENTRY_ROW_SCN = preload("uid://buo1rmesoj57w")

@onready var status_vbox: VBoxContainer = %StatusVBox

func _ready() -> void:
	_clear_rows()
	Events.status_tooltip_requested.connect(show_view)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		hide_view()

func show_view(statuses: Array[StatusDisplay]) -> void:
	_clear_rows()
	for status_display: StatusDisplay in statuses:
		var new_status_entry_row := STATUS_ENTRY_ROW_SCN.instantiate() as StatusEntryRow
		status_vbox.add_child(new_status_entry_row)
		new_status_entry_row.source_display = status_display
	show()

func hide_view() -> void:
	_clear_rows()
	hide()

func _clear_rows() -> void:
	for row: StatusEntryRow in status_vbox.get_children():
		row.queue_free()

func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click") and visible:
		hide_view()


func _on_back_button_pressed() -> void:
	hide_view()
