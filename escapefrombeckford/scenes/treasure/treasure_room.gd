class_name TreasureRoom extends Control

@export var treasure_arcanum_pool: Arcana
@export var arcanum_system: ArcanaSystem
@export var player_data: PlayerData

@onready var animation_player: AnimationPlayer = %AnimationPlayer
var found_arcanum: Arcanum

func generate_arcanum() -> void:
	var available_arcana: Array[Arcanum] = player_data.possible_arcana.arcana.filter(
		func(arcanum: Arcanum):
			return !arcanum_system.has_arcanum(arcanum.id)
	)
	found_arcanum = available_arcana.pick_random()

# Called from the AnimationPlayer, at the end of the 'open' animation
func _on_treasure_opened() -> void:
	Events.treasure_room_exited.emit(found_arcanum)

func _on_texture_rect_gui_input(event: InputEvent) -> void:
	if animation_player.current_animation == 'open':
		return
	if event.is_action_pressed("mouse_click"):
		animation_player.play("open")
