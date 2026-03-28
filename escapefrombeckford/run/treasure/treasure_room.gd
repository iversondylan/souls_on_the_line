class_name TreasureRoom extends Control

@export var treasure_arcanum_pool: Arcana
@export var player_data: PlayerData

@onready var animation_player: AnimationPlayer = %AnimationPlayer
var found_arcanum: Arcanum

func set_found_arcanum(arcanum: Arcanum) -> void:
	found_arcanum = arcanum

# Called from the AnimationPlayer, at the end of the 'open' animation
func _on_treasure_opened() -> void:
	Events.treasure_room_exited.emit(found_arcanum)

func _on_texture_rect_gui_input(event: InputEvent) -> void:
	if animation_player.current_animation == 'open':
		return
	if event.is_action_pressed("mouse_click"):
		animation_player.play("open")
