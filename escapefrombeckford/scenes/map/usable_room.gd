class_name UsableRoom extends Area2D

signal room_selected(room: Room)

const ICONS := {
	Room.RoomType.NOT_ASSIGNED: [null, Vector2.ONE],
	Room.RoomType.BATTLE: [preload("res://assets/sprites/crossed-swords_48_w.png"), Vector2.ONE],
	Room.RoomType.TREASURE: [preload("res://assets/sprites/chest_48_w.png"), Vector2.ONE],
	Room.RoomType.REST: [preload("res://assets/sprites/campfire_48_w.png"), Vector2.ONE],
	Room.RoomType.SHOP: [preload("res://assets/sprites/village_48_w.png"), Vector2.ONE],
	Room.RoomType.BOSS: [preload("res://assets/sprites/bossskull_48_w.png"), Vector2(1.25, 1.25)]
}

@onready var sprite_2d: Sprite2D = $Visuals/Sprite2D
@onready var line_2d: Line2D = $Visuals/Line2D
@onready var animation_player = $AnimationPlayer

var room_available := false : set = set_room_available
var room: Room : set = set_room

#func _ready() -> void:
	#var test_room := Room.new()
	#test_room.type = Room.RoomType.REST
	#test_room.position = Vector2(100, 100)
	#room = test_room
	#
	#await get_tree().create_timer(1).timeout
	#room_available = true

func set_room_available(new_value: bool) -> void:
	room_available = new_value
	
	if room_available:
		animation_player.play("highlight_map_icon")
	elif !room.selected:
		animation_player.play("RESET")

func set_room(new_room: Room) -> void:
	room = new_room
	position = room.position
	line_2d.rotation_degrees = randi_range(0, 360)
	sprite_2d.texture = ICONS[room.type][0]
	sprite_2d.scale = ICONS[room.type][1]

func show_selected() -> void:
	line_2d.modulate = Color.WHITE



func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if !room_available or !event.is_action_pressed("mouse_click"):
		return
	
	room.selected = true
	animation_player.play("select_map_icon")

#Called by the AnimationPlayer when the "select_map_icon" animation finishes
func _on_usable_room_selected() -> void:
	room_selected.emit(room)
