class_name IntentDisplay extends Control
@export var intent_data: IntentData
@onready var text: Label = $Text
@onready var icon: TextureRect = $Icon

func _ready() -> void:
	pass

func load_icon_data(_intent_data: IntentData):
	intent_data = _intent_data
	set_icon_values()

func set_icon_values():
	#print("intent_display.gd set_icon_values() text: %s" % intent_data.base_text)
	text.text = intent_data.base_text
	icon.set_texture(intent_data.icon)

#func _process(_delta: float) -> void:
	#_update_graphics()
#
#func _update_graphics():
	#if text.get_text() != intent_data.text:
		#text.set_text(intent_data.text)

func _on_mouse_entered() -> void:
	Events.icon_tooltip_show_requested.emit(self as IntentDisplay)


func _on_mouse_exited() -> void:
	Events.icon_tooltip_hide_requested.emit()
