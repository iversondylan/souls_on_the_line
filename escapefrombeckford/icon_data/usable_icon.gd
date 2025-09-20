class_name UsableIcon extends Control
@export var icon_data: IconData
@onready var text: Label = $Text
@onready var icon: TextureRect = $Icon

func _ready() -> void:
	pass

func load_icon_data(_icon_data: IconData):
	icon_data = _icon_data
	set_icon_values()

func set_icon_values():
	text.text = icon_data.text
	icon.set_texture(icon_data.icon)

func _process(_delta: float) -> void:
	_update_graphics()

func _update_graphics():
	if text.get_text() != icon_data.text:
		text.set_text(icon_data.text)

func _on_mouse_entered() -> void:
	Events.icon_tooltip_show_requested.emit(self as UsableIcon)


func _on_mouse_exited() -> void:
	Events.icon_tooltip_hide_requested.emit()
