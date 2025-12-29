class_name IntentContainer extends Node2D

@onready var intent_display_scn = preload("res://intents/intent_display.tscn")
@onready var h_box_container = $HBoxContainer

func _ready() -> void:
	pass

func clear_display() -> void:
	for child in h_box_container.get_children():
		h_box_container.remove_child(child) # important: immediate layout update
		child.queue_free()

func display_icons(intent_dataz: Array[IntentData]):
	clear_display()
	for intent_data: IntentData in intent_dataz:
		var intent_display : IntentDisplay = intent_display_scn.instantiate()
		h_box_container.add_child(intent_display)
		intent_display.load_icon_data(intent_data)
