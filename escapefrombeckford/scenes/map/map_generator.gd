class_name MapGenerator extends Node

const X_DIST := 100
const Y_DIST := 120
const PLACEMENT_RANDOMNESS := 5
const ENCOUNTERS := 15
const MAP_HEIGHT := 7
const PATHS := 6
const BATTLE_ROOM_WEIGHT := 10.0
const SHOP_ROOM_WEIGHT := 2.5
const REST_ROOM_WEIGHT := 4.0

@export var battle_pool: BattlePool

var random_room_type_weights = {
	Room.RoomType.BATTLE: 0.0,
	Room.RoomType.REST: 0.0,
	Room.RoomType.SHOP: 0.0
}

var random_room_type_total_weight := 0.0
var map_data: Array[Array]

#func _ready() -> void:
	#make_map()

func make_map() -> Array[Array]:
	map_data = _make_empty_grid()
	var starting_points := _get_random_starting_points()
	#print(str(starting_points))
	for j in starting_points:
		var current_j := j
		for i in ENCOUNTERS - 1:
			#print("current_j is %s" % current_j)
			current_j = _make_connection(i, current_j)
	
	battle_pool.init_weights()
	
	_make_boss_room()
	_make_random_room_weights()
	_make_room_types()
	
	#var i:= 0
	#for encounter in map_data:
		#print("floor %s" % i)
		#var used_rooms = encounter.filter(
			#func(room: Room): return room.next_rooms.size() > 0
		#)
		#print(used_rooms)
		#i += 1
	#print(starting_points)
	#var i := 0
	#for encounter in map_data:
		#print("encounter %s:\t%s" % [i, encounter])
		#i += 1
	
	return map_data

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
				current_room.position.x = (i + 1) * X_DIST
			
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

func _make_boss_room() -> void:
	var middle_index := floori(MAP_HEIGHT * 0.5)
	var boss_room := map_data[ENCOUNTERS - 1][middle_index] as Room
	
	for j in MAP_HEIGHT:
		var current_room = map_data[ENCOUNTERS - 2][j] as Room
		if current_room.next_rooms:
			current_room.next_rooms = [] as Array[Room]
			current_room.next_rooms.push_back(boss_room)
	
	boss_room.type = Room.RoomType.BOSS
	boss_room.battle_data = battle_pool.get_random_battle_for_tier(2)
	
func _make_random_room_weights() -> void:
	random_room_type_weights[Room.RoomType.BATTLE] = BATTLE_ROOM_WEIGHT
	random_room_type_weights[Room.RoomType.REST] = BATTLE_ROOM_WEIGHT + REST_ROOM_WEIGHT
	random_room_type_weights[Room.RoomType.SHOP] = BATTLE_ROOM_WEIGHT + REST_ROOM_WEIGHT + SHOP_ROOM_WEIGHT
	
	random_room_type_total_weight = random_room_type_weights[Room.RoomType.SHOP]

func _make_room_types() -> void:
	#first room is always a battle
	for room: Room in map_data[0]:
		if room.next_rooms.size() > 0:
			room.type = Room.RoomType.BATTLE
			room.battle_data = battle_pool.get_random_battle_for_tier(0)
	#9th floor is always a treasure
	for room: Room in map_data[8]:
		if room.next_rooms.size() > 0:
			room.type = Room.RoomType.TREASURE
	#room before boss is always a rest area
	for room: Room in map_data[ENCOUNTERS - 2]:
		if room.next_rooms.size() > 0:
			room.type = Room.RoomType.REST
	
	#rest of rooms
	for encounter_stage in map_data:
		for room: Room in encounter_stage:
			for next_room: Room in room.next_rooms:
				if next_room.type == Room.RoomType.NOT_ASSIGNED:
					_set_weighted_room_type(next_room)

func _set_weighted_room_type(room_to_set: Room) -> void:
	var rest_below_4 := true
	var consecutive_rest := true
	var consecutive_shop := true
	var rest_on_13 := true
	
	var type_candidate: Room.RoomType
	
	while rest_below_4 or consecutive_rest or consecutive_shop or rest_on_13:
		type_candidate = _get_random_room_type_by_weight()
		
		var is_rest := type_candidate == Room.RoomType.REST
		var has_rest_parent := _room_has_parent_of_type(room_to_set, Room.RoomType.REST)
		var is_shop := type_candidate == Room.RoomType.SHOP
		var has_shop_parent := _room_has_parent_of_type(room_to_set, Room.RoomType.SHOP)
		
		rest_below_4 = is_rest and room_to_set.column < 3
		consecutive_rest = is_rest and has_rest_parent
		consecutive_shop = is_shop and has_shop_parent
		rest_on_13 = is_rest and room_to_set.column == 12
	
	room_to_set.type = type_candidate
	
	if type_candidate == Room.RoomType.BATTLE:
		var tier_for_battle_rooms := 0
		
		if room_to_set.row > 2:
			tier_for_battle_rooms = 1
		
		room_to_set.battle_data = battle_pool.get_random_battle_for_tier(tier_for_battle_rooms)

func _room_has_parent_of_type(room: Room, type: Room.RoomType) -> bool:
	var parents: Array[Room] = []
	#above parent
	if room.row > 0 and room.column > 0:
		var parent_candidate := map_data[room.column - 1][room.row -1] as Room
		if parent_candidate.next_rooms.has(room):
			parents.push_back(parent_candidate)
	#middle parent
	if room.column > 0:
		var parent_candidate := map_data[room.column - 1][room.row] as Room
		if parent_candidate.next_rooms.has(room):
			parents.push_back(parent_candidate)
	#below parent
	if room.row < MAP_HEIGHT-1 and room.column > 0:
		var parent_candidate := map_data[room.column - 1][room.row + 1] as Room
		if parent_candidate.next_rooms.has(room):
			parents.push_back(parent_candidate)
	
	for parent: Room in parents:
		if parent.type == type:
			return true
	
	return false

func _get_random_room_type_by_weight() -> Room.RoomType:
	var roll := randf_range(0.0, random_room_type_total_weight)
	
	for type: Room.RoomType in random_room_type_weights:
		if random_room_type_weights[type] > roll:
			return type
	
	return Room.RoomType.BATTLE
