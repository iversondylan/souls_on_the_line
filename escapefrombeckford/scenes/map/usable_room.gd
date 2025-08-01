class_name UsableRoom extends Area2D

signal room_selected(room: Room)

const ICONS := {
	Room.RoomType.NOT_ASSIGNED: [null, Vector2.ONE],
	Room.RoomType.BATTLE: 
}

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	pass # Replace with function body.
