class_name Projectile
extends Node2D

@onready var anim: AnimationPlayer = get_node_or_null("Animation")

var _impacted := false


func _ready() -> void:
	_on_spawned()


func _on_spawned() -> void:
	pass


func play_impact() -> void:
	if _impacted:
		return
	_impacted = true

	if anim != null and anim.has_animation("impact"):
		anim.play("impact")
		anim.animation_finished.connect(_on_impact_finished, CONNECT_ONE_SHOT)
	else:
		_finish_projectile()


func _on_impact_finished(_anim_name: StringName) -> void:
	_finish_projectile()


func _finish_projectile() -> void:
	queue_free()
