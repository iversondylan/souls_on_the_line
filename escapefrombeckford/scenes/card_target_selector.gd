extends Node2D

const ARC_POINTS := 8

@onready var area_2d: Area2D = $Area2D
@onready var card_arc: Line2D = $CanvasLayer/CardArc

var current_card: UsableCard
var targeting := false

func _ready() -> void:
	area_2d.card_target_selector = self
	Events.card_aim_started.connect(_on_card_aim_started)
	Events.card_aim_ended.connect(_on_card_aim_ended)
	Events.battlefield_aim_started.connect(_on_battlefield_aim_started)
	Events.battlefield_aim_ended.connect(_on_battlefield_aim_ended)

func _process(_delta: float) -> void:
	if not targeting:
		return
	
	area_2d.position = get_local_mouse_position()
	card_arc.points = _get_points()

func _get_points() -> Array:
	var points := []
	var start := current_card.global_position
	#start.x += (current_card.size.x /2)
	var target := get_local_mouse_position()
	var distance := (target - start)
	
	for i in range(ARC_POINTS):
		var t := (1.0 / ARC_POINTS) * i
		var x := start.x + (distance.x / ARC_POINTS) * i
		var y := start.y + ease_out_cubic(t) * distance.y
		points.append(Vector2(x, y))
	
	points.append(target)
	
	return points

func ease_out_cubic(number : float) -> float:
	return 1.0 - pow(1.0 - number, 3.0)

func _on_card_aim_started(card: UsableCard) -> void:
	if not card.card_data.is_single_targeted():
		return
	area_2d.set_collision_mask_value(4, false)
	area_2d.set_collision_mask_value(3, true)
	targeting = true
	area_2d.monitoring = true
	area_2d.monitorable = true
	current_card = card
	#card

func _on_card_aim_ended(_card: UsableCard) -> void:
	targeting = false
	card_arc.clear_points()
	area_2d.position = Vector2.ZERO
	area_2d.monitoring = false
	area_2d.monitorable = false
	current_card = null

func _on_battlefield_aim_started(card: UsableCard) -> void:
	if not card.card_data.target_type == CardData.TargetType.BATTLEFIELD:
		return
	area_2d.set_collision_mask_value(3, false)
	area_2d.set_collision_mask_value(4, true)
	targeting = true
	area_2d.monitoring = true
	area_2d.monitorable = true
	current_card = card

func _on_battlefield_aim_ended(_card: UsableCard) -> void:
	targeting = false
	card_arc.clear_points()
	area_2d.position = Vector2.ZERO
	area_2d.monitoring = false
	area_2d.monitorable = false
	current_card = null

func _on_area_2d_area_entered(area: Area2D) -> void:
	if !current_card or !targeting:
		return
	
	if not current_card.targets.has(area):
		
		current_card.targets.append(area)

func _on_area_2d_area_exited(area: Area2D) -> void:
	if !current_card or !targeting:
		return
	
	current_card.targets.erase(area)
