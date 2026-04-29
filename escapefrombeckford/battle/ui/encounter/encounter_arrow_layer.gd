class_name EncounterArrowLayer extends Control

const DEFAULT_ARROW_OFFSET := Vector2(0, -90)

@export var arrow_scene: PackedScene = preload("res://battle/ui/encounter/encounter_bobbing_arrow.tscn")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func clear_arrows() -> void:
	for child in get_children():
		child.queue_free()

func point_to_node(anchor: Node, offset: Vector2 = DEFAULT_ARROW_OFFSET, clear_existing := true) -> void:
	if anchor == null or !is_instance_valid(anchor):
		return
	point_to_position(_get_node_screen_position(anchor), offset, clear_existing)

func point_to_nodes(anchors: Array, offset: Vector2 = DEFAULT_ARROW_OFFSET, clear_existing := true) -> void:
	if clear_existing:
		clear_arrows()
	for anchor in anchors:
		if anchor == null or !is_instance_valid(anchor):
			continue
		point_to_position(_get_node_screen_position(anchor), offset, false)

func point_to_position(screen_position: Vector2, offset: Vector2 = DEFAULT_ARROW_OFFSET, clear_existing := true) -> void:
	if clear_existing:
		clear_arrows()
	var arrow := _make_arrow()
	if arrow == null:
		return
	add_child(arrow)
	arrow.point_at(screen_position, offset)

func _make_arrow() -> Node:
	if arrow_scene == null:
		return null
	return arrow_scene.instantiate()

func _get_node_screen_position(anchor: Node) -> Vector2:
	if anchor is Control:
		var control := anchor as Control
		return control.get_global_rect().get_center()
	if anchor is Node2D:
		var node_2d := anchor as Node2D
		return node_2d.get_global_transform_with_canvas().origin
	return Vector2.ZERO
