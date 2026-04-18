# arcanum_display.gd

class_name ArcanumDisplay extends Control

@export var arcanum: Arcanum : set = _set_arcanum

@onready var icon: TextureRect = $Icon
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _set_arcanum(new_arcanum: Arcanum) -> void:
	if !is_node_ready():
		await ready
	arcanum = new_arcanum
	# Legacy convenience for older run-level modifier/live paths.
	# Sim battle activation should not depend on this mutable display reference.
	arcanum.arcanum_display = self
	icon.texture = arcanum.icon

func flash() -> void:
	animation_player.play("flash")

func _exit_tree() -> void:
	Events.tooltip_source_exited.emit(self)

func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click"):
		Events.arcanum_popup_requested.emit(arcanum)

func _on_mouse_entered() -> void:
	Events.tooltip_source_entered.emit(self, _build_tooltip_request())

func _on_mouse_exited() -> void:
	Events.tooltip_source_exited.emit(self)

func _build_tooltip_request() -> TooltipRequest:
	var request := TooltipRequest.new()
	request.anchor_control = self
	request.anchor_rect = get_global_rect()
	request.icon_uid = arcanum.icon.resource_path if arcanum != null and arcanum.icon != null else ""
	request.text_bbcode = arcanum.get_tooltip() if arcanum != null else ""
	return request
