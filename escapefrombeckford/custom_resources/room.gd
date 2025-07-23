class_name Room extends Resource

enum RoomType {NOT_ASSIGNED, BATTLE, TREASURE, REST, SHOP, BOSS}

@export var type: RoomType
@export var row: int
@export var column: int
@export var position: Vector2
@export var next_rooms: Array[Room]
@export var selected := false

func _to_string() -> String:
	return "%s (%s)" % [column, RoomType.keys()[type][0]]
