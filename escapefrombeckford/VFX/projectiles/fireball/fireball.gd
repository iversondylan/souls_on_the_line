class_name Fireball
extends Projectile

@onready var sprite: Sprite2D = $Sprite
@onready var particles: GPUParticles2D = $Particles


func _on_spawned() -> void:
	# Safety defaults
	if sprite:
		sprite.visible = true
	if particles:
		particles.emitting = true

	# Play spawn animation immediately
	if anim and anim.has_animation("grow_in"):
		anim.play("grow_in")

func play_impact() -> void:
	# Stop continuous motion visuals
	if particles:
		particles.emitting = false
	super.play_impact()
