# map.gd

class_name Map extends Node2D

const SCROLL_SPEED := 15
const USABLE_ROOM = preload("uid://chlyh1tfceais")
const MAP_LINE = preload("uid://8mr0wyv43d4t")

@onready var map_generator: MapGenerator = $MapGenerator
@onready var lines: Node2D = %Lines
@onready var rooms: Node2D = %Rooms
@onready var visuals: Node2D = $Visuals
@onready var camera_2d: Camera2D = $Camera2D

var map_data: Array[Array]
var n_encounters_finished: int
var last_room: Room
var camera_edge_x: float
var battle_pool: BattlePool

func _ready() -> void:
	#camera_edge_x = MapGenerator.X_DIST * (MapGenerator.ENCOUNTERS - 1)
	pass
	

#do I need to make a new _input method? Maybe I can avoid scrolling

func generate_new_map(rng: RNG) -> void:
	_clear_map_visuals()
	n_encounters_finished = 0
	last_room = null
	map_generator.battle_pool = battle_pool
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
		if usable_room == null or usable_room.room == null:
			continue
		usable_room.room_available = column_number == 0 and is_room_selectable(usable_room.room)

func unlock_next_rooms() -> void:
	for usable_room: UsableRoom in rooms.get_children():
		if usable_room == null or usable_room.room == null:
			continue
		usable_room.room_available = is_room_selectable(usable_room.room)

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
	if !is_room_selectable(room):
		push_warning("Map._on_usable_room_selected(): rejected invalid room selection at (%d,%d)." % [room.column if room != null else -1, room.row if room != null else -1])
		if last_room == null or n_encounters_finished <= 0:
			unlock_encounter_column(0)
		else:
			unlock_next_rooms()
		return

	for usable_room: UsableRoom in rooms.get_children():
		if usable_room == null:
			continue
		usable_room.room_available = false
	
	last_room = room
	n_encounters_finished = maxi(n_encounters_finished, int(room.column) + 1)
	Events.map_exited.emit(room)


func get_room_at(column: int, row: int) -> Room:
	if column < 0 or column >= map_data.size():
		return null
	var column_rooms: Array = map_data[column]
	if row < 0 or row >= column_rooms.size():
		return null
	return column_rooms[row] as Room


func is_room_selectable(room: Room) -> bool:
	if room == null:
		return false
	if int(room.column) < n_encounters_finished:
		return false
	if n_encounters_finished <= 0 or last_room == null:
		return int(room.column) == 0
	if int(room.column) != int(last_room.column) + 1:
		return false
	return last_room.next_rooms.has(room)


func set_active_room(room: Room) -> void:
	if room == null:
		return
	room.selected = true
	last_room = room
	n_encounters_finished = maxi(n_encounters_finished, int(room.column) + 1)

	for usable_room: UsableRoom in rooms.get_children():
		if usable_room == null or usable_room.room == null:
			continue
		if usable_room.room == room:
			usable_room.show_selected()


func restore_progress(cleared_room_coords: Array[Vector2i]) -> void:
	n_encounters_finished = 0
	last_room = null

	for coord in cleared_room_coords:
		var room := get_room_at(int(coord.x), int(coord.y))
		if room == null:
			continue
		room.selected = true
		n_encounters_finished = maxi(n_encounters_finished, int(room.column) + 1)
		if last_room == null or int(room.column) > int(last_room.column):
			last_room = room

	for usable_room: UsableRoom in rooms.get_children():
		if usable_room == null or usable_room.room == null:
			continue
		if usable_room.room.selected and usable_room.room.column < n_encounters_finished:
			usable_room.show_selected()

	if n_encounters_finished <= 0:
		unlock_encounter_column(0)
	elif last_room != null:
		unlock_next_rooms()


func _clear_map_visuals() -> void:
	for child in rooms.get_children():
		child.queue_free()
	for child in lines.get_children():
		child.queue_free()
