# map.gd

class_name Map extends Node2D

const SCROLL_SPEED := 15
const USABLE_ROOM = preload("res://scenes/map/usable_room.tscn")
const MAP_LINE = preload("res://scenes/map/map_line.tscn")

@onready var map_generator: MapGenerator = $MapGenerator
@onready var lines: Node2D = %Lines
@onready var rooms: Node2D = %Rooms
@onready var visuals: Node2D = $Visuals
@onready var camera_2d: Camera2D = $Camera2D

var map_data: Array[Array]
var n_encounters_finished: int
var last_room: Room
var camera_edge_x: float

func _ready() -> void:
	#camera_edge_x = MapGenerator.X_DIST * (MapGenerator.ENCOUNTERS - 1)
	pass
	

#do I need to make a new _input method? Maybe I can avoid scrolling

func generate_new_map(rng: RNG) -> void:
	n_encounters_finished = 0
	map_data = map_generator.make_map(rng)
	create_map()

func create_map() -> void:
	for current_encounter: Array in map_data:
		for room: Room in current_encounter:
			if room.next_rooms.size() > 0:
				_spawn_room(room)
	
	# Boss room has no next room but we need to spawn it
	var middle := floori(MapGenerator.MAP_HEIGHT * 0.5)
	_spawn_room(map_data[MapGenerator.ENCOUNTERS - 1][middle])
	
	#Simplifying this becaue I don't want scrolling
	var map_width_pixels := MapGenerator.X_DIST * (MapGenerator.ENCOUNTERS - 1)
	var map_height_pixels := MapGenerator.Y_DIST * (MapGenerator.MAP_HEIGHT - 1)
	visuals.position.x = (get_viewport_rect().size.x - map_width_pixels) / 2
	visuals.position.y = (get_viewport_rect().size.y - map_height_pixels) / 2

func unlock_encounter_column(column_number: int = n_encounters_finished) -> void:
	for usable_room: UsableRoom in rooms.get_children():
		if usable_room.room.column == column_number:
			usable_room.room_available = true

func unlock_next_rooms() -> void:
	for usable_room: UsableRoom in rooms.get_children():
		if last_room.next_rooms.has(usable_room.room):
			usable_room.room_available = true

func show_map() -> void:
	show()
	camera_2d.enabled = true

func hide_map() -> void:
	hide()
	camera_2d.enabled = false

func _spawn_room(room: Room) -> void:
	var new_usable_room := USABLE_ROOM.instantiate() as UsableRoom
	rooms.add_child(new_usable_room)
	new_usable_room.room = room
	new_usable_room.room_selected.connect(_on_usable_room_selected)
	_draw_lines(room)
	
	if room.selected and room.column < n_encounters_finished:
		new_usable_room.show_selected()

func _draw_lines(room: Room) -> void:
	if room.next_rooms.is_empty():
		return
	
	for next_room: Room in room.next_rooms:
		var new_map_line := MAP_LINE.instantiate() as Line2D
		new_map_line.add_point(room.position)
		new_map_line.add_point(next_room.position)
		lines.add_child(new_map_line)

func _on_usable_room_selected(room: Room) -> void:
	for usable_room: UsableRoom in rooms.get_children():
		if usable_room.room.column == room.column:
			usable_room.room_available = false
	
	last_room = room
	n_encounters_finished += 1
	Events.map_exited.emit(room)
