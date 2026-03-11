# perspective_card.gd

class_name PerspectiveCard extends Node2D

var up_left: Vector2 = Vector2(0,0)
var up_right: Vector2 = Vector2(1,0)
var down_right: Vector2 = Vector2(1,1)
var down_left: Vector2 = Vector2(0,1)
var squeeze: float = 0
var tween_time: float = 0.55
#var point_a_old: Vector2 = Vector2(200.0,200.0)
#var point_b_old: Vector2 = Vector2(1000.0,600.0)
@onready var sprite_2d: Sprite2D = $Sprite2D

#func _ready() -> void:
	#zoom_card(point_a_old, point_b_old)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	sprite_2d.material.set_shader_parameter('up_left',Vector2(0-squeeze, 0+10*squeeze**2.0))
	sprite_2d.material.set_shader_parameter('up_right',Vector2(1+squeeze, 0+10*squeeze**2.0))
	sprite_2d.material.set_shader_parameter('down_right',Vector2(1-squeeze, 1-10*squeeze**2.0))
	sprite_2d.material.set_shader_parameter('down_left',Vector2(0+squeeze, 1-10*squeeze**2.0))
	sprite_2d.scale = Vector2(1-25*squeeze**2.0,1-25*squeeze**2.0)

func zoom_card(point_a: Vector2, point_b: Vector2) -> void:
	squeeze = -0.1
	position = point_a
	var dx: float = point_b.x - point_a.x
	var dy: float = point_b.y - point_a.y
	sprite_2d.rotation = atan(-dx/dy)
	
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).set_parallel()
	tween.tween_property(self, "squeeze", 0.1, tween_time)
	tween.tween_property(self, "position", point_b, tween_time)
	#tween.tween_property(sprite_2d, "scale", Vector2(0.4+10*squeeze**2.0,0.4+10*squeeze**2.0), tween_time)
	tween.finished.connect(
		func(): queue_free()
	)
	
