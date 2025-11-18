class_name StatusView extends Control

const STATUS_TOOLTIP_SCN = preload("res://scenes/ui/status_tooltip.tscn")

@onready var status_vbox: VBoxContainer = %StatusVBox

func _ready() -> void:
	for tooltip: StatusTooltip in status_vbox.get_children():
		tooltip.queue_free()
	Events.status_tooltip_requested.connect(show_view)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		hide_view()

func show_view(statuses: Array[Status]) -> void:
	for status: Status in statuses:
		var new_status_tooltip := STATUS_TOOLTIP_SCN.instantiate() as StatusTooltip
		status_vbox.add_child(new_status_tooltip)
		new_status_tooltip.status = status
	show()

func hide_view() -> void:
	for tooltip: StatusTooltip in status_vbox.get_children():
		tooltip.queue_free()
	hide()

func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click") and visible:
		hide_view()


func _on_back_button_pressed() -> void:
	hide_view()
