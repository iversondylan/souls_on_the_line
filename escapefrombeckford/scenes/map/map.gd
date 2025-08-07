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
	generate_new_map()
	unlock_floor(0)
	

#do I need to make a new _input method? Maybe I can avoid scrolling

func generate_new_map() -> void:
	n_encounters_finished = 0
	map_data = map_generator.make_map()
	create_map()

func create_map() -> void:
	for current_encounter: Array in map_data:
		for room: Room in current_encounter:
			if room.next_rooms.size() > 0:
				_spawn_room(room)
	
	# Boss room has no next room but we need to spawn it
	var middle := floori(MapGenerator.MAP_HEIGHT * 0.5)
	_spawn_room(map_data[MapGenerator.ENCOUNTERS - 1][middle])
