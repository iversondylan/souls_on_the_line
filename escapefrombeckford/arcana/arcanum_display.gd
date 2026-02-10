# arcanum_display.gd

class_name ArcanumDisplay extends Control

@export var arcanum: Arcanum : set = _set_arcanum

@onready var icon: TextureRect = $Icon
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _set_arcanum(new_arcanum: Arcanum) -> void:
	if !is_node_ready():
		await ready
	arcanum = new_arcanum
	arcanum.arcanum_display = self
	icon.texture = arcanum.icon

func flash() -> void:
	animation_player.play("flash")

func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click"):
		Events.arcanum_popup_requested.emit(arcanum)

func _on_mouse_entered() -> void:
	Events.arcanum_tooltip_show_requested.emit(self as ArcanumDisplay)

func _on_mouse_exited() -> void:
	Events.tooltip_hide_requested.emit()
