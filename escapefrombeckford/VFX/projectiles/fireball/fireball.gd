class_name Fireball
extends Node2D

@onready var sprite: Sprite2D = $Sprite
@onready var particles: GPUParticles2D = $Particles
@onready var anim: AnimationPlayer = $Animation

var _impacted := false


func _ready() -> void:
	# Safety defaults
	if sprite:
		sprite.visible = true
	if particles:
		particles.emitting = true

	# Play spawn animation immediately
	if anim and anim.has_animation("grow_in"):
		anim.play("grow_in")


## Called by attack sequence when the projectile reaches its target.
## This should NOT apply damage — visuals only.
func play_impact() -> void:
	if _impacted:
		return
	_impacted = true

	# Stop continuous motion visuals
	if particles:
		particles.emitting = false

	if anim and anim.has_animation("impact"):
		anim.play("impact")
		# Clean up when animation finishes
		anim.animation_finished.connect(_on_impact_finished, CONNECT_ONE_SHOT)
	else:
		# Fallback: no impact animation
		queue_free()


func _on_impact_finished(_anim_name: StringName) -> void:
	queue_free()
