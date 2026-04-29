extends Node2D

@export var duration := 0.75
@export var particle_linger := 0.8
@export var effect_size := Vector2(256, 256)

var elapsed := 0.0
var _done := false

@onready var particles: GPUParticles2D = $CloudParticles
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var smoke_poof_rect: ColorRect = $SmokePoofRect


func _ready() -> void:
	configure_fx(effect_size)
	if smoke_poof_rect.material != null:
		smoke_poof_rect.material = smoke_poof_rect.material.duplicate()
		smoke_poof_rect.material.set_shader_parameter("progress", 0.0)
	if particles != null:
		particles.emitting = true
	if animation_player != null and animation_player.has_animation(&"poof"):
		animation_player.play(&"poof")


func _process(delta: float) -> void:
	elapsed += delta
	var t := clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
	if smoke_poof_rect.material != null:
		smoke_poof_rect.material.set_shader_parameter("progress", t)

	if !_done and t >= 1.0:
		_done = true
		if particles != null:
			particles.emitting = false

	if elapsed >= duration + particle_linger:
		queue_free()


func configure_fx(size: Vector2) -> void:
	effect_size = Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	if smoke_poof_rect != null:
		smoke_poof_rect.size = effect_size
		smoke_poof_rect.position = -effect_size * 0.5
		smoke_poof_rect.pivot_offset = effect_size * 0.5
	if particles != null:
		particles.position = Vector2.ZERO
