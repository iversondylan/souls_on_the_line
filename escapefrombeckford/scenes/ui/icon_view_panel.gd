class_name IconViewPanel extends Node2D

#@onready var icon_container_scn: PackedScene = preload("res://scenes/ui/icon_container.tscn")
@onready var intent_display_scn = preload("res://intents/intent_display.tscn")
#@onready var usable_card_scn: PackedScene = preload("res://scenes/cards/UsableCard.tscn")
@onready var h_box_container = $HBoxContainer

func _ready() -> void:
	pass
	#$ColorRect.set_size($ScrollContainer.size)
	#$ColorRect.set_position($ScrollContainer.position)

func clear_display():
	for child in h_box_container.get_children():
		child.queue_free()

func display_icons(intent_dataz: Array[IntentData]):
	clear_display()
	for intent_data: IntentData in intent_dataz:
		var intent_display : IntentDisplay = intent_display_scn.instantiate()
		h_box_container.add_child(intent_display)
		intent_display.load_icon_data(intent_data)

#func display_icons_from_data(intent_dataz: Array[IntentData]) -> void:
	#clear_display()
	#for intent_data: IntentData in intent_dataz:
		#var intent_display = intent_display_scn.instantiate()
		#h_box_container.add_child(intent_display)
		#intent_display.load_icon_data(intent_data)
