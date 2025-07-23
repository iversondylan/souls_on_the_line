class_name MapGenerator extends Node

const X_DIST := 25
const Y_DIST := 30
const PLACEMENT_RANDOMNESS := 5
const ENCOUNTERS := 15
const MAP_HEIGHT := 7
const PATHS := 6
const MONSTER_ROOM_WEIGHT := 10.0
const SHOP_ROOM_WEIGHT := 2.5
const CAMPFIRE_ROOM_WEIGHT := 4.0

var random_room_type_weights = {
	Room.RoomType.BATTLE: 0.0,
	Room.RoomType.REST: 0.0,
	Room.RoomType.SHOP: 0.0
}

var random_room_type_total_weight := 0.0
var map_data: Array[Array]

func _ready() -> void:
	make_map()

func make_map() -> Array[Array]:
	map_data = _make_empty_grid()
	var starting_points := _get_random_starting_points()
	print(str(starting_points))
	for j in starting_points:
		var current_j := j
		for i in ENCOUNTERS - 1:
			#print("current_j is %s" % current_j)
			current_j = _make_connection(i, current_j)
	
	var i:= 0
	for encounter in map_data:
		print("floor %s" % i)
		var used_rooms = encounter.filter(
			func(room: Room): return room.next_rooms.size() > 0
		)
		print(used_rooms)
		i += 1
	#print(starting_points)
	#var i := 0
	#for encounter in map_data:
		#print("encounter %s:\t%s" % [i, encounter])
		#i += 1
	
	return []

func _make_empty_grid() -> Array[Array]:
	var grid: Array[Array] = []
	for i in ENCOUNTERS:
		var adjacent_rooms: Array[Room] = []
		
		for j in MAP_HEIGHT:
			var current_room := Room.new()
			var offset := Vector2(randf(), randf()) * PLACEMENT_RANDOMNESS
			current_room.position = Vector2(i * X_DIST, j * Y_DIST) + offset
			current_room.column = i
			current_room.row = j
			current_room.next_rooms = []
			
			# Boss room has a non-random X
			if i == ENCOUNTERS - 1:
				current_room.position.x = (i + 1) * Y_DIST
			
			adjacent_rooms.push_back(current_room)
		
		grid.push_back(adjacent_rooms)
	
	return grid

func _get_random_starting_points() -> Array[int]:
	var j_coordinates: Array[int]
	var n_unique_points: int = 0
	
	while n_unique_points < 2:
		n_unique_points = 0
		j_coordinates = []
		
		for i in PATHS:
			var starting_point := randi_range(0, MAP_HEIGHT - 1)
			if !j_coordinates.has(starting_point):
				n_unique_points += 1
			
			j_coordinates.push_back(starting_point)
	
	return j_coordinates

func _make_connection(i: int, j: int) -> int:
	var next_room: Room = null
	#print("i: %s, j: %s" % [i, j])
	var current_room: Room = map_data[i][j] as Room
	while !next_room or _would_cross_existing_path(i, j, next_room):
		var random_j := clampi(randi_range(j - 1, j + 1), 0, MAP_HEIGHT - 1)
		next_room = map_data[i + 1][random_j]
	
	current_room.next_rooms.push_back(next_room)
	
	return next_room.row

func _would_cross_existing_path(i: int, j: int, room: Room) -> bool:
	var above_neighbor: Room
	var below_neighbor: Room
	
	#if j == 0, there's no above neighbor
	if j > 0:
		above_neighbor = map_data[i][j - 1]
	#if j == MAP_HEIGHT - 1, there's no below neighbor
	if j < MAP_HEIGHT - 1:
		below_neighbor = map_data[i][j + 1]
	
	#can't cross in down dir if below neighbor goes up
	if below_neighbor and room.row > j:
		for next_room: Room in below_neighbor.next_rooms:
			if next_room.row < room.row:
				return true
	
	#can't cross in up dir if above neighbor goes down
	if above_neighbor and room.row < j:
		for next_room: Room in above_neighbor.next_rooms:
			if next_room.row > room.row:
				return true
	
	return false
