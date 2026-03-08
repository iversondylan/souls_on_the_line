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

func apply_intent(planned_idx, icon_uid, icon_ranged_uid, is_ranged, intent_text, tooltip_text) -> void:
	clear_display()
	if planned_idx < 0:
		return
	var intent_data := IntentData.new()
	#@export var icon: Texture
	#@export var icon_uid: String
	#@export var base_text: String
	#@export var tooltip: String
#
	#var action: NPCAction
	#var current_text: String
	#var current_tooltip_text: String
	if icon_uid and icon_ranged_uid:
		intent_data.icon_uid = icon_ranged_uid if is_ranged else icon_uid
	elif icon_ranged_uid:
		intent_data.icon_uid = icon_ranged_uid
	else:
		intent_data.icon_uid = icon_uid
	intent_data.base_text = intent_text
	intent_data.tooltip = tooltip_text
	var intent_display : IntentDisplay = intent_display_scn.instantiate()
	h_box_container.add_child(intent_display)
	intent_display.load_icon_data(intent_data)
