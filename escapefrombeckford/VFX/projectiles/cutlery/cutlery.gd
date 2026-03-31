class_name Cutlery
extends Projectile

@onready var sprite: Sprite2D = $Sprite

const FORK_PATH := "res://_assets/sprites/effects/projectiles/vintagefork.PNG"
const KNIFE_PATH := "res://_assets/sprites/effects/projectiles/vintageknife.PNG"

var _rng := RandomNumberGenerator.new()


func _on_spawned() -> void:
	_rng.randomize()
	if sprite == null:
		return
	if _rng.randi_range(0, 1) == 0:
		sprite.texture = load(FORK_PATH) as Texture2D
	else:
		sprite.texture = load(KNIFE_PATH) as Texture2D
